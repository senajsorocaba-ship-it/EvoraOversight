#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Coletor de menções por nome do vereador (bloco 6, Imprensa)
==============================================================================
O bloco 6 do briefing (evora_gerar_briefing_diario, BLOCO 4) hoje só cobre
cobertura DA CIDADE em geral (fontes declaradas manualmente em `fontes`).
Este script busca especificamente o que a imprensa está falando sobre O
PRÓPRIO VEREADOR — pelo nome dele(a) — e grava em `mencoes_imprensa`, a mesma
tabela que o bloco 6 já lê.

Um coletor equivalente (imprensa_coletor_evora.py) existe num projeto irmão
(D:\\motor), mas não está acessível deste repositório/ambiente — este script
é uma recriação independente, self-contained, sem depender daquele arquivo.

MECANISMO: Google News RSS (news.google.com/rss/search), um endpoint público
sem necessidade de chave/autenticação — mesma técnica que o coletor original
usa. NÃO é uma API oficial documentada do Google; pode mudar de formato ou
ficar indisponível sem aviso (mesma classe de risco já aceita no vigia de
vereadores, Fase 9, para o site da Câmara).

BUSCAS POR TENANT (todas via `tenants.nome_autoridade`/`municipio_sede`/`uf`
— nenhum cadastro novo, sem campo de "apelido" por enquanto):
  1. "<nome completo>"                 — frase exata, ex.: "Tatiane Costa"
  2. "<primeiro nome>" "<cidade>"       — ex.: "Tatiane" "Sorocaba"
     (o primeiro nome SOZINHO seria ruidoso demais — qualquer "Tatiane" do
     Brasil apareceria. Combinado com a cidade fica utilizável sem exigir
     cadastro de apelido.)
  3. "<nome completo>" site:<dominio>  — uma por jornal/veículo JÁ conhecido
     da cidade (fontes do próprio tenant com esfera municipal/regional, mais
     o que o Atlas Municipal — `municipio_fontes` — já tiver pra essa
     cidade). Não descobre jornal nenhum sozinho; só usa o que já existe.
     Essas buscas restritas eliminam quase todo o risco de falso positivo
     (uma pessoa homônima em outra cidade/estado dificilmente seria coberta
     pelo jornal local da cidade certa) — confirmado em teste real: a busca
     1 sozinha trouxe uma "Tatiane Costa" completamente diferente, candidata
     no Rio Grande do Norte, junto com a cobertura real da vereadora de
     Sorocaba.

LIMITAÇÕES HONESTAS (mesmo padrão do resto do projeto — não escondidas):
  · Não há filtro de relevância além da própria busca do Google — pode trazer
    falso positivo (outra pessoa com o mesmo primeiro nome, por coincidência
    mencionada perto do nome da cidade). É uma lista de CANDIDATOS a menção
    para leitura humana, não um fato verificado.
  · Cobre só notícias (Google News). Redes sociais (X/Instagram) ficam de
    fora de propósito — exigiriam API paga ou scraping fora dos termos de
    uso da maioria das redes; decisão explícita de não fazer isso agora.

VARIÁVEIS DE AMBIENTE OBRIGATÓRIAS: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
(mesmas de evora_motor_execucao.py — não precisa de ANTHROPIC_API_KEY, este
script não redige nada, só busca e grava dado estruturado).

DEPENDÊNCIA: nenhuma além da biblioteca padrão do Python.

USO:
    python evora_coletor_mencoes.py --tenant-id <uuid> --mundo gabinete
    python evora_coletor_mencoes.py --todos --mundo gabinete
        (processa todo tenant com ativo=true; falha de um tenant não
        interrompe os demais — mesma garantia do evora_motor_execucao.py)
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime

LIMITE_POR_CONSULTA_PADRAO = 15
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
)


# ---------------------------------------------------------------------
# 0. Configuração / ambiente
# ---------------------------------------------------------------------
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


# ---------------------------------------------------------------------
# 1. Cliente PostgREST mínimo (só stdlib) — mesmo padrão dos scripts irmãos
# ---------------------------------------------------------------------
def _rest_request(method, url, service_key, body=None, prefer=None):
    dados = json.dumps(body).encode("utf-8") if body is not None else None
    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Content-Type": "application/json",
    }
    if prefer:
        headers["Prefer"] = prefer
    req = urllib.request.Request(url, data=dados, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            corpo = r.read().decode("utf-8")
            return json.loads(corpo) if corpo else None
    except urllib.error.HTTPError as e:
        detalhe = e.read().decode("utf-8", errors="replace")[:500]
        raise SystemExit(
            f"Erro do Supabase ({e.code}) em {method} {url.split('?')[0]}: {detalhe}"
        )


def listar_tenants_ativos(cfg):
    url = (
        f"{cfg['supabase_url']}/rest/v1/tenants"
        "?select=id,nome_autoridade,municipio_sede,uf&ativo=eq.true"
    )
    return _rest_request("GET", url, cfg["supabase_key"]) or []


def buscar_tenant(cfg, tenant_id):
    url = (
        f"{cfg['supabase_url']}/rest/v1/tenants?id=eq.{tenant_id}"
        "&select=id,nome_autoridade,municipio_sede,uf,ativo"
    )
    linhas = _rest_request("GET", url, cfg["supabase_key"])
    if not linhas:
        raise SystemExit(f"Tenant {tenant_id} não encontrado.")
    return linhas[0]


def _extrair_dominio(url_bruta):
    try:
        rede = urllib.parse.urlparse(url_bruta).netloc.lower()
    except ValueError:
        return None
    return rede[4:] if rede.startswith("www.") else rede or None


def buscar_dominios_locais(cfg, tenant, mundo):
    """Jornais/veículos já conhecidos pra cidade do tenant — tanto os que o
    próprio tenant declarou (`fontes`, esfera municipal/regional) quanto os
    do Atlas Municipal (`municipio_fontes`, plataforma-compartilhado, se a
    cidade já tiver sido semeada). Não descobre nada novo — só reaproveita o
    que já existe, pra não duplicar a Fase 7 nem inventar fonte."""
    dominios = set()

    url_fontes = (
        f"{cfg['supabase_url']}/rest/v1/fontes"
        f"?select=url&tenant_id=eq.{tenant['id']}&mundo=eq.{mundo}"
        "&ativa=eq.true&esfera=in.(municipal,regional)"
    )
    for f in _rest_request("GET", url_fontes, cfg["supabase_key"]) or []:
        d = _extrair_dominio(f.get("url") or "")
        if d:
            dominios.add(d)

    cidade = (tenant.get("municipio_sede") or "").strip()
    uf = (tenant.get("uf") or "").strip()
    if cidade and uf:
        url_municipio = (
            f"{cfg['supabase_url']}/rest/v1/municipios?select=id"
            f"&nome=ilike.{urllib.parse.quote(cidade)}&uf=eq.{urllib.parse.quote(uf.upper())}"
        )
        municipios = _rest_request("GET", url_municipio, cfg["supabase_key"]) or []
        if municipios:
            url_mf = (
                f"{cfg['supabase_url']}/rest/v1/municipio_fontes"
                f"?select=url&municipio_id=eq.{municipios[0]['id']}&ativa=eq.true"
            )
            for f in _rest_request("GET", url_mf, cfg["supabase_key"]) or []:
                d = _extrair_dominio(f.get("url") or "")
                if d:
                    dominios.add(d)

    return sorted(dominios)


# ---------------------------------------------------------------------
# 2. Consultas — nome completo + "primeiro nome" + cidade
# ---------------------------------------------------------------------
def montar_consultas(tenant, dominios_locais):
    nome = (tenant.get("nome_autoridade") or "").strip()
    cidade = (tenant.get("municipio_sede") or "").strip()
    if not nome:
        return []

    consultas = [(f'"{nome}"', f'nome completo: "{nome}"')]

    primeiro_nome = nome.split()[0]
    if cidade and primeiro_nome.lower() != nome.lower():
        consultas.append(
            (f'"{primeiro_nome}" "{cidade}"', f'primeiro nome + cidade: "{primeiro_nome}" "{cidade}"')
        )

    # Buscas restritas a jornais/veículos JÁ conhecidos da cidade (fontes do
    # tenant + Atlas Municipal) — praticamente elimina o risco de pegar uma
    # pessoa homônima de outro lugar do Brasil, porque só um veículo local
    # cobriria o(a) vereador(a) local com esse nome.
    for dominio in dominios_locais:
        consultas.append(
            (f'"{nome}" site:{dominio}', f'fonte local conhecida ({dominio}): "{nome}"')
        )
    return consultas


# ---------------------------------------------------------------------
# 3. Google News RSS — busca + parse (stdlib apenas)
# ---------------------------------------------------------------------
def buscar_google_news(query, limite):
    url = "https://news.google.com/rss/search?" + urllib.parse.urlencode(
        {"q": query, "hl": "pt-BR", "gl": "BR", "ceid": "BR:pt-BR"}
    )
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            corpo = r.read()
    except (urllib.error.URLError, urllib.error.HTTPError) as e:
        raise SystemExit(f"Falha ao consultar Google News para {query!r}: {e}")

    try:
        raiz = ET.fromstring(corpo)
    except ET.ParseError as e:
        raise SystemExit(f"RSS inválido para {query!r}: {e}")

    itens = []
    for item in raiz.findall("./channel/item")[:limite]:
        titulo = (item.findtext("title") or "").strip()
        link = (item.findtext("link") or "").strip()
        if not titulo or not link:
            continue
        pub_date_bruto = (item.findtext("pubDate") or "").strip() or None
        fonte_el = item.find("source")
        fonte_nome = fonte_el.text.strip() if fonte_el is not None and fonte_el.text else None
        itens.append(
            {
                "titulo": titulo,
                "link": link,
                "publicado_em_bruto": pub_date_bruto,
                "fonte_nome": fonte_nome,
            }
        )
    return itens


def _parse_data_rss(bruta):
    if not bruta:
        return None
    try:
        return parsedate_to_datetime(bruta).isoformat()
    except (TypeError, ValueError):
        return None


# ---------------------------------------------------------------------
# 4. Orquestração por tenant
# ---------------------------------------------------------------------
def processar_tenant(cfg, tenant, mundo, limite_por_consulta):
    dominios_locais = buscar_dominios_locais(cfg, tenant, mundo)
    if dominios_locais:
        print(f"  jornais locais conhecidos: {', '.join(dominios_locais)}")
    consultas = montar_consultas(tenant, dominios_locais)
    if not consultas:
        print("  (sem nome_autoridade cadastrado — nada a buscar)")
        return 0

    por_link = {}
    for query, rotulo in consultas:
        print(f"  → buscando: {rotulo}")
        itens = buscar_google_news(query, limite_por_consulta)
        for item in itens:
            if item["link"] not in por_link:
                por_link[item["link"]] = {**item, "consulta": rotulo}

    if not por_link:
        print("  nenhuma menção encontrada.")
        return 0

    linhas = [
        {
            "tenant_id": tenant["id"],
            "mundo": mundo,
            "titulo": item["titulo"],
            "fonte_nome": item["fonte_nome"],
            "link": link,
            "publicado_em": _parse_data_rss(item["publicado_em_bruto"]),
            "publicado_em_bruto": item["publicado_em_bruto"],
            "consulta": item["consulta"],
        }
        for link, item in por_link.items()
    ]

    url = cfg["supabase_url"] + "/rest/v1/mencoes_imprensa?on_conflict=tenant_id,link"
    _rest_request(
        "POST", url, cfg["supabase_key"], linhas,
        prefer="resolution=merge-duplicates,return=minimal",
    )
    print(f"  {len(linhas)} menção(ões) gravada(s)/atualizada(s).")
    return len(linhas)


def main():
    ap = argparse.ArgumentParser(
        description="Coletor de menções de imprensa por nome do vereador (Évora Oversight)"
    )
    alvo = ap.add_mutually_exclusive_group(required=True)
    alvo.add_argument("--tenant-id", help="uuid de um único tenant")
    alvo.add_argument(
        "--todos", action="store_true",
        help="processa todo tenant com ativo=true (usado pelo agendador diário)",
    )
    ap.add_argument("--mundo", required=True, choices=["gabinete", "campanha"])
    ap.add_argument(
        "--limite-por-consulta", type=int, default=LIMITE_POR_CONSULTA_PADRAO,
        help=f"máximo de itens por consulta (default: {LIMITE_POR_CONSULTA_PADRAO})",
    )
    args = ap.parse_args()

    cfg = carregar_ambiente()

    if not args.todos:
        tenant = buscar_tenant(cfg, args.tenant_id)
        if not tenant.get("ativo", True):
            raise SystemExit(f"Tenant {args.tenant_id} está inativo — abortando.")
        processar_tenant(cfg, tenant, args.mundo, args.limite_por_consulta)
        return

    tenants = listar_tenants_ativos(cfg)
    print(f"→ {len(tenants)} tenant(s) ativo(s) encontrado(s).")
    falharam = []
    for i, t in enumerate(tenants):
        print(f"\n--- tenant {t['nome_autoridade']} ({t['id']}) ---")
        try:
            processar_tenant(cfg, t, args.mundo, args.limite_por_consulta)
        except (SystemExit, Exception) as e:
            print(f"  ✗ FALHOU: {e}")
            falharam.append((t["id"], t["nome_autoridade"]))
        if i < len(tenants) - 1:
            time.sleep(1)  # cortesia com o serviço do Google, não é endpoint nosso

    print(f"\n{len(tenants) - len(falharam)}/{len(tenants)} tenant(s) processado(s) com sucesso.")
    if falharam:
        raise SystemExit(f"{len(falharam)} tenant(s) falharam: {falharam}")


if __name__ == "__main__":
    main()
