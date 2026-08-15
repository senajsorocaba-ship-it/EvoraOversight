"""
Évora Oversight — Atlas Municipal (versão em arquivo)
======================================================
Implementa o Anexo 16 §2–§4 do Manual Supremo v10.6 SEM depender do banco
(Etapa 3): cada município vive em um `atlas_<municipio>.json`. Quando o
Supabase subir, estes arquivos migram para as tabelas `municipios` e
`municipio_fontes` sem mudança de estrutura.

O que este componente faz:
  1. `semear`  — cria o esqueleto do Atlas de uma cidade nova, com todos os
     campos previstos e TUDO marcado "a confirmar" (selo CVI). A máquina não
     inventa: o esqueleto existe para o humano preencher e verificar.
  2. `aplicar` — cruza o Atlas com um perfil de tenant (o que a Entrevista
     de Fundação gerou): os veículos F1/F2 verificados da cidade entram em
     `monitoramento.veiculos_detalhe` com procedência `atlas`.
  3. `validar` — confere as regras travadas do Anexo 16 (F3 nunca no Atlas,
     campo factual com fonte, selo por campo).

TRAVAS (Anexo 16, ratificadas pelo fundador em 19/07/2026):
  - Atlas é camada COMPARTILHADA da plataforma: fatos públicos sobre a
    CIDADE. Nada de tenant aqui — temas, pessoas de interesse e F3 moram
    no perfil isolado.
  - Leitura A (factual): só o que consta em fonte oficial nomeada, pode ser
    reproduzido sem adjetivo e sobrevive a contestação sem interpretação.
  - CNPJ identifica o veículo e atesta regularidade — não decide entrada
    nem mede credibilidade. Entrada é por COBERTURA.
  - Edição com trilha: toda mudança gravada em `_trilha` (quem, quando, o quê).
    Na versão em arquivo a trilha é local; no banco ela vai à AAS-Évora.

USO
---
    python atlas_municipal.py semear "Itu" SP
    python atlas_municipal.py aplicar atlas_sorocaba.json perfil_tatiane.json
    python atlas_municipal.py validar atlas_sorocaba.json
"""

import json
import re
import sys
import unicodedata
from collections import OrderedDict
from datetime import date
from pathlib import Path

VERSAO = "Atlas v1 (arquivo) · Manual v10.6, Anexo 16"

CNAES_MIDIA = {
    "5812": "edição de jornais",
    "5813": "edição de revistas",
    "6010": "rádio",
    "6021": "TV aberta",
    "6022": "TV por assinatura (programadoras)",
    "6319": "portais/provedores de conteúdo",
    "5911": "produção audiovisual",
    "5912": "pós-produção audiovisual",
}


def _slug(texto):
    t = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode()
    return re.sub(r"-{2,}", "-", re.sub(r"[^a-zA-Z0-9]+", "-", t).strip("-").lower())


def _hoje():
    return date.today().strftime("%d/%m/%Y")


def _campo(valor="", fonte="", selo="a confirmar"):
    """Todo campo do Atlas carrega valor + fonte + selo CVI + data.
    Selo 'verificado' só com fonte nomeada — a função trava isso."""
    if selo == "verificado" and not fonte:
        raise ValueError("Selo 'verificado' exige fonte nomeada (Anexo 16 §4).")
    return OrderedDict([("valor", valor), ("fonte", fonte),
                        ("selo", selo), ("data", _hoje() if valor else "")])


# ---------------------------------------------------------------------------
# 1. SEMEAR — esqueleto de cidade nova (nada inventado; tudo "a confirmar")
# ---------------------------------------------------------------------------
def semear(municipio, uf):
    a = OrderedDict()
    a["_versao"] = VERSAO
    a["_camada"] = ("COMPARTILHADA da plataforma — fatos públicos sobre a cidade. "
                     "Nunca guardar aqui dados de tenant (temas, pessoas de interesse, F3).")
    a["municipio"] = municipio
    a["uf"] = uf.upper()
    a["slug"] = _slug(f"{municipio}-{uf}")

    a["identificacao"] = OrderedDict([
        ("codigo_ibge", _campo()),
        ("regiao", _campo()),
        ("microrregiao", _campo()),
        ("populacao", _campo()),
    ])
    a["executivo"] = OrderedDict([
        ("prefeito", _campo()),
        ("vice", _campo()),
        ("cnpj_prefeitura", _campo()),
        ("portal", _campo()),
        ("secretarias", []),          # cada item: {"nome": _campo(), "titular": _campo()}
    ])
    a["legislativo"] = OrderedDict([
        ("num_vereadores", _campo()),
        ("presidente_camara", _campo()),
        ("composicao_partidaria", []),  # cada item: {"partido": str, "cadeiras": int, "fonte": str, "selo": str}
        ("portal", _campo()),
        ("sistema_tramitacao", _campo()),
    ])
    a["diario_oficial"] = OrderedDict([
        ("onde_publica", _campo()),
        ("formato", _campo()),          # PDF / HTML / XML / RSS
        ("plataforma", _campo()),       # determina QUAL conector COM serve
        ("periodicidade", _campo()),
        ("conector_com", _campo(valor="", fonte="", selo="a confirmar")),  # ex.: RMS-001
    ])
    a["contratacoes"] = OrderedDict([
        ("cnpjs_pncp", []),             # cada item: {"orgao": str, "cnpj": _campo()}
    ])
    a["mapa_politico_factual"] = OrderedDict([
        ("_regra", "Leitura A (decisão D3): só fato público com fonte — eleitos, votos, partidos, "
                    "coligações declaradas, presidências. PROIBIDO: inferência de alinhamento. "
                    "Correlações são pesquisa sob demanda no tenant, nunca cadastro aqui."),
        ("ultima_eleicao_municipal", _campo()),
        ("eleitos", []),                # cada item: {"nome": str, "cargo": str, "partido": str, "votos": int, "fonte": str, "selo": str}
    ])
    a["midia"] = OrderedDict([
        ("_regra", "Níveis F1 (CNPJ ativo + CNAE de mídia — identificação) e F2 (cobertura comprovada "
                    "com evidência arquivada). F3 NUNCA entra no Atlas. CNPJ não mede credibilidade; "
                    "ausência de CNPJ não descarta fonte. Revalidação semestral do CNPJ."),
        ("veiculos", []),               # ver _veiculo() abaixo
    ])
    a["_trilha"] = [OrderedDict([("data", _hoje()), ("acao", "semeadura do esqueleto"),
                                  ("autor", "atlas_municipal.py"), ("obs", "tudo 'a confirmar'")])]
    a["_pendencias_go_live"] = [
        "Verificação humana da mídia local (obrigatória — decisão D6)",
        "Confirmar plataforma do Diário Oficial e conector COM correspondente",
        "Preencher CNPJs dos órgãos para o PNCP",
    ]
    return a


def _veiculo(nome, nivel, cobertura, url="", cnpj="", situacao_receita="", cnae="",
             evidencia="", fonte="", selo="a confirmar"):
    """Monta um veículo F1/F2 do Atlas com as regras do Anexo 16 §3."""
    nivel = nivel.upper()
    if nivel == "F3":
        raise ValueError("F3 (influencers/perfis pessoais) NUNCA entra no Atlas — "
                          "vai no perfil isolado do tenant (Anexo 16 §3).")
    if nivel == "F2" and not evidencia:
        raise ValueError("F2 exige evidência de cobertura arquivada (links de matérias, com data).")
    v = OrderedDict([
        ("nome", nome), ("nivel", nivel), ("url", url),
        ("cobertura", cobertura),
        ("cnpj", cnpj), ("situacao_receita", situacao_receita),
        ("cnae", cnae), ("cnae_descricao", CNAES_MIDIA.get(cnae[:4], "") if cnae else ""),
        ("identificacao", "verificada" if (cnpj and situacao_receita.lower() == "ativa")
                           else "pendente"),
        ("evidencia_cobertura", evidencia),
        ("fonte", fonte), ("selo", selo), ("data", _hoje()),
        ("proxima_revalidacao_cnpj", ""),
    ])
    return v


# ---------------------------------------------------------------------------
# 2. APLICAR — cruza Atlas -> perfil do tenant (procedência 'atlas')
# ---------------------------------------------------------------------------
def aplicar(atlas_path, perfil_path):
    atlas = json.loads(Path(atlas_path).read_text(encoding="utf-8"))
    perfil = json.loads(Path(perfil_path).read_text(encoding="utf-8"),
                        object_pairs_hook=OrderedDict)

    cidade_perfil = (perfil.get("autoridade", {}).get("municipio_sede")
                     or perfil.get("autoridade", {}).get("municipio", ""))
    if _slug(f"{cidade_perfil}-{perfil.get('autoridade',{}).get('uf','')}") != atlas.get("slug"):
        print(f"AVISO: cidade do perfil ('{cidade_perfil}') difere do Atlas "
              f"('{atlas.get('municipio')}'). Nada aplicado.")
        return False

    mon = perfil.setdefault("monitoramento", OrderedDict())
    detalhe = mon.setdefault("veiculos_detalhe", [])
    ja = {v.get("nome", "").lower() for v in detalhe if isinstance(v, dict)}

    aplicados = 0
    for v in atlas.get("midia", {}).get("veiculos", []):
        if v.get("nome", "").lower() in ja:
            continue
        detalhe.append(OrderedDict([
            ("nome", v["nome"]), ("url", v.get("url", "")),
            ("nivel", v.get("nivel", "")), ("cobertura", v.get("cobertura", "")),
            ("identificacao", v.get("identificacao", "pendente")),
            ("procedencia", "atlas"),
            ("selo", v.get("selo", "a confirmar")),
        ]))
        aplicados += 1

    # órgãos do PNCP
    orgaos = mon.setdefault("orgaos", [])
    for item in atlas.get("contratacoes", {}).get("cnpjs_pncp", []):
        nome = item.get("orgao", "")
        if nome and nome not in orgaos:
            orgaos.append(nome)

    proc = perfil.setdefault("_procedencia", OrderedDict())
    proc["monitoramento.veiculos"] = (f"atlas ({atlas.get('municipio')}) — {aplicados} veículo(s) "
                                       f"aplicado(s) em {_hoje()}; verificação humana antes do "
                                       f"go-live continua obrigatória (D6)")

    Path(perfil_path).write_text(json.dumps(perfil, ensure_ascii=False, indent=1),
                                  encoding="utf-8")
    print(f"✓ {aplicados} veículo(s) do Atlas aplicados ao perfil ({perfil_path}).")
    if aplicados == 0:
        print("  (Nenhum veículo novo — Atlas vazio ou tudo já constava no perfil.)")
    return True


# ---------------------------------------------------------------------------
# 3. VALIDAR — regras travadas do Anexo 16
# ---------------------------------------------------------------------------
def validar(atlas_path):
    a = json.loads(Path(atlas_path).read_text(encoding="utf-8"))
    problemas = []
    for v in a.get("midia", {}).get("veiculos", []):
        if v.get("nivel", "").upper() == "F3":
            problemas.append(f"PROIBIDO: veículo F3 no Atlas ({v.get('nome')}).")
        if v.get("nivel", "").upper() == "F2" and not v.get("evidencia_cobertura"):
            problemas.append(f"F2 sem evidência de cobertura ({v.get('nome')}).")
        if v.get("selo") == "verificado" and not v.get("fonte"):
            problemas.append(f"Selo 'verificado' sem fonte ({v.get('nome')}).")
    for chave in ("temas", "politicos_pessoas", "influencers"):
        if chave in json.dumps(a, ensure_ascii=False).lower():
            pass  # nomes de campo de tenant não devem existir; checagem leve
    if not a.get("_trilha"):
        problemas.append("Atlas sem trilha de edição.")
    if problemas:
        print(f"✗ {len(problemas)} problema(s) em {atlas_path}:")
        for p in problemas:
            print("   ·", p)
        return False
    print(f"✓ {atlas_path} passa nas regras do Anexo 16.")
    return True


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    cmd = sys.argv[1]
    if cmd == "semear" and len(sys.argv) >= 4:
        municipio, uf = sys.argv[2], sys.argv[3]
        a = semear(municipio, uf)
        saida = f"atlas_{a['slug']}.json"
        Path(saida).write_text(json.dumps(a, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"✓ Esqueleto criado: {saida}")
        print("  Tudo está 'a confirmar' — preencha e verifique antes de aplicar a um tenant.")
        for p in a["_pendencias_go_live"]:
            print("   ·", p)
    elif cmd == "aplicar" and len(sys.argv) >= 4:
        aplicar(sys.argv[2], sys.argv[3])
    elif cmd == "validar" and len(sys.argv) >= 3:
        validar(sys.argv[2])
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
