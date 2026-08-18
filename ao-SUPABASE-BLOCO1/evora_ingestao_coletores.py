#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Ingestão dos coletores no Supabase (Fase 6)
================================================================
Lê os arquivos JSON que os coletores do motor/ já produzem
(contratos_sorocaba.json, noticias.json) e grava em duas tabelas do
BLOCO 1 (achados_fiscalizacao, mencoes_imprensa) via PostgREST, usando a
service_role key. Não recoleta nada, não reformula texto, não reimplementa
a lógica dos coletores — só transporta campo a campo o que eles já
escreveram em disco, sem inventar dado que o coletor não entrega hoje
(ex.: mediana_referencia/desvio_pct ficam NULL, porque o coletor só
embute esse cálculo em texto livre no campo 'indicio', não em campos
numéricos separados — fonte ou silêncio).

ORDEM DE USO (depois que o BLOCO 1/2/4 já rodaram no Supabase):
  1. python motor/coletor_pncp_evora.py        (gera motor/contratos_sorocaba.json)
  2. python motor/imprensa_coletor_evora.py    (gera motor/noticias.json)
  3. python evora_ingestao_coletores.py --tenant-id <uuid> --mundo gabinete

VARIÁVEIS DE AMBIENTE OBRIGATÓRIAS (as mesmas do evora_motor_execucao.py):
    SUPABASE_URL
    SUPABASE_SERVICE_ROLE_KEY

DEPENDÊNCIA: nenhuma além da biblioteca padrão do Python (urllib, json,
email.utils) — mesma filosofia zero-dependência do motor/ original.

LIMITAÇÃO CONHECIDA (documentada, não escondida): contratos do PNCP sem
numeroControlePNCP (a API às vezes não devolve — ver ATENÇÃO no cabeçalho
de coletor_pncp_evora.py) não têm chave natural para deduplicar. Rodar
este script várias vezes para o mesmo dia pode duplicar SÓ esses casos.
Contratos COM número são upsert de verdade (mesmo número não duplica).
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from email.utils import parsedate_to_datetime


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


def _rest(method, url, service_key, body, prefer):
    dados = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=dados,
        method=method,
        headers={
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
            "Content-Type": "application/json",
            "Prefer": prefer,
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


def ingerir_contratos(cfg, caminho, tenant_id, mundo):
    if not os.path.exists(caminho):
        print(f"  (sem {caminho} — nada a ingerir de fiscalização)")
        return 0
    with open(caminho, encoding="utf-8") as f:
        contratos = json.load(f)
    if not contratos:
        return 0

    linhas = [
        {
            "tenant_id": tenant_id,
            "mundo": mundo,
            "numero_pncp": c.get("numero") or None,
            "objeto": c.get("objeto") or "(sem objeto)",
            "valor": c.get("valor") or 0,
            "orgao": c.get("orgao") or None,
            "fornecedor": c.get("fornecedor") or None,
            "municipio": c.get("municipio") or None,
            "data_publicacao": c.get("data_publicacao") or None,
            "relevancia": c.get("relevancia") or "rotina",
            "indicio": c.get("indicio") or None,
            "fonte": "PNCP",
        }
        for c in contratos
    ]
    url = cfg["supabase_url"] + "/rest/v1/achados_fiscalizacao?on_conflict=tenant_id,numero_pncp"
    _rest("POST", url, cfg["supabase_key"], linhas, prefer="resolution=merge-duplicates,return=minimal")
    return len(linhas)


def _parse_data_rss(bruta):
    """pubDate do RSS (RFC 2822, ex.: 'Tue, 18 Aug 2026 10:00:00 GMT') -> ISO8601, ou None se não der."""
    if not bruta:
        return None
    try:
        return parsedate_to_datetime(bruta).isoformat()
    except (TypeError, ValueError):
        return None


def ingerir_noticias(cfg, caminho, tenant_id, mundo):
    if not os.path.exists(caminho):
        print(f"  (sem {caminho} — nada a ingerir de imprensa)")
        return 0
    with open(caminho, encoding="utf-8") as f:
        noticias = json.load(f)

    linhas = []
    for n in noticias:
        link = n.get("link") or ""
        if not link:
            continue  # sem link não há como citar a fonte nem deduplicar (fonte ou silêncio)
        linhas.append({
            "tenant_id": tenant_id,
            "mundo": mundo,
            "titulo": n.get("titulo") or "(sem título)",
            "fonte_nome": n.get("fonte") or None,
            "link": link,
            "publicado_em": _parse_data_rss(n.get("data")),
            "publicado_em_bruto": n.get("data") or None,
            "consulta": n.get("consulta") or None,
        })
    if not linhas:
        return 0
    url = cfg["supabase_url"] + "/rest/v1/mencoes_imprensa?on_conflict=tenant_id,link"
    _rest("POST", url, cfg["supabase_key"], linhas, prefer="resolution=merge-duplicates,return=minimal")
    return len(linhas)


def main():
    ap = argparse.ArgumentParser(description="Ingestão dos coletores PNCP/imprensa no Supabase (Fase 6)")
    ap.add_argument("--tenant-id", required=True, help="uuid do tenant (gabinete)")
    ap.add_argument("--mundo", required=True, choices=["gabinete", "campanha"])
    ap.add_argument("--contratos", default=os.path.join("..", "motor", "contratos_sorocaba.json"))
    ap.add_argument("--noticias", default=os.path.join("..", "motor", "noticias.json"))
    args = ap.parse_args()

    cfg = carregar_ambiente()

    print("→ Ingerindo contratos (fiscalização)...")
    n1 = ingerir_contratos(cfg, args.contratos, args.tenant_id, args.mundo)
    print(f"  {n1} contrato(s) enviado(s) para achados_fiscalizacao.")

    print("→ Ingerindo notícias (imprensa)...")
    n2 = ingerir_noticias(cfg, args.noticias, args.tenant_id, args.mundo)
    print(f"  {n2} notícia(s) enviada(s) para mencoes_imprensa.")

    if n1 == 0 and n2 == 0:
        print("\n⚠ Nada foi ingerido — rode os coletores primeiro (ver docstring deste arquivo).")
        sys.exit(1)


if __name__ == "__main__":
    main()
