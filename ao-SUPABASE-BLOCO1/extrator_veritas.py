#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════════════
# ÉVORA OVERSIGHT — EXTRATOR DO VERITAS
# ═══════════════════════════════════════════════════════════════════════════
#
# Lê normas do portal público da Câmara Sem Papel e prepara a carga do acervo
# legal — para CONFERÊNCIA HUMANA antes de entrar no banco.
#
# ── POR QUE ESTE SCRIPT NÃO GRAVA NO BANCO ────────────────────────────────
# A regra do Veritas é carga curada. Uma norma mal extraída — artigo faltando,
# revogação não percebida, versão desatualizada — faz a Bia citar artigo
# errado. E citar artigo errado é pior que não citar nada, porque o assessor
# confia e age.
#
# Por isso o fluxo tem três etapas separadas, e a do meio é humana:
#
#   1. inspecionar → descobre a estrutura da página (só olha, não interpreta)
#   2. extrair     → gera um arquivo para revisão
#   3. gerar-sql   → produz o SQL, exigindo o nome de quem verificou
#
# ── USO ────────────────────────────────────────────────────────────────────
#   python3 extrator_veritas.py inspecionar <url>
#   python3 extrator_veritas.py extrair <url> --saida regimento.json
#   python3 extrator_veritas.py gerar-sql regimento.json --verificado-por "Seu Nome"
#
# ═══════════════════════════════════════════════════════════════════════════

import argparse
import json
import re
import sys
import unicodedata
from collections import Counter
from datetime import date

try:
    import requests
    from bs4 import BeautifulSoup
except ImportError:
    sys.exit("Faltam bibliotecas. Rode:  pip install requests beautifulsoup4 lxml")


CABECALHO = {
    "User-Agent": "Evora-Oversight/1.0 (coletor de acervo legal; contato: o gabinete)"
}
TEMPO_LIMITE = 30


# ═══════════════════════════════════════════════════════════════════════════
# PADRÕES DA LC 95/1998 — a lei que define como se escreve norma no Brasil
# ═══════════════════════════════════════════════════════════════════════════
# A hierarquia é: artigo → parágrafo → inciso → alínea → item.
# Estes padrões são a única parte "esperta" do script, e são conservadores:
# na dúvida, o trecho vira texto solto para o humano decidir.

# re.MULTILINE é necessário: sem ele, o "^" só casa no início do texto
# inteiro, e a contagem da inspeção dá zero mesmo em norma bem formada.
PADROES = {
    "artigo":    re.compile(r"^\s*Art(?:igo)?\.?\s*(\d+)\s*[º°\.\-–]?\s*", re.I | re.M),
    "paragrafo": re.compile(r"^\s*(?:§\s*(\d+)\s*[º°]?|Parágrafo\s+único)\s*[\.\-–]?\s*", re.I | re.M),
    "inciso":    re.compile(r"^\s*([IVXLCDM]+)\s*[\-–\.]\s+", re.M),
    "alinea":    re.compile(r"^\s*([a-z])\s*\)\s*", re.M),
    "item":      re.compile(r"^\s*(\d+)\s*[\.\)]\s+", re.M),
}

ESPECIES = {
    "resolução": "resolucao", "resolucao": "resolucao",
    "lei complementar": "lei_complementar",
    "lei orgânica": "lei_organica", "lei organica": "lei_organica",
    "lei": "lei_ordinaria",
    "decreto legislativo": "decreto_legislativo",
    "decreto": "decreto",
    "portaria": "portaria",
    "ato da mesa": "ato_da_mesa",
}

MESES = {
    "janeiro": 1, "fevereiro": 2, "março": 3, "marco": 3, "abril": 4,
    "maio": 5, "junho": 6, "julho": 7, "agosto": 8, "setembro": 9,
    "outubro": 10, "novembro": 11, "dezembro": 12,
}


def sem_acento(t):
    return "".join(c for c in unicodedata.normalize("NFD", t)
                   if unicodedata.category(c) != "Mn")


def limpar(t):
    """Normaliza espaços sem alterar o conteúdo."""
    return re.sub(r"\s+", " ", (t or "")).strip()


def buscar(url):
    r = requests.get(url, headers=CABECALHO, timeout=TEMPO_LIMITE)
    r.raise_for_status()
    if not r.encoding or r.encoding.lower() == "iso-8859-1":
        r.encoding = r.apparent_encoding or "utf-8"
    return r.text


# ═══════════════════════════════════════════════════════════════════════════
# ETAPA 1 — INSPECIONAR
# ═══════════════════════════════════════════════════════════════════════════
# Só olha a página e relata o que encontrou. Não interpreta, não afirma.
# Serve para confirmar se a extração é viável antes de confiar nela.

def inspecionar(url):
    print(f"\n{'═'*70}\n INSPEÇÃO — {url}\n{'═'*70}\n")
    try:
        html = buscar(url)
    except Exception as e:
        print(f"  ✗ Não foi possível acessar: {e}")
        print("\n  Verifique o endereço, ou se o portal exige login.")
        return

    sopa = BeautifulSoup(html, "lxml")
    print(f"  Tamanho da página: {len(html):,} caracteres")
    print(f"  Título: {limpar(sopa.title.get_text()) if sopa.title else '(sem título)'}\n")

    # que elementos estruturam o conteúdo
    print("  ── Elementos mais frequentes ──")
    tags = Counter(t.name for t in sopa.find_all())
    for nome, n in tags.most_common(12):
        print(f"     {nome:12s} {n:5d}")

    # tabelas costumam ser a listagem de normas
    tabelas = sopa.find_all("table")
    print(f"\n  ── Tabelas encontradas: {len(tabelas)} ──")
    for i, tab in enumerate(tabelas[:3], 1):
        linhas = tab.find_all("tr")
        print(f"     tabela {i}: {len(linhas)} linhas")
        if linhas:
            celulas = [limpar(c.get_text())[:28] for c in linhas[0].find_all(["th", "td"])]
            print(f"       cabeçalho: {celulas}")

    # links que parecem norma
    links = sopa.find_all("a", href=True)
    normativos = [a for a in links
                  if re.search(r"(lei|decreto|resolu|portaria|norma|legisla)",
                               sem_acento(a.get_text() + a["href"]), re.I)]
    print(f"\n  ── Links: {len(links)} no total, {len(normativos)} parecem normativos ──")
    for a in normativos[:8]:
        print(f"     {limpar(a.get_text())[:50]:52s} → {a['href'][:44]}")

    # o texto tem estrutura de artigo?
    texto = sopa.get_text("\n")
    achados = {k: len(p.findall(texto)) for k, p in PADROES.items()}
    print(f"\n  ── Estrutura normativa detectada no texto ──")
    for k, n in achados.items():
        print(f"     {k:12s} {n:5d}")

    print(f"\n{'─'*70}")
    if achados["artigo"] >= 3:
        print("  ✓ A página parece conter o TEXTO de uma norma.")
        print("    Próximo passo:  extrair <url> --saida norma.json")
    elif normativos:
        print("  ✓ A página parece ser uma LISTAGEM de normas.")
        print("    Abra um dos links acima e inspecione a norma em si.")
    else:
        print("  ⚠ Não reconheci estrutura normativa nem listagem.")
        print("    Pode ser página dinâmica, PDF, ou exigir login.")
    print(f"{'─'*70}\n")


# ═══════════════════════════════════════════════════════════════════════════
# ETAPA 2 — EXTRAIR
# ═══════════════════════════════════════════════════════════════════════════

def identificar_norma(texto):
    """Tenta identificar espécie, número, ano e data. Devolve o que achou,
    e None no que não achou. NUNCA chuta."""
    cab = texto[:2500]
    dados = {"especie": None, "numero": None, "ano": None,
             "data_publicacao": None, "ementa": None}

    m = re.search(
        r"(Resolu[çc][ãa]o|Lei\s+Complementar|Lei\s+Org[âa]nica|Lei|"
        r"Decreto\s+Legislativo|Decreto|Portaria|Ato\s+da\s+Mesa)"
        r"[\s,]*n?[º°\.]?\s*(\d+)?", cab, re.I)
    if m:
        chave = sem_acento(m.group(1).lower().strip())
        for k, v in ESPECIES.items():
            if sem_acento(k) == chave:
                dados["especie"] = v
                break
        dados["numero"] = m.group(2)

    m = re.search(r"de\s+(\d{1,2})\s+de\s+(\w+)\s+de\s+(\d{4})", cab, re.I)
    if m:
        dia, mes_txt, ano = m.groups()
        mes = MESES.get(sem_acento(mes_txt.lower()))
        dados["ano"] = int(ano)
        if mes:
            dados["data_publicacao"] = f"{ano}-{mes:02d}-{int(dia):02d}"
    else:
        m = re.search(r"\b(19|20)\d{2}\b", cab)
        if m:
            dados["ano"] = int(m.group(0))

    m = re.search(r"(Disp[õo]e sobre|Institui|Estabelece|Altera|Regulamenta|Aprova)"
                  r"[^\.]{10,300}\.", cab, re.I)
    if m:
        dados["ementa"] = limpar(m.group(0))

    return dados


def extrair_dispositivos(texto):
    """Quebra o texto em dispositivos. Conservador: o que não reconhece
    vira continuação do anterior, para o humano revisar."""
    linhas = [limpar(l) for l in texto.split("\n")]
    linhas = [l for l in linhas if len(l) > 2]

    disp = []
    ordem = 0
    atual_artigo = None

    for linha in linhas:
        nivel = rotulo = None

        if PADROES["artigo"].match(linha):
            m = PADROES["artigo"].match(linha)
            nivel, rotulo = "artigo", f"Art. {m.group(1)}"
            atual_artigo = rotulo
        elif PADROES["paragrafo"].match(linha):
            m = PADROES["paragrafo"].match(linha)
            nivel = "paragrafo"
            rotulo = f"§ {m.group(1)}º" if m.group(1) else "Parágrafo único"
        elif PADROES["inciso"].match(linha):
            m = PADROES["inciso"].match(linha)
            nivel, rotulo = "inciso", m.group(1)
        elif PADROES["alinea"].match(linha):
            m = PADROES["alinea"].match(linha)
            nivel, rotulo = "alinea", f"{m.group(1)})"

        if nivel:
            ordem += 1
            disp.append({
                "ordem": ordem,
                "nivel": nivel,
                "rotulo": rotulo,
                "artigo_pai": atual_artigo if nivel != "artigo" else None,
                "texto": linha,
                "revisado": False,          # ← o humano marca aqui
            })
        elif disp:
            disp[-1]["texto"] += " " + linha

    return disp


def extrair(url, saida):
    print(f"\n{'═'*70}\n EXTRAÇÃO — {url}\n{'═'*70}\n")
    html = buscar(url)
    sopa = BeautifulSoup(html, "lxml")

    for lixo in sopa(["script", "style", "nav", "header", "footer"]):
        lixo.decompose()
    texto = sopa.get_text("\n")

    norma = identificar_norma(texto)
    disp = extrair_dispositivos(texto)

    pacote = {
        "_AVISO": "CARGA NÃO VERIFICADA. Confira cada campo antes de gerar o SQL.",
        "url_oficial": url,
        "consultado_em": date.today().isoformat(),
        "norma": {
            **norma,
            "apelido": None,                # ← preencher: "Regimento Interno"
            "situacao": "vigente",          # ← conferir
            "vigencia_inicio": norma.get("data_publicacao"),  # ← conferir
            "vigencia_fim": None,
            "territorio": None,             # ← preencher: "Sorocaba/SP"
        },
        "dispositivos": disp,
        "_pendencias": [],
    }

    # apontar o que não foi possível determinar
    p = pacote["_pendencias"]
    for campo in ("especie", "numero", "ano", "ementa"):
        if not norma.get(campo):
            p.append(f"campo '{campo}' não identificado — preencher à mão")
    if not norma.get("data_publicacao"):
        p.append("data de publicação não identificada — preencher vigencia_inicio")
    if len(disp) < 3:
        p.append(f"apenas {len(disp)} dispositivos — a extração pode ter falhado")
    p.append("apelido, territorio e situacao precisam ser preenchidos")
    p.append("marcar 'revisado': true em cada dispositivo conferido")

    with open(saida, "w", encoding="utf-8") as f:
        json.dump(pacote, f, ensure_ascii=False, indent=2)

    print(f"  Espécie ......... {norma['especie'] or '⚠ não identificada'}")
    print(f"  Número/ano ...... {norma['numero'] or '⚠'}/{norma['ano'] or '⚠'}")
    print(f"  Publicação ...... {norma['data_publicacao'] or '⚠ não identificada'}")
    print(f"  Dispositivos .... {len(disp)}")
    for nivel, n in Counter(d['nivel'] for d in disp).most_common():
        print(f"      {nivel:12s} {n}")

    print(f"\n  ── {len(p)} pendências para você resolver ──")
    for x in p:
        print(f"     • {x}")

    print(f"\n  Arquivo gravado: {saida}")
    print(f"\n  PRÓXIMO PASSO — abra o arquivo, confira cada dispositivo,")
    print(f"  preencha as pendências e marque 'revisado': true.")
    print(f"  Depois:  gerar-sql {saida} --verificado-por \"Seu Nome\"\n")


# ═══════════════════════════════════════════════════════════════════════════
# ETAPA 3 — GERAR SQL
# ═══════════════════════════════════════════════════════════════════════════

def escapar(v):
    if v is None:
        return "null"
    return "'" + str(v).replace("'", "''") + "'"


def gerar_sql(arquivo, verificado_por, forcar=False):
    with open(arquivo, encoding="utf-8") as f:
        pacote = json.load(f)

    n = pacote["norma"]
    disp = pacote["dispositivos"]

    # ── As recusas. Este bloco é a razão de o script existir. ──
    faltando = [c for c in ("especie", "ementa", "vigencia_inicio", "territorio")
                if not n.get(c)]
    if faltando:
        sys.exit(f"\n  ✗ RECUSADO — campos obrigatórios em branco: {', '.join(faltando)}\n"
                 f"    Preencha no arquivo antes de gerar o SQL.\n")

    nao_revisados = [d for d in disp if not d.get("revisado")]
    if nao_revisados and not forcar:
        sys.exit(f"\n  ✗ RECUSADO — {len(nao_revisados)} de {len(disp)} dispositivos "
                 f"não foram marcados como revisados.\n"
                 f"    Abra {arquivo}, confira cada um e marque \"revisado\": true.\n"
                 f"    O Veritas não aceita norma sem conferência humana.\n")

    if not verificado_por or len(verificado_por.strip()) < 3:
        sys.exit("\n  ✗ RECUSADO — informe quem verificou: --verificado-por \"Nome\"\n")

    linhas = [
        "-- ═══════════════════════════════════════════════════════════════",
        f"-- VERITAS — carga de norma",
        f"-- Verificado por: {verificado_por}",
        f"-- Gerado em: {date.today().isoformat()}",
        f"-- Fonte: {pacote['url_oficial']}",
        "-- ═══════════════════════════════════════════════════════════════",
        "",
        "begin;",
        "",
        "-- território (precisa existir em farus_territorios)",
        f"\\set territorio '{n['territorio']}'",
        "",
        "with t as (",
        f"  select id from farus_territorios",
        f"   where lower(municipio) = lower({escapar(n['territorio'].split('/')[0])})",
        "   limit 1",
        "),",
        "nova as (",
        "  insert into veritas_normas (",
        "    territorio_id, especie, numero, ano, ementa, apelido, situacao,",
        "    data_publicacao, vigencia_inicio, vigencia_fim,",
        "    texto_integral, url_oficial, consultado_em,",
        "    carregado_por, verificado_por, verificado_em",
        "  )",
        "  select t.id,",
        f"    {escapar(n['especie'])}::veritas_especie,",
        f"    {escapar(n['numero'])},",
        f"    {n['ano'] if n.get('ano') else 'null'},",
        f"    {escapar(n['ementa'])},",
        f"    {escapar(n.get('apelido'))},",
        f"    {escapar(n['situacao'])}::veritas_situacao,",
        f"    {escapar(n.get('data_publicacao'))}::date,",
        f"    {escapar(n['vigencia_inicio'])}::date,",
        f"    {escapar(n.get('vigencia_fim'))}::date,",
        "    null,",
        f"    {escapar(pacote['url_oficial'])},",
        f"    {escapar(pacote['consultado_em'])}::timestamptz,",
        f"    {escapar(verificado_por)},",
        f"    {escapar(verificado_por)},",
        "    now()",
        "  from t",
        "  returning id, territorio_id",
        ")",
        "insert into veritas_carga (norma_id, territorio_id, origem_url, metodo, quem, resultado)",
        f"select nova.id, nova.territorio_id, {escapar(pacote['url_oficial'])},",
        f"       'extracao', {escapar(verificado_por)}, 'sucesso'",
        "from nova;",
        "",
        "-- dispositivos",
    ]

    for d in disp:
        linhas += [
            "insert into veritas_dispositivos (norma_id, nivel, rotulo, artigo_pai, ordem, texto)",
            "select n.id,",
            f"  {escapar(d['nivel'])}::veritas_nivel,",
            f"  {escapar(d['rotulo'])},",
            f"  {escapar(d.get('artigo_pai'))},",
            f"  {d['ordem']},",
            f"  {escapar(d['texto'])}",
            "from veritas_normas n",
            f"where n.url_oficial = {escapar(pacote['url_oficial'])}",
            "  and n.verificado_em = (select max(verificado_em) from veritas_normas",
            f"                         where url_oficial = {escapar(pacote['url_oficial'])});",
            "",
        ]

    linhas += ["commit;", ""]

    saida = arquivo.rsplit(".", 1)[0] + "_carga.sql"
    with open(saida, "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))

    print(f"\n  ✓ SQL gerado: {saida}")
    print(f"    {len(disp)} dispositivos · verificado por {verificado_por}")
    print(f"\n    Confira o arquivo antes de rodar no banco.\n")


# ═══════════════════════════════════════════════════════════════════════════

def main():
    p = argparse.ArgumentParser(
        description="Extrator do Veritas — carga curada de acervo legal")
    sub = p.add_subparsers(dest="cmd", required=True)

    a = sub.add_parser("inspecionar", help="descobre a estrutura da página")
    a.add_argument("url")

    b = sub.add_parser("extrair", help="gera arquivo para revisão humana")
    b.add_argument("url")
    b.add_argument("--saida", default="norma.json")

    c = sub.add_parser("gerar-sql", help="gera o SQL da carga, após revisão")
    c.add_argument("arquivo")
    c.add_argument("--verificado-por", required=True)
    c.add_argument("--forcar", action="store_true",
                   help="ignora a exigência de revisão (NÃO use em produção)")

    args = p.parse_args()
    if args.cmd == "inspecionar":
        inspecionar(args.url)
    elif args.cmd == "extrair":
        extrair(args.url, args.saida)
    else:
        gerar_sql(args.arquivo, args.verificado_por, args.forcar)


if __name__ == "__main__":
    main()
