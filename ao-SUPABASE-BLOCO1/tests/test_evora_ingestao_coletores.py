"""Testes unitários de evora_ingestao_coletores.py.

Ponte entre os JSONs que o motor/ (pré-Supabase) ainda produz e as tabelas
achados_fiscalizacao/mencoes_imprensa. `_rest` é mockado — o que importa
testar é o que acontece ANTES da rede: arquivo ausente, lista vazia,
valores default quando um campo falta, e a regra "sem link não há notícia"
(fonte ou silêncio, nunca notícia sem como citar de onde veio).
"""
import json
from unittest.mock import patch

import evora_ingestao_coletores as ing


CFG = {"supabase_url": "https://x.supabase.co", "supabase_key": "chave"}


# ---------------------------------------------------------------------
# carregar_ambiente
# ---------------------------------------------------------------------

def test_carregar_ambiente_falta_variavel(monkeypatch):
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)
    import pytest
    with pytest.raises(SystemExit, match="SUPABASE_URL"):
        ing.carregar_ambiente()


# ---------------------------------------------------------------------
# ingerir_contratos
# ---------------------------------------------------------------------

def test_ingerir_contratos_arquivo_ausente_devolve_zero_sem_chamar_rede(tmp_path):
    caminho = str(tmp_path / "nao-existe.json")
    with patch.object(ing, "_rest") as m:
        total = ing.ingerir_contratos(CFG, caminho, "tenant-1", "gabinete")
    assert total == 0
    m.assert_not_called()


def test_ingerir_contratos_lista_vazia_devolve_zero(tmp_path):
    caminho = tmp_path / "contratos.json"
    caminho.write_text("[]", encoding="utf-8")
    with patch.object(ing, "_rest") as m:
        total = ing.ingerir_contratos(CFG, str(caminho), "tenant-1", "gabinete")
    assert total == 0
    m.assert_not_called()


def test_ingerir_contratos_aplica_defaults_em_campo_ausente(tmp_path):
    caminho = tmp_path / "contratos.json"
    caminho.write_text(json.dumps([{"numero": "1"}]), encoding="utf-8")
    with patch.object(ing, "_rest") as m:
        total = ing.ingerir_contratos(CFG, str(caminho), "tenant-1", "gabinete")
    assert total == 1
    linhas = m.call_args[0][3]
    assert linhas[0]["objeto"] == "(sem objeto)"
    assert linhas[0]["relevancia"] == "rotina"
    assert linhas[0]["valor"] == 0
    assert linhas[0]["fonte"] == "PNCP"


def test_ingerir_contratos_usa_on_conflict_tenant_numero(tmp_path):
    caminho = tmp_path / "contratos.json"
    caminho.write_text(json.dumps([{"numero": "1"}]), encoding="utf-8")
    with patch.object(ing, "_rest") as m:
        ing.ingerir_contratos(CFG, str(caminho), "tenant-1", "gabinete")
    url = m.call_args[0][1]
    assert "on_conflict=tenant_id,numero_pncp" in url
    assert m.call_args[1]["prefer"] == "resolution=merge-duplicates,return=minimal"


# ---------------------------------------------------------------------
# ingerir_noticias — "sem link, sem notícia" é a regra que mais importa
# ---------------------------------------------------------------------

def test_ingerir_noticias_arquivo_ausente_devolve_zero(tmp_path):
    caminho = str(tmp_path / "nao-existe.json")
    with patch.object(ing, "_rest") as m:
        assert ing.ingerir_noticias(CFG, caminho, "tenant-1", "gabinete") == 0
    m.assert_not_called()


def test_ingerir_noticias_descarta_item_sem_link(tmp_path):
    caminho = tmp_path / "noticias.json"
    caminho.write_text(json.dumps([
        {"titulo": "Com link", "link": "https://x.com/1"},
        {"titulo": "Sem link"},  # deve ser descartada — sem como citar a fonte
    ]), encoding="utf-8")
    with patch.object(ing, "_rest") as m:
        total = ing.ingerir_noticias(CFG, str(caminho), "tenant-1", "gabinete")
    assert total == 1
    linhas = m.call_args[0][3]
    assert len(linhas) == 1
    assert linhas[0]["titulo"] == "Com link"


def test_ingerir_noticias_todas_sem_link_nao_chama_rede(tmp_path):
    caminho = tmp_path / "noticias.json"
    caminho.write_text(json.dumps([{"titulo": "Sem link nenhum"}]), encoding="utf-8")
    with patch.object(ing, "_rest") as m:
        total = ing.ingerir_noticias(CFG, str(caminho), "tenant-1", "gabinete")
    assert total == 0
    m.assert_not_called()


def test_ingerir_noticias_converte_data_do_rss(tmp_path):
    caminho = tmp_path / "noticias.json"
    caminho.write_text(json.dumps([{
        "titulo": "Notícia", "link": "https://x.com/1",
        "data": "Wed, 17 Sep 2026 08:45:00 GMT",
    }]), encoding="utf-8")
    with patch.object(ing, "_rest") as m:
        ing.ingerir_noticias(CFG, str(caminho), "tenant-1", "gabinete")
    linha = m.call_args[0][3][0]
    assert linha["publicado_em"].startswith("2026-09-17")
    assert linha["publicado_em_bruto"] == "Wed, 17 Sep 2026 08:45:00 GMT"


def test_ingerir_noticias_usa_on_conflict_tenant_link(tmp_path):
    caminho = tmp_path / "noticias.json"
    caminho.write_text(json.dumps([{"titulo": "N", "link": "https://x.com/1"}]), encoding="utf-8")
    with patch.object(ing, "_rest") as m:
        ing.ingerir_noticias(CFG, str(caminho), "tenant-1", "gabinete")
    url = m.call_args[0][1]
    assert "on_conflict=tenant_id,link" in url


# ---------------------------------------------------------------------
# _parse_data_rss
# ---------------------------------------------------------------------

def test_parse_data_rss_valido_e_invalido():
    assert ing._parse_data_rss("Wed, 17 Sep 2026 08:45:00 GMT").startswith("2026-09-17")
    assert ing._parse_data_rss("") is None
    assert ing._parse_data_rss("lixo") is None
