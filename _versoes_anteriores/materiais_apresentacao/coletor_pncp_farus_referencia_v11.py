#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════════════
# ÉVORA OVERSIGHT — COLETOR PNCP → FARUS
# ═══════════════════════════════════════════════════════════════════════════
#
# Lê contratações públicas do PNCP e grava no acervo FARUS.
#
# ── ESTE ARQUIVO É O MODELO DOS DEMAIS COLETORES ──────────────────────────
# Guiron: leia até o fim antes de escrever o coletor de Diário Oficial ou o
# de imprensa. O que está aqui vale para todos:
#
#   1. Coletor NUNCA lê o acervo para decidir o que coletar
#   2. Escreve com service_role, nunca com credencial de aplicação
#   3. Usa farus_hash do banco — não calcula hash por conta própria
#   4. on conflict do nothing — a mesma matéria não entra duas vezes
#   5. Grava o resultado da execução MESMO QUANDO VAZIO
#   6. Falha de um coletor não derruba os outros
#
# ── O QUE MUDOU EM RELAÇÃO AO COLETOR ANTERIOR ────────────────────────────
# Antes: gravava em contratos_sorocaba.json, arquivo local sobrescrito a cada
# execução. Cada briefing recomeçava do zero.
# Agora: grava em farus_itens. O acervo permanece, permite comparação
# histórica, e é compartilhado entre os gabinetes do mesmo município.
#
# ── USO ────────────────────────────────────────────────────────────────────
#   export EVORA_DB="postgresql://usuario:senha@host:5432/postgres"
#   python3 coletor_pncp_farus.py --municipio Sorocaba --uf SP --dias 7
#   python3 coletor_pncp_farus.py --municipio Sorocaba --uf SP --ensaio
#
# `--ensaio` mostra o que gravaria, sem gravar. Use sempre na primeira vez.
# ═══════════════════════════════════════════════════════════════════════════

import argparse
import json
import os
import statistics
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import date, timedelta

try:
    import psycopg2
    from psycopg2.extras import execute_batch
except ImportError:
    sys.exit("Falta a biblioteca. Rode:  pip install psycopg2-binary")


BASE = "https://pncp.gov.br/api/consulta/v1/contratos"
TEMPO_LIMITE = 45
CABECALHO = {"User-Agent": "Evora-Oversight/1.0 (coletor institucional)"}


# ═══════════════════════════════════════════════════════════════════════════
# 1. BUSCA NA FONTE
# ═══════════════════════════════════════════════════════════════════════════

def buscar_contratos(dias, pagina=1):
    """Consulta a API pública do PNCP. Devolve lista vazia em caso de falha —
    nunca levanta exceção para fora. Briefing com 6 blocos é melhor que
    briefing nenhum."""
    fim = date.today()
    ini = fim - timedelta(days=dias)
    params = {
        "dataInicial": ini.strftime("%Y%m%d"),
        "dataFinal":   fim.strftime("%Y%m%d"),
        "pagina":      str(pagina),
        "tamanhoPagina": "500",
    }
    url = f"{BASE}?{urllib.parse.urlencode(params)}"
    try:
        req = urllib.request.Request(url, headers=CABECALHO)
        with urllib.request.urlopen(req, timeout=TEMPO_LIMITE) as r:
            dados = json.loads(r.read().decode("utf-8"))
    except urllib.error.URLError as e:
        print(f"  ! PNCP inacessível ({e.reason}) — o bloco dirá 'sem dado hoje'")
        return []
    except Exception as e:
        print(f"  ! erro ao consultar o PNCP: {e}")
        return []

    itens = dados.get("data", dados) if isinstance(dados, dict) else dados
    return itens if isinstance(itens, list) else []


def normalizar(itens, municipio):
    """Achata a resposta do PNCP num formato estável.

    A API varia os nomes dos campos entre versões, por isso cada campo
    tenta várias chaves. Se o PNCP mudar, o coletor degrada em vez de
    quebrar — e o campo vem vazio, que é honesto."""
    out = []
    for it in itens:
        def g(*chaves):
            for k in chaves:
                if isinstance(it, dict) and it.get(k) not in (None, ""):
                    return it[k]
            return ""

        mun = str(g("municipioNome", "municipio", "nomeMunicipio"))
        if municipio and mun and municipio.lower() not in mun.lower():
            continue

        out.append({
            "numero":     str(g("numeroControlePNCP", "numeroContrato", "numero")),
            "objeto":     str(g("objetoContrato", "objeto", "descricaoObjeto")),
            "valor":      float(g("valorGlobal", "valorInicial", "valor") or 0),
            "orgao":      str(g("orgaoEntidadeRazaoSocial", "orgao", "nomeOrgao")),
            "fornecedor": str(g("nomeRazaoSocialFornecedor", "fornecedor", "nomeFornecedor")),
            "publicado":  str(g("dataPublicacaoPncp", "dataPublicacao", "data"))[:10],
            "municipio":  mun,
            "url":        str(g("linkSistemaOrigem", "urlContrato", "")),
        })
    return out


# ═══════════════════════════════════════════════════════════════════════════
# 2. INDÍCIOS — a parte que exige mais cuidado
# ═══════════════════════════════════════════════════════════════════════════

def sinalizar_indicios(contratos, limiar):
    """Marca contratos acima da mediana dos comparáveis.

    ── A REGRA QUE NÃO SE NEGOCIA ─────────────────────────────────────────
    Indício NUNCA é acusação. O texto aponta o fato verificável e a base de
    comparação, e diz onde conferir. Não afirma irregularidade, sobrepreço,
    fracionamento nem má-fé — essas são conclusões, e conclusão é da pessoa.

    Com menos de 4 comparáveis não se sinaliza nada: mediana de 3 contratos
    não é base, é ruído.
    """
    valores = [c["valor"] for c in contratos if c["valor"] > 0]
    if len(valores) < 4:
        for c in contratos:
            c["indicio"] = ""
        return contratos

    mediana = statistics.median(valores)
    for c in contratos:
        if c["valor"] > 0 and c["valor"] > mediana * (1 + limiar):
            desvio = (c["valor"] / mediana - 1) * 100
            c["indicio"] = (
                f"Valor {desvio:.0f}% acima da mediana dos contratos do período. "
                f"Base de comparação: mediana de {len(valores)} contratos no PNCP "
                f"(R$ {mediana:,.2f}). Limiar configurado pelo gabinete: "
                f"{int(limiar*100)}%. Fato verificável na fonte — verificação e "
                f"eventual questionamento são decisão humana."
            )
        else:
            c["indicio"] = ""
    return contratos


# ═══════════════════════════════════════════════════════════════════════════
# 3. GRAVAÇÃO NO FARUS
# ═══════════════════════════════════════════════════════════════════════════

SQL_TERRITORIO = """
select id from farus_territorios
 where lower(municipio) = lower(%s) and uf = %s and ativo
 limit 1
"""

SQL_FONTE = """
select id from farus_fontes
 where territorio_id = %s and especie = 'contratacao' and estado = 'configurada'
 limit 1
"""

# O insert usa farus_hash do PRÓPRIO BANCO.
# Calcular o hash em Python divergiria da regra do banco e duplicaria em silêncio.
SQL_INSERT = """
insert into farus_itens (
  territorio_id, origem_aquisicao, especie, titulo, conteudo,
  url, publicado_em, fonte_id, estado, verificado_por, verificado_em, hash_conteudo
) values (
  %(territorio)s, 'coleta_programada', 'contratacao', %(titulo)s, %(conteudo)s,
  nullif(%(url)s,''), nullif(%(publicado)s,'')::date, %(fonte)s,
  'confirmado', 'motor', now(), farus_hash(%(titulo)s, %(conteudo)s)
)
on conflict (territorio_id, hash_conteudo) do nothing
"""


def montar_texto(c):
    """Monta título e conteúdo do item de acervo.

    O título precisa ser estável: ele entra no hash de deduplicação. Se o
    título variar a cada execução, o mesmo contrato entra várias vezes."""
    titulo = f"Contrato {c['numero']} — {c['objeto'][:160]}".strip()
    partes = [
        f"Órgão: {c['orgao']}" if c['orgao'] else "",
        f"Fornecedor: {c['fornecedor']}" if c['fornecedor'] else "",
        f"Valor: R$ {c['valor']:,.2f}" if c['valor'] else "",
        f"Município: {c['municipio']}" if c['municipio'] else "",
        f"\nINDÍCIO PARA VERIFICAÇÃO: {c['indicio']}" if c['indicio'] else "",
    ]
    return titulo, "\n".join(p for p in partes if p)


def gravar(conn, territorio_id, fonte_id, contratos, ensaio=False):
    """Grava no acervo. Devolve quantos entraram de fato.

    `on conflict do nothing` faz o repetido ser ignorado em silêncio — por
    isso contamos pelo rowcount, não pelo tamanho da lista."""
    linhas = []
    for c in contratos:
        titulo, conteudo = montar_texto(c)
        linhas.append({
            "territorio": territorio_id,
            "titulo":     titulo,
            "conteudo":   conteudo,
            "url":        c["url"],
            "publicado":  c["publicado"] if len(c["publicado"]) == 10 else "",
            "fonte":      fonte_id,
        })

    if ensaio:
        print(f"\n  [ENSAIO] {len(linhas)} itens seriam gravados. Amostra:")
        for l in linhas[:3]:
            print(f"    · {l['titulo'][:88]}")
        return 0

    gravados = 0
    with conn.cursor() as cur:
        for l in linhas:
            cur.execute(SQL_INSERT, l)
            gravados += cur.rowcount
    conn.commit()
    return gravados


# ═══════════════════════════════════════════════════════════════════════════
# 4. REGISTRO DA EXECUÇÃO
# ═══════════════════════════════════════════════════════════════════════════

def registrar_execucao(municipio, encontrados, gravados, indicios, erro=None):
    """Grava o resultado MESMO QUANDO VAZIO.

    ── POR QUE ISSO IMPORTA ───────────────────────────────────────────────
    Sem este registro, não há como distinguir "não havia contrato novo hoje"
    de "o coletor falhou". A primeira situação produz 'sem dado hoje' no
    briefing, que é resposta honesta. A segunda é falha silenciosa, que é o
    pior modo de falhar.
    """
    linha = {
        "coletor": "pncp",
        "municipio": municipio,
        "quando": date.today().isoformat(),
        "encontrados": encontrados,
        "gravados": gravados,
        "indicios": indicios,
        "erro": erro,
        "resultado": "falha" if erro else ("vazio" if encontrados == 0 else "sucesso"),
    }
    caminho = "execucoes_coletor.jsonl"
    with open(caminho, "a", encoding="utf-8") as f:
        f.write(json.dumps(linha, ensure_ascii=False) + "\n")
    return linha


# ═══════════════════════════════════════════════════════════════════════════

def main():
    p = argparse.ArgumentParser(description="Coletor PNCP → FARUS")
    p.add_argument("--municipio", required=True)
    p.add_argument("--uf", required=True)
    p.add_argument("--dias", type=int, default=7)
    p.add_argument("--limiar", type=float, default=0.25,
                   help="desvio acima da mediana para sinalizar (padrão 0.25)")
    p.add_argument("--ensaio", action="store_true",
                   help="mostra o que gravaria, sem gravar")
    args = p.parse_args()

    print("═" * 68)
    print("ÉVORA — Coletor PNCP → FARUS")
    print(f"{args.municipio}/{args.uf} · janela {args.dias} dias · "
          f"limiar {int(args.limiar*100)}%" + ("  [ENSAIO]" if args.ensaio else ""))
    print("═" * 68)

    dsn = os.environ.get("EVORA_DB")
    if not dsn:
        sys.exit("\n  ✗ Falta a variável EVORA_DB com a conexão do banco.\n"
                 "    export EVORA_DB=\"postgresql://usuario:senha@host:5432/postgres\"\n")

    # ── busca ──
    brutos = buscar_contratos(args.dias)
    print(f"\n  PNCP devolveu {len(brutos)} contratos no período")
    contratos = sinalizar_indicios(normalizar(brutos, args.municipio), args.limiar)
    indicios = [c for c in contratos if c["indicio"]]
    print(f"  {len(contratos)} de {args.municipio} · {len(indicios)} com indício")

    if indicios:
        print("\n  ── indícios para verificação humana ──")
        for c in indicios[:5]:
            print(f"    • {c['objeto'][:62]}")
            print(f"      R$ {c['valor']:,.2f} — {c['indicio'][:76]}…")

    # ── grava ──
    erro = None
    gravados = 0
    try:
        conn = psycopg2.connect(dsn)
        with conn.cursor() as cur:
            cur.execute(SQL_TERRITORIO, (args.municipio, args.uf))
            row = cur.fetchone()
            if not row:
                raise RuntimeError(
                    f"território {args.municipio}/{args.uf} não cadastrado em "
                    f"farus_territorios — cadastre antes de coletar")
            territorio_id = row[0]

            cur.execute(SQL_FONTE, (territorio_id,))
            row = cur.fetchone()
            if not row:
                raise RuntimeError(
                    "não há fonte de contratação 'configurada' para este território. "
                    "Cadastre o PNCP como fonte e libere-a — decisão D6: nenhuma "
                    "fonte alimenta afirmação sem liberação humana registrada.")
            fonte_id = row[0]

        gravados = gravar(conn, territorio_id, fonte_id, contratos, args.ensaio)
        conn.close()
    except Exception as e:
        erro = str(e)
        print(f"\n  ✗ {erro}")

    # ── registra a execução, com ou sem erro ──
    reg = registrar_execucao(args.municipio, len(contratos), gravados,
                             len(indicios), erro)

    print(f"\n  ── resultado ──")
    print(f"    encontrados: {len(contratos)}")
    print(f"    gravados no acervo: {gravados}"
          + ("  (o restante já estava)" if gravados < len(contratos) and not erro else ""))
    print(f"    indícios: {len(indicios)}")
    print(f"    situação: {reg['resultado']}")
    print(f"\n  Execução registrada em execucoes_coletor.jsonl")
    print("  Indício é para verificação humana — nunca acusação.\n")

    sys.exit(1 if erro else 0)


if __name__ == "__main__":
    main()
