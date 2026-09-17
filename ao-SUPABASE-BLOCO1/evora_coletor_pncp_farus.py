#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Coletor PNCP → FARUS (contratos confirmados, Manual v11.0)
==============================================================================
Diferente de `evora_coletor_farus.py` (busca geral por Google News, todo
item nasce e permanece `estado='nao_verificado'`, sem `farus_fontes`
nenhuma): este lê a API pública do PNCP — dado estruturado de origem
primária — e grava com `estado='confirmado'`, `verificado_por='motor'`.
Os dois coexistem: um é o "F1 honesto" de qualquer cidade sem curadoria
prévia, o outro é o F1 de verdade pra quem já liberou o PNCP como fonte.

ORIGEM: adaptado de um coletor de referência entregue com o "Caderno do
Programador" (acompanha o Manual Supremo v11.0, 16/09/2026) — o arquivo
original usava `psycopg2` com um DSN direto ao Postgres (`EVORA_DB`).
Convertido aqui pro mesmo padrão REST + `SUPABASE_SERVICE_ROLE_KEY` que
todo o resto deste diretório usa, pra não introduzir uma segunda forma de
autenticar nem uma dependência nova (`psycopg2-binary` não está em
`requirements.txt` e não devia precisar estar). O registro de execução
também mudou: o original gravava em `execucoes_coletor.jsonl`, um arquivo
local que não sobrevive entre execuções do GitHub Actions (runner
efêmero — exatamente o problema que o próprio arquivo original diz ter
resolvido pro CONTEÚDO, só que não resolveu pro log da execução). Aqui,
o progresso vai só pro stdout (o log do Actions já retém isso por 90
dias) — mesmo padrão de todo outro coletor deste diretório, nenhum dos
quais tem uma tabela de log de execução dedicada.

NÃO VERIFICADO NESTA SESSÃO CONTRA A API REAL — a URL/formato de campos
do PNCP (`https://pncp.gov.br/api/consulta/v1/contratos`) é a mesma que
`motor/coletor_pncp_evora.py` já usa (o próprio módulo admite no
cabeçalho: "endpoint/campos devem ser CONFIRMADOS na implementação real,
a API evolui"). Rode primeiro com `--ensaio` antes de confiar.

DECISÃO D6 (liberação humana de fonte) — TRAVA DE VERDADE, NÃO SÓ
DOCUMENTADA: este coletor RECUSA rodar para um território sem uma linha
em `farus_fontes` com `especie='contratacao'` e `estado='configurada'`
(`liberada_por`/`liberada_em` preenchidos). O coletor nunca cria nem
libera essa fonte sozinho — é decisão humana, registrada, uma vez por
território. Pra liberar (via `service_role`, fora deste script):

    POST /rest/v1/farus_fontes
    {"territorio_id": "<uuid>", "nome": "PNCP", "especie": "contratacao",
     "url": "https://pncp.gov.br", "estado": "configurada",
     "liberada_por": "<nome de quem decidiu>", "liberada_em": "<agora>"}

INDÍCIO, NUNCA ACUSAÇÃO: contratos com valor acima da mediana dos
comparáveis do período ganham uma nota de "indício para verificação" no
próprio `conteudo` do item — nunca uma afirmação de irregularidade, nunca
sobrepreço/fracionamento/má-fé (essas são conclusões humanas). Com menos
de 4 comparáveis, nada é sinalizado — mediana de poucos pontos é ruído,
não base de comparação.

VARIÁVEIS DE AMBIENTE: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (mesmas
dos coletores irmãos).

USO:
    python evora_coletor_pncp_farus.py --tenant-id <uuid> [--dias 7] [--ensaio]
    python evora_coletor_pncp_farus.py --todos [--dias 7]
        (mesma semântica --tenant-id/--todos dos coletores irmãos —
        território vem do município/uf do(s) tenant(s); falha de um
        território não interrompe os demais em modo --todos)
"""

import argparse
import json
import statistics
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import date, datetime, timedelta, timezone

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

BASE_PNCP = "https://pncp.gov.br/api/consulta/v1/contratos"
TEMPO_LIMITE = 45
CABECALHO = {"User-Agent": "Evora-Oversight/1.0 (coletor institucional)"}


# ---------------------------------------------------------------------
# 1. Busca na fonte
# ---------------------------------------------------------------------
def buscar_contratos(dias):
    """Consulta a API pública do PNCP. Devolve lista vazia em caso de
    falha — nunca levanta exceção pra fora. Briefing com os outros blocos
    é melhor que briefing nenhum."""
    fim = date.today()
    ini = fim - timedelta(days=dias)
    params = {
        "dataInicial": ini.strftime("%Y%m%d"),
        "dataFinal": fim.strftime("%Y%m%d"),
        "pagina": "1",
        "tamanhoPagina": "500",
    }
    url = f"{BASE_PNCP}?{urllib.parse.urlencode(params)}"
    try:
        req = urllib.request.Request(url, headers=CABECALHO)
        with urllib.request.urlopen(req, timeout=TEMPO_LIMITE) as r:
            dados = json.loads(r.read().decode("utf-8"))
    except urllib.error.URLError as e:
        print(f"  ! PNCP inacessível ({e.reason}) — pulando este território.")
        return []
    except Exception as e:
        print(f"  ! erro ao consultar o PNCP: {e}")
        return []

    itens = dados.get("data", dados) if isinstance(dados, dict) else dados
    return itens if isinstance(itens, list) else []


def normalizar(itens, municipio):
    """Achata a resposta do PNCP num formato estável. A API varia os nomes
    dos campos entre versões — cada campo tenta várias chaves. Se o PNCP
    mudar, degrada (campo vazio, honesto) em vez de quebrar."""
    out = []
    for it in itens:
        def g(*chaves):
            for k in chaves:
                if isinstance(it, dict) and it.get(k) not in (None, ""):
                    return it[k]
            return ""

        mun = str(g("municipioNome", "municipio", "nomeMunicipio"))
        if municipio and mun and municipio.lower() not in mun.lower():
            continue

        out.append({
            "numero": str(g("numeroControlePNCP", "numeroContrato", "numero")),
            "objeto": str(g("objetoContrato", "objeto", "descricaoObjeto")),
            "valor": float(g("valorGlobal", "valorInicial", "valor") or 0),
            "orgao": str(g("orgaoEntidadeRazaoSocial", "orgao", "nomeOrgao")),
            "fornecedor": str(g("nomeRazaoSocialFornecedor", "fornecedor", "nomeFornecedor")),
            "publicado": str(g("dataPublicacaoPncp", "dataPublicacao", "data"))[:10],
            "municipio": mun,
            "url": str(g("linkSistemaOrigem", "urlContrato", "")),
        })
    return out


# ---------------------------------------------------------------------
# 2. Indícios — a parte que exige mais cuidado (AFEx-g: indício, nunca acusação)
# ---------------------------------------------------------------------
def sinalizar_indicios(contratos, limiar=0.25):
    valores = [c["valor"] for c in contratos if c["valor"] > 0]
    if len(valores) < 4:
        for c in contratos:
            c["indicio"] = ""
        return contratos

    mediana = statistics.median(valores)
    for c in contratos:
        if c["valor"] > 0 and c["valor"] > mediana * (1 + limiar):
            desvio = (c["valor"] / mediana - 1) * 100
            c["indicio"] = (
                f"Valor {desvio:.0f}% acima da mediana dos contratos do período. "
                f"Base de comparação: mediana de {len(valores)} contratos no PNCP "
                f"(R$ {mediana:,.2f}). Fato verificável na fonte — verificação e "
                f"eventual questionamento são decisão humana, não deste coletor."
            )
        else:
            c["indicio"] = ""
    return contratos


def montar_texto(c):
    """Título precisa ser estável — entra no hash de deduplicação."""
    titulo = f"Contrato {c['numero']} — {c['objeto'][:160]}".strip()
    partes = [
        f"Órgão: {c['orgao']}" if c["orgao"] else "",
        f"Fornecedor: {c['fornecedor']}" if c["fornecedor"] else "",
        f"Valor: R$ {c['valor']:,.2f}" if c["valor"] else "",
        f"\nINDÍCIO PARA VERIFICAÇÃO: {c['indicio']}" if c["indicio"] else "",
    ]
    return titulo, "\n".join(p for p in partes if p)


# ---------------------------------------------------------------------
# 3. Orquestração por território
# ---------------------------------------------------------------------
def processar_tenant(cfg, tenant, dias, ensaio):
    municipio = (tenant.get("municipio_sede") or "").strip()
    uf = (tenant.get("uf") or "").strip()

    territorio_id = garantir_territorio(cfg, municipio, uf)
    garantir_vinculo_tenant(cfg, tenant["id"], territorio_id)

    fonte_id = buscar_fonte_configurada(cfg, territorio_id, "contratacao")
    if not fonte_id:
        raise SystemExit(
            f"Sem fonte 'contratacao' configurada para {municipio}-{uf} — "
            "cadastre o PNCP em farus_fontes com estado='configurada' e "
            "liberada_por/liberada_em preenchidos antes de rodar este "
            "coletor (ver docstring do módulo). Decisão D6: nenhuma fonte "
            "alimenta afirmação sem liberação humana registrada."
        )

    print(f"  território: {municipio}-{uf} ({territorio_id}) · fonte: {fonte_id}")

    brutos = buscar_contratos(dias)
    print(f"  PNCP devolveu {len(brutos)} contrato(s) no período")
    contratos = sinalizar_indicios(normalizar(brutos, municipio))
    indicios = [c for c in contratos if c["indicio"]]
    print(f"  {len(contratos)} de {municipio} · {len(indicios)} com indício")

    if not contratos:
        return 0

    linhas = []
    for c in contratos:
        titulo, conteudo = montar_texto(c)
        hash_conteudo = calcular_hash(cfg, titulo, conteudo)
        linhas.append({
            "territorio_id": territorio_id,
            "origem_aquisicao": "coleta_programada",
            "tenant_origem": None,
            "fonte_id": fonte_id,
            "especie": "contratacao",
            "url": c["url"] or None,
            "titulo": titulo,
            "conteudo": conteudo,
            "publicado_em": c["publicado"] if len(c["publicado"]) == 10 else None,
            "estado": "confirmado",
            "verificado_por": "motor",
            "verificado_em": datetime.now(timezone.utc).isoformat(),
            "hash_conteudo": hash_conteudo,
        })

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
    ap = argparse.ArgumentParser(description="Coletor PNCP → FARUS (Évora Oversight)")
    alvo = ap.add_mutually_exclusive_group(required=True)
    alvo.add_argument("--tenant-id", help="uuid de um único tenant (usa o município dele)")
    alvo.add_argument("--todos", action="store_true", help="processa todo tenant com ativo=true")
    ap.add_argument("--dias", type=int, default=7, help="janela de busca em dias (default: 7)")
    ap.add_argument("--ensaio", action="store_true", help="mostra o que gravaria, sem gravar")
    args = ap.parse_args()

    cfg = carregar_ambiente()

    if not args.todos:
        tenant = buscar_tenant(cfg, args.tenant_id)
        if not tenant.get("ativo", True):
            raise SystemExit(f"Tenant {args.tenant_id} está inativo — abortando.")
        processar_tenant(cfg, tenant, args.dias, args.ensaio)
        return

    tenants = listar_tenants_ativos(cfg)
    print(f"→ {len(tenants)} tenant(s) ativo(s) encontrado(s).")
    falharam = []
    for i, t in enumerate(tenants):
        print(f"\n--- tenant {t['nome_autoridade']} ({t['id']}) ---")
        try:
            processar_tenant(cfg, t, args.dias, args.ensaio)
        except (SystemExit, Exception) as e:
            print(f"  ✗ FALHOU/pulado: {e}")
            falharam.append((t["id"], t["nome_autoridade"]))
        if i < len(tenants) - 1:
            time.sleep(1)

    print(f"\n{len(tenants) - len(falharam)}/{len(tenants)} tenant(s) processado(s) com sucesso.")
    # Território sem fonte configurada é esperado (a maioria hoje) — não é
    # falha do coletor, é a trava D6 fazendo o que deve fazer. Por isso
    # este script nunca sai com código de erro só por falta de fonte;
    # sai != 0 apenas se TODOS os tenants falharam (sinal de problema real,
    # não de ausência de liberação humana).
    if falharam and len(falharam) == len(tenants):
        raise SystemExit(f"Todos os {len(tenants)} tenant(s) falharam: {falharam}")


if __name__ == "__main__":
    main()
