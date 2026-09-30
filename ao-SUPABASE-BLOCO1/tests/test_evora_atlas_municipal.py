"""Testes unitários de evora_atlas_municipal.py.

Arquivo grande (quase 1000 linhas), a maior parte orquestração contra o
Supabase (`_rest`, `semear`/`validar`/`aplicar`/`importar`/`vigiar`) — não
coberta aqui, é a mesma decisão das outras suítes desta pasta: rede real
fica pro teste ao vivo, não pro unitário. O que importa isolar: os
tradutores de formato (protótipo-em-arquivo → banco), o parser CSV/JSON de
lote de vereadores, o extrator heurístico sem IA, e principalmente
`_diff_vereadores` — é ele que decide o que vira pendência humana no vigia
(Fase 9), nunca escreve nada sozinho.
"""
import json

import pytest

import evora_atlas_municipal as atlas


# ---------------------------------------------------------------------
# _slug
# ---------------------------------------------------------------------

def test_slug_remove_acento_e_espaco():
    assert atlas._slug("São Paulo") == "sao-paulo"


def test_slug_colapsa_hifens_repetidos():
    assert atlas._slug("Cidade -- Estado") == "cidade-estado"


def test_slug_municipio_mais_uf():
    assert atlas._slug("Sorocaba-SP") == "sorocaba-sp"


# ---------------------------------------------------------------------
# _campo — CVI: selo 'verificado' exige fonte nomeada, trava no código
# ---------------------------------------------------------------------

def test_campo_verificado_sem_fonte_e_recusado():
    with pytest.raises(ValueError, match="exige fonte nomeada"):
        atlas._campo("valor", fonte="", selo="verificado")


def test_campo_verificado_com_fonte_ok():
    campo = atlas._campo("valor", fonte="Prefeitura", selo="verificado")
    assert campo["selo"] == "verificado"
    assert campo["fonte"] == "Prefeitura"
    assert campo["data"]  # preenchida porque tem valor


def test_campo_sem_valor_nao_grava_data():
    campo = atlas._campo("", fonte="", selo="a_confirmar")
    assert campo["data"] == ""


# ---------------------------------------------------------------------
# _traduzir_selo — protótipo usa espaço, banco usa underscore
# ---------------------------------------------------------------------

def test_traduzir_selo_espaco_vira_underscore():
    assert atlas._traduzir_selo("a confirmar") == "a_confirmar"


def test_traduzir_selo_vazio_vira_a_confirmar():
    assert atlas._traduzir_selo(None) == "a_confirmar"
    assert atlas._traduzir_selo("") == "a_confirmar"


def test_traduzir_selo_desconhecido_e_recusado():
    with pytest.raises(ValueError, match="Selo desconhecido"):
        atlas._traduzir_selo("confia-em-mim")


def test_traduzir_selo_ja_no_formato_do_banco_passa_direto():
    assert atlas._traduzir_selo("verificado") == "verificado"


# ---------------------------------------------------------------------
# _traduzir_campo / _traduzir_secao — recursivo, sobre estrutura aninhada
# ---------------------------------------------------------------------

def test_traduzir_campo_traduz_o_selo_preserva_o_resto():
    campo = {"valor": "x", "fonte": "y", "selo": "a confirmar", "data": "2026-01-01"}
    traduzido = atlas._traduzir_campo(campo)
    assert traduzido["selo"] == "a_confirmar"
    assert traduzido["valor"] == "x"


def test_traduzir_campo_ignora_o_que_nao_e_dict():
    assert atlas._traduzir_campo("string qualquer") == "string qualquer"
    assert atlas._traduzir_campo(None) is None


def test_traduzir_secao_desce_por_dicionarios_aninhados():
    secao = {
        "identificacao": {"valor": "123", "fonte": "IBGE", "selo": "verificado"},
        "outro_nivel": {"campo_interno": {"valor": "y", "fonte": "x", "selo": "a confirmar"}},
    }
    traduzida = atlas._traduzir_secao(secao)
    assert traduzida["identificacao"]["selo"] == "verificado"
    assert traduzida["outro_nivel"]["campo_interno"]["selo"] == "a_confirmar"


def test_traduzir_secao_desce_por_listas():
    secao = [
        {"valor": "a", "fonte": "f1", "selo": "a confirmar"},
        {"valor": "b", "fonte": "f2", "selo": "verificado"},
    ]
    traduzida = atlas._traduzir_secao(secao)
    assert traduzida[0]["selo"] == "a_confirmar"
    assert traduzida[1]["selo"] == "verificado"


def test_traduzir_secao_valor_escalar_passa_direto():
    assert atlas._traduzir_secao("texto solto") == "texto solto"
    assert atlas._traduzir_secao(42) == 42


# ---------------------------------------------------------------------
# _data_iso
# ---------------------------------------------------------------------

def test_data_iso_converte_br_para_iso_com_meia_noite():
    assert atlas._data_iso("17/09/2026") == "2026-09-17T00:00:00"


def test_data_iso_vazio_ou_invalido_devolve_none():
    assert atlas._data_iso("") is None
    assert atlas._data_iso(None) is None
    assert atlas._data_iso("não é data") is None


# ---------------------------------------------------------------------
# _ler_lote_vereadores — CSV e JSON, mesmo contrato de saída
# ---------------------------------------------------------------------

def test_ler_lote_json(tmp_path):
    caminho = tmp_path / "lote.json"
    caminho.write_text(json.dumps([
        {"nome": " Fulano ", "email": " fulano@camara.sp.gov.br ", "partido": "X"},
        {"nome": "", "email": "sem-nome@x.com"},  # sem nome, descartar
    ]), encoding="utf-8")
    lote = atlas._ler_lote_vereadores(str(caminho))
    assert lote == [{"nome": "Fulano", "email": "fulano@camara.sp.gov.br", "partido": "X"}]


def test_ler_lote_csv_sem_partido(tmp_path):
    caminho = tmp_path / "lote.csv"
    caminho.write_text("nome,email\nFulano de Tal,fulano@camara.sp.gov.br\n", encoding="utf-8")
    lote = atlas._ler_lote_vereadores(str(caminho))
    assert lote == [{"nome": "Fulano de Tal", "email": "fulano@camara.sp.gov.br", "partido": None}]


def test_ler_lote_csv_descarta_linhas_incompletas(tmp_path):
    caminho = tmp_path / "lote.csv"
    caminho.write_text(
        "nome,email,partido\n"
        "Completo,completo@x.com,PARTIDO\n"
        ",sememail@x.com,\n"  # sem nome
        "Sem Email,,\n",       # sem e-mail
        encoding="utf-8",
    )
    lote = atlas._ler_lote_vereadores(str(caminho))
    assert len(lote) == 1
    assert lote[0]["nome"] == "Completo"
    assert lote[0]["partido"] == "PARTIDO"


# ---------------------------------------------------------------------
# _limpar_html
# ---------------------------------------------------------------------

def test_limpar_html_remove_script_e_style():
    bruto = "<html><style>.x{color:red}</style><body>Texto<script>alert(1)</script></body></html>"
    limpo = atlas._limpar_html(bruto)
    assert "alert(1)" not in limpo
    assert "color:red" not in limpo
    assert "Texto" in limpo


def test_limpar_html_respeita_o_limite_de_tamanho():
    bruto = "x" * (atlas.LIMITE_HTML_VIGIA + 1000)
    assert len(atlas._limpar_html(bruto)) == atlas.LIMITE_HTML_VIGIA


# ---------------------------------------------------------------------
# _texto_de_celula / _parece_nome_pessoa
# ---------------------------------------------------------------------

def test_texto_de_celula_remove_tags_e_normaliza_espaco():
    assert atlas._texto_de_celula("<b>Fulano</b>  <i>de Tal</i>") == "Fulano de Tal"


def test_texto_de_celula_desfaz_entidades_html():
    assert atlas._texto_de_celula("Jo&atilde;o") == "João"


@pytest.mark.parametrize(
    "texto,esperado",
    [
        ("Fulano de Tal", True),
        ("Maria da Silva Santos", True),
        ("email", False),                      # genérico, uma palavra
        ("respostas de requerimentos", False),  # minúsculo, não é nome
        ("Fulano", False),                      # uma palavra só, fora do range 2-6
        ("A B C D E F G", False),                # mais de 6 palavras
    ],
)
def test_parece_nome_pessoa(texto, esperado):
    assert atlas._parece_nome_pessoa(texto) is esperado


# ---------------------------------------------------------------------
# _extrair_vereadores_heuristica — tabela nome/e-mail sem IA
# ---------------------------------------------------------------------

def test_extrai_heuristica_de_tabela_simples():
    html = """
    <table>
      <tr><td>Nome</td><td>E-mail</td></tr>
      <tr><td>Fulano de Tal</td><td>fulano@camara.sp.gov.br</td></tr>
      <tr><td>Maria Santos</td><td>MARIA@camara.sp.gov.br</td></tr>
    </table>
    """
    pares = atlas._extrair_vereadores_heuristica(html)
    nomes = {p["nome"] for p in pares}
    assert "Fulano de Tal" in nomes
    assert "Maria Santos" in nomes
    # e-mail sempre normalizado pra minúsculo
    assert {"nome": "Maria Santos", "email": "maria@camara.sp.gov.br"} in pares


def test_extrai_heuristica_ignora_linha_de_cabecalho_generica():
    html = """
    <table>
      <tr><td>email</td><td>contato@camara.sp.gov.br</td></tr>
      <tr><td>Fulano de Tal</td><td>fulano@camara.sp.gov.br</td></tr>
    </table>
    """
    pares = atlas._extrair_vereadores_heuristica(html)
    assert len(pares) == 1
    assert pares[0]["nome"] == "Fulano de Tal"


def test_extrai_heuristica_ignora_linha_sem_email():
    html = "<table><tr><td>Fulano de Tal</td><td>sem e-mail aqui</td></tr></table>"
    assert atlas._extrair_vereadores_heuristica(html) == []


def test_extrai_heuristica_nao_duplica_mesmo_email():
    html = """
    <table>
      <tr><td>Fulano de Tal</td><td>fulano@camara.sp.gov.br</td></tr>
      <tr><td>Fulano de Tal</td><td>FULANO@camara.sp.gov.br</td></tr>
    </table>
    """
    pares = atlas._extrair_vereadores_heuristica(html)
    assert len(pares) == 1


def test_extrai_heuristica_pagina_sem_tabela_devolve_vazio():
    assert atlas._extrair_vereadores_heuristica("<html><body>Nada aqui.</body></html>") == []


# ---------------------------------------------------------------------
# _diff_vereadores — o coração do vigia (Fase 9). Nunca escreve, só calcula.
# ---------------------------------------------------------------------

def test_diff_sem_mudanca_nao_gera_pendencia():
    atuais = [{"nome": "Fulano", "email": "fulano@x.com"}]
    extraidos = [{"nome": "Fulano", "email": "fulano@x.com"}]
    assert atlas._diff_vereadores(atuais, extraidos) == []


def test_diff_detecta_vereador_novo():
    atuais = []
    extraidos = [{"nome": "Fulano Novo", "email": "novo@x.com"}]
    pendencias = atlas._diff_vereadores(atuais, extraidos)
    assert pendencias == [{"tipo": "novo", "nome": "Fulano Novo", "email": "novo@x.com", "email_anterior": None}]


def test_diff_detecta_email_alterado_pelo_mesmo_nome():
    atuais = [{"nome": "Fulano", "email": "antigo@x.com"}]
    extraidos = [{"nome": "Fulano", "email": "novo@x.com"}]
    pendencias = atlas._diff_vereadores(atuais, extraidos)
    assert pendencias == [{
        "tipo": "email_alterado", "nome": "Fulano",
        "email": "novo@x.com", "email_anterior": "antigo@x.com",
    }]


def test_diff_detecta_possivel_saida_quando_no_extraido_some():
    atuais = [{"nome": "Fulano", "email": "fulano@x.com"}]
    extraidos = []  # a página não lista mais esse vereador
    pendencias = atlas._diff_vereadores(atuais, extraidos)
    assert pendencias == [{
        "tipo": "possivel_saida", "nome": "Fulano",
        "email": "fulano@x.com", "email_anterior": None,
    }]


def test_diff_email_alterado_nao_conta_tambem_como_saida():
    # o e-mail antigo "sumiu" da extração, mas é porque virou o novo — não
    # é uma saída independente, senão duplicaria a pendência
    atuais = [{"nome": "Fulano", "email": "antigo@x.com"}]
    extraidos = [{"nome": "Fulano", "email": "novo@x.com"}]
    pendencias = atlas._diff_vereadores(atuais, extraidos)
    tipos = [p["tipo"] for p in pendencias]
    assert tipos == ["email_alterado"]  # não aparece "possivel_saida" também


def test_diff_nome_diferente_mas_mesmo_email_nao_gera_pendencia():
    # e-mail já conhecido — considera o mesmo vereador mesmo se o nome
    # variar ligeiramente (abreviação, etc.), sem inventar pendência
    atuais = [{"nome": "Fulano de Tal", "email": "fulano@x.com"}]
    extraidos = [{"nome": "Fulano T.", "email": "fulano@x.com"}]
    assert atlas._diff_vereadores(atuais, extraidos) == []


def test_diff_varios_cenarios_juntos():
    atuais = [
        {"nome": "Continua", "email": "continua@x.com"},
        {"nome": "Trocou Email", "email": "email-velho@x.com"},
        {"nome": "Saiu", "email": "saiu@x.com"},
    ]
    extraidos = [
        {"nome": "Continua", "email": "continua@x.com"},
        {"nome": "Trocou Email", "email": "email-novo@x.com"},
        {"nome": "Entrou Agora", "email": "entrou@x.com"},
    ]
    pendencias = atlas._diff_vereadores(atuais, extraidos)
    por_tipo = {p["tipo"]: p for p in pendencias}
    assert set(por_tipo) == {"email_alterado", "novo", "possivel_saida"}
    assert por_tipo["email_alterado"]["nome"] == "Trocou Email"
    assert por_tipo["novo"]["nome"] == "Entrou Agora"
    assert por_tipo["possivel_saida"]["nome"] == "Saiu"
