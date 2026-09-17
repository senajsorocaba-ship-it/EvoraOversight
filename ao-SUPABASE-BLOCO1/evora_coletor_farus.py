#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Coletor de ingestão do FARUS (Fase 10, F1 — Memória)
========================================================================
O schema do FARUS (`farus_territorios`/`farus_tenant_territorios`/
`farus_fontes`/`farus_itens`) já está integrado e testado (10/10), mas
vazio: nenhum coletor grava nele. Este script fecha esse ciclo — busca
informação geral sobre o TERRITÓRIO (o município como um todo, não uma
pessoa — isso já é o `evora_coletor_mencoes.py`) e grava no acervo
FARUS, com a deduplicação e a retenção que o schema já garante.

DECISÃO DELIBERADA — sem catálogo de fontes pré-aprovado: o Manual
descreve um ciclo de vida de fonte (`descoberta → observada →
configurada`) que exige liberação humana antes de uma fonte "sustentar
afirmação". Mas essa trava (`farus_fonte_liberacao_humana`) é sobre a
tabela `farus_fontes` — um catálogo RECORRENTE de veículos. Um item em
`farus_itens` não depende de ter uma `farus_fontes` associada
(`fonte_id` é opcional) nem de estar num estado que exija verificação —
só PRECISA disso quando `estado in ('confirmado','corroborado')`. Este
coletor nunca grava nesses dois estados: todo item nasce
`estado = 'nao_verificado'` (o default da coluna), exatamente a "Regra
pétrea" do FARUS: "quando não souber, declara que não foi possível
verificar — é preferível admitir a lacuna a preencher com invenção."

LIMITE HONESTO — isto NÃO é um coletor de Diário Oficial/PNCP oficial
(o próprio `evora briefing motor mvp v1.sql` documenta esse coletor como
"um coletor que ainda não existe como código"). É busca geral via
Google News RSS (mesmo endpoint gratuito, sem chave, já usado em
`evora_coletor_mencoes.py`), escopada pro município inteiro em vez de
uma pessoa. Uma aproximação honesta e testável do F1 ("Memória"), não
uma integração oficial com o Diário Oficial da cidade. Todo item entra
como `especie = 'materia'` — nunca `ato_oficial`/`contratacao`/`norma`,
que implicariam uma fonte primária oficial que este script não lê.

TERRITÓRIO: compartilhado por município (mesma economia de escala do
Atlas Municipal) — criado sozinho na primeira vez que um tenant daquela
cidade é processado (`garantir_territorio`), sem passo manual. O vínculo
tenant↔território (`farus_tenant_territorios`) também é criado sozinho.

DEDUPLICAÇÃO: usa `farus_hash(titulo, conteudo)`, a mesma função SQL
IMMUTABLE que o schema já define — pedida via RPC em vez de reimplementada
em Python, pra garantir que o hash bate exatamente com o que o índice
`ix_farus_itens_dedup (territorio_id, hash_conteudo)` espera.

VARIÁVEIS DE AMBIENTE OBRIGATÓRIAS: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
(mesmas dos coletores irmãos).

DEPENDÊNCIA: nenhuma além da biblioteca padrão — reaproveita
`buscar_google_news`/`_parse_data_rss`/`_rest_request`/
`listar_tenants_ativos`/`buscar_tenant` de `evora_coletor_mencoes.py`
(mesmo diretório) em vez de duplicar.

USO:
    python evora_coletor_farus.py --tenant-id <uuid> --mundo gabinete
    python evora_coletor_farus.py --todos --mundo gabinete
        (processa todo tenant com ativo=true; falha de um tenant não
        interrompe os demais — mesma garantia dos coletores irmãos)
"""

import argparse
import time
import urllib.parse

from evora_coletor_mencoes import (
    LIMITE_POR_CONSULTA_PADRAO,
    _parse_data_rss,
    _rest_request,
    buscar_google_news,
    buscar_tenant,
    carregar_ambiente,
    listar_tenants_ativos,
)


# ---------------------------------------------------------------------
# 1. Território — achar ou criar, sozinho, sem catálogo pré-existente
# ---------------------------------------------------------------------
def garantir_territorio(cfg, municipio, uf):
    """`farus_territorios` tem um índice único FUNCIONAL (lower(municipio),
    uf), não uma constraint simples — PostgREST não faz upsert direto nisso.
    Por isso: busca primeiro, cria só se não achar."""
    municipio = (municipio or "").strip()
    uf = (uf or "").strip().upper()
    if not municipio or not uf:
        raise SystemExit(
            "Tenant sem municipio_sede/uf cadastrado — não dá pra ligar ao FARUS."
        )

    url_busca = (
        f"{cfg['supabase_url']}/rest/v1/farus_territorios"
        f"?select=id&municipio=ilike.{urllib.parse.quote(municipio)}"
        f"&uf=eq.{urllib.parse.quote(uf)}"
    )
    achados = _rest_request("GET", url_busca, cfg["supabase_key"]) or []
    if achados:
        return achados[0]["id"]

    url_criar = f"{cfg['supabase_url']}/rest/v1/farus_territorios"
    criado = _rest_request(
        "POST", url_criar, cfg["supabase_key"],
        {"municipio": municipio, "uf": uf},
        prefer="return=representation",
    )
    return criado[0]["id"]


def garantir_vinculo_tenant(cfg, tenant_id, territorio_id):
    """`farus_tenant_territorios` tem PK simples (tenant_id, territorio_id) —
    aceita upsert direto via on_conflict."""
    url = (
        f"{cfg['supabase_url']}/rest/v1/farus_tenant_territorios"
        "?on_conflict=tenant_id,territorio_id"
    )
    _rest_request(
        "POST", url, cfg["supabase_key"],
        {
            "tenant_id": tenant_id,
            "territorio_id": territorio_id,
            "principal": True,
            "incluido_por": "evora_coletor_farus.py",
        },
        prefer="resolution=merge-duplicates,return=minimal",
    )


# ---------------------------------------------------------------------
# 2. Consultas gerais pro território (não é nome de pessoa)
# ---------------------------------------------------------------------
def montar_consultas_farus(municipio):
    """Escopo do F1 por analogia ao que o Manual descreve pro MVP do FARUS
    (nomeações/exonerações, contratos/licitações, pautas) — via Google News,
    não Diário Oficial/PNCP oficiais (ver docstring do módulo)."""
    return [
        (f'"Prefeitura de {municipio}"', "prefeitura"),
        (f'"Câmara Municipal de {municipio}"', "câmara municipal"),
        (f'"{municipio}" licitação', "licitações"),
        (f'"{municipio}" decreto', "decretos/portarias"),
    ]


# ---------------------------------------------------------------------
# 3. Hash de dedup — pedido ao Postgres, nunca recalculado em Python
# ---------------------------------------------------------------------
def calcular_hash(cfg, titulo, conteudo):
    url = f"{cfg['supabase_url']}/rest/v1/rpc/farus_hash"
    return _rest_request(
        "POST", url, cfg["supabase_key"],
        {"p_titulo": titulo, "p_conteudo": conteudo},
    )


# ---------------------------------------------------------------------
# 3b. Fonte liberada — usada só pelos coletores que gravam estado=
# 'confirmado' (evora_coletor_pncp_farus.py, evora_conector_agenda_
# legislativa.py). Este arquivo (busca geral) nunca chama isto — ele
# nunca grava 'confirmado', então nunca precisa de fonte alguma (ver
# docstring do módulo). Decisão D6 (Anexo 16): nenhuma fonte alimenta
# afirmação sem liberação humana registrada — por isso esta função só
# BUSCA, nunca cria nem libera uma fonte sozinha. Sem fonte 'configurada'
# pro território+espécie, quem chama isto decide o que fazer (normalmente:
# recusar rodar, com uma mensagem dizendo como liberar).
# ---------------------------------------------------------------------
def buscar_fonte_configurada(cfg, territorio_id, especie):
    url = (
        f"{cfg['supabase_url']}/rest/v1/farus_fontes"
        f"?select=id&territorio_id=eq.{territorio_id}"
        f"&especie=eq.{especie}&estado=eq.configurada&limit=1"
    )
    achados = _rest_request("GET", url, cfg["supabase_key"]) or []
    return achados[0]["id"] if achados else None


# ---------------------------------------------------------------------
# 4. Orquestração por tenant
# ---------------------------------------------------------------------
def processar_tenant(cfg, tenant, limite_por_consulta):
    municipio = (tenant.get("municipio_sede") or "").strip()
    uf = (tenant.get("uf") or "").strip()

    territorio_id = garantir_territorio(cfg, municipio, uf)
    garantir_vinculo_tenant(cfg, tenant["id"], territorio_id)
    print(f"  território: {municipio}-{uf} ({territorio_id})")

    consultas = montar_consultas_farus(municipio)
    por_url = {}
    for query, rotulo in consultas:
        print(f"  → buscando: {rotulo}")
        itens = buscar_google_news(query, limite_por_consulta)
        for item in itens:
            if item["link"] not in por_url:
                por_url[item["link"]] = item

    if not por_url:
        print("  nenhum item encontrado.")
        return 0

    # Dedup por hash ANTES de mandar pro banco, não só por link — o Google
    # News às vezes devolve o mesmo título por dois links diferentes (ex.:
    # versão AMP vs original). Um único INSERT com ON CONFLICT não aceita a
    # mesma chave de conflito duas vezes na mesma leva (erro real visto:
    # "ON CONFLICT DO UPDATE command cannot affect row a second time") — o
    # próprio hash é a chave de conflito (territorio_id, hash_conteudo).
    por_hash = {}
    for link, item in por_url.items():
        hash_conteudo = calcular_hash(cfg, item["titulo"], None)
        if hash_conteudo in por_hash:
            continue
        publicado_iso = _parse_data_rss(item["publicado_em_bruto"])
        por_hash[hash_conteudo] = {
            "territorio_id": territorio_id,
            "origem_aquisicao": "coleta_programada",
            "tenant_origem": None,
            "especie": "materia",
            "url": link,
            "titulo": item["titulo"],
            "conteudo": None,
            "publicado_em": publicado_iso[:10] if publicado_iso else None,
            "hash_conteudo": hash_conteudo,
        }
    linhas = list(por_hash.values())

    url = (
        cfg["supabase_url"]
        + "/rest/v1/farus_itens?on_conflict=territorio_id,hash_conteudo"
    )
    _rest_request(
        "POST", url, cfg["supabase_key"], linhas,
        prefer="resolution=merge-duplicates,return=minimal",
    )
    print(f"  {len(linhas)} item(ns) do acervo FARUS gravado(s)/atualizado(s).")
    return len(linhas)


def main():
    ap = argparse.ArgumentParser(
        description="Coletor de ingestão do FARUS por território (Évora Oversight)"
    )
    alvo = ap.add_mutually_exclusive_group(required=True)
    alvo.add_argument("--tenant-id", help="uuid de um único tenant (usa o município dele)")
    alvo.add_argument(
        "--todos", action="store_true",
        help="processa todo tenant com ativo=true (usado pelo agendador diário)",
    )
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
        processar_tenant(cfg, tenant, args.limite_por_consulta)
        return

    tenants = listar_tenants_ativos(cfg)
    print(f"→ {len(tenants)} tenant(s) ativo(s) encontrado(s).")
    falharam = []
    for i, t in enumerate(tenants):
        print(f"\n--- tenant {t['nome_autoridade']} ({t['id']}) ---")
        try:
            processar_tenant(cfg, t, args.limite_por_consulta)
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
