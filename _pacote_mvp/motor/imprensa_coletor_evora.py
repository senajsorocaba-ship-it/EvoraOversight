#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Coletor de Imprensa (alimenta o AIM-g · Monitoramento)
========================================================================
Busca notícias no Google News (feed RSS público, sem chave/sem custo) sobre
a autoridade, a cidade e os temas de interesse — e devolve a lista limpa que
o agente AIM-g usa no bloco de Monitoramento do Briefing Matinal.

Por que Google News RSS: é uma "API silenciosa" — uma URL pública que
devolve notícias em XML, sem login, sem limite, agregando milhares de fontes.

COMO RODAR (Claude Code / Python 3, sem instalar nada):
  python3 imprensa_coletor_evora.py
Usa só a biblioteca padrão (urllib + xml). Saída: terminal + noticias.json
"""

import json, urllib.request, urllib.parse, xml.etree.ElementTree as ET
from datetime import datetime
from html import unescape
import re

# ===================== CONFIG (config zero) =====================
# Termos monitorados. Use aspas para frase exata; OR para alternativas.
CONSULTAS = [
    '"Tatiane Costa" OR "Tati Costa" OR "Vereadora Tati" OR "Vereadora Tatiane" Sorocaba',
    '"gabinete 6" "Câmara de Sorocaba" OR "vereadora Tatiane"',  # gabinete dela; termo fraco na imprensa — pode retornar pouco
    '"Câmara de Sorocaba"',
    'Sorocaba prefeitura',
    'Sorocaba segurança OR cultura OR educação',
    'Sorocaba "proteção à mulher" OR misoginia',
    '"Cruzeiro do Sul" Sorocaba',            # veículo canônico local (online)
    '"Z Norte" Sorocaba OR Sorocabanices',   # veículo canônico local (seção Sorocabanices)
    'site:jornalipanema.com.br Sorocaba',    # Jornal Ipanema / IPA Online
    'site:girosorocaba.com.br Sorocaba OR "Giro Sorocaba"',  # Giro Sorocaba
    'site:portalporque.com.br Sorocaba OR "Portal Porque"',  # Portal Porque
]
# Nota: no MVP os veículos entram via Google News (agregador). O conector direto
# por site (Cruzeiro do Sul online, Z Norte) entra na fase COM — conector direto por veículo.
# Nacionais (G1/Globo, GloboNews, Record News) chegam pelo texto dos portais via agregador.
JANELA = "7d"          # when:7d → últimos 7 dias
MAX_POR_CONSULTA = 8
IDIOMA = "hl=pt-BR&gl=BR&ceid=BR:pt-BR"
BASE = "https://news.google.com/rss/search?q="
# ================================================================


def _get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Evora-Oversight/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()


def _limpa(txt):
    if not txt:
        return ""
    txt = re.sub(r"<[^>]+>", "", txt)      # tira HTML
    return unescape(txt).strip()


def buscar(consulta):
    q = urllib.parse.quote(f"{consulta} when:{JANELA}")
    url = f"{BASE}{q}&{IDIOMA}"
    try:
        xml = _get(url)
    except Exception as e:
        print(f"  ! erro em '{consulta}': {e}")
        return []
    try:
        root = ET.fromstring(xml)
    except ET.ParseError:
        return []
    itens = []
    for item in root.iter("item"):
        titulo = _limpa(item.findtext("title"))
        link = item.findtext("link") or ""
        data = item.findtext("pubDate") or ""
        fonte_el = item.find("source")
        fonte = _limpa(fonte_el.text) if fonte_el is not None else ""
        # o título do Google News vem "Manchete - Fonte"; separa
        if not fonte and " - " in titulo:
            titulo, fonte = titulo.rsplit(" - ", 1)
        itens.append({
            "titulo": titulo,
            "fonte": fonte,
            "data": data,
            "link": link,
            "consulta": consulta,
        })
        if len(itens) >= MAX_POR_CONSULTA:
            break
    return itens


def dedup(itens):
    visto, out = set(), []
    for it in itens:
        chave = it["titulo"].lower()[:80]
        if chave not in visto:
            visto.add(chave)
            out.append(it)
    return out


def main():
    print("=" * 64)
    print("ÉVORA — Coletor de Imprensa (AIM-g · Monitoramento)")
    print(f"Janela: últimos {JANELA} · {len(CONSULTAS)} consultas")
    print("=" * 64)

    todos = []
    for c in CONSULTAS:
        print(f"→ buscando: {c}")
        todos += buscar(c)
    todos = dedup(todos)

    print(f"\n{len(todos)} notícias (após deduplicação):\n")
    print("-" * 64)
    print("BLOCO MONITORAMENTO — imprensa e menções")
    print("-" * 64)
    for n in todos[:20]:
        print(f"\n• {n['titulo']}")
        print(f"  {n['fonte']}  ·  {n['data']}")

    with open("noticias.json", "w", encoding="utf-8") as f:
        json.dump(todos, f, ensure_ascii=False, indent=2)
    print("\n✓ Salvo em noticias.json (insumo do AIM-g para o briefing)")
    print("  Obs.: o AIM-g depois filtra por relevância e escreve o bloco.")


if __name__ == "__main__":
    main()
