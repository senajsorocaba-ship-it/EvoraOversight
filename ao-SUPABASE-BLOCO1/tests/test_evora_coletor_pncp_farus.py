"""Testes unitários de evora_coletor_pncp_farus.py.

A parte que mais importa testar aqui é `sinalizar_indicios` — é onde a
disciplina "indício, nunca acusação" (mesma do achados_fiscalizacao/AFEx-g)
vira código. Um bug ali faria o coletor apontar contrato como suspeito sem
base estatística, ou pior, afirmar em vez de indicar.
"""
import urllib.error
from unittest.mock import MagicMock, patch

import evora_coletor_pncp_farus as pncp


# ---------------------------------------------------------------------
# normalizar — achata a resposta do PNCP, degrada honesto se campo faltar
# ---------------------------------------------------------------------

def test_normaliza_contrato_com_nomes_de_campo_atuais():
    itens = [{
        "numeroControlePNCP": "2026/001",
        "objetoContrato": "Aquisição de merenda escolar",
        "valorGlobal": 150000.50,
        "orgaoEntidadeRazaoSocial": "Prefeitura de Sorocaba",
        "nomeRazaoSocialFornecedor": "Fornecedor Ltda",
        "dataPublicacaoPncp": "2026-09-15T10:00:00",
        "municipioNome": "Sorocaba",
        "linkSistemaOrigem": "https://pncp.gov.br/x",
    }]
    out = pncp.normalizar(itens, "Sorocaba")
    assert len(out) == 1
    c = out[0]
    assert c["numero"] == "2026/001"
    assert c["objeto"] == "Aquisição de merenda escolar"
    assert c["valor"] == 150000.50
    assert c["orgao"] == "Prefeitura de Sorocaba"
    assert c["publicado"] == "2026-09-15"  # cortado pros 10 primeiros caracteres


def test_normaliza_cai_pro_nome_de_campo_alternativo_se_o_atual_faltar():
    # a API do PNCP varia o nome do campo entre versões — o fallback existe
    # exatamente pra isso.
    itens = [{"numeroContrato": "77", "objeto": "Obra", "valorInicial": 1000,
              "orgao": "Câmara", "fornecedor": "X", "data": "2026-01-01",
              "municipio": "Sorocaba"}]
    out = pncp.normalizar(itens, "Sorocaba")
    assert out[0]["numero"] == "77"
    assert out[0]["valor"] == 1000.0


def test_normaliza_filtra_por_municipio():
    itens = [
        {"municipioNome": "Sorocaba", "numeroControlePNCP": "1"},
        {"municipioNome": "Campinas", "numeroControlePNCP": "2"},
    ]
    out = pncp.normalizar(itens, "Sorocaba")
    assert len(out) == 1
    assert out[0]["numero"] == "1"


def test_normaliza_sem_filtro_de_municipio_quando_nao_informado():
    itens = [{"municipioNome": "Qualquer Lugar", "numeroControlePNCP": "1"}]
    out = pncp.normalizar(itens, municipio="")
    assert len(out) == 1


def test_normaliza_campo_ausente_vira_string_vazia_nao_erro():
    # nenhum campo de valor/objeto presente — degrada, não quebra
    out = pncp.normalizar([{"municipioNome": "Sorocaba"}], "Sorocaba")
    assert out[0]["objeto"] == ""
    assert out[0]["valor"] == 0.0


# ---------------------------------------------------------------------
# sinalizar_indicios — indício, NUNCA acusação
# ---------------------------------------------------------------------

def _contrato(valor):
    return {"numero": "x", "objeto": "y", "valor": valor, "orgao": "o",
            "fornecedor": "f", "publicado": "2026-01-01", "municipio": "m",
            "url": "", "indicio": ""}


def test_sem_indicio_quando_ha_menos_de_quatro_valores():
    contratos = [_contrato(v) for v in (1000, 2000, 3000)]
    out = pncp.sinalizar_indicios(contratos)
    assert all(c["indicio"] == "" for c in out)


def test_sinaliza_contrato_acima_da_mediana_mais_o_limiar():
    # mediana de [100, 100, 100, 100] é 100; um 500 é 400% acima — deve sinalizar
    contratos = [_contrato(100), _contrato(100), _contrato(100), _contrato(500)]
    out = pncp.sinalizar_indicios(contratos, limiar=0.25)
    comum = [c for c in out if c["valor"] == 100]
    suspeito = [c for c in out if c["valor"] == 500][0]
    assert all(c["indicio"] == "" for c in comum)
    assert suspeito["indicio"] != ""


def test_indicio_usa_linguagem_de_indicio_nunca_de_acusacao():
    contratos = [_contrato(100), _contrato(100), _contrato(100), _contrato(1000)]
    out = pncp.sinalizar_indicios(contratos, limiar=0.25)
    suspeito = [c for c in out if c["valor"] == 1000][0]
    texto = suspeito["indicio"].lower()
    # o texto bruto deixa claro que é indício factual, decisão de outra
    # pessoa — nunca afirma irregularidade/fraude, só aponta o desvio
    assert "decisão humana" in texto
    assert "fato verificável" in texto
    assert "fraude" not in texto and "irregular" not in texto

    # e o rótulo "INDÍCIO PARA VERIFICAÇÃO" só aparece na hora de renderizar
    # (montar_texto) — nunca como fato consumado no texto bruto
    _titulo, corpo = pncp.montar_texto(suspeito)
    assert "INDÍCIO PARA VERIFICAÇÃO" in corpo


def test_valor_dentro_do_limiar_nao_e_sinalizado():
    # mediana 100, limiar 25% → até 125 não sinaliza
    contratos = [_contrato(100), _contrato(100), _contrato(100), _contrato(120)]
    out = pncp.sinalizar_indicios(contratos, limiar=0.25)
    assert all(c["indicio"] == "" for c in out)


def test_contratos_com_valor_zero_nao_entram_no_calculo_nem_sao_sinalizados():
    contratos = [_contrato(0), _contrato(100), _contrato(100), _contrato(100), _contrato(100)]
    out = pncp.sinalizar_indicios(contratos, limiar=0.25)
    zerado = [c for c in out if c["valor"] == 0][0]
    assert zerado["indicio"] == ""


# ---------------------------------------------------------------------
# montar_texto — título estável (entra no hash de dedup)
# ---------------------------------------------------------------------

def test_montar_texto_inclui_numero_e_objeto_no_titulo():
    c = _contrato(1000)
    c["numero"] = "2026/042"
    c["objeto"] = "Reforma da escola municipal"
    titulo, _corpo = pncp.montar_texto(c)
    assert titulo == "Contrato 2026/042 — Reforma da escola municipal"


def test_montar_texto_so_inclui_indicio_quando_existe():
    c = _contrato(1000)
    c["indicio"] = ""
    _titulo, corpo_sem = pncp.montar_texto(c)
    assert "INDÍCIO" not in corpo_sem

    c["indicio"] = "Valor 300% acima da mediana."
    _titulo, corpo_com = pncp.montar_texto(c)
    assert "INDÍCIO PARA VERIFICAÇÃO: Valor 300% acima da mediana." in corpo_com


def test_montar_texto_objeto_muito_longo_e_cortado_no_titulo():
    c = _contrato(1000)
    c["objeto"] = "x" * 300
    titulo, _ = pncp.montar_texto(c)
    # "Contrato x — " + 160 chars do objeto
    assert len(titulo) < 300


# ---------------------------------------------------------------------
# buscar_contratos — nunca levanta exceção pra fora (briefing degradado >
# briefing nenhum)
# ---------------------------------------------------------------------

def _resposta_http(corpo_bytes):
    r = MagicMock()
    r.read.return_value = corpo_bytes
    r.__enter__.return_value = r
    r.__exit__.return_value = False
    return r


def test_buscar_contratos_url_error_devolve_lista_vazia_sem_lancar():
    with patch("urllib.request.urlopen", side_effect=urllib.error.URLError("timeout")):
        assert pncp.buscar_contratos(30) == []


def test_buscar_contratos_erro_generico_devolve_lista_vazia_sem_lancar():
    with patch("urllib.request.urlopen", side_effect=ValueError("boom")):
        assert pncp.buscar_contratos(30) == []


def test_buscar_contratos_aceita_resposta_em_formato_lista():
    import json
    corpo = json.dumps([{"numeroControlePNCP": "1"}]).encode()
    with patch("urllib.request.urlopen", return_value=_resposta_http(corpo)):
        itens = pncp.buscar_contratos(30)
    assert itens == [{"numeroControlePNCP": "1"}]


def test_buscar_contratos_aceita_resposta_envelopada_em_data():
    import json
    corpo = json.dumps({"data": [{"numeroControlePNCP": "1"}]}).encode()
    with patch("urllib.request.urlopen", return_value=_resposta_http(corpo)):
        itens = pncp.buscar_contratos(30)
    assert itens == [{"numeroControlePNCP": "1"}]
