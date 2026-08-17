#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Coletor PNCP (alimenta o AFEx-g · Fiscalização do Executivo)
==============================================================================
Lê contratos publicados no Portal Nacional de Contratações Públicas (PNCP) e
prepara a lista para o AFEx-g sinalizar — por INDÍCIO, nunca acusação — itens
com valor fora da referência, para verificação HUMANA.

PRINCÍPIO PÉTREO (Manual Évora): o AFEx-g levanta indício e declara a base de
comparação; a decisão é sempre humana. Este coletor NÃO conclui irregularidade.

Usa só a biblioteca padrão (urllib + json). Saída: contratos_sorocaba.json

ATENÇÃO (pendência registrada no Blueprint): o endpoint/campos exatos da API de
consulta do PNCP devem ser CONFIRMADOS na implementação real (a API evolui).
Os nomes abaixo seguem o padrão público de consulta; ajuste no go-live.
"""

import json, urllib.request, urllib.parse, statistics
from datetime import date, timedelta

# ===================== CONFIG =====================
MUNICIPIO   = "Sorocaba"
UF          = "SP"
IBGE_MUNIC  = "3552205"          # código IBGE de Sorocaba/SP
CNPJ_ORGAO  = "46634044000174"   # CNPJ da Prefeitura Municipal de Sorocaba (filtra no servidor)
DIAS        = 30                 # janela de busca
LIMIAR_DESVIO = 0.30             # 30% acima da mediana → indício para verificar
BASE        = "https://pncp.gov.br/api/consulta/v1/contratos"
TIMEOUT     = 30
# ==================================================


def _get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Evora-Oversight/1.0"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return json.loads(r.read().decode("utf-8"))


def buscar_contratos():
    """Consulta o PNCP na janela de dias. Retorna lista crua de contratos."""
    fim = date.today()
    ini = fim - timedelta(days=DIAS)
    params = {
        "dataInicial": ini.strftime("%Y%m%d"),
        "dataFinal":   fim.strftime("%Y%m%d"),
        "pagina":      "1",
    }
    # A API do PNCP não filtra por município (sem parâmetro de IBGE nesse
    # endpoint) — o filtro real e documentado é por CNPJ do órgão.
    if CNPJ_ORGAO:
        params["cnpjOrgao"] = CNPJ_ORGAO
    url = f"{BASE}?{urllib.parse.urlencode(params)}"
    try:
        dados = _get(url)
    except Exception as e:
        print(f"  ! erro ao consultar o PNCP: {e}")
        return []
    # a API costuma devolver {"data":[...]} ou lista direta; tratamos os dois
    itens = dados.get("data", dados) if isinstance(dados, dict) else dados
    return itens if isinstance(itens, list) else []


def normalizar(itens):
    """Extrai os campos que o AFEx-g usa, tolerando nomes diferentes."""
    out = []
    for it in itens:
        def g(*chaves):
            for k in chaves:
                if isinstance(it, dict) and it.get(k) not in (None, ""):
                    return it[k]
            return ""
        unidade = it.get("unidadeOrgao") or {} if isinstance(it, dict) else {}
        orgao_ent = it.get("orgaoEntidade") or {} if isinstance(it, dict) else {}
        # município e órgão vêm aninhados na resposta real do PNCP, não no nível raiz
        municipio = str(g("municipioNome", "municipio", "nomeMunicipio") or unidade.get("municipioNome", ""))
        if MUNICIPIO and municipio and MUNICIPIO.lower() not in municipio.lower():
            continue
        out.append({
            "numero":          g("numeroControlePNCP", "numeroContrato", "numero"),
            "objeto":          g("objetoContrato", "objeto", "descricaoObjeto"),
            "valor":           float(g("valorGlobal", "valorInicial", "valor") or 0),
            "orgao":           g("orgaoEntidadeRazaoSocial", "orgao", "nomeOrgao") or orgao_ent.get("razaoSocial", ""),
            "fornecedor":      g("nomeRazaoSocialFornecedor", "fornecedor", "nomeFornecedor"),
            "data_publicacao": g("dataPublicacaoPncp", "dataPublicacao", "data"),
            "municipio":       municipio,
        })
    return out


def sinalizar_indicios(contratos):
    """Marca indício quando o valor está acima da mediana dos comparáveis.
    Base de comparação SEMPRE declarada. Nunca afirma irregularidade."""
    valores = [c["valor"] for c in contratos if c["valor"] > 0]
    if len(valores) < 4:
        # poucos dados → não há base estatística; não sinaliza desvio
        for c in contratos:
            c["relevancia"] = "rotina"
            c["indicio"] = ""
        return contratos
    mediana = statistics.median(valores)
    for c in contratos:
        if c["valor"] > 0 and c["valor"] > mediana * (1 + LIMIAR_DESVIO):
            desvio = (c["valor"] / mediana - 1) * 100
            c["relevancia"] = "atenção"
            c["indicio"] = (f"valor ~{desvio:.0f}% acima da mediana dos contratos "
                            f"do período; sugiro verificar. Base: mediana de "
                            f"{len(valores)} contratos no PNCP (R$ {mediana:,.2f}).")
        else:
            c["relevancia"] = "rotina"
            c["indicio"] = ""
    return contratos


def main():
    print("=" * 64)
    print("ÉVORA — Coletor PNCP (AFEx-g · Fiscalização do Executivo)")
    print(f"Município: {MUNICIPIO}/{UF} · janela: {DIAS} dias · limiar: {int(LIMIAR_DESVIO*100)}%")
    print("=" * 64)

    brutos = buscar_contratos()
    print(f"→ {len(brutos)} contratos retornados pelo PNCP")
    contratos = sinalizar_indicios(normalizar(brutos))

    indicios = [c for c in contratos if c.get("indicio")]
    print(f"→ {len(contratos)} contratos de {MUNICIPIO}; {len(indicios)} com indício para verificar\n")
    for c in indicios[:10]:
        print(f"• {c['objeto'][:60]}  | R$ {c['valor']:,.2f}")
        print(f"  INDÍCIO (verificar, não acusação): {c['indicio']}")

    with open("contratos_sorocaba.json", "w", encoding="utf-8") as f:
        json.dump(contratos, f, ensure_ascii=False, indent=2)
    print("\n✓ Salvo em contratos_sorocaba.json (insumo do AFEx-g)")
    print("  Lembrete: indício é para verificação humana — nunca acusação.")


if __name__ == "__main__":
    main()
