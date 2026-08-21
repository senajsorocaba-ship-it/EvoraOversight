#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Atlas Municipal (Fase 7, Anexo 16)
================================================================
CLI operacional para semear/validar/aplicar/importar o Atlas Municipal
direto no Postgres via PostgREST, usando a service_role key — mesmo
padrão de `evora_ingestao_coletores.py`. Sem UI, sem papel novo: quem
opera isto é o time interno, por terminal, igual ao cadastro manual de
tenant (mesma operação que já é feita hoje via curl/dashboard).

Substitui o protótipo em arquivo `atlas municipal.py` (órfão em
_versoes_anteriores/), que gravava um `atlas_<slug>.json` por cidade.
Aqui a mesma lógica grava em `municipios`/`municipio_fontes`/
`municipio_trilha` (BLOCO 1, tabelas 14-16).

TRAVAS (Anexo 16, herdadas do protótipo):
  - Atlas é camada COMPARTILHADA da plataforma: fatos públicos sobre a
    CIDADE. Nada de tenant aqui — temas, pessoas de interesse e F3
    moram no perfil isolado (tenants.perfil).
  - F3 nunca entra no Atlas — trava em Python aqui E em CHECK no banco
    (municipio_fontes_nunca_f3), redundância deliberada.
  - Selo 'verificado' exige fonte nomeada.
  - mapa_politico_factual não tem ingestão nesta fase — não existe
    coletor de TSE no repositório. Não fabricar dado.

USO
---
    python evora_atlas_municipal.py semear "Itu" SP
    python evora_atlas_municipal.py validar sorocaba-sp
    python evora_atlas_municipal.py aplicar <tenant-id> sorocaba-sp
    python evora_atlas_municipal.py importar "atlas sorocaba-sp.json"

VARIÁVEIS DE AMBIENTE OBRIGATÓRIAS (as mesmas do evora_motor_execucao.py):
    SUPABASE_URL
    SUPABASE_SERVICE_ROLE_KEY

DEPENDÊNCIA: nenhuma além da biblioteca padrão do Python.
"""

import argparse
import json
import os
import re
import sys
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime

CNAES_MIDIA = {
    "5812": "edição de jornais",
    "5813": "edição de revistas",
    "6010": "rádio",
    "6021": "TV aberta",
    "6022": "TV por assinatura (programadoras)",
    "6319": "portais/provedores de conteúdo",
    "5911": "produção audiovisual",
    "5912": "pós-produção audiovisual",
}

SELOS_VALIDOS = {"verificado", "a_confirmar", "descartado"}

PENDENCIAS_GO_LIVE = [
    "Verificação humana da mídia local (obrigatória — decisão D6)",
    "Confirmar plataforma do Diário Oficial e conector COM correspondente",
    "Preencher CNPJs dos órgãos para o PNCP",
]


def _slug(texto):
    t = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode()
    return re.sub(r"-{2,}", "-", re.sub(r"[^a-zA-Z0-9]+", "-", t).strip("-").lower())


def _campo(valor="", fonte="", selo="a_confirmar"):
    """Todo campo do Atlas carrega valor + fonte + selo CVI + data.
    Selo 'verificado' só com fonte nomeada — a função trava isso."""
    if selo == "verificado" and not fonte:
        raise ValueError("Selo 'verificado' exige fonte nomeada (Anexo 16 §4).")
    return {"valor": valor, "fonte": fonte, "selo": selo,
            "data": datetime.now().strftime("%Y-%m-%d") if valor else ""}


def _traduzir_selo(selo_bruto):
    """O protótipo em arquivo usa 'a confirmar' (com espaço); o enum do banco
    (evora_selo_cvi) usa 'a_confirmar' (underscore). Traduz genericamente —
    não assume que todo import futuro já vem no formato certo."""
    if not selo_bruto:
        return "a_confirmar"
    s = selo_bruto.strip().lower().replace(" ", "_")
    if s not in SELOS_VALIDOS:
        raise ValueError(f"Selo desconhecido: {selo_bruto!r} (esperado um de {SELOS_VALIDOS}).")
    return s


def carregar_ambiente():
    faltando = [
        nome for nome in ("SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY")
        if not os.environ.get(nome)
    ]
    if faltando:
        raise SystemExit(
            "Variáveis de ambiente ausentes: " + ", ".join(faltando) + ".\n"
            "Defina-as no ambiente (nunca em código-fonte). Veja .env.example."
        )
    return {
        "supabase_url": os.environ["SUPABASE_URL"].rstrip("/"),
        "supabase_key": os.environ["SUPABASE_SERVICE_ROLE_KEY"],
    }


def _rest(method, path, cfg, body=None, prefer=None, params=None):
    url = cfg["supabase_url"] + "/rest/v1/" + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    headers = {
        "apikey": cfg["supabase_key"],
        "Authorization": f"Bearer {cfg['supabase_key']}",
        "Content-Type": "application/json",
    }
    if prefer:
        headers["Prefer"] = prefer
    dados = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=dados, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            corpo = r.read().decode("utf-8")
            return json.loads(corpo) if corpo else None
    except urllib.error.HTTPError as e:
        detalhe = e.read().decode("utf-8", errors="replace")[:500]
        raise SystemExit(f"Erro do Supabase ({e.code}) em {method} {url.split('?')[0]}: {detalhe}")


def _buscar_municipio(cfg, slug):
    linhas = _rest("GET", "municipios", cfg, params={"slug": f"eq.{slug}", "select": "*"})
    return linhas[0] if linhas else None


# ---------------------------------------------------------------------------
# 1. SEMEAR — esqueleto de cidade nova (nada inventado; tudo "a_confirmar")
# ---------------------------------------------------------------------------
def semear(cfg, municipio, uf):
    slug = _slug(f"{municipio}-{uf}")
    if _buscar_municipio(cfg, slug):
        raise SystemExit(f"Município '{slug}' já existe no Atlas — semear de novo apagaria dado curado. Aborta.")

    linha = {
        "nome": municipio,
        "uf": uf.upper(),
        "slug": slug,
        "codigo_ibge": None,
        "identificacao": {
            "codigo_ibge": _campo(), "regiao": _campo(),
            "microrregiao": _campo(), "populacao": _campo(),
        },
        "executivo": {
            "prefeito": _campo(), "vice": _campo(), "cnpj_prefeitura": _campo(),
            "portal": _campo(), "secretarias": [],
        },
        "legislativo": {
            "num_vereadores": _campo(), "presidente_camara": _campo(),
            "composicao_partidaria": [], "portal": _campo(), "sistema_tramitacao": _campo(),
        },
        "diario_oficial": {
            "onde_publica": _campo(), "formato": _campo(),
            "plataforma": _campo(), "periodicidade": _campo(), "conector_com": _campo(),
        },
        "contratacoes": {"cnpjs_pncp": []},
        "mapa_politico_factual": {
            "ultima_eleicao_municipal": _campo(), "eleitos": [],
        },
    }
    criado = _rest("POST", "municipios", cfg, body=linha, prefer="return=representation")
    municipio_id = criado[0]["id"]

    _rest("POST", "municipio_trilha", cfg, body={
        "municipio_id": municipio_id,
        "acao": "semeadura do esqueleto",
        "autor": "evora_atlas_municipal.py",
        "obs": "tudo 'a_confirmar'",
    }, prefer="return=minimal")

    print(f"✓ Município '{slug}' semeado (id={municipio_id}). Tudo está 'a_confirmar'.")
    print("  Pendências antes do go-live desta cidade:")
    for p in PENDENCIAS_GO_LIVE:
        print("   ·", p)


# ---------------------------------------------------------------------------
# 2. VALIDAR — regras travadas do Anexo 16
# ---------------------------------------------------------------------------
def validar(cfg, slug):
    m = _buscar_municipio(cfg, slug)
    if not m:
        raise SystemExit(f"Município '{slug}' não encontrado no Atlas.")

    fontes = _rest("GET", "municipio_fontes", cfg, params={"municipio_id": f"eq.{m['id']}", "select": "*"}) or []
    trilha = _rest("GET", "municipio_trilha", cfg, params={"municipio_id": f"eq.{m['id']}", "select": "id"}) or []

    problemas = []
    for v in fontes:
        if v["nivel"] == "F3":
            problemas.append(f"PROIBIDO: veículo F3 no Atlas ({v['nome']}) — banco já bloquearia isto via CHECK.")
        if v["nivel"] == "F2" and not v.get("evidencia_cobertura"):
            problemas.append(f"F2 sem evidência de cobertura ({v['nome']}).")
        if v.get("selo") == "verificado" and not v.get("fonte"):
            problemas.append(f"Selo 'verificado' sem fonte ({v['nome']}).")
    if not trilha:
        problemas.append("Município sem trilha de edição (municipio_trilha vazio).")

    if problemas:
        print(f"✗ {len(problemas)} problema(s) em '{slug}':")
        for p in problemas:
            print("   ·", p)
        sys.exit(1)
    print(f"✓ '{slug}' passa nas regras do Anexo 16 ({len(fontes)} veículo(s), {len(trilha)} entrada(s) de trilha).")


# ---------------------------------------------------------------------------
# 3. APLICAR — cruza Atlas -> perfil do tenant (procedência 'atlas')
# ---------------------------------------------------------------------------
def aplicar(cfg, tenant_id, slug):
    m = _buscar_municipio(cfg, slug)
    if not m:
        raise SystemExit(f"Município '{slug}' não encontrado no Atlas.")

    tenants = _rest("GET", "tenants", cfg, params={"id": f"eq.{tenant_id}", "select": "id,perfil"})
    if not tenants:
        raise SystemExit(f"Tenant '{tenant_id}' não encontrado.")
    perfil = tenants[0]["perfil"] or {}

    fontes = _rest("GET", "municipio_fontes", cfg, params={
        "municipio_id": f"eq.{m['id']}", "ativa": "eq.true", "select": "*",
    }) or []

    mon = perfil.setdefault("monitoramento", {})
    detalhe = mon.setdefault("veiculos_detalhe", [])
    ja = {v.get("nome", "").lower() for v in detalhe if isinstance(v, dict)}

    aplicados = 0
    for v in fontes:
        if v["nome"].lower() in ja:
            continue
        detalhe.append({
            "nome": v["nome"], "url": v.get("url") or "",
            "nivel": v["nivel"], "cobertura": v.get("cobertura") or "",
            "identificacao": v.get("identificacao", "pendente"),
            "procedencia": "atlas",
            "selo": v.get("selo", "a_confirmar"),
        })
        aplicados += 1

    orgaos = mon.setdefault("orgaos", [])
    for item in (m.get("contratacoes") or {}).get("cnpjs_pncp", []):
        nome = item.get("orgao", "")
        if nome and nome not in orgaos:
            orgaos.append(nome)

    proc = perfil.setdefault("_procedencia", {})
    proc["monitoramento.veiculos"] = (
        f"atlas ({m['nome']}) — {aplicados} veículo(s) aplicado(s) em "
        f"{datetime.now().strftime('%Y-%m-%d')}; verificação humana antes do "
        f"go-live continua obrigatória (D6)"
    )

    _rest("PATCH", "tenants", cfg, body={"perfil": perfil},
          params={"id": f"eq.{tenant_id}"}, prefer="return=minimal")

    print(f"✓ {aplicados} veículo(s) do Atlas aplicados ao perfil do tenant {tenant_id}.")
    if aplicados == 0:
        print("  (Nenhum veículo novo — Atlas vazio ou tudo já constava no perfil.)")


# ---------------------------------------------------------------------------
# 4. IMPORTAR — migra um atlas_<slug>.json do protótipo em arquivo pro banco
# ---------------------------------------------------------------------------
def _data_iso(dd_mm_yyyy):
    if not dd_mm_yyyy:
        return None
    try:
        return datetime.strptime(dd_mm_yyyy.strip(), "%d/%m/%Y").strftime("%Y-%m-%dT00:00:00")
    except ValueError:
        return None


def _traduzir_campo(campo):
    """Traduz um {valor,fonte,selo,data} do formato do protótipo (selo com
    espaço) pro formato do banco (selo com underscore). Passa os demais
    campos como estão."""
    if not isinstance(campo, dict):
        return campo
    novo = dict(campo)
    if "selo" in novo:
        novo["selo"] = _traduzir_selo(novo["selo"])
    return novo


def _traduzir_secao(secao):
    """Aplica _traduzir_campo recursivamente numa seção do Atlas (dict de
    campos, alguns dos quais são listas de objetos com seus próprios campos)."""
    if isinstance(secao, dict):
        if set(secao.keys()) >= {"valor", "fonte", "selo"}:
            return _traduzir_campo(secao)
        return {k: _traduzir_secao(v) for k, v in secao.items()}
    if isinstance(secao, list):
        return [_traduzir_secao(item) for item in secao]
    return secao


def importar(cfg, caminho):
    with open(caminho, encoding="utf-8") as f:
        atlas = json.load(f)

    slug = atlas.get("slug") or _slug(f"{atlas['municipio']}-{atlas['uf']}")
    if _buscar_municipio(cfg, slug):
        raise SystemExit(f"Município '{slug}' já existe no Atlas — importar de novo apagaria dado curado. Aborta.")

    codigo_ibge = ((atlas.get("identificacao") or {}).get("codigo_ibge") or {}).get("valor") or None

    linha = {
        "nome": atlas["municipio"],
        "uf": atlas["uf"],
        "slug": slug,
        "codigo_ibge": codigo_ibge,
        "identificacao": _traduzir_secao(atlas.get("identificacao") or {}),
        "executivo": _traduzir_secao(atlas.get("executivo") or {}),
        "legislativo": _traduzir_secao(atlas.get("legislativo") or {}),
        "diario_oficial": _traduzir_secao(atlas.get("diario_oficial") or {}),
        "contratacoes": _traduzir_secao(atlas.get("contratacoes") or {}),
        "mapa_politico_factual": _traduzir_secao(
            {k: v for k, v in (atlas.get("mapa_politico_factual") or {}).items() if k != "_regra"}
        ),
    }
    criado = _rest("POST", "municipios", cfg, body=linha, prefer="return=representation")
    municipio_id = criado[0]["id"]
    print(f"✓ municipios: 1 linha ({slug}, id={municipio_id}).")

    veiculos = (atlas.get("midia") or {}).get("veiculos", [])
    n_fontes = 0
    for v in veiculos:
        linha_fonte = {
            "municipio_id": municipio_id,
            "nome": v["nome"],
            "url": v.get("url") or None,
            "nivel": v.get("nivel", "F2"),
            "cobertura": v.get("cobertura") or None,
            "evidencia_cobertura": v.get("evidencia_cobertura") or None,
            "cnpj": v.get("cnpj") or None,
            "situacao_receita": v.get("situacao_receita") or None,
            "cnae": v.get("cnae") or None,
            "cnae_descricao": v.get("cnae_descricao") or CNAES_MIDIA.get((v.get("cnae") or "")[:4]) or None,
            "identificacao": v.get("identificacao", "pendente"),
            "fonte": v.get("fonte") or None,
            "selo": _traduzir_selo(v.get("selo")),
            "proxima_revalidacao": None,
        }
        _rest("POST", "municipio_fontes", cfg, body=linha_fonte, prefer="return=minimal")
        n_fontes += 1
    print(f"✓ municipio_fontes: {n_fontes} linha(s).")

    trilha = atlas.get("_trilha", [])
    n_trilha = 0
    for t in trilha:
        obs = t.get("obs") or ""
        data_original = t.get("data")
        if data_original:
            obs = f"{obs} (data original do registro: {data_original})".strip()
        _rest("POST", "municipio_trilha", cfg, body={
            "municipio_id": municipio_id,
            "ocorrido_em": _data_iso(data_original),
            "acao": t.get("acao", "importação"),
            "autor": t.get("autor", "evora_atlas_municipal.py (importar)"),
            "obs": obs or None,
        }, prefer="return=minimal")
        n_trilha += 1
    if n_trilha == 0:
        _rest("POST", "municipio_trilha", cfg, body={
            "municipio_id": municipio_id,
            "acao": "importação do protótipo em arquivo",
            "autor": "evora_atlas_municipal.py (importar)",
            "obs": f"origem: {caminho}",
        }, prefer="return=minimal")
        n_trilha = 1
    print(f"✓ municipio_trilha: {n_trilha} linha(s).")

    pendencias = atlas.get("_pendencias_go_live") or PENDENCIAS_GO_LIVE
    print("  Pendências antes do go-live desta cidade (não persistidas, só aviso):")
    for p in pendencias:
        print("   ·", p)


def main():
    ap = argparse.ArgumentParser(description="Atlas Municipal (Fase 7, Anexo 16) — CLI operacional")
    sub = ap.add_subparsers(dest="comando", required=True)

    p_semear = sub.add_parser("semear", help="cria o esqueleto de uma cidade nova")
    p_semear.add_argument("municipio")
    p_semear.add_argument("uf")

    p_validar = sub.add_parser("validar", help="confere as regras do Anexo 16 pra uma cidade")
    p_validar.add_argument("slug")

    p_aplicar = sub.add_parser("aplicar", help="cruza o Atlas de uma cidade com o perfil de um tenant")
    p_aplicar.add_argument("tenant_id")
    p_aplicar.add_argument("slug")

    p_importar = sub.add_parser("importar", help="migra um atlas_<slug>.json do protótipo em arquivo pro banco")
    p_importar.add_argument("caminho")

    args = ap.parse_args()
    cfg = carregar_ambiente()

    if args.comando == "semear":
        semear(cfg, args.municipio, args.uf)
    elif args.comando == "validar":
        validar(cfg, args.slug)
    elif args.comando == "aplicar":
        aplicar(cfg, args.tenant_id, args.slug)
    elif args.comando == "importar":
        importar(cfg, args.caminho)


if __name__ == "__main__":
    main()
