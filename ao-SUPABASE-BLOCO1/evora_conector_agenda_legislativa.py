#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Conector da Agenda Legislativa (Manual Supremo v11.0)
==============================================================================
Lê a "Ordem do Dia Completa" das sessões plenárias publicadas pelo sistema
Câmara Sem Papel (ASP.NET WebForms, tabela server-renderizada — sem API
JSON) e grava cada matéria como um item `especie='ato_oficial'` no acervo
FARUS, com `estado='confirmado'` (dado estruturado de fonte primária
pública, sem interpretação).

VERIFICADO NESTA SESSÃO, contra a página real de Sorocaba (curl direto,
sem WAF nesta subdomínio — diferente do site institucional da Câmara que
a Fase 9 já documentou como bloqueado por WAF):
  - `sessoes.aspx` lista as sessões numa `<table id="tabela">`, uma `<tr>`
    por sessão, com tipo+número, data, horário, "publicada em", e o link
    pra `sessao-leitura.aspx?id=<id>&tip=1` (Ordem do Dia Completa, HTML).
  - `sessao-leitura.aspx?id=<id>&tip=1` lista as matérias numa
    `<table id="...grv_sessoes_proposicoes">`, uma `<td>` por matéria,
    com Ordem, tipo+número+ano, nº do processo, data de apresentação,
    autor, ementa, fase e ação — exatamente os campos que o Caderno do
    Programador pede, MENOS partido (não aparece nesta página; ver
    "O QUE NÃO ESTÁ AQUI" abaixo).

O QUE NÃO ESTÁ AQUI (limite honesto, não contornado por invenção):
  - PARTIDO do autor: não aparece na Ordem do Dia — só o nome, com link
    pra `consulta-producao.aspx?autor=<id>`. Cruzar isso exigiria mais
    uma requisição por autor por matéria; deixado de fora por ora — o
    campo não é preenchido, nunca é adivinhado.
  - O "achado de maior valor" do Caderno — comparar "Ordem do Dia
    Resumida" com "Resumida Atualizada" pra ver o que entrou/saiu da
    pauta — NÃO está implementado aqui. Essas duas são links diretos
    pra PDF (confirmado nesta sessão), não HTML — extrair texto
    estruturado de um PDF pra comparar duas versões é um problema
    diferente (precisaria de uma biblioteca de PDF, nenhuma faz parte
    deste projeto hoje) que não foi verificado contra o PDF real. Fica
    documentado como pendência explícita, não como "feito".
  - Só a sessão MAIS RECENTE da listagem é processada por padrão
    (`--sessoes N` pega as N mais recentes). Sem paginação pra trás.
  - Só verificado contra Sorocaba. `--dominio` aceita outra cidade no
    mesmo sistema (Câmara Sem Papel é usado por várias câmaras
    municipais), mas nenhuma outra foi testada — se a estrutura variar,
    o parser degrada pra zero itens (não inventa campo), não quebra.

DECISÃO D6 (liberação humana de fonte) — mesma trava do coletor PNCP:
recusa rodar pra um território sem `farus_fontes` com
`especie='ato_oficial'` e `estado='configurada'`. Pra liberar (via
service_role, fora deste script):

    POST /rest/v1/farus_fontes
    {"territorio_id": "<uuid>", "nome": "Câmara Sem Papel — Sorocaba",
     "especie": "ato_oficial", "url": "https://sorocaba.camarasempapel.com.br",
     "estado": "configurada", "liberada_por": "<nome>", "liberada_em": "<agora>"}

VARIÁVEIS DE AMBIENTE: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.

USO:
    python evora_conector_agenda_legislativa.py --tenant-id <uuid> [--sessoes 3] [--ensaio]
    python evora_conector_agenda_legislativa.py --todos [--sessoes 3]
"""

import argparse
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

from evora_coletor_farus import (
    buscar_fonte_configurada,
    calcular_hash,
    garantir_territorio,
    garantir_vinculo_tenant,
)
from evora_coletor_mencoes import (
    _rest_request,
    buscar_tenant,
    carregar_ambiente,
    listar_tenants_ativos,
)

DOMINIO_PADRAO = "sorocaba.camarasempapel.com.br"
TEMPO_LIMITE = 30
CABECALHO = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
}


def _baixar(url):
    req = urllib.request.Request(url, headers=CABECALHO)
    with urllib.request.urlopen(req, timeout=TEMPO_LIMITE) as r:
        return r.read().decode("utf-8", errors="replace")


# ---------------------------------------------------------------------
# 1. Listagem de sessões — extrai id/tipo/número/data/horário/publicada
# ---------------------------------------------------------------------
RE_LINHA_SESSAO = re.compile(
    r"<strong>\s*(?P<tipo>[A-ZÀ-Úa-zà-ú]+)\s*N°\s*(?P<numero>\d+)\s*</strong>.*?"
    r"sessao-leitura\.aspx\?id=(?P<id>\d+)&tip=1.*?"
    r"<strong>\s*Data:\s*</strong>\s*(?P<data>\d{2}/\d{2}/\d{4}).*?"
    r"<strong>\s*Horário\s*</strong>\s*(?P<horario>\d{2}:\d{2}).*?"
    r"Publicada em:\s*</strong>\s*(?P<publicada>[\d/: ]+?)\s*<",
    re.DOTALL,
)


def listar_sessoes(dominio, limite):
    """Devolve as `limite` sessões mais recentes da listagem (ordem em que
    o site já as publica — não reordena, não pagina pra trás)."""
    html = _baixar(f"https://{dominio}/spl/sessoes.aspx")
    sessoes = []
    for m in RE_LINHA_SESSAO.finditer(html):
        sessoes.append({
            "id": m.group("id"),
            "tipo": m.group("tipo").strip(),
            "numero": m.group("numero"),
            "data": m.group("data"),
            "horario": m.group("horario"),
            "publicada_em": m.group("publicada").strip(),
        })
        if len(sessoes) >= limite:
            break
    return sessoes


# ---------------------------------------------------------------------
# 2. Ordem do Dia Completa de uma sessão — uma matéria por bloco <td>
# ---------------------------------------------------------------------
RE_ORDEM = re.compile(
    r"<strong>Ordem:</strong>\s*(?P<ordem>\d+)&nbsp;\s*"
    r'<a href="processo\.aspx\?id=(?P<processo_id>\d+)"[^>]*>\s*<strong>\s*'
    r"(?P<tipo>[^<]*?)\s*N°\s*(?P<numero>\d+)\s*/(?P<ano>\d+)\s*</strong></a>",
    re.DOTALL,
)
RE_NPROCESSO = re.compile(r"Nº Processo:\s*<a>\s*(?P<n>[^<]+?)\s*</a>", re.DOTALL)
RE_AUTOR = re.compile(r"<strong>Autor:</strong>\s*<span[^>]*><a[^>]*>(?P<autor>[^<]+)</a></span>", re.DOTALL)
RE_EMENTA = re.compile(r'<a href="https://[^"]*?/processo\.aspx\?id=\d+">\s*(?P<ementa>[^<]+?)\s*</a>', re.DOTALL)
RE_FASE = re.compile(r"<strong>Fase:\s*</strong>\s*(?P<fase>[^<]+?)\s*</div>", re.DOTALL)
RE_ACAO = re.compile(r"<strong>Ação:\s*</strong>\s*(?P<acao>[^<]+?)\s*</div>", re.DOTALL)


def extrair_materias(html):
    """Cada matéria é um bloco <td>...</td> dentro da tabela de proposições
    da sessão — divide por esse limite real (verificado contra a página ao
    vivo) e aplica um regex por campo dentro de cada bloco."""
    inicio = html.find('id="ContentPlaceHolder1_grv_sessoes_proposicoes"')
    if inicio == -1:
        return []
    corpo = html[inicio:]
    blocos = re.split(r"</td>\s*</tr>\s*<tr>\s*<td>", corpo)

    materias = []
    for bloco in blocos:
        m_ordem = RE_ORDEM.search(bloco)
        if not m_ordem:
            continue  # não é um bloco de matéria (cabeçalho/rodapé da tabela)

        m_proc = RE_NPROCESSO.search(bloco)
        m_autor = RE_AUTOR.search(bloco)
        m_ementa = RE_EMENTA.search(bloco)
        m_fase = RE_FASE.search(bloco)
        m_acao = RE_ACAO.search(bloco)

        materias.append({
            "ordem": m_ordem.group("ordem"),
            "processo_id": m_ordem.group("processo_id"),
            "tipo": m_ordem.group("tipo").strip(),
            "numero": m_ordem.group("numero"),
            "ano": m_ordem.group("ano"),
            "num_processo": m_proc.group("n").strip() if m_proc else "",
            "autor": m_autor.group("autor").strip() if m_autor else "",
            "ementa": m_ementa.group("ementa").strip() if m_ementa else "",
            "fase": m_fase.group("fase").strip() if m_fase else "",
            "acao": m_acao.group("acao").strip() if m_acao else "",
        })
    return materias


# ---------------------------------------------------------------------
# 3. Monta o item FARUS
# ---------------------------------------------------------------------
def montar_texto(sessao, materia, dominio):
    titulo = (
        f"{materia['tipo']} Nº {materia['numero']}/{materia['ano']} — "
        f"Ordem {materia['ordem']}, Sessão {sessao['tipo']} Nº {sessao['numero']}"
    ).strip()
    partes = [
        f"Nº Processo: {materia['num_processo']}" if materia["num_processo"] else "",
        f"Autor: {materia['autor']}" if materia["autor"] else "",
        f"Ementa: {materia['ementa']}" if materia["ementa"] else "",
        f"Fase: {materia['fase']}" if materia["fase"] else "",
        f"Ação: {materia['acao']}" if materia["acao"] else "",
        f"Sessão {sessao['tipo']} Nº {sessao['numero']} — {sessao['data']} {sessao['horario']}",
    ]
    conteudo = "\n".join(p for p in partes if p)
    url = f"https://{dominio}/processo.aspx?id={materia['processo_id']}"
    return titulo, conteudo, url


def _data_iso(data_br):
    """'17/09/2026' -> '2026-09-17'. Devolve None se não bater o formato —
    honesto, não força uma data que não foi lida."""
    try:
        d, m, a = data_br.split("/")
        return f"{a}-{m}-{d}"
    except ValueError:
        return None


# ---------------------------------------------------------------------
# 4. Orquestração por território
# ---------------------------------------------------------------------
def processar_tenant(cfg, tenant, dominio, n_sessoes, ensaio):
    municipio = (tenant.get("municipio_sede") or "").strip()
    uf = (tenant.get("uf") or "").strip()

    territorio_id = garantir_territorio(cfg, municipio, uf)
    garantir_vinculo_tenant(cfg, tenant["id"], territorio_id)

    fonte_id = buscar_fonte_configurada(cfg, territorio_id, "ato_oficial")
    if not fonte_id:
        raise SystemExit(
            f"Sem fonte 'ato_oficial' configurada para {municipio}-{uf} — "
            "cadastre a Câmara Sem Papel em farus_fontes com "
            "estado='configurada' e liberada_por/liberada_em preenchidos "
            "antes de rodar este conector (ver docstring do módulo)."
        )

    print(f"  território: {municipio}-{uf} ({territorio_id}) · fonte: {fonte_id}")

    sessoes = listar_sessoes(dominio, n_sessoes)
    print(f"  {len(sessoes)} sessão(ões) encontrada(s) em {dominio}")

    linhas = []
    for sessao in sessoes:
        html = _baixar(f"https://{dominio}/spl/sessao-leitura.aspx?id={sessao['id']}&tip=1")
        materias = extrair_materias(html)
        print(f"    sessão {sessao['tipo']} Nº{sessao['numero']} ({sessao['data']}): "
              f"{len(materias)} matéria(s)")

        for materia in materias:
            titulo, conteudo, url = montar_texto(sessao, materia, dominio)
            hash_conteudo = calcular_hash(cfg, titulo, conteudo)
            linhas.append({
                "territorio_id": territorio_id,
                "origem_aquisicao": "coleta_programada",
                "tenant_origem": None,
                "fonte_id": fonte_id,
                "especie": "ato_oficial",
                "url": url,
                "titulo": titulo,
                "conteudo": conteudo,
                "publicado_em": _data_iso(sessao["data"]),
                "estado": "confirmado",
                "verificado_por": "motor",
                "verificado_em": datetime.now(timezone.utc).isoformat(),
                "hash_conteudo": hash_conteudo,
            })

    if not linhas:
        print("  nenhuma matéria encontrada.")
        return 0

    if ensaio:
        print(f"\n  [ENSAIO] {len(linhas)} item(ns) seriam gravados. Amostra:")
        for l in linhas[:3]:
            print(f"    · {l['titulo'][:88]}")
        return 0

    url = cfg["supabase_url"] + "/rest/v1/farus_itens?on_conflict=territorio_id,hash_conteudo"
    _rest_request(
        "POST", url, cfg["supabase_key"], linhas,
        prefer="resolution=merge-duplicates,return=minimal",
    )
    print(f"  {len(linhas)} item(ns) gravado(s)/atualizado(s) no acervo FARUS (confirmado).")
    return len(linhas)


def main():
    ap = argparse.ArgumentParser(description="Conector da Agenda Legislativa → FARUS (Évora Oversight)")
    alvo = ap.add_mutually_exclusive_group(required=True)
    alvo.add_argument("--tenant-id", help="uuid de um único tenant (usa o município dele)")
    alvo.add_argument("--todos", action="store_true", help="processa todo tenant com ativo=true")
    ap.add_argument("--dominio", default=DOMINIO_PADRAO,
                     help=f"domínio do sistema Câmara Sem Papel (default: {DOMINIO_PADRAO} — único verificado)")
    ap.add_argument("--sessoes", type=int, default=3, help="quantas sessões mais recentes ler (default: 3)")
    ap.add_argument("--ensaio", action="store_true", help="mostra o que gravaria, sem gravar")
    args = ap.parse_args()

    cfg = carregar_ambiente()

    if not args.todos:
        tenant = buscar_tenant(cfg, args.tenant_id)
        if not tenant.get("ativo", True):
            raise SystemExit(f"Tenant {args.tenant_id} está inativo — abortando.")
        processar_tenant(cfg, tenant, args.dominio, args.sessoes, args.ensaio)
        return

    tenants = listar_tenants_ativos(cfg)
    print(f"→ {len(tenants)} tenant(s) ativo(s) encontrado(s).")
    falharam = []
    for i, t in enumerate(tenants):
        print(f"\n--- tenant {t['nome_autoridade']} ({t['id']}) ---")
        try:
            processar_tenant(cfg, t, args.dominio, args.sessoes, args.ensaio)
        except (SystemExit, Exception) as e:
            print(f"  ✗ FALHOU/pulado: {e}")
            falharam.append((t["id"], t["nome_autoridade"]))
        if i < len(tenants) - 1:
            time.sleep(1)

    print(f"\n{len(tenants) - len(falharam)}/{len(tenants)} tenant(s) processado(s) com sucesso.")
    if falharam and len(falharam) == len(tenants):
        raise SystemExit(f"Todos os {len(tenants)} tenant(s) falharam: {falharam}")


if __name__ == "__main__":
    main()
