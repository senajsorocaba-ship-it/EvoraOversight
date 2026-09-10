#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Motor de Execução do Briefing Matinal (camada externa)
=========================================================================
Este é o elo entre o BLOCO 4 (evora_briefing_motor_mvp_v1.sql, já aplicado no
Supabase) e um briefing REAL, com texto redigido. Ele não reimplementa nada
que já existe:

  · a montagem dos 7 blocos continua 100% dentro do Postgres
    (evora_montar_blocos_briefing / evora_gerar_briefing_diario, BLOCO 4);
  · a persona "Bia" e as regras de redação (Cláusula de Caráter Travado,
    formato dos blocos, freio humano) são adaptadas de
    D:\\motor\\montador_briefing_evora.py — generalizadas aqui para QUALQUER
    tenant (lendo tenants.nome_autoridade/cargo/partido/perfil), em vez do
    "vereadora Tatiane Costa" fixo do protótipo original;
  · a renderização markdown → HTML é adaptada de
    D:\\motor\\render_briefing_evora.py (mesmo algoritmo simples, sem libs
    externas), só trocando o cabeçalho fixo pelo nome do tenant.

O QUE ESTE SCRIPT FAZ, EM ORDEM:
  1. Chama evora_gerar_briefing_diario(tenant_id, mundo, data) via PostgREST,
     autenticado com a service_role key — a mesma função SQL do BLOCO 4, que
     já faz upsert em `briefings` e grava a auditoria. Não duplica essa lógica.
  2. Lê de volta a linha gravada (os 7 blocos) e o perfil do tenant.
  3. Pede à API da Claude (SDK oficial `anthropic`) para redigir o texto do
     briefing a partir SOMENTE desses blocos — nunca inventa o que a etapa 1
     não forneceu; blocos "pendente_integracao_externa"/"sem_dado_hoje" saem
     como "sem registro hoje", nunca preenchidos por suposição.
  4. Renderiza o markdown em HTML e grava markdown/html/modelo_ia/custo_estimado
     de volta na MESMA linha (UPDATE, não INSERT — não cria duplicata).
  5. NÃO dá ciência nem entrega nada: `ciencia_por`/`ciencia_em`/`entregue_em`
     ficam como estavam (v10.8: a leitura chega às 06:45 sem isso; ciência é
     exigida só antes de qualquer ato de efeito externo). O freio humano
     continua sendo uma ação humana na aplicação, fora deste script.

SEGURANÇA — LEIA ANTES DE RODAR:
  · A service_role key do Supabase IGNORA o RLS. Este script só pode rodar em
    ambiente de SERVIDOR de confiança (sua máquina, um cron, uma function) —
    NUNCA em navegador, app mobile, ou qualquer lugar que um usuário final
    acesse. Nunca commit a chave no repositório.
  · Chaves vêm SOMENTE de variáveis de ambiente. Este script nunca imprime,
    loga nem grava a service_role key ou a ANTHROPIC_API_KEY em lugar nenhum.
  · tenant_id/mundo são exigidos como PARÂMETRO EXPLÍCITO (mesma regra de
    falha fechada do BLOCO 4) — não há um "modo padrão" que rode para todos
    os tenants sem dizer qual.

DEPENDÊNCIA (única): SDK oficial da Anthropic.
    pip install anthropic
(A chamada à API da Claude usa o SDK oficial, não HTTP cru — é a exigência
padrão para qualquer integração com a API da Anthropic. A parte que fala com
o Supabase usa só a biblioteca padrão do Python, via REST/PostgREST, para não
adicionar uma dependência pesada só para isso.)

VARIÁVEIS DE AMBIENTE OBRIGATÓRIAS:
    SUPABASE_URL                 ex.: https://xxxxxxxx.supabase.co
    SUPABASE_SERVICE_ROLE_KEY    a chave service_role (NUNCA a anon/public)
    ANTHROPIC_API_KEY            chave da API da Anthropic (sk-ant-...)

VARIÁVEIS OPCIONAIS:
    ANTHROPIC_MODEL_BRIEFING     default: claude-opus-5

USO:
    python evora_motor_execucao.py --tenant-id <uuid> --mundo gabinete
    python evora_motor_execucao.py --tenant-id <uuid> --mundo gabinete --data 2026-08-09
    python evora_motor_execucao.py --todos --mundo gabinete
        (processa todo tenant com ativo=true; usado pelo agendador diário,
        .github/workflows/briefing-diario.yml — falha de um tenant não
        interrompe os demais, só reflete no exit code no final)
"""

import argparse
import html
import json
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import date

MODELO_PADRAO = "claude-opus-5"  # ver shared/models.md do skill claude-api
MAX_TOKENS = 8000
EFFORT = "medium"  # geração de texto de rotina; não é tarefa agentic/código

# Preços de referência (USD por milhão de tokens) do modelo usado — só para
# preencher briefings.custo_estimado como estimativa; ajuste se trocar de modelo.
PRECO_INPUT_MTOK = 5.0
PRECO_OUTPUT_MTOK = 25.0
PRECO_CACHE_ESCRITA_MTOK = PRECO_INPUT_MTOK * 1.25
PRECO_CACHE_LEITURA_MTOK = PRECO_INPUT_MTOK * 0.1


# ---------------------------------------------------------------------
# 0. Configuração / ambiente
# ---------------------------------------------------------------------
class ConfigError(SystemExit):
    pass


def carregar_ambiente():
    faltando = [
        nome
        for nome in ("SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "ANTHROPIC_API_KEY")
        if not os.environ.get(nome)
    ]
    if faltando:
        raise ConfigError(
            "Variáveis de ambiente ausentes: " + ", ".join(faltando) + ".\n"
            "Defina-as no ambiente do SERVIDOR (nunca em código-fonte). Veja o "
            "arquivo .env.example para o que cada uma precisa conter."
        )
    return {
        "supabase_url": os.environ["SUPABASE_URL"].rstrip("/"),
        "supabase_key": os.environ["SUPABASE_SERVICE_ROLE_KEY"],
        "anthropic_key": os.environ["ANTHROPIC_API_KEY"],
        "modelo": os.environ.get("ANTHROPIC_MODEL_BRIEFING", MODELO_PADRAO),
    }


# ---------------------------------------------------------------------
# 1. Cliente PostgREST mínimo (só stdlib) — fala com o Supabase
# ---------------------------------------------------------------------
def _rest_request(method, url, service_key, body=None):
    dados = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(
        url,
        data=dados,
        method=method,
        headers={
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
            "Content-Type": "application/json",
            "Prefer": "return=representation",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            corpo = r.read().decode("utf-8")
            return json.loads(corpo) if corpo else None
    except urllib.error.HTTPError as e:
        detalhe = e.read().decode("utf-8", errors="replace")[:500]
        raise SystemExit(
            f"Erro do Supabase ({e.code}) em {method} {url.split('?')[0]}: {detalhe}"
        )


def rpc_gerar_briefing(cfg, tenant_id, mundo, data_referencia):
    """Chama a função SQL do BLOCO 4 — não reimplementa a agregação aqui."""
    payload = {"p_tenant_id": tenant_id, "p_mundo": mundo}
    if data_referencia:
        payload["p_data_referencia"] = data_referencia
    url = f"{cfg['supabase_url']}/rest/v1/rpc/evora_gerar_briefing_diario"
    resultado = _rest_request("POST", url, cfg["supabase_key"], payload)
    if not resultado:
        raise SystemExit("evora_gerar_briefing_diario não retornou um id de briefing.")
    return resultado  # PostgREST devolve o uuid escalar puro


def buscar_briefing(cfg, briefing_id):
    url = f"{cfg['supabase_url']}/rest/v1/briefings?id=eq.{briefing_id}&select=*"
    linhas = _rest_request("GET", url, cfg["supabase_key"])
    if not linhas:
        raise SystemExit(f"Briefing {briefing_id} não encontrado após a geração.")
    return linhas[0]


def buscar_tenant(cfg, tenant_id):
    url = (
        f"{cfg['supabase_url']}/rest/v1/tenants?id=eq.{tenant_id}"
        "&select=nome_autoridade,cargo,partido,municipio_sede,uf,perfil,ativo"
    )
    linhas = _rest_request("GET", url, cfg["supabase_key"])
    if not linhas:
        raise SystemExit(f"Tenant {tenant_id} não encontrado.")
    return linhas[0]


def listar_tenants_ativos(cfg):
    """Usado pelo modo --todos. Mesmo filtro que evora_gerar_briefing_diario
    já aplica sozinho (tenants.ativo) — não filtra por operacional/
    ciencia_travas de propósito (ver evora_motor_execucao.py --help e
    CLAUDE.md, seção do agendador, para o porquê)."""
    url = f"{cfg['supabase_url']}/rest/v1/tenants?select=id,nome_autoridade&ativo=eq.true"
    return _rest_request("GET", url, cfg["supabase_key"]) or []


def atualizar_briefing(cfg, briefing_id, markdown, html_final, modelo, custo):
    url = f"{cfg['supabase_url']}/rest/v1/briefings?id=eq.{briefing_id}"
    corpo = {
        "markdown": markdown,
        "html": html_final,
        "modelo_ia": modelo,
        "custo_estimado": round(custo, 4),
    }
    _rest_request("PATCH", url, cfg["supabase_key"], corpo)


# ---------------------------------------------------------------------
# 2. A "Bia" — persona e regras, adaptadas de D:\motor\montador_briefing_evora.py
#    mas generalizadas por tenant (nada fixo tipo "Tatiane Costa" aqui).
# ---------------------------------------------------------------------
def montar_prompt_sistema(tenant):
    cargo = tenant.get("cargo") or "autoridade"
    partido = f" ({tenant['partido']})" if tenant.get("partido") else ""
    local = ", ".join(filter(None, [tenant.get("municipio_sede"), tenant.get("uf")]))
    perfil = tenant.get("perfil") or {}
    temas = perfil.get("temas_prioritarios") or perfil.get("temas") or []
    temas_txt = ", ".join(temas) if temas else "não cadastrados no perfil"

    return f"""Você é a Bia, Gestora do Gabinete na plataforma Évora Oversight.
Sua tarefa: escrever o Briefing Matinal de {tenant['nome_autoridade']}, {cargo}{partido}
({local}), a partir SOMENTE dos dados estruturados fornecidos pelo usuário —
já agregados pelo banco de dados nos 7 blocos canônicos do Évora.

REGRAS INVIOLÁVEIS (Cláusula de Caráter Travado):
- Não invente nada. Use apenas os dados recebidos.
- Quando um bloco vier com status "pendente_integracao_externa" ou
  "sem_dado_hoje", diga explicitamente que não há registro hoje para aquele
  bloco — nunca preencha com suposição, estimativa ou exemplo genérico.
- Cada item relevante deve citar a fonte/origem quando o dado trouxer uma. Se
  o item tiver um link (campo "link" ou "url" nos dados), inclua-o SEMPRE
  como link em markdown — `[nome da fonte](link)`, ex.: `[G1](https://...)`.
  Nunca cite uma fonte com link disponível sem incluir o link: é o que
  permite conferir a informação na origem (CVI — cada afirmação vem com
  veículo, data e link, nunca só a palavra da Bia).
- Tom factual, conciso, respeitoso. Sem opinião pessoal, sem recomendação de voto.
- O bloco de Fiscalização é sempre "indício para acompanhar, NUNCA acusação".
- O bloco "Movimento sugerido" traz sugestões que dependem de APROVAÇÃO HUMANA
  (freio humano) — nunca dê a entender que algo já foi decidido, aprovado ou enviado.
- Não mencione nem infira dados de identificação de cidadãos (protegidos por
  LGPD) — eles não estão neste pacote de dados de propósito.

FORMATO DE SAÍDA (markdown, exatamente estes 7 blocos, nesta ordem):
# Briefing Matinal — {{data}}
## Resumo do dia
## Radar de Nomeações
## Fiscalização
## Pulso da Câmara/DO
## Demandas
## Imprensa
## Movimento sugerido (72h)

Temas prioritários cadastrados no perfil: {temas_txt}.
Seja objetivo — isto é lido às 6h45 no celular."""


def montar_mensagem_usuario(blocos, data_referencia):
    partes = [f"Dados de hoje ({data_referencia}), já agregados pelo banco (BLOCO 4)."]
    for bloco in blocos:
        partes.append(
            f"\n[BLOCO {bloco['ordem']} — {bloco['titulo']} | dono: {bloco['dono_agente']} "
            f"| status: {bloco['status']}]\n"
            f"Aviso do banco: {bloco['aviso']}\n"
            f"Itens: {json.dumps(bloco['itens'], ensure_ascii=False)}"
        )
    partes.append(
        "\nEscreva o Briefing Matinal seguindo o formato e as regras do sistema. "
        f"Data de hoje: {data_referencia}."
    )
    return "\n".join(partes)


# ---------------------------------------------------------------------
# 3. Chamada à API da Claude — SDK oficial (não HTTP cru)
# ---------------------------------------------------------------------
def redigir_briefing(cfg, sistema, mensagem):
    try:
        import anthropic
    except ImportError:
        raise SystemExit(
            "Falta o SDK oficial da Anthropic. Rode: pip install anthropic"
        )

    client = anthropic.Anthropic(api_key=cfg["anthropic_key"])
    resposta = client.messages.create(
        model=cfg["modelo"],
        max_tokens=MAX_TOKENS,
        system=sistema,
        output_config={"effort": EFFORT},
        messages=[{"role": "user", "content": mensagem}],
    )

    if resposta.stop_reason == "refusal":
        raise SystemExit(
            "A API recusou a geração (stop_reason=refusal). "
            f"Detalhe: {getattr(resposta, 'stop_details', None)}"
        )

    texto = "\n".join(b.text for b in resposta.content if b.type == "text").strip()
    if not texto:
        raise SystemExit("A API respondeu sem texto utilizável.")

    u = resposta.usage
    custo = (
        (u.input_tokens or 0) * PRECO_INPUT_MTOK
        + (u.output_tokens or 0) * PRECO_OUTPUT_MTOK
        + (getattr(u, "cache_creation_input_tokens", 0) or 0) * PRECO_CACHE_ESCRITA_MTOK
        + (getattr(u, "cache_read_input_tokens", 0) or 0) * PRECO_CACHE_LEITURA_MTOK
    ) / 1_000_000
    return texto, custo


# ---------------------------------------------------------------------
# 4. Render markdown → HTML — adaptado de D:\motor\render_briefing_evora.py
# ---------------------------------------------------------------------
CSS = """
:root{--navy:#213A5C;--gold:#B5985A;--cream:#F4F1EA;--paper:#FBFAF6;--ink:#23272e;--mut:#5b6470;--line:#E4DED1}
*{box-sizing:border-box;margin:0;padding:0}
body{background:var(--cream);color:var(--ink);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;line-height:1.55}
.wrap{max-width:620px;margin:0 auto;padding-bottom:50px}
.top{background:var(--navy);color:#fff;padding:18px}
.bname{font-family:Georgia,serif;letter-spacing:.26em;font-size:12px}
.bname b{color:var(--gold)}
.btitle{font-family:Georgia,serif;font-size:22px;margin-top:8px}
.bsub{font-size:12.5px;color:#b9c6d6;margin-top:2px}
.block{margin:16px 14px 0;background:var(--paper);border:1px solid var(--line);border-radius:9px;padding:14px 16px}
h1{display:none}
h2{font-family:Georgia,serif;font-size:16px;color:var(--navy);margin:0 0 8px;padding-bottom:6px;border-bottom:1px solid var(--line)}
ul{margin:4px 0 0 18px}li{font-size:14px;margin:5px 0}
p{font-size:14px;margin:6px 0}
strong{color:var(--navy)}
a{color:var(--navy);text-decoration:underline;text-decoration-color:var(--gold)}
.foot{margin:18px 14px 0;font-size:11px;color:var(--mut);text-align:center;line-height:1.6}
"""


def _md_para_html(md):
    out, in_ul = [], False
    for raw in md.splitlines():
        line = raw.rstrip()
        if not line.strip():
            if in_ul:
                out.append("</ul>")
                in_ul = False
            continue

        def bold(s):
            s = html.escape(s)
            s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
            # Link em markdown, [texto](url) — o CVI exige veículo+data+link
            # em cada afirmação (ver montar_prompt_sistema); sem isto, o link
            # que a Bia escreve fica preso entre colchetes, texto morto, não
            # clicável. Roda DEPOIS do html.escape() de propósito: um "&" que
            # apareça na URL (comum em query string) já sai como "&amp;",
            # forma correta dentro de um atributo href.
            s = re.sub(
                r"\[([^\]]+)\]\((https?://[^\s)]+)\)",
                r'<a href="\2" target="_blank" rel="noopener noreferrer">\1</a>',
                s,
            )
            return s

        if line.startswith("# "):
            if in_ul:
                out.append("</ul>")
                in_ul = False
            out.append(f"<h1>{bold(line[2:])}</h1>")
        elif line.startswith("## "):
            if in_ul:
                out.append("</ul>")
                in_ul = False
            out.append(f'<div class="block"><h2>{bold(line[3:])}</h2>')
        elif line.lstrip().startswith(("- ", "* ")):
            if not in_ul:
                out.append("<ul>")
                in_ul = True
            out.append(f"<li>{bold(line.lstrip()[2:])}</li>")
        else:
            if in_ul:
                out.append("</ul>")
                in_ul = False
            out.append(f"<p>{bold(line)}</p>")
    if in_ul:
        out.append("</ul>")
    corpo = "\n".join(out)
    corpo = corpo.replace('<div class="block"><h2>', '</div><div class="block"><h2>')
    if corpo.startswith("</div>"):
        corpo = corpo[6:]
    corpo += "</div>"
    return corpo


def renderizar_html(markdown, tenant, data_referencia):
    corpo = _md_para_html(markdown)
    nome = html.escape(tenant["nome_autoridade"])
    return f"""<!DOCTYPE html><html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Briefing Matinal — {nome}</title><style>{CSS}</style></head><body>
<div class="wrap">
  <div class="top">
    <div class="bname">ÉVORA <b>OVERSIGHT</b></div>
    <div class="btitle">Briefing Matinal — {nome}</div>
    <div class="bsub">{data_referencia} · 06h45 · gerado pela Bia a partir de dados do gabinete</div>
  </div>
  {corpo}
  <div class="foot">ÉVORA OVERSIGHT · cada item com origem declarada · uso interno do gabinete<br>
  Indício é para verificação humana — nunca acusação. Pendente aprovação humana antes de qualquer entrega.</div>
</div></body></html>"""


# ---------------------------------------------------------------------
# 5. Orquestração
# ---------------------------------------------------------------------
def processar_tenant(cfg, tenant_id, mundo, data=None):
    """Gera+redige+salva o briefing de UM tenant/mundo. Mesma lógica de
    sempre (única lógica que existe) — usada tanto pelo modo --tenant-id
    quanto, em loop, pelo modo --todos."""
    print("→ Gerando/atualizando o briefing via BLOCO 4 (evora_gerar_briefing_diario)...")
    briefing_id = rpc_gerar_briefing(cfg, tenant_id, mundo, data)
    print(f"  briefing_id: {briefing_id}")

    briefing = buscar_briefing(cfg, briefing_id)
    tenant = buscar_tenant(cfg, tenant_id)
    if not tenant.get("ativo", True):
        raise SystemExit(f"Tenant {tenant_id} está inativo — abortando.")

    data_referencia = briefing["data_referencia"]
    blocos = briefing["blocos"]

    print("→ A Bia está redigindo o briefing (API da Claude)...")
    sistema = montar_prompt_sistema(tenant)
    mensagem = montar_mensagem_usuario(blocos, data_referencia)
    markdown, custo = redigir_briefing(cfg, sistema, mensagem)
    html_final = renderizar_html(markdown, tenant, data_referencia)

    print("→ Salvando markdown/html na linha do briefing (UPDATE, sem duplicar)...")
    atualizar_briefing(cfg, briefing_id, markdown, html_final, cfg["modelo"], custo)

    print("\n" + "=" * 64)
    print("✓ Briefing redigido e salvo.")
    print(f"  tenant:          {tenant['nome_autoridade']}")
    print(f"  mundo:           {mundo}")
    print(f"  data_referencia: {data_referencia}")
    print(f"  briefing_id:     {briefing_id}")
    print(f"  modelo:          {cfg['modelo']}")
    print(f"  custo estimado:  US$ {custo:.4f}")
    for b in blocos:
        print(f"    bloco {b['ordem']} {b['titulo']:<24} status={b['status']}")
    print("=" * 64)
    print(
        "⚠ FREIO HUMANO: ciencia_por/ciencia_em NÃO foram preenchidos por este "
        "script. Nenhum ato de efeito externo deve ocorrer até que um usuário com "
        "alçada_aprovacao aprove este briefing na aplicação."
    )


def main():
    ap = argparse.ArgumentParser(description="Motor de execução do briefing matinal (Évora Oversight)")
    alvo = ap.add_mutually_exclusive_group(required=True)
    alvo.add_argument("--tenant-id", help="uuid de um único tenant (gabinete)")
    alvo.add_argument(
        "--todos",
        action="store_true",
        help="processa todo tenant com ativo=true (usado pelo agendador diário)",
    )
    ap.add_argument("--mundo", required=True, choices=["gabinete", "campanha"])
    ap.add_argument("--data", default=None, help="YYYY-MM-DD; default: hoje (servidor)")
    args = ap.parse_args()

    cfg = carregar_ambiente()

    if not args.todos:
        processar_tenant(cfg, args.tenant_id, args.mundo, args.data)
        return

    tenants = listar_tenants_ativos(cfg)
    print(f"→ {len(tenants)} tenant(s) ativo(s) encontrado(s).")
    falharam = []
    for t in tenants:
        print(f"\n--- tenant {t['nome_autoridade']} ({t['id']}) ---")
        try:
            processar_tenant(cfg, t["id"], args.mundo, args.data)
        except (SystemExit, Exception) as e:
            # Exception, não só SystemExit: erros do SDK da Anthropic (ex.:
            # anthropic.AuthenticationError) e qualquer outra falha inesperada
            # também não podem derrubar o loop — um tenant ruim não pode
            # impedir os demais de receber o briefing.
            print(f"  ✗ FALHOU: {e}")
            falharam.append((t["id"], t["nome_autoridade"]))

    print(f"\n{len(tenants) - len(falharam)}/{len(tenants)} briefing(s) gerado(s) com sucesso.")
    if falharam:
        raise SystemExit(f"{len(falharam)} tenant(s) falharam: {falharam}")


if __name__ == "__main__":
    main()
