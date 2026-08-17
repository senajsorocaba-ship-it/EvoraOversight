#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Camada de Aprendizado (Guarda Constitucional)
================================================================
Aplica o feedback da autoridade (👍/👎 e sugestões) para calibrar a RELEVÂNCIA
e a FORMA do briefing — nunca a verdade, nunca as travas. Toda mudança entra
na trilha (append-only). É a materialização do "aprende com o uso" dentro dos
princípios do fundador.

REGRAS PÉTREAS (a Guarda Constitucional bloqueia qualquer aprendizado que):
  - tente alterar uma fonte ou apagar um fato verificado;
  - peça para publicar/decidir sozinho (o freio humano é inviolável);
  - tente remover a citação de origem;
  - empurre para opinião política ou recomendação de voto.

USO:
  Registrar feedback:  python3 aprendizado_evora.py fb <assunto_id> up|down "sugestão opcional"
  Ver pesos atuais:    python3 aprendizado_evora.py pesos
Arquivos: pesos_relevancia.json (estado) · trilha_aprendizado.log (append-only)
"""
import sys, json, os
from datetime import datetime

PESOS = "pesos_relevancia.json"
TRILHA = "trilha_aprendizado.log"

# frases/intenções que a Guarda Constitucional NÃO permite aprender
PROIBIDO = [
    "publicar sozinho", "postar automaticamente", "decidir sozinho",
    "remover fonte", "apagar fonte", "esconder origem",
    "recomendar voto", "atacar", "acusar sem prova",
]

def trilha(msg):
    with open(TRILHA, "a", encoding="utf-8") as f:
        f.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} · {msg}\n")

def carregar_pesos():
    if os.path.exists(PESOS):
        with open(PESOS, encoding="utf-8") as f:
            return json.load(f)
    return {}

def salvar_pesos(p):
    with open(PESOS, "w", encoding="utf-8") as f:
        json.dump(p, f, ensure_ascii=False, indent=2)

def guarda_constitucional(sugestao):
    """Retorna (permitido, motivo). Bloqueia sugestões que ferem as travas."""
    s = (sugestao or "").lower()
    for termo in PROIBIDO:
        if termo in s:
            return False, f"sugestão bloqueada pela Guarda Constitucional (contém: '{termo}')"
    return True, "ok"

def aplicar_feedback(assunto, sinal, sugestao=""):
    pesos = carregar_pesos()
    atual = pesos.get(assunto, 1.0)

    permitido, motivo = guarda_constitucional(sugestao)
    if not permitido:
        trilha(f"BLOQUEIO · assunto={assunto} · {motivo} · sugestão='{sugestao}'")
        print(f"⛔ {motivo}. Nada foi alterado. Registrado na trilha.")
        return

    if sinal == "up":
        novo = min(atual + 0.15, 3.0)      # sobe a relevância (teto)
    elif sinal == "down":
        novo = max(atual - 0.15, 0.2)      # desce (piso — nunca zera/apaga)
    else:
        print("Sinal inválido: use up ou down.")
        return

    pesos[assunto] = round(novo, 3)
    salvar_pesos(pesos)
    trilha(f"FEEDBACK · assunto={assunto} · {sinal} · peso {atual}→{pesos[assunto]}"
           + (f" · sugestão='{sugestao}' (encaminhada à VRX)" if sugestao else ""))
    print(f"✓ Relevância de '{assunto}': {atual} → {pesos[assunto]}")
    if sugestao:
        print("  Sugestão registrada e encaminhada à VRX (Porta de Suporte).")
    print("  A verdade e as fontes NÃO mudam — só a prioridade de exibição.")

def main():
    if len(sys.argv) < 2:
        print(__doc__); return
    cmd = sys.argv[1]
    if cmd == "pesos":
        print(json.dumps(carregar_pesos(), ensure_ascii=False, indent=2)); return
    if cmd == "fb" and len(sys.argv) >= 4:
        assunto, sinal = sys.argv[2], sys.argv[3]
        sugestao = sys.argv[4] if len(sys.argv) > 4 else ""
        aplicar_feedback(assunto, sinal, sugestao); return
    print("Uso: fb <assunto_id> up|down \"sugestão\"  |  pesos")

if __name__ == "__main__":
    main()
