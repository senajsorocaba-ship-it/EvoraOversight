#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Orquestrador do Briefing
==========================================
Roda o pipeline completo do Briefing Matinal, na ordem:
  1) coletor de imprensa   -> noticias.json
  2) coletor do PNCP       -> contratos_sorocaba.json
  3) montador (a Bia)      -> briefing_AAAAMMDD.md   (usa a API da Claude)
  4) render                -> briefing_AAAAMMDD.html

Tolerante a falha: se um coletor falhar (rede/fonte fora do ar), registra o
aviso em avisos_evora.log (data · hora · ocorrência) e segue com o que tem —
padrão ouro: degradar avisando, nunca falhar em silêncio.

USO:  python3 orquestrador_evora.py
Requer: ANTHROPIC_API_KEY definida (só para o passo 3).
"""
import subprocess, sys, os
from datetime import datetime, date

PASSOS = [
    ("Coletor de imprensa", "imprensa_coletor_evora.py", False),
    ("Coletor do PNCP",     "coletor_pncp_evora.py",     False),
    ("Montador (Bia escreve o briefing)", "montador_briefing_evora.py", True),
    ("Render do briefing",  "render_briefing_evora.py",  False),
]

def aviso(msg):
    """Registra ocorrência na caixa de avisos rastreados (padrão do sistema)."""
    linha = f"{datetime.now():%Y-%m-%d %H:%M:%S} · {msg}\n"
    with open("avisos_evora.log", "a", encoding="utf-8") as f:
        f.write(linha)
    print("  ⚠  " + msg)

def roda(nome, script, critico):
    print(f"\n▶ {nome}  ({script})")
    if not os.path.exists(script):
        aviso(f"{nome}: script {script} não encontrado — passo pulado.")
        return not critico
    try:
        r = subprocess.run([sys.executable, script], timeout=300)
        if r.returncode != 0:
            aviso(f"{nome}: terminou com código {r.returncode}.")
            return not critico
        return True
    except subprocess.TimeoutExpired:
        aviso(f"{nome}: tempo esgotado (timeout).")
        return not critico
    except Exception as e:
        aviso(f"{nome}: erro {e}.")
        return not critico

def main():
    print("=" * 64)
    print("ÉVORA OVERSIGHT — Orquestrador do Briefing Matinal")
    print(f"Data: {date.today():%d/%m/%Y}")
    print("=" * 64)
    if not os.environ.get("ANTHROPIC_API_KEY"):
        aviso("ANTHROPIC_API_KEY não definida — o passo do montador vai falhar. "
              "Defina a chave antes (veja o GUIA).")
    for nome, script, critico in PASSOS:
        ok = roda(nome, script, critico)
        if not ok:
            print(f"\n✗ Pipeline interrompido em: {nome} (passo crítico).")
            print("  Veja avisos_evora.log para o histórico rastreado.")
            return
    nome_html = f"briefing_{date.today():%Y%m%d}.html"
    print("\n" + "=" * 64)
    print("✓ Briefing gerado.")
    print(f"  Abra: {nome_html}")
    print("  Avisos (se houver): avisos_evora.log")
    print("=" * 64)

if __name__ == "__main__":
    main()
