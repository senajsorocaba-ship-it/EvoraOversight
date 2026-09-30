"""Testes unitários de extrator_veritas.py — só a parte que não toca rede.

`buscar`/`inspecionar`/`extrair` fazem HTTP de verdade (requests.get) e não
são testados aqui — cobrir isso exigiria mockar a rede, e o valor real deles
já foi verificado ao vivo contra sorocaba.camarasempapel.com.br em sessão
anterior (ver CLAUDE.md). O que importa testar sem rede: os parsers puros
(identificar_norma/extrair_dispositivos), o normalizador de texto, o
escapador de SQL, e as recusas de gerar_sql — é ali que a Cláusula de
Caráter Travado do Veritas ("carga não verificada não entra") realmente
vive.
"""
import json

import pytest

import extrator_veritas as ev


# ---------------------------------------------------------------------
# sem_acento / limpar
# ---------------------------------------------------------------------

def test_sem_acento_remove_diacriticos():
    assert ev.sem_acento("Disposições Gerais") == "Disposicoes Gerais"
    assert ev.sem_acento("Resolução") == "Resolucao"


def test_sem_acento_preserva_texto_sem_acento():
    assert ev.sem_acento("abc123") == "abc123"


def test_limpar_colapsa_espacos_e_tira_bordas():
    assert ev.limpar("  Art.   1º   \n\n  fica assim  ") == "Art. 1º fica assim"


def test_limpar_none_vira_string_vazia():
    assert ev.limpar(None) == ""


# ---------------------------------------------------------------------
# identificar_norma — nunca chuta o que não achou (ver docstring da função)
# ---------------------------------------------------------------------

def test_identifica_resolucao_completa():
    texto = (
        "RESOLUÇÃO Nº 322, de 18 de setembro de 2007.\n\n"
        "Dispõe sobre o Regimento Interno da Câmara Municipal de Sorocaba "
        "e dá outras providências.\n\nArt. 1º ..."
    )
    dados = ev.identificar_norma(texto)
    assert dados["especie"] == "resolucao"
    assert dados["numero"] == "322"
    assert dados["ano"] == 2007
    assert dados["data_publicacao"] == "2007-09-18"
    assert dados["ementa"].startswith("Dispõe sobre o Regimento Interno")


def test_identifica_lei_organica_distinta_de_lei_simples():
    texto = "LEI ORGÂNICA DO MUNICÍPIO DE SOROCABA, de 5 de abril de 1990."
    dados = ev.identificar_norma(texto)
    assert dados["especie"] == "lei_organica"


def test_identifica_lei_simples_nao_confunde_com_complementar():
    texto = "LEI Nº 1234, de 1 de janeiro de 2020."
    dados = ev.identificar_norma(texto)
    assert dados["especie"] == "lei_ordinaria"


def test_texto_sem_estrutura_normativa_nao_inventa_nada():
    dados = ev.identificar_norma("Bem-vindo ao portal da Câmara. Notícias recentes.")
    assert dados["especie"] is None
    assert dados["numero"] is None
    assert dados["ementa"] is None


def test_ano_isolado_sem_data_completa_cai_no_fallback():
    # Sem "de DD de MES de AAAA" — só um ano solto no texto.
    dados = ev.identificar_norma("Norma referente ao exercício de 2019, sem data explícita.")
    assert dados["ano"] == 2019
    assert dados["data_publicacao"] is None


# ---------------------------------------------------------------------
# extrair_dispositivos — hierarquia da LC 95/1998
# ---------------------------------------------------------------------

def test_extrai_artigo_paragrafo_inciso_alinea_em_ordem():
    texto = (
        "Art. 1º Fica instituído o Regimento Interno.\n"
        "Parágrafo único. Aplica-se a todos os órgãos.\n"
        "Art. 2º As sessões são públicas.\n"
        "I - ordinárias, às terças e quintas\n"
        "a) com pauta publicada com antecedência\n"
    )
    disp = ev.extrair_dispositivos(texto)
    niveis = [(d["nivel"], d["rotulo"]) for d in disp]
    assert niveis == [
        ("artigo", "Art. 1"),
        ("paragrafo", "Parágrafo único"),
        ("artigo", "Art. 2"),
        ("inciso", "I"),
        ("alinea", "a)"),
    ]
    # ordem é sequencial e nunca se repete
    assert [d["ordem"] for d in disp] == [1, 2, 3, 4, 5]


def test_dispositivo_guarda_o_artigo_pai_correto():
    texto = "Art. 5º Caput do artigo.\nI - primeiro inciso do artigo 5\n"
    disp = ev.extrair_dispositivos(texto)
    artigo, inciso = disp
    assert artigo["artigo_pai"] is None  # artigo nunca tem pai
    assert inciso["artigo_pai"] == "Art. 5"


def test_paragrafo_numerado_recebe_simbolo_de_grau():
    texto = "Art. 1º Caput.\n§ 2º Parágrafo segundo.\n"
    disp = ev.extrair_dispositivos(texto)
    assert disp[1]["rotulo"] == "§ 2º"


def test_linha_sem_marcador_vira_continuacao_do_dispositivo_anterior():
    texto = (
        "Art. 1º O prazo para\n"
        "manifestação é de dez dias úteis,\n"
        "contados da publicação.\n"
    )
    disp = ev.extrair_dispositivos(texto)
    assert len(disp) == 1
    assert disp[0]["texto"] == (
        "Art. 1º O prazo para manifestação é de dez dias úteis, "
        "contados da publicação."
    )


def test_todo_dispositivo_nasce_nao_revisado():
    texto = "Art. 1º Qualquer coisa.\n"
    disp = ev.extrair_dispositivos(texto)
    assert disp[0]["revisado"] is False


def test_texto_sem_estrutura_nao_produz_dispositivo_nenhum():
    assert ev.extrair_dispositivos("Só um texto corrido, sem artigo nenhum.\n") == []


# ---------------------------------------------------------------------
# escapar — a única defesa contra SQL malformado/injeção no SQL gerado
# ---------------------------------------------------------------------

def test_escapar_none_vira_null_sem_aspas():
    assert ev.escapar(None) == "null"


def test_escapar_aspas_simples_duplica_a_aspa():
    assert ev.escapar("O'Brien") == "'O''Brien'"


def test_escapar_numero_ainda_sai_entre_aspas():
    assert ev.escapar(2026) == "'2026'"


def test_escapar_tentativa_de_injecao_fica_inofensiva():
    malicioso = "x'; drop table veritas_normas; --"
    escapado = ev.escapar(malicioso)
    # a aspa simples do meio do payload vira duas aspas — dentro de uma
    # string SQL, '' é UM caractere de aspa literal, não o fim da string.
    # É por isso que a saída tem que ter exatamente essa forma, e não
    # (por exemplo) fechar em "x'" e deixar o resto solto como SQL.
    assert escapado == "'x''; drop table veritas_normas; --'"


# ---------------------------------------------------------------------
# gerar_sql — as recusas SÃO a razão de o script existir (ver módulo)
# ---------------------------------------------------------------------

def _pacote_base(**overrides):
    base = {
        "url_oficial": "https://sorocaba.camarasempapel.com.br/legislacao/res322.aspx",
        "consultado_em": "2026-09-20",
        "norma": {
            "especie": "resolucao",
            "numero": "322",
            "ano": 2007,
            "ementa": "Dispõe sobre o Regimento Interno.",
            "apelido": "Regimento Interno",
            "situacao": "vigente",
            "data_publicacao": "2007-09-18",
            "vigencia_inicio": "2007-09-18",
            "vigencia_fim": None,
            "territorio": "Sorocaba/SP",
        },
        "dispositivos": [
            {"ordem": 1, "nivel": "artigo", "rotulo": "Art. 1",
             "artigo_pai": None, "texto": "Art. 1º Caput.", "revisado": True},
        ],
    }
    base.update(overrides)
    return base


def _escrever_pacote(tmp_path, pacote, nome="norma.json"):
    caminho = tmp_path / nome
    caminho.write_text(json.dumps(pacote, ensure_ascii=False), encoding="utf-8")
    return str(caminho)


def test_recusa_quando_falta_campo_obrigatorio(tmp_path):
    pacote = _pacote_base()
    pacote["norma"]["ementa"] = None
    arquivo = _escrever_pacote(tmp_path, pacote)
    with pytest.raises(SystemExit, match="ementa"):
        ev.gerar_sql(arquivo, "Fulano de Tal")


def test_recusa_dispositivo_nao_revisado(tmp_path):
    pacote = _pacote_base()
    pacote["dispositivos"][0]["revisado"] = False
    arquivo = _escrever_pacote(tmp_path, pacote)
    with pytest.raises(SystemExit, match="não foram marcados como revisados"):
        ev.gerar_sql(arquivo, "Fulano de Tal")


def test_forcar_ignora_a_exigencia_de_revisao(tmp_path):
    pacote = _pacote_base()
    pacote["dispositivos"][0]["revisado"] = False
    arquivo = _escrever_pacote(tmp_path, pacote)
    # não deve levantar SystemExit
    ev.gerar_sql(arquivo, "Fulano de Tal", forcar=True)


def test_recusa_sem_verificado_por(tmp_path):
    arquivo = _escrever_pacote(tmp_path, _pacote_base())
    with pytest.raises(SystemExit, match="informe quem verificou"):
        ev.gerar_sql(arquivo, "")


def test_recusa_verificado_por_curto_demais(tmp_path):
    arquivo = _escrever_pacote(tmp_path, _pacote_base())
    with pytest.raises(SystemExit, match="informe quem verificou"):
        ev.gerar_sql(arquivo, "Al")  # menos de 3 caracteres


def test_gera_sql_com_sucesso_e_grava_arquivo_carga(tmp_path):
    arquivo = _escrever_pacote(tmp_path, _pacote_base())
    ev.gerar_sql(arquivo, "Maria Verificadora")

    saida = tmp_path / "norma_carga.sql"
    assert saida.exists()
    sql = saida.read_text(encoding="utf-8")
    assert "insert into veritas_normas" in sql
    assert "insert into veritas_carga" in sql
    assert "insert into veritas_dispositivos" in sql
    assert "Maria Verificadora" in sql
    assert "begin;" in sql and "commit;" in sql
