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

Dois caminhos de coleta, igual pedido na Tarefa 1 do Briefing do Luiz
(13/11/2026): quando um veículo tem RSS próprio, coleta direto dele
(origem=rss_direto); senão, continua via Google News (origem=google_news).
Verificado nesta rodada (16/11/2026):
  - Sorocabanices (seção "Z Norte"): tem RSS próprio funcionando
    (sorocabanices.com.br/feed/, sem restrição no robots.txt) — migrado
    pra rss_direto.
  - Cruzeiro do Sul (jornalcruzeiro.com.br): site real confirmado, mas
    /rss e /feed/ devolveram 403 — sem RSS acessível encontrado. Continua
    via Google News.
  - Jovem Pan Sorocaba (91,1 FM): confirmado como praça real da rede, mas
    sem site dedicado com feed (jovempansorocaba.com.br é só uma página
    de apresentação, sem RSS). Entra via Google News.
  - "Jornal Olá": NÃO FOI POSSÍVEL CONFIRMAR que esse veículo existe em
    Sorocaba — nenhuma busca encontrou um jornal com esse nome na região.
    Por "não inventar dado", nenhuma consulta foi criada pra ele. Isto
    pede confirmação do Luiz: nome certo, ou o veículo não existe/não é
    indexado — ver aviso impresso e gravado no log a cada execução.

COMO RODAR (Claude Code / Python 3, sem instalar nada):
  python3 imprensa_coletor_evora.py
Usa só a biblioteca padrão (urllib + xml + logging). Saída: terminal +
noticias.json + coletor_imprensa.log (erros e avisos, com fonte/horário).
"""

import json
import logging
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from html import unescape

# Windows às vezes abre o terminal em cp1252, que não tem os acentos/símbolos
# usados nos prints abaixo (ex.: "→", "✓") — força utf-8 pra não derrubar o
# script no meio da coleta por causa só da formatação do print.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

# ===================== CONFIG (config zero) =====================
# Termos monitorados. Use aspas para frase exata; OR para alternativas.
CONSULTAS = [
    '"Tatiane Costa" OR "Tati Costa" Sorocaba',
    '"Câmara de Sorocaba"',
    'Sorocaba prefeitura',
    'Sorocaba segurança OR cultura OR educação',
    'Sorocaba "proteção à mulher" OR misoginia',
    '"Cruzeiro do Sul" Sorocaba',            # veículo canônico local (online) — sem RSS próprio acessível
    'site:jornalipanema.com.br Sorocaba',    # Jornal Ipanema / IPA Online
    'site:girosorocaba.com.br Sorocaba OR "Giro Sorocaba"',  # Giro Sorocaba
    'site:portalporque.com.br Sorocaba OR "Portal Porque"',  # Portal Porque
    '"Jovem Pan" Sorocaba',                  # Jovem Pan 91,1 FM — praça real, sem feed próprio
]
# Z Norte/Sorocabanices saiu daqui — tem RSS próprio, ver FONTES_RSS_DIRETO.
# Nacionais (G1/Globo, GloboNews, Record News) chegam pelo texto dos portais via agregador.
JANELA = "7d"          # when:7d → últimos 7 dias
MAX_POR_CONSULTA = 8
IDIOMA = "hl=pt-BR&gl=BR&ceid=BR:pt-BR"
BASE = "https://news.google.com/rss/search?q="

# Veículos com RSS próprio confirmado — coleta direta, sem passar pelo agregador.
FONTES_RSS_DIRETO = [
    {"nome": "Sorocabanices (Z Norte)", "url": "https://sorocabanices.com.br/feed/"},
]

# Veículo pedido na Tarefa 1 que não foi possível localizar — não inventar
# consulta pra ele; só avisar, alto e visível, em toda execução.
VEICULOS_PENDENTES_CONFIRMACAO = [
    "Jornal Olá — nenhum site/veículo com esse nome foi encontrado cobrindo "
    "Sorocaba-SP nesta verificação (16/11/2026). Confirmar com o Luiz o "
    "nome exato ou o endereço do veículo antes de adicionar a consulta.",
]

LOG_FILE = "coletor_imprensa.log"
# ================================================================

logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S%z",
    encoding="utf-8",  # console do Windows às vezes não é utf-8; o arquivo de log sempre é
)


def _agora_iso():
    return datetime.now(timezone.utc).isoformat()


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
    """Google News RSS — origem='google_news'."""
    q = urllib.parse.quote(f"{consulta} when:{JANELA}")
    url = f"{BASE}{q}&{IDIOMA}"
    try:
        xml_bruto = _get(url)
    except Exception as e:
        msg = f"google_news · consulta='{consulta}' · {e}"
        print(f"  ! erro em '{consulta}': {e}")
        logging.error(msg)
        return []
    try:
        root = ET.fromstring(xml_bruto)
    except ET.ParseError as e:
        msg = f"google_news · consulta='{consulta}' · XML inválido: {e}"
        print(f"  ! XML inválido em '{consulta}': {e}")
        logging.error(msg)
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
            "origem": "google_news",
            "coletado_em": _agora_iso(),
        })
        if len(itens) >= MAX_POR_CONSULTA:
            break
    return itens


def buscar_rss_direto(nome_fonte, url):
    """RSS do próprio site do veículo — origem='rss_direto'."""
    try:
        xml_bruto = _get(url)
    except Exception as e:
        msg = f"rss_direto · fonte='{nome_fonte}' · url={url} · {e}"
        print(f"  ! erro em '{nome_fonte}' (RSS direto): {e}")
        logging.error(msg)
        return []
    try:
        root = ET.fromstring(xml_bruto)
    except ET.ParseError as e:
        msg = f"rss_direto · fonte='{nome_fonte}' · url={url} · XML inválido: {e}"
        print(f"  ! XML inválido em '{nome_fonte}': {e}")
        logging.error(msg)
        return []
    itens = []
    for item in root.iter("item"):
        titulo = _limpa(item.findtext("title"))
        link = item.findtext("link") or ""
        data = item.findtext("pubDate") or ""
        itens.append({
            "titulo": titulo,
            "fonte": nome_fonte,
            "data": data,
            "link": link,
            "consulta": f"rss_direto:{nome_fonte}",
            "origem": "rss_direto",
            "coletado_em": _agora_iso(),
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
    print(f"Janela: últimos {JANELA} · {len(CONSULTAS)} consultas (Google News) "
          f"+ {len(FONTES_RSS_DIRETO)} fonte(s) com RSS direto")
    print("=" * 64)

    logging.info(f"Execução iniciada — {len(CONSULTAS)} consultas google_news, "
                 f"{len(FONTES_RSS_DIRETO)} fonte(s) rss_direto")

    for aviso in VEICULOS_PENDENTES_CONFIRMACAO:
        print(f"  [PENDENTE] {aviso}")
        logging.warning(f"veiculo_pendente_confirmacao - {aviso}")

    todos = []
    for c in CONSULTAS:
        print(f"→ buscando (google_news): {c}")
        todos += buscar(c)
    for f in FONTES_RSS_DIRETO:
        print(f"→ buscando (rss_direto): {f['nome']}")
        todos += buscar_rss_direto(f["nome"], f["url"])
    todos = dedup(todos)

    print(f"\n{len(todos)} notícias (após deduplicação):\n")
    print("-" * 64)
    print("BLOCO MONITORAMENTO — imprensa e menções")
    print("-" * 64)
    for n in todos[:20]:
        print(f"\n• {n['titulo']}")
        print(f"  {n['fonte']}  ·  {n['data']}  ·  {n['origem']}")

    with open("noticias.json", "w", encoding="utf-8") as f:
        json.dump(todos, f, ensure_ascii=False, indent=2)
    print("\n✓ Salvo em noticias.json (insumo do AIM-g para o briefing)")
    print("  Obs.: o AIM-g depois filtra por relevância e escreve o bloco.")

    logging.info(f"Execução concluída — {len(todos)} notícia(s) após deduplicação, "
                 f"gravadas em noticias.json")


if __name__ == "__main__":
    main()
