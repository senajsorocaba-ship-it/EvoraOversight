"""Testes unitários de evora_coletor_farus.py.

`_rest_request` é mockado (patch no nome importado dentro do próprio
módulo) — o que se testa aqui é a lógica de decisão em torno dele: acha ou
cria território (índice funcional, sem upsert direto), upsert de vínculo,
e a regra mais importante do arquivo — Decisão D6: `buscar_fonte_
configurada` NUNCA cria/libera fonte sozinha, só devolve None quando não
acha uma já configurada, e quem chama decide o que fazer com isso.
"""
from unittest.mock import patch

import evora_coletor_farus as farus


CFG = {"supabase_url": "https://x.supabase.co", "supabase_key": "chave"}


# ---------------------------------------------------------------------
# montar_consultas_farus — pura
# ---------------------------------------------------------------------

def test_montar_consultas_farus_cobre_o_escopo_do_f1():
    consultas = farus.montar_consultas_farus("Sorocaba")
    textos = [c[0] for c in consultas]
    assert '"Prefeitura de Sorocaba"' in textos
    assert '"Câmara Municipal de Sorocaba"' in textos
    assert '"Sorocaba" licitação' in textos
    assert '"Sorocaba" decreto' in textos
    assert len(consultas) == 4


# ---------------------------------------------------------------------
# garantir_territorio — busca primeiro, cria só se não achar (índice
# funcional não aceita upsert direto)
# ---------------------------------------------------------------------

def test_garantir_territorio_reaproveita_se_ja_existe():
    with patch.object(farus, "_rest_request", return_value=[{"id": "id-existente"}]) as m:
        resultado = farus.garantir_territorio(CFG, "Sorocaba", "sp")
    assert resultado == "id-existente"
    # só a busca (GET) foi chamada — nunca tentou criar de novo
    assert m.call_count == 1
    assert m.call_args[0][0] == "GET"


def test_garantir_territorio_cria_quando_nao_existe():
    respostas = [[], [{"id": "id-novo"}]]  # 1a chamada: busca vazia; 2a: criação

    def fake(*args, **kwargs):
        return respostas.pop(0)

    with patch.object(farus, "_rest_request", side_effect=fake) as m:
        resultado = farus.garantir_territorio(CFG, "Sorocaba", "sp")
    assert resultado == "id-novo"
    assert m.call_count == 2
    assert m.call_args_list[0][0][0] == "GET"
    assert m.call_args_list[1][0][0] == "POST"


def test_garantir_territorio_normaliza_uf_maiuscula():
    capturado = {}

    def fake(method, url, key, *a, **kw):
        capturado["url"] = url
        return [{"id": "x"}]

    with patch.object(farus, "_rest_request", side_effect=fake):
        farus.garantir_territorio(CFG, "Sorocaba", "sp")
    assert "uf=eq.SP" in capturado["url"]


def test_garantir_territorio_recusa_sem_municipio_ou_uf():
    import pytest
    with pytest.raises(SystemExit, match="não dá pra ligar ao FARUS"):
        farus.garantir_territorio(CFG, "", "SP")
    with pytest.raises(SystemExit, match="não dá pra ligar ao FARUS"):
        farus.garantir_territorio(CFG, "Sorocaba", "")


# ---------------------------------------------------------------------
# garantir_vinculo_tenant — upsert direto (PK simples aceita on_conflict)
# ---------------------------------------------------------------------

def test_garantir_vinculo_tenant_usa_on_conflict_e_merge():
    with patch.object(farus, "_rest_request", return_value=None) as m:
        farus.garantir_vinculo_tenant(CFG, "tenant-1", "territorio-1")
    args, kwargs = m.call_args
    assert "on_conflict=tenant_id,territorio_id" in args[1]
    assert kwargs["prefer"] == "resolution=merge-duplicates,return=minimal"
    body = args[3]
    assert body["tenant_id"] == "tenant-1"
    assert body["territorio_id"] == "territorio-1"
    assert body["principal"] is True


# ---------------------------------------------------------------------
# calcular_hash — sempre pede ao Postgres, nunca calcula em Python
# ---------------------------------------------------------------------

def test_calcular_hash_chama_a_rpc_certa():
    with patch.object(farus, "_rest_request", return_value="deadbeef") as m:
        resultado = farus.calcular_hash(CFG, "Título", "Conteúdo")
    assert resultado == "deadbeef"
    args, kwargs = m.call_args
    assert args[0] == "POST"
    assert args[1].endswith("/rpc/farus_hash")
    assert args[3] == {"p_titulo": "Título", "p_conteudo": "Conteúdo"}


# ---------------------------------------------------------------------
# buscar_fonte_configurada — Decisão D6: NUNCA cria/libera sozinha
# ---------------------------------------------------------------------

def test_buscar_fonte_configurada_devolve_id_quando_ha_uma():
    with patch.object(farus, "_rest_request", return_value=[{"id": "fonte-1"}]):
        assert farus.buscar_fonte_configurada(CFG, "territorio-1", "contratacao") == "fonte-1"


def test_buscar_fonte_configurada_devolve_none_sem_criar_nada():
    with patch.object(farus, "_rest_request", return_value=[]) as m:
        resultado = farus.buscar_fonte_configurada(CFG, "territorio-1", "contratacao")
    assert resultado is None
    # só uma chamada — GET de busca. Nunca um POST tentando liberar sozinha.
    assert m.call_count == 1
    assert m.call_args[0][0] == "GET"


def test_buscar_fonte_configurada_filtra_por_estado_configurada():
    capturado = {}

    def fake(method, url, key):
        capturado["url"] = url
        return []

    with patch.object(farus, "_rest_request", side_effect=fake):
        farus.buscar_fonte_configurada(CFG, "territorio-1", "ato_oficial")
    assert "estado=eq.configurada" in capturado["url"]
    assert "especie=eq.ato_oficial" in capturado["url"]
