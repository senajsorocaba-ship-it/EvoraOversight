#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Renderizador do Briefing (markdown -> HTML on-brand)
======================================================================
Pega o briefing_AAAAMMDD.md (escrito pela Bia) e gera um HTML no padrão visual
do Évora (navy + dourado), pronto para ler no celular às 06h45.

Usa só a biblioteca padrão. Conversão de markdown propositalmente simples
(títulos, listas, negrito) — suficiente para o formato do briefing.

USO:  python3 render_briefing_evora.py            (pega o briefing de hoje)
      python3 render_briefing_evora.py arquivo.md (renderiza um específico)
"""
import sys, re, html
from datetime import date

CSS = """
:root{--navy:#213A5C;--gold:#B5985A;--cream:#F4F1EA;--paper:#FBFAF6;--ink:#23272e;--mut:#5b6470;--line:#E4DED1;--soft:#EEF2F7}
*{box-sizing:border-box;margin:0;padding:0}
body{background:var(--cream);color:var(--ink);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;line-height:1.55}
.wrap{max-width:620px;margin:0 auto;padding-bottom:50px}
.top{background:var(--navy);color:#fff;padding:18px}
.bname{font-family:Georgia,serif;letter-spacing:.26em;font-size:12px}
.bname b{color:var(--gold)}
.btitle{font-family:Georgia,serif;font-size:22px;margin-top:8px}
.bsub{font-size:12.5px;color:#b9c6d6;margin-top:2px}
.block{margin:16px 14px 0;background:var(--paper);border:1px solid var(--line);border-radius:9px;padding:14px 16px}
h1{display:none}
h2{font-family:Georgia,serif;font-size:16px;color:var(--navy);margin:0 0 8px;padding-bottom:6px;border-bottom:1px solid var(--line)}
ul{margin:4px 0 0 18px}li{font-size:14px;margin:5px 0}
p{font-size:14px;margin:6px 0}
strong{color:var(--navy)}
.foot{margin:18px 14px 0;font-size:11px;color:var(--mut);text-align:center;line-height:1.6}
"""

def _bold(s):
    s = html.escape(s)
    return re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)

def md_to_html(md):
    # Rastreia bloco aberto (in_block) para nunca deixar </div> órfão.
    # Blocos = cada "## ". O bloco só é fechado se de fato houver um aberto.
    out, in_ul, in_block = [], False, False
    for raw in md.splitlines():
        line = raw.rstrip()
        if not line.strip():
            if in_ul: out.append("</ul>"); in_ul = False
            continue
        if line.startswith("# "):
            if in_ul: out.append("</ul>"); in_ul = False
            out.append(f"<h1>{_bold(line[2:])}</h1>")
        elif line.startswith("## "):
            if in_ul: out.append("</ul>"); in_ul = False
            if in_block: out.append("</div>")   # fecha o bloco anterior, se houver
            out.append(f'<div class="block"><h2>{_bold(line[3:])}</h2>')
            in_block = True
        elif line.lstrip().startswith(("- ", "* ")):
            if not in_ul: out.append("<ul>"); in_ul = True
            out.append(f"<li>{_bold(line.lstrip()[2:])}</li>")
        else:
            if in_ul: out.append("</ul>"); in_ul = False
            out.append(f"<p>{_bold(line)}</p>")
    if in_ul: out.append("</ul>")
    if in_block: out.append("</div>")           # fecha o último bloco, se houver
    return "\n".join(out)

def main():
    arq = sys.argv[1] if len(sys.argv) > 1 else f"briefing_{date.today().strftime('%Y%m%d')}.md"
    try:
        md = open(arq, encoding="utf-8").read()
    except FileNotFoundError:
        raise SystemExit(f"Arquivo não encontrado: {arq} (rode antes o montador).")
    corpo = md_to_html(md)
    page = f"""<!DOCTYPE html><html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Briefing Matinal — Évora</title><style>{CSS}</style></head><body>
<div class="wrap">
  <div class="top">
    <div class="bname">ÉVORA <b>GABINETE</b></div>
    <div class="btitle">Briefing Matinal</div>
    <div class="bsub">{date.today().strftime('%d/%m/%Y')} · 06h45 · gerado pela Bia a partir de fontes públicas</div>
  </div>
  {corpo}
  <div class="foot">ÉVORA OVERSIGHT · cada item com origem declarada · uso interno do gabinete<br>Indício é para verificação humana — nunca acusação.</div>
</div></body></html>"""
    saida = arq.replace(".md", ".html")
    open(saida, "w", encoding="utf-8").write(page)
    print(f"✓ Briefing renderizado em {saida}")

if __name__ == "__main__":
    main()
