#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Montador do Briefing Matinal (a Bia escreve, via API da Claude)
=================================================================================
Pega o que os coletores juntaram (contratos do PNCP + notícias) e a BIA
(Gestora do Gabinete) escreve o Briefing Matinal em português, no formato e
nas regras do Manual v6.0. É a peça que transforma DADO em RELATÓRIO PRONTO.

Entradas (geradas pelos coletores):
  • contratos_sorocaba.json   (do coletor/módulo PNCP)
  • noticias.json             (do coletor de imprensa)
Se algum faltar, o montador segue só com o que existir.

Saída:
  • briefing_AAAAMMDD.md  + impressão no terminal

PRÉ-REQUISITO: uma chave da API da Claude (sua conta Anthropic), na variável
de ambiente ANTHROPIC_API_KEY. É pago por uso (centavos por briefing).
  No Mac/Linux:  export ANTHROPIC_API_KEY="sua-chave"
  No Windows:    setx ANTHROPIC_API_KEY "sua-chave"

COMO RODAR (Claude Code / Python 3, sem instalar nada — usa só stdlib):
  python3 montador_briefing_evora.py
"""

import os, json, urllib.request, urllib.error
from datetime import date

MODELO   = "claude-sonnet-4-6"   # bom custo/qualidade; pode trocar por claude-opus-4-8
MAX_TOK  = 2000
API_URL  = "https://api.anthropic.com/v1/messages"

# Persona + regras pétreas embutidas (a "constituição" da Bia para o briefing)
SISTEMA = """Você é a Bia, Gestora do Gabinete na plataforma Évora Oversight.
Sua tarefa: escrever o Briefing Matinal da vereadora Tatiane Costa (PL, Sorocaba/SP),
pré-candidata a Deputada Federal 2026, a partir SOMENTE dos dados fornecidos.

REGRAS INVIOLÁVEIS:
- Não invente nada. Use apenas os dados recebidos. Se algo não vier, diga que não há registro hoje.
- Cada item relevante deve citar a fonte/origem.
- Tom factual, conciso, respeitoso. Sem opinião pessoal, sem recomendação de voto.
- O bloco de fiscalização é sempre "indício para acompanhar, NUNCA acusação".
- Marque relevância quando útil (Rotina / Atenção).
- O bloco "Movimento sugerido" traz sugestões que dependem de APROVAÇÃO HUMANA (freio humano).

FORMATO (markdown, blocos nesta ordem, só inclua os que tiverem conteúdo):
# Briefing Matinal — {data}
## Resumo do dia  (3 a 5 marcadores)
## Fiscalização do Executivo  (indícios do PNCP; indício, não acusação)
## Monitoramento & Imprensa  (manchetes relevantes, com a fonte)
## Movimento sugerido (72h)  (sugestões; nada sai sem aprovação)
Seja objetivo — isto é lido às 6h45 no celular."""


def carregar(caminho):
    if not os.path.exists(caminho):
        return None
    try:
        with open(caminho, encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return None


def resumir_contratos(contratos, top=8):
    """Reduz a lista a um resumo enxuto para o prompt (economiza tokens)."""
    if not contratos:
        return "Sem dados de contratos (rode o coletor PNCP)."
    total = sum(c.get("valor", 0) for c in contratos)
    maiores = sorted(contratos, key=lambda c: c.get("valor", 0), reverse=True)[:top]
    linhas = [f"Total: {len(contratos)} contratos somando R$ {total:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")]
    for c in maiores:
        v = c.get("valor", 0)
        linhas.append(f"- R$ {v:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".") +
                      f" | {c.get('objeto','—')[:70]} | órgão: {c.get('orgao','—')} "
                      f"| fornecedor: {c.get('fornecedor','—')} | {c.get('relevancia','')} "
                      f"| publicado: {c.get('data_publicacao','—')}")
    return "\n".join(linhas)


def resumir_noticias(noticias, top=12):
    if not noticias:
        return "Sem notícias coletadas (rode o coletor de imprensa)."
    linhas = []
    for n in noticias[:top]:
        linhas.append(f"- {n.get('titulo','—')} | fonte: {n.get('fonte','—')} | {n.get('data','')}")
    return "\n".join(linhas)


def montar_mensagem(contratos, noticias):
    return f"""Dados de hoje para o briefing.

[FISCALIZAÇÃO — contratos públicos (PNCP)]
{resumir_contratos(contratos)}

[IMPRENSA — notícias coletadas]
{resumir_noticias(noticias)}

Escreva o Briefing Matinal seguindo o formato e as regras. Data de hoje: {date.today().strftime('%d/%m/%Y')}."""


def chamar_api(mensagem):
    chave = os.environ.get("ANTHROPIC_API_KEY")
    if not chave:
        raise SystemExit("⚠️  Defina a variável ANTHROPIC_API_KEY com sua chave da API da Claude.")
    corpo = json.dumps({
        "model": MODELO,
        "max_tokens": MAX_TOK,
        "system": SISTEMA,
        "messages": [{"role": "user", "content": mensagem}],
    }).encode("utf-8")
    req = urllib.request.Request(API_URL, data=corpo, headers={
        "x-api-key": chave,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            dados = json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        raise SystemExit(f"Erro da API ({e.code}): {e.read().decode('utf-8')[:300]}")
    # a resposta vem em content: [{type:'text', text:'...'}]
    partes = [b.get("text", "") for b in dados.get("content", []) if b.get("type") == "text"]
    return "\n".join(partes).strip()


def main():
    print("→ Carregando dados dos coletores...")
    contratos = carregar("contratos_sorocaba.json")
    noticias = carregar("noticias.json")
    if not contratos and not noticias:
        print("Nenhum dado encontrado. Rode primeiro os coletores (PNCP e imprensa).")
        # segue mesmo assim, para você ver o formato
    mensagem = montar_mensagem(contratos, noticias)

    print("→ A Bia está escrevendo o briefing (API da Claude)...\n")
    texto = chamar_api(mensagem)
    print(texto)

    nome = f"briefing_{date.today().strftime('%Y%m%d')}.md"
    with open(nome, "w", encoding="utf-8") as f:
        f.write(texto + "\n")
    print(f"\n✓ Briefing salvo em {nome}")


if __name__ == "__main__":
    main()
