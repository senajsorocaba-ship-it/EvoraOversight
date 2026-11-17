#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Spike: pauta real da Câmara de Sorocaba
===========================================================
Entregável da Tarefa 2 (Briefing Técnico Guiron, 13/11/2026): baixa a
sessão mais recente publicada em sessoes.aspx e grava a pauta real (as
matérias da Ordem do Dia daquela sessão) em pauta_AAAAMMDD.json, com
fonte, link e coletado_em em cada item — só pra responder "dá pra ler a
pauta de forma automática?", NÃO o conector completo (isso é o spike,
ver CAMARA_SOROCABA_SPIKE.md pro relatório das 7 perguntas).

Site: sorocaba.camarasempapel.com.br — "Câmara Sem Papel" (ASP.NET
WebForms, página pública, sem login). robots.txt confirmado aberto
("User-agent: *" / "Allow: /", sem Disallow) em 16/11/2026. NÃO usa
nenhuma credencial do SAP/gabinete — só as duas páginas públicas abaixo.

Padrões de extração (sessoes.aspx, sessao-leitura.aspx) copiados de
`ao-SUPABASE-BLOCO1/evora_conector_agenda_legislativa.py` — já
verificados contra o site ao vivo numa sessão anterior (9 matérias reais
conferidas campo a campo). Copiados, não importados, porque este é um
script de investigação avulso (spike), separado da pipeline de produção;
não altera nem depende do arquivo original.

USO:
    python3 spike_pauta_camara.py
"""

import json
import re
import sys
import urllib.request
from datetime import datetime, timezone

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

DOMINIO = "sorocaba.camarasempapel.com.br"
CABECALHO = {"User-Agent": "Evora-Oversight-Spike/1.0 (investigacao Tarefa 2, nao producao)"}
TEMPO_LIMITE = 30

RE_LINHA_SESSAO = re.compile(
    r"<strong>\s*(?P<tipo>[A-ZÀ-Úa-zà-ú]+)\s*N°\s*(?P<numero>\d+)\s*</strong>.*?"
    r"sessao-leitura\.aspx\?id=(?P<id>\d+)&tip=1.*?"
    r"<strong>\s*Data:\s*</strong>\s*(?P<data>\d{2}/\d{2}/\d{4}).*?"
    r"<strong>\s*Horário\s*</strong>\s*(?P<horario>\d{2}:\d{2}).*?"
    r"Publicada em:\s*</strong>\s*(?P<publicada>[\d/: ]+?)\s*<",
    re.DOTALL,
)
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


def _baixar(url):
    req = urllib.request.Request(url, headers=CABECALHO)
    with urllib.request.urlopen(req, timeout=TEMPO_LIMITE) as r:
        return r.read().decode("utf-8", errors="replace")


def _agora_iso():
    return datetime.now(timezone.utc).isoformat()


def sessao_mais_recente():
    html = _baixar(f"https://{DOMINIO}/spl/sessoes.aspx")
    m = RE_LINHA_SESSAO.search(html)
    if not m:
        raise SystemExit(
            "Não achei nenhuma sessão em sessoes.aspx — a página pode ter mudado "
            "de estrutura desde a última verificação (16/09/2026)."
        )
    return {
        "id": m.group("id"),
        "tipo": m.group("tipo").strip(),
        "numero": m.group("numero"),
        "data": m.group("data"),
        "horario": m.group("horario"),
        "publicada_em": m.group("publicada").strip(),
    }


def extrair_materias(html):
    inicio = html.find('id="ContentPlaceHolder1_grv_sessoes_proposicoes"')
    if inicio == -1:
        return []
    corpo = html[inicio:]
    blocos = re.split(r"</td>\s*</tr>\s*<tr>\s*<td>", corpo)

    materias = []
    for bloco in blocos:
        m_ordem = RE_ORDEM.search(bloco)
        if not m_ordem:
            continue
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


def _nome_arquivo(sessao):
    # AAAAMMDD a partir da DATA DA SESSÃO (a pauta é dela, não do dia em que
    # rodamos o script) — cai pra hoje só se a data vier num formato
    # inesperado (honesto: nunca inventa um dia que não leu).
    try:
        d, m, a = sessao["data"].split("/")
        return f"pauta_{a}{m}{d}.json"
    except ValueError:
        return f"pauta_{datetime.now().strftime('%Y%m%d')}.json"


def main():
    print("=" * 64)
    print("ÉVORA — Spike: pauta real da Câmara de Sorocaba (Tarefa 2)")
    print("=" * 64)

    print("→ buscando a sessão mais recente em sessoes.aspx...")
    sessao = sessao_mais_recente()
    print(f"  {sessao['tipo']} Nº {sessao['numero']} — {sessao['data']} {sessao['horario']} "
          f"(id={sessao['id']})")

    url_sessao = f"https://{DOMINIO}/spl/sessao-leitura.aspx?id={sessao['id']}&tip=1"
    print(f"→ baixando a Ordem do Dia Completa: {url_sessao}")
    html = _baixar(url_sessao)
    materias = extrair_materias(html)
    print(f"  {len(materias)} matéria(s) encontrada(s)")

    coletado_em = _agora_iso()
    pauta = {
        "sessao": {**sessao, "fonte": "Câmara Sem Papel — Sorocaba/SP", "link": url_sessao,
                   "coletado_em": coletado_em},
        "materias": [
            {
                **materia,
                "fonte": "Câmara Sem Papel — Sorocaba/SP",
                "link": f"https://{DOMINIO}/processo.aspx?id={materia['processo_id']}",
                "coletado_em": coletado_em,
            }
            for materia in materias
        ],
    }

    nome_arquivo = _nome_arquivo(sessao)
    with open(nome_arquivo, "w", encoding="utf-8") as f:
        json.dump(pauta, f, ensure_ascii=False, indent=2)

    print(f"\n✓ Salvo em {nome_arquivo}")
    if not materias:
        print("  Aviso: 0 matérias extraídas — pode ser uma sessão Solene (sem Ordem do "
          "Dia) ou a estrutura da página mudou. Confira manualmente antes de concluir "
          "que o conector quebrou.")


if __name__ == "__main__":
    main()
