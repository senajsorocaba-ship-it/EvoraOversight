"""Testes unitários de evora_coletor_mencoes.py.

Rede real (Google News, PostgREST) é sempre mockada aqui — o valor real
desses coletores já foi verificado ao vivo em sessão anterior (ver
CLAUDE.md, "500 contratos e 59 headlines ingeridos"). O que os testes
unitários cobrem: a lógica pura de montagem de consulta e parsing de
domínio/data, e o contrato de erro dos dois clientes HTTP (o que acontece
quando a rede ou o Supabase falham).
"""
import json
import urllib.error
from unittest.mock import MagicMock, patch

import pytest

import evora_coletor_mencoes as cm


# ---------------------------------------------------------------------
# carregar_ambiente
# ---------------------------------------------------------------------

def test_carregar_ambiente_ok(monkeypatch):
    monkeypatch.setenv("SUPABASE_URL", "https://exemplo.supabase.co/")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "chave-fake")
    cfg = cm.carregar_ambiente()
    # a barra final é removida — evita "//rest/v1" nas urls montadas depois
    assert cfg == {"supabase_url": "https://exemplo.supabase.co", "supabase_key": "chave-fake"}


def test_carregar_ambiente_falta_variavel(monkeypatch):
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)
    with pytest.raises(SystemExit, match="SUPABASE_URL"):
        cm.carregar_ambiente()


# ---------------------------------------------------------------------
# _extrair_dominio
# ---------------------------------------------------------------------

@pytest.mark.parametrize(
    "url,esperado",
    [
        ("https://www.cruzeirodosul.inf.br/noticia/123", "cruzeirodosul.inf.br"),
        ("https://g1.globo.com/sp/sorocaba", "g1.globo.com"),
        ("http://www.jornalola.com.br", "jornalola.com.br"),
        ("", None),
        (None, None),
    ],
)
def test_extrair_dominio(url, esperado):
    assert cm._extrair_dominio(url or "") == esperado


# ---------------------------------------------------------------------
# montar_consultas
# ---------------------------------------------------------------------

def test_montar_consultas_nome_completo_sempre_entra():
    consultas = cm.montar_consultas({"nome_autoridade": "Tatiane Costa"}, [])
    assert consultas[0][0] == '"Tatiane Costa"'


def test_montar_consultas_sem_nome_devolve_vazio():
    assert cm.montar_consultas({"nome_autoridade": ""}, []) == []
    assert cm.montar_consultas({}, []) == []


def test_montar_consultas_primeiro_nome_mais_cidade():
    consultas = cm.montar_consultas(
        {"nome_autoridade": "Tatiane Costa", "municipio_sede": "Sorocaba"}, []
    )
    textos = [c[0] for c in consultas]
    assert '"Tatiane" "Sorocaba"' in textos


def test_montar_consultas_nome_de_uma_palavra_nao_duplica_a_consulta():
    # primeiro_nome == nome inteiro — não faz sentido repetir a mesma busca
    consultas = cm.montar_consultas(
        {"nome_autoridade": "Ozzy", "municipio_sede": "Sorocaba"}, []
    )
    textos = [c[0] for c in consultas]
    assert '"Ozzy" "Sorocaba"' not in textos
    assert textos == ['"Ozzy"']


def test_montar_consultas_um_site_por_dominio_local():
    consultas = cm.montar_consultas(
        {"nome_autoridade": "Tatiane Costa", "municipio_sede": "Sorocaba"},
        ["cruzeirodosul.inf.br", "g1.globo.com"],
    )
    textos = [c[0] for c in consultas]
    assert '"Tatiane Costa" site:cruzeirodosul.inf.br' in textos
    assert '"Tatiane Costa" site:g1.globo.com' in textos


# ---------------------------------------------------------------------
# _parse_data_rss
# ---------------------------------------------------------------------

def test_parse_data_rss_formato_valido():
    iso = cm._parse_data_rss("Wed, 17 Sep 2026 08:45:00 GMT")
    assert iso.startswith("2026-09-17")


def test_parse_data_rss_vazio_ou_invalido_nao_derruba_o_coletor():
    assert cm._parse_data_rss("") is None
    assert cm._parse_data_rss(None) is None
    assert cm._parse_data_rss("isso não é uma data") is None


# ---------------------------------------------------------------------
# _rest_request — o cliente PostgREST mínimo que todo coletor reusa
# ---------------------------------------------------------------------

def _resposta_http(corpo_bytes):
    cm_resp = MagicMock()
    cm_resp.read.return_value = corpo_bytes
    cm_resp.__enter__.return_value = cm_resp
    cm_resp.__exit__.return_value = False
    return cm_resp


def test_rest_request_get_decodifica_json():
    payload = [{"id": "abc", "nome": "Teste"}]
    with patch("urllib.request.urlopen", return_value=_resposta_http(json.dumps(payload).encode())):
        resultado = cm._rest_request("GET", "https://x.supabase.co/rest/v1/tenants", "chave")
    assert resultado == payload


def test_rest_request_corpo_vazio_vira_none():
    with patch("urllib.request.urlopen", return_value=_resposta_http(b"")):
        resultado = cm._rest_request("DELETE", "https://x.supabase.co/rest/v1/tenants", "chave")
    assert resultado is None


def test_rest_request_envia_apikey_e_bearer():
    capturado = {}

    def fake_urlopen(req, timeout=60):
        capturado["headers"] = dict(req.headers)
        capturado["method"] = req.get_method()
        return _resposta_http(b"null")

    with patch("urllib.request.urlopen", side_effect=fake_urlopen):
        cm._rest_request("POST", "https://x.supabase.co/rest/v1/tenants", "minha-chave")

    # urllib normaliza o nome do header pra Capitalizado
    assert capturado["headers"]["Apikey"] == "minha-chave"
    assert capturado["headers"]["Authorization"] == "Bearer minha-chave"
    assert capturado["method"] == "POST"


def test_rest_request_http_error_vira_system_exit_com_detalhe():
    erro = urllib.error.HTTPError(
        url="https://x.supabase.co/rest/v1/tenants",
        code=409,
        msg="Conflict",
        hdrs=None,
        fp=None,
    )
    erro.read = lambda: b'{"message":"duplicate key"}'
    with patch("urllib.request.urlopen", side_effect=erro):
        with pytest.raises(SystemExit, match="409"):
            cm._rest_request("POST", "https://x.supabase.co/rest/v1/tenants?a=1", "chave")


# ---------------------------------------------------------------------
# buscar_google_news — parsing do RSS (a parte não-trivial do coletor)
# ---------------------------------------------------------------------

RSS_EXEMPLO = """<?xml version="1.0"?>
<rss version="2.0"><channel>
  <item>
    <title>Vereadora anuncia obra na Vila Barão</title>
    <link>https://exemplo.com/noticia-1</link>
    <pubDate>Wed, 17 Sep 2026 08:45:00 GMT</pubDate>
    <source url="https://exemplo.com">Jornal Exemplo</source>
  </item>
  <item>
    <title>Sem link, deve ser ignorado</title>
    <link></link>
    <pubDate>Wed, 17 Sep 2026 09:00:00 GMT</pubDate>
  </item>
</channel></rss>"""


def test_buscar_google_news_parseia_itens_validos_e_ignora_incompletos():
    with patch("urllib.request.urlopen", return_value=_resposta_http(RSS_EXEMPLO.encode())):
        itens = cm.buscar_google_news('"Tatiane Costa"', limite=10)
    assert len(itens) == 1
    assert itens[0]["titulo"] == "Vereadora anuncia obra na Vila Barão"
    assert itens[0]["link"] == "https://exemplo.com/noticia-1"
    assert itens[0]["fonte_nome"] == "Jornal Exemplo"


def test_buscar_google_news_respeita_o_limite():
    rss_com_tres = RSS_EXEMPLO.replace(
        "</channel>",
        "<item><title>Terceira</title><link>https://x.com/3</link></item></channel>",
    )
    with patch("urllib.request.urlopen", return_value=_resposta_http(rss_com_tres.encode())):
        itens = cm.buscar_google_news("qualquer coisa", limite=1)
    assert len(itens) == 1


def test_buscar_google_news_falha_de_rede_vira_system_exit():
    with patch("urllib.request.urlopen", side_effect=urllib.error.URLError("sem conexão")):
        with pytest.raises(SystemExit, match="Falha ao consultar Google News"):
            cm.buscar_google_news('"Tatiane Costa"', limite=10)


def test_buscar_google_news_rss_invalido_vira_system_exit():
    with patch("urllib.request.urlopen", return_value=_resposta_http(b"isto nao e xml")):
        with pytest.raises(SystemExit, match="RSS inválido"):
            cm.buscar_google_news('"Tatiane Costa"', limite=10)
