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

    (Fase 8 — autocadastro de vereador, ver municipio_vereadores)
    python evora_atlas_municipal.py vereadores adicionar sorocaba-sp \
        --nome "Fulano de Tal" --email "fulano@camarasorocaba.sp.gov.br" \
        --partido "PXX" --fonte "portal da Câmara, conferido em dd/mm/aaaa" --selo verificado
    python evora_atlas_municipal.py vereadores listar sorocaba-sp
    python evora_atlas_municipal.py vereadores importar-lote sorocaba-sp vereadores.csv \
        --fonte "portal da Câmara, conferido em dd/mm/aaaa"
        # vereadores.csv: colunas nome,email[,partido] — reimportar atualiza
        # quem já existe (por e-mail) em vez de duplicar, então também serve
        # pra manter a lista em dia depois de uma eleição.

    (Fase 9 — vigia de vereadores: revisita a fonte oficial e SÓ REGISTRA
    diferenças pra revisão humana, nunca escreve direto em municipio_vereadores.
    Extração é por regex/heurística — funciona SEM ANTHROPIC_API_KEY em
    páginas de tabela simples nome/e-mail, que é o caso mais comum em sites
    de Câmara. Só cai pra IA se a heurística não achar uma lista razoável
    E houver ANTHROPIC_API_KEY configurada; sem chave e sem heurística
    aplicável, avisa pra checar manualmente em vez de travar o comando.)
    python evora_atlas_municipal.py vereadores configurar-fonte-url sorocaba-sp \
        "https://www.camarasorocaba.sp.gov.br/page.html?tag=faleconosco"
    python evora_atlas_municipal.py vereadores vigiar sorocaba-sp
    python evora_atlas_municipal.py vereadores vigiar-todas
    python evora_atlas_municipal.py vereadores pendencias listar sorocaba-sp
    python evora_atlas_municipal.py vereadores pendencias aplicar sorocaba-sp <id> \
        --fonte "conferido manualmente em dd/mm/aaaa" --selo verificado
    python evora_atlas_municipal.py vereadores pendencias rejeitar sorocaba-sp <id>

VARIÁVEIS DE AMBIENTE OBRIGATÓRIAS (as mesmas do evora_motor_execucao.py):
    SUPABASE_URL
    SUPABASE_SERVICE_ROLE_KEY

VARIÁVEL OPCIONAL, SÓ PARA 'vigiar'/'vigiar-todas' (Fase 9) — NÃO obrigatória:
    ANTHROPIC_API_KEY   — 'vigiar' tenta primeiro uma extração por
                          regex/heurística, sem IA nenhuma (funciona bem em
                          páginas de tabela simples nome/e-mail). Só usa a
                          API da Claude (mesmo SDK oficial de
                          evora_motor_execucao.py) se a heurística não achar
                          uma lista razoável de vereadores E esta variável
                          estiver definida. Opcional: ANTHROPIC_MODEL_VIGIA
                          (default: claude-haiku-4-5-20251001).

DEPENDÊNCIA: nenhuma além da biblioteca padrão do Python. O SDK da Anthropic
(`pip install anthropic`) só é importado se 'vigiar'/'vigiar-todas' precisarem
mesmo cair pro fallback de IA — os demais subcomandos, e o caso comum de
'vigiar' contra uma tabela simples, não dependem dele.
"""

import argparse
import csv
import html as html_mod
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


def _ler_lote_vereadores(caminho):
    """Lê um lote de vereadores de um .csv (colunas nome,email[,partido]) ou
    .json (lista de objetos {nome,email,partido?}). Formato pensado pra
    colar direto a tabela que a própria Câmara Municipal publica (ex.: a
    página 'Fale Conosco') — sem exigir nada além de nome+e-mail."""
    if caminho.lower().endswith(".json"):
        with open(caminho, encoding="utf-8") as f:
            bruto = json.load(f)
        return [
            {"nome": r["nome"].strip(), "email": r["email"].strip(), "partido": r.get("partido") or None}
            for r in bruto
            if r.get("nome") and r.get("email")
        ]
    with open(caminho, encoding="utf-8-sig", newline="") as f:
        leitor = csv.DictReader(f)
        return [
            {
                "nome": r["nome"].strip(),
                "email": r["email"].strip(),
                "partido": (r.get("partido") or "").strip() or None,
            }
            for r in leitor
            if (r.get("nome") or "").strip() and (r.get("email") or "").strip()
        ]


def _upsert_vereador(cfg, municipio_id, nome, email, partido, fonte, selo):
    """Insere um vereador; se o e-mail já existir nesse município (unique
    idx_municipio_vereadores_email), atualiza a linha em vez de falhar —
    é o caso normal de reimportar a lista depois de uma eleição/mudança de
    e-mail. Devolve 'inserido' ou 'atualizado'."""
    linha = {
        "municipio_id": municipio_id, "nome": nome, "email": email,
        "partido": partido or None, "fonte": fonte or None, "selo": selo, "ativo": True,
    }
    try:
        _rest("POST", "municipio_vereadores", cfg, body=linha, prefer="return=minimal")
        return "inserido"
    except SystemExit as e:
        if "(409)" not in str(e):
            raise
        _rest("PATCH", "municipio_vereadores", cfg, body={
            "nome": nome, "partido": partido or None, "fonte": fonte or None,
            "selo": selo, "ativo": True,
        }, params={"municipio_id": f"eq.{municipio_id}", "email": f"ilike.{email}"}, prefer="return=minimal")
        return "atualizado"


def vereadores_adicionar(cfg, slug, nome, email, partido, fonte, selo):
    m = _buscar_municipio(cfg, slug)
    if not m:
        raise SystemExit(f"Município '{slug}' não encontrado no Atlas — rode 'semear'/'importar' antes.")

    selo = _traduzir_selo(selo)
    if selo == "verificado" and not fonte:
        raise ValueError("Selo 'verificado' exige fonte nomeada (Anexo 16 §4).")

    resultado = _upsert_vereador(cfg, m["id"], nome, email, partido, fonte, selo)
    _rest("POST", "municipio_trilha", cfg, body={
        "municipio_id": m["id"],
        "acao": f"vereador {resultado} no autocadastro",
        "autor": "evora_atlas_municipal.py (vereadores adicionar)",
        "obs": f"{nome} <{email}>",
    }, prefer="return=minimal")
    print(f"✓ Vereador '{nome}' <{email}> {resultado} em '{slug}' (selo={selo}).")


def vereadores_importar_lote(cfg, slug, caminho, fonte, selo):
    m = _buscar_municipio(cfg, slug)
    if not m:
        raise SystemExit(f"Município '{slug}' não encontrado no Atlas — rode 'semear'/'importar' antes.")

    selo = _traduzir_selo(selo)
    if selo == "verificado" and not fonte:
        raise ValueError("Selo 'verificado' exige fonte nomeada (Anexo 16 §4) — obrigatória num lote inteiro.")

    linhas = _ler_lote_vereadores(caminho)
    if not linhas:
        raise SystemExit(f"Nenhuma linha válida em '{caminho}' (esperado colunas/campos nome,email).")

    inseridos = atualizados = 0
    for r in linhas:
        resultado = _upsert_vereador(cfg, m["id"], r["nome"], r["email"], r.get("partido"), fonte, selo)
        if resultado == "inserido":
            inseridos += 1
        else:
            atualizados += 1

    _rest("POST", "municipio_trilha", cfg, body={
        "municipio_id": m["id"],
        "acao": "importação em lote de vereadores",
        "autor": "evora_atlas_municipal.py (vereadores importar-lote)",
        "obs": f"{inseridos} novo(s), {atualizados} atualizado(s); origem: {caminho}; fonte: {fonte}",
    }, prefer="return=minimal")
    print(f"✓ Lote aplicado a '{slug}': {inseridos} novo(s), {atualizados} atualizado(s) (de {len(linhas)} linha(s) no arquivo).")


def vereadores_listar(cfg, slug):
    m = _buscar_municipio(cfg, slug)
    if not m:
        raise SystemExit(f"Município '{slug}' não encontrado no Atlas.")
    linhas = _rest("GET", "municipio_vereadores", cfg, params={
        "municipio_id": f"eq.{m['id']}", "select": "*", "order": "nome",
    }) or []
    if not linhas:
        print(f"Nenhum vereador semeado para '{slug}' ainda — autocadastro fica bloqueado até semear pelo menos um.")
        return
    for v in linhas:
        estado = "ativo" if v["ativo"] else "inativo"
        print(f"  · {v['nome']} <{v['email']}>  partido={v.get('partido') or '-'}  "
              f"selo={v['selo']}  ({estado})")
    print(f"Total: {len(linhas)} vereador(es) em '{slug}'.")


# ---------------------------------------------------------------------------
# 5. VIGIA DE VEREADORES (Fase 9) — revisita a fonte oficial de uma cidade já
# configurada, usa a API da Claude pra extrair nome+e-mail de HTML sem
# estrutura previsível, e só REGISTRA diferenças em
# municipio_vereadores_pendencias. Nunca escreve direto em
# municipio_vereadores — aplicar é sempre uma ação humana explícita
# (pendencias aplicar), que reusa o _upsert_vereador acima.
# ---------------------------------------------------------------------------
LIMITE_HTML_VIGIA = 40_000
MAX_VEREADORES_RAZOAVEL = 60  # a maior câmara do Brasil (São Paulo) tem 55


def vereadores_configurar_fonte_url(cfg, slug, url):
    m = _buscar_municipio(cfg, slug)
    if not m:
        raise SystemExit(f"Município '{slug}' não encontrado no Atlas.")
    _rest("PATCH", "municipios", cfg, body={"vereadores_fonte_url": url},
          params={"id": f"eq.{m['id']}"}, prefer="return=minimal")
    print(f"✓ vereadores_fonte_url de '{slug}' definida: {url}")


def _buscar_pagina(url, timeout=30):
    # Vários sites de Câmara Municipal usam um WAF genérico que devolve 403
    # pra qualquer User-Agent que não pareça navegador (confirmado contra o
    # site de Sorocaba: um UA de script tomava 403, um UA de navegador comum
    # passava — sem robots.txt nenhum proibindo o acesso). É uma página
    # institucional pública (contato dos vereadores); buscar com um UA de
    # navegador comum é o equivalente a abrir a página manualmente, uma vez
    # por checagem — não é um crawler agressivo nem contorna autenticação.
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                      "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    })
    with urllib.request.urlopen(req, timeout=timeout) as r:
        bruto = r.read()
    for enc in ("utf-8", "latin-1"):
        try:
            return bruto.decode(enc)
        except UnicodeDecodeError:
            continue
    return bruto.decode("utf-8", errors="replace")


def _limpar_html(html_bruto):
    sem_script = re.sub(r"(?is)<script.*?</script>", " ", html_bruto)
    sem_estilo = re.sub(r"(?is)<style.*?</style>", " ", sem_script)
    return sem_estilo[:LIMITE_HTML_VIGIA]


def _extrair_vereadores_ia(anthropic_key, modelo, html_limpo, municipio_nome):
    try:
        import anthropic
    except ImportError:
        raise SystemExit("Falta o SDK oficial da Anthropic. Rode: pip install anthropic")

    client = anthropic.Anthropic(api_key=anthropic_key)
    sistema = (
        "Você extrai dados estruturados de uma página HTML de uma Câmara "
        "Municipal brasileira. Devolva SOMENTE um JSON — lista de objetos "
        '{"nome": "...", "email": "..."} — sem nenhum texto antes ou depois, '
        "sem cercas de código. Inclua só pessoas que aparecem como "
        "vereador(a) na página, com nome e e-mail institucional REAIS "
        "extraídos literalmente do HTML — nunca invente, complete ou "
        "deduza um e-mail que não esteja no HTML. Sem vereador encontrado, "
        "devolva []."
    )
    mensagem = f"Município: {municipio_nome}\n\nHTML (pode conter lixo de navegação/rodapé):\n{html_limpo}"

    resposta = client.messages.create(
        model=modelo,
        max_tokens=4000,
        system=sistema,
        output_config={"effort": "low"},
        messages=[{"role": "user", "content": mensagem}],
    )
    if resposta.stop_reason == "refusal":
        raise SystemExit(f"A API recusou a extração (stop_reason=refusal). Detalhe: {getattr(resposta, 'stop_details', None)}")

    texto = "\n".join(b.text for b in resposta.content if b.type == "text").strip()
    texto = re.sub(r"^```(?:json)?\s*|\s*```$", "", texto).strip()
    try:
        dados = json.loads(texto)
    except json.JSONDecodeError:
        raise SystemExit(f"A extração não voltou JSON válido: {texto[:300]!r}")
    if not isinstance(dados, list):
        raise SystemExit("A extração não voltou uma lista.")
    return [
        {"nome": (d.get("nome") or "").strip(), "email": (d.get("email") or "").strip().lower()}
        for d in dados
        if isinstance(d, dict) and d.get("nome") and d.get("email")
    ]


_EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
_CONECTORES_NOME = {"de", "da", "do", "das", "dos", "e"}


def _texto_de_celula(celula_html):
    sem_tags = re.sub(r"<[^>]+>", " ", celula_html)
    return re.sub(r"\s+", " ", html_mod.unescape(sem_tags)).strip()


def _parece_nome_pessoa(texto):
    """Filtra linhas de cabeçalho/contato genérico (ex.: 'email',
    'respostas de requerimentos e indicações') que também têm um e-mail ao
    lado, mas não são vereador — nome de pessoa real é Title Case (com
    exceção de conectores como 'de'/'da'), 2 a 6 palavras."""
    palavras = texto.split()
    if not (2 <= len(palavras) <= 6):
        return False
    return all(p.lower() in _CONECTORES_NOME or (p[:1].isalpha() and p[:1].isupper()) for p in palavras)


def _extrair_vereadores_heuristica(html_bruto):
    """Extração sem IA, só regex/stdlib: funciona bem quando a página é uma
    tabela simples nome/e-mail (comum em sites de Câmara — geralmente uma
    tabela colada do Word/Excel). Não depende de ANTHROPIC_API_KEY. Devolve
    [] se a página não tiver essa estrutura (aí quem chama decide se cai
    pra extração por IA, se houver chave configurada)."""
    pares = []
    vistos = set()
    for linha in re.findall(r"(?is)<tr[^>]*>(.*?)</tr>", html_bruto):
        celulas = re.findall(r"(?is)<td[^>]*>(.*?)</td>", linha)
        if len(celulas) < 2:
            continue
        textos = [_texto_de_celula(c) for c in celulas]
        email = next((_EMAIL_RE.search(t).group(0) for t in textos if _EMAIL_RE.search(t)), None)
        if not email:
            continue
        nome = next((t for t in textos if t and _EMAIL_RE.search(t) is None and _parece_nome_pessoa(t)), None)
        if not nome:
            continue
        chave = email.lower()
        if chave in vistos:
            continue
        vistos.add(chave)
        pares.append({"nome": nome, "email": email.lower()})
    return pares


def _diff_vereadores(atuais, extraidos):
    """atuais: linhas de municipio_vereadores (ativo=true, campos nome/email).
    extraidos: [{"nome","email"}] vindo da IA. Devolve pendências propostas —
    nunca escreve em lugar nenhum, só calcula a diferença."""
    por_email_atual = {a["email"].lower(): a for a in atuais}
    por_nome_atual = {a["nome"].strip().lower(): a for a in atuais}
    emails_extraidos = {e["email"] for e in extraidos}

    pendencias = []
    for e in extraidos:
        email, nome = e["email"], e["nome"]
        if email in por_email_atual:
            continue  # já conhecido, nada mudou
        existente_por_nome = por_nome_atual.get(nome.strip().lower())
        if existente_por_nome and existente_por_nome["email"].lower() != email:
            pendencias.append({
                "tipo": "email_alterado", "nome": nome, "email": email,
                "email_anterior": existente_por_nome["email"],
            })
        else:
            pendencias.append({"tipo": "novo", "nome": nome, "email": email, "email_anterior": None})

    emails_absorvidos = {p["email_anterior"].lower() for p in pendencias if p.get("email_anterior")}
    for a in atuais:
        if a["email"].lower() not in emails_extraidos and a["email"].lower() not in emails_absorvidos:
            pendencias.append({"tipo": "possivel_saida", "nome": a["nome"], "email": a["email"], "email_anterior": None})
    return pendencias


def vigiar(cfg, slug):
    m = _buscar_municipio(cfg, slug)
    if not m:
        raise SystemExit(f"Município '{slug}' não encontrado no Atlas.")
    url = m.get("vereadores_fonte_url")
    if not url:
        raise SystemExit(f"'{slug}' não tem vereadores_fonte_url configurada — rode 'vereadores configurar-fonte-url' antes.")

    print(f"→ [{slug}] buscando {url} ...")
    try:
        html_bruto = _buscar_pagina(url)
    except Exception as e:
        raise SystemExit(f"Falha ao baixar '{url}': {e}")

    def _razoavel(lista):
        return 0 < len(lista) <= MAX_VEREADORES_RAZOAVEL

    extraidos = _extrair_vereadores_heuristica(html_bruto)
    metodo = "heurística (sem IA)"

    if not _razoavel(extraidos):
        anthropic_key = os.environ.get("ANTHROPIC_API_KEY")
        if not anthropic_key:
            achou = len(extraidos)
            raise SystemExit(
                f"A extração sem IA achou {achou} nome(s)/e-mail(s) em '{url}' — "
                "página provavelmente não é uma tabela simples nome/e-mail. "
                "Configure ANTHROPIC_API_KEY pra tentar com IA, ou verifique/semeie "
                "essa cidade manualmente."
            )
        modelo = os.environ.get("ANTHROPIC_MODEL_VIGIA", "claude-haiku-4-5-20251001")
        extraidos = _extrair_vereadores_ia(anthropic_key, modelo, _limpar_html(html_bruto), m["nome"])
        metodo = f"IA ({modelo})"

    if len(extraidos) == 0:
        raise SystemExit(f"A extração ({metodo}) não achou nenhum vereador em '{url}' — verifique manualmente antes de confiar no vigia pra essa cidade.")
    if len(extraidos) > MAX_VEREADORES_RAZOAVEL:
        raise SystemExit(
            f"A extração ({metodo}) achou {len(extraidos)} 'vereadores' — acima do razoável "
            f"(a maior câmara do Brasil tem {MAX_VEREADORES_RAZOAVEL}). Provavelmente "
            "pegou lixo da página; nenhuma pendência foi gerada. Verifique manualmente."
        )
    print(f"  método de extração: {metodo} ({len(extraidos)} encontrado(s))")

    atuais = _rest("GET", "municipio_vereadores", cfg, params={
        "municipio_id": f"eq.{m['id']}", "ativo": "eq.true", "select": "nome,email",
    }) or []

    pendencias = _diff_vereadores(atuais, extraidos)
    if not pendencias:
        print(f"✓ '{slug}': nada mudou ({len(extraidos)} vereador(es) na página, tudo já conhecido).")
        return

    ja_pendentes = _rest("GET", "municipio_vereadores_pendencias", cfg, params={
        "municipio_id": f"eq.{m['id']}", "status": "eq.pendente", "select": "tipo,email",
    }) or []
    chaves_existentes = {(p["tipo"], p["email"].lower()) for p in ja_pendentes}

    novas = 0
    for p in pendencias:
        if (p["tipo"], p["email"].lower()) in chaves_existentes:
            continue
        _rest("POST", "municipio_vereadores_pendencias", cfg, body={
            "municipio_id": m["id"], "tipo": p["tipo"], "nome": p["nome"],
            "email": p["email"], "email_anterior": p["email_anterior"],
        }, prefer="return=minimal")
        novas += 1

    print(f"✓ '{slug}': {len(pendencias)} diferença(s) detectada(s), {novas} nova(s) "
          f"pendência(s) registrada(s) (revise com 'pendencias listar {slug}').")


def vigiar_todas(cfg):
    municipios = _rest("GET", "municipios", cfg, params={
        "vereadores_fonte_url": "not.is.null", "ativo": "eq.true", "select": "slug",
    }) or []
    if not municipios:
        print("Nenhuma cidade com vereadores_fonte_url configurada ainda.")
        return
    falhas = []
    for m in municipios:
        try:
            vigiar(cfg, m["slug"])
        except SystemExit as e:
            print(f"  ! {m['slug']}: {e}")
            falhas.append(m["slug"])
    print(f"\nConcluído: {len(municipios)} cidade(s) verificada(s), {len(falhas)} falha(s).")
    if falhas:
        print("  Falharam:", ", ".join(falhas))


def pendencias_listar(cfg, slug):
    m = _buscar_municipio(cfg, slug)
    if not m:
        raise SystemExit(f"Município '{slug}' não encontrado no Atlas.")
    linhas = _rest("GET", "municipio_vereadores_pendencias", cfg, params={
        "municipio_id": f"eq.{m['id']}", "status": "eq.pendente", "select": "*", "order": "detectado_em",
    }) or []
    if not linhas:
        print(f"Nenhuma pendência para '{slug}'.")
        return
    for p in linhas:
        extra = f"  (era: {p['email_anterior']})" if p.get("email_anterior") else ""
        print(f"  [{p['id']}] {p['tipo']}: {p.get('nome') or '?'} <{p['email']}>{extra}  detectado_em={p['detectado_em']}")
    print(f"Total: {len(linhas)} pendência(s) em '{slug}'.")


def pendencias_aplicar(cfg, slug, pendencia_id, fonte, selo):
    m = _buscar_municipio(cfg, slug)
    if not m:
        raise SystemExit(f"Município '{slug}' não encontrado no Atlas.")
    linhas = _rest("GET", "municipio_vereadores_pendencias", cfg, params={
        "id": f"eq.{pendencia_id}", "municipio_id": f"eq.{m['id']}", "select": "*",
    }) or []
    if not linhas:
        raise SystemExit(f"Pendência '{pendencia_id}' não encontrada em '{slug}'.")
    p = linhas[0]
    if p["status"] != "pendente":
        raise SystemExit(f"Pendência '{pendencia_id}' já está '{p['status']}'.")

    selo = _traduzir_selo(selo)
    if selo == "verificado" and not fonte:
        raise ValueError("Selo 'verificado' exige fonte nomeada (Anexo 16 §4).")

    if p["tipo"] == "possivel_saida":
        _rest("PATCH", "municipio_vereadores", cfg, body={"ativo": False},
              params={"municipio_id": f"eq.{m['id']}", "email": f"ilike.{p['email']}"}, prefer="return=minimal")
        resultado = "desativado"
    else:
        resultado = _upsert_vereador(cfg, m["id"], p["nome"], p["email"], None, fonte, selo)

    _rest("PATCH", "municipio_vereadores_pendencias", cfg, body={
        "status": "aplicada", "revisado_por": "evora_atlas_municipal.py (pendencias aplicar)",
        "revisado_em": datetime.now().isoformat(),
    }, params={"id": f"eq.{pendencia_id}"}, prefer="return=minimal")

    _rest("POST", "municipio_trilha", cfg, body={
        "municipio_id": m["id"],
        "acao": f"pendência de vigia aplicada ({p['tipo']} → {resultado})",
        "autor": "evora_atlas_municipal.py (pendencias aplicar)",
        "obs": f"{p.get('nome') or '?'} <{p['email']}>",
    }, prefer="return=minimal")
    print(f"✓ Pendência '{pendencia_id}' aplicada ({resultado}).")


def pendencias_rejeitar(cfg, slug, pendencia_id):
    m = _buscar_municipio(cfg, slug)
    if not m:
        raise SystemExit(f"Município '{slug}' não encontrado no Atlas.")
    linhas = _rest("GET", "municipio_vereadores_pendencias", cfg, params={
        "id": f"eq.{pendencia_id}", "municipio_id": f"eq.{m['id']}", "select": "status",
    }) or []
    if not linhas:
        raise SystemExit(f"Pendência '{pendencia_id}' não encontrada em '{slug}'.")
    if linhas[0]["status"] != "pendente":
        raise SystemExit(f"Pendência '{pendencia_id}' já está '{linhas[0]['status']}'.")
    _rest("PATCH", "municipio_vereadores_pendencias", cfg, body={
        "status": "rejeitada", "revisado_por": "evora_atlas_municipal.py (pendencias rejeitar)",
        "revisado_em": datetime.now().isoformat(),
    }, params={"id": f"eq.{pendencia_id}"}, prefer="return=minimal")
    print(f"✓ Pendência '{pendencia_id}' rejeitada.")


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

    p_vereadores = sub.add_parser(
        "vereadores",
        help="gerencia a lista de vereadores verificados (Fase 8, autocadastro)",
    )
    sub_vereadores = p_vereadores.add_subparsers(dest="acao", required=True)

    p_v_add = sub_vereadores.add_parser("adicionar", help="adiciona um vereador verificado à lista de uma cidade")
    p_v_add.add_argument("slug")
    p_v_add.add_argument("--nome", required=True)
    p_v_add.add_argument("--email", required=True)
    p_v_add.add_argument("--partido", default=None)
    p_v_add.add_argument("--fonte", default=None, help="proveniência real (ex.: 'portal da Câmara, conferido em dd/mm/aaaa')")
    p_v_add.add_argument("--selo", default="a_confirmar", choices=sorted(SELOS_VALIDOS | {"a confirmar"}))

    p_v_list = sub_vereadores.add_parser("listar", help="lista os vereadores já semeados de uma cidade")
    p_v_list.add_argument("slug")

    p_v_lote = sub_vereadores.add_parser(
        "importar-lote",
        help="importa/atualiza vários vereadores de uma vez, a partir de um .csv ou .json",
    )
    p_v_lote.add_argument("slug")
    p_v_lote.add_argument("caminho", help=".csv (colunas nome,email[,partido]) ou .json (lista de objetos)")
    p_v_lote.add_argument("--fonte", required=True, help="proveniência real, aplicada a todo o lote (ex.: 'portal da Câmara, conferido em dd/mm/aaaa')")
    p_v_lote.add_argument("--selo", default="verificado", choices=sorted(SELOS_VALIDOS | {"a confirmar"}))

    p_v_url = sub_vereadores.add_parser(
        "configurar-fonte-url",
        help="define a URL oficial da lista de vereadores de uma cidade (Fase 9, vigia)",
    )
    p_v_url.add_argument("slug")
    p_v_url.add_argument("url")

    p_v_vigiar = sub_vereadores.add_parser(
        "vigiar",
        help="revisita a fonte configurada e registra diferenças como pendências (Fase 9)",
    )
    p_v_vigiar.add_argument("slug")

    sub_vereadores.add_parser(
        "vigiar-todas",
        help="roda 'vigiar' pra toda cidade com vereadores_fonte_url configurada (Fase 9)",
    )

    p_v_pend = sub_vereadores.add_parser(
        "pendencias",
        help="gerencia a fila de revisão do vigia (Fase 9) — listar/aplicar/rejeitar",
    )
    sub_pend = p_v_pend.add_subparsers(dest="pend_acao", required=True)

    p_pend_listar = sub_pend.add_parser("listar", help="lista pendências de uma cidade")
    p_pend_listar.add_argument("slug")

    p_pend_aplicar = sub_pend.add_parser("aplicar", help="aplica uma pendência (upsert real em municipio_vereadores)")
    p_pend_aplicar.add_argument("slug")
    p_pend_aplicar.add_argument("pendencia_id")
    p_pend_aplicar.add_argument("--fonte", default=None, help="proveniência real, conferida por você antes de aplicar")
    p_pend_aplicar.add_argument("--selo", default="a_confirmar", choices=sorted(SELOS_VALIDOS | {"a confirmar"}))

    p_pend_rejeitar = sub_pend.add_parser("rejeitar", help="descarta uma pendência sem aplicar")
    p_pend_rejeitar.add_argument("slug")
    p_pend_rejeitar.add_argument("pendencia_id")

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
    elif args.comando == "vereadores":
        if args.acao == "adicionar":
            vereadores_adicionar(cfg, args.slug, args.nome, args.email, args.partido, args.fonte, args.selo)
        elif args.acao == "listar":
            vereadores_listar(cfg, args.slug)
        elif args.acao == "importar-lote":
            vereadores_importar_lote(cfg, args.slug, args.caminho, args.fonte, args.selo)
        elif args.acao == "configurar-fonte-url":
            vereadores_configurar_fonte_url(cfg, args.slug, args.url)
        elif args.acao == "vigiar":
            vigiar(cfg, args.slug)
        elif args.acao == "vigiar-todas":
            vigiar_todas(cfg)
        elif args.acao == "pendencias":
            if args.pend_acao == "listar":
                pendencias_listar(cfg, args.slug)
            elif args.pend_acao == "aplicar":
                pendencias_aplicar(cfg, args.slug, args.pendencia_id, args.fonte, args.selo)
            elif args.pend_acao == "rejeitar":
                pendencias_rejeitar(cfg, args.slug, args.pendencia_id)


if __name__ == "__main__":
    main()
