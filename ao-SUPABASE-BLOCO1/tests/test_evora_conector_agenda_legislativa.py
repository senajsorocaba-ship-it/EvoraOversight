"""Testes unitários de evora_conector_agenda_legislativa.py.

Os regexes de extração (`RE_LINHA_SESSAO`, `RE_ORDEM`, etc.) foram
verificados ao vivo contra sorocaba.camarasempapel.com.br numa sessão
anterior (ver CLAUDE.md) — os fragmentos de HTML abaixo reproduzem a
estrutura real então observada, não são inventados. `_baixar` é mockado;
tudo daqui pra baixo (parsing) roda sobre HTML estático, sem rede.
"""
from unittest.mock import patch

import evora_conector_agenda_legislativa as agenda


# ---------------------------------------------------------------------
# listar_sessoes
# ---------------------------------------------------------------------

HTML_SESSOES = """
<div>
  <strong>Ordinária N°79</strong>
  <a href="sessao-leitura.aspx?id=1297&tip=1">ver pauta</a>
  <strong>Data:</strong> 17/09/2026
  <strong>Horário</strong> 08:45
  Publicada em:</strong> 10/09/2026 08:00<br>
</div>
<div>
  <strong>Extraordinária N°80</strong>
  <a href="sessao-leitura.aspx?id=1298&tip=1">ver pauta</a>
  <strong>Data:</strong> 24/09/2026
  <strong>Horário</strong> 09:00
  Publicada em:</strong> 18/09/2026 10:00<br>
</div>
"""


def test_listar_sessoes_extrai_campos_da_primeira_sessao():
    with patch.object(agenda, "_baixar", return_value=HTML_SESSOES):
        sessoes = agenda.listar_sessoes("sorocaba.camarasempapel.com.br", limite=10)
    assert len(sessoes) == 2
    primeira = sessoes[0]
    assert primeira["id"] == "1297"
    assert primeira["tipo"] == "Ordinária"
    assert primeira["numero"] == "79"
    assert primeira["data"] == "17/09/2026"
    assert primeira["horario"] == "08:45"
    assert primeira["publicada_em"] == "10/09/2026 08:00"


def test_listar_sessoes_respeita_o_limite_sem_reordenar():
    with patch.object(agenda, "_baixar", return_value=HTML_SESSOES):
        sessoes = agenda.listar_sessoes("sorocaba.camarasempapel.com.br", limite=1)
    assert len(sessoes) == 1
    assert sessoes[0]["numero"] == "79"  # a primeira da listagem, não reordena


def test_listar_sessoes_pagina_sem_sessao_nenhuma_devolve_lista_vazia():
    with patch.object(agenda, "_baixar", return_value="<html>nada aqui</html>"):
        assert agenda.listar_sessoes("x", limite=10) == []


# ---------------------------------------------------------------------
# extrair_materias
# ---------------------------------------------------------------------

def _bloco_materia(ordem, processo_id, tipo, numero, ano, *, processo="", autor="",
                    ementa="", fase="", acao=""):
    partes = [f'<strong>Ordem:</strong> {ordem}&nbsp;\n'
              f'<a href="processo.aspx?id={processo_id}" target="_blank">\n'
              f'<strong> {tipo} N°{numero}/{ano} </strong></a>']
    if processo:
        partes.append(f'Nº Processo:<a> {processo} </a>')
    if autor:
        partes.append(f'<strong>Autor:</strong><span class="a"><a href="#">{autor}</a></span>')
    if ementa:
        partes.append(
            f'<a href="https://sorocaba.camarasempapel.com.br/processo.aspx?id={processo_id}"> {ementa} </a>'
        )
    if fase:
        partes.append(f'<strong>Fase:</strong> {fase}</div>')
    if acao:
        partes.append(f'<strong>Ação:</strong> {acao}</div>')
    return "\n".join(partes)


def _pagina_com_materias(*blocos):
    corpo = "</td>\n</tr>\n<tr>\n<td>".join(blocos)
    return (
        '<table id="ContentPlaceHolder1_grv_sessoes_proposicoes">'
        "<tr><td>" + corpo + "</td></tr></table>"
    )


def test_extrair_materias_sem_o_marcador_da_tabela_devolve_vazio():
    assert agenda.extrair_materias("<html>página qualquer</html>") == []


def test_extrair_materias_le_todos_os_campos_de_uma_materia_completa():
    bloco = _bloco_materia(
        17, 8842, "Requerimento", 450, 2026,
        processo="2437/2026",
        autor="Vereador Autor - PARTIDO",
        ementa="Requer informações sobre a fila de espera na UBS do Éden.",
        fase="1ª discussão",
        acao="Aguardando parecer",
    )
    html = _pagina_com_materias(bloco)
    materias = agenda.extrair_materias(html)
    assert len(materias) == 1
    m = materias[0]
    assert m["ordem"] == "17"
    assert m["processo_id"] == "8842"
    assert m["tipo"] == "Requerimento"
    assert m["numero"] == "450"
    assert m["ano"] == "2026"
    assert m["num_processo"] == "2437/2026"
    assert m["autor"] == "Vereador Autor - PARTIDO"
    assert "fila de espera" in m["ementa"]
    assert m["fase"] == "1ª discussão"
    assert m["acao"] == "Aguardando parecer"


def test_extrair_materias_campo_opcional_ausente_fica_string_vazia_nunca_quebra():
    # sem autor, sem ementa — o parser não pode inventar nem quebrar
    bloco = _bloco_materia(1, 100, "Indicação", 10, 2026, fase="Protocolada")
    html = _pagina_com_materias(bloco)
    materias = agenda.extrair_materias(html)
    assert len(materias) == 1
    assert materias[0]["autor"] == ""
    assert materias[0]["ementa"] == ""
    assert materias[0]["fase"] == "Protocolada"


def test_extrair_materias_varias_na_mesma_pagina_em_ordem():
    bloco1 = _bloco_materia(1, 100, "Requerimento", 10, 2026, ementa="Primeira matéria")
    bloco2 = _bloco_materia(2, 101, "Indicação", 11, 2026, ementa="Segunda matéria")
    html = _pagina_com_materias(bloco1, bloco2)
    materias = agenda.extrair_materias(html)
    assert [m["ordem"] for m in materias] == ["1", "2"]
    assert materias[0]["ementa"] == "Primeira matéria"
    assert materias[1]["ementa"] == "Segunda matéria"


def test_extrair_materias_ignora_partido_nao_extraivel_desta_pagina():
    # gap honesto documentado no CLAUDE.md: só nome do autor sai daqui, o
    # partido exigiria uma segunda página (consulta-producao.aspx). O
    # parser nunca deve inventar um partido que não está no HTML.
    bloco = _bloco_materia(1, 100, "Moção", 5, 2026, autor="Vereadora Autora")
    html = _pagina_com_materias(bloco)
    materias = agenda.extrair_materias(html)
    assert materias[0]["autor"] == "Vereadora Autora"
    assert "partido" not in materias[0]


# ---------------------------------------------------------------------
# montar_texto
# ---------------------------------------------------------------------

def test_montar_texto_monta_titulo_conteudo_e_url():
    sessao = {"tipo": "Ordinária", "numero": "79", "data": "17/09/2026", "horario": "08:45"}
    materia = {
        "ordem": "17", "processo_id": "8842", "tipo": "Requerimento",
        "numero": "450", "ano": "2026", "num_processo": "2437/2026",
        "autor": "Vereador Autor - PARTIDO",
        "ementa": "Requer informações sobre a UBS do Éden.",
        "fase": "1ª discussão", "acao": "Aguardando parecer",
    }
    titulo, conteudo, url = agenda.montar_texto(sessao, materia, "sorocaba.camarasempapel.com.br")
    assert titulo == "Requerimento Nº 450/2026 — Ordem 17, Sessão Ordinária Nº 79"
    assert "Ementa: Requer informações sobre a UBS do Éden." in conteudo
    assert "Autor: Vereador Autor - PARTIDO" in conteudo
    assert url == "https://sorocaba.camarasempapel.com.br/processo.aspx?id=8842"


def test_montar_texto_omite_campo_vazio_do_conteudo():
    sessao = {"tipo": "Ordinária", "numero": "79", "data": "17/09/2026", "horario": "08:45"}
    materia = {
        "ordem": "1", "processo_id": "1", "tipo": "Indicação", "numero": "1", "ano": "2026",
        "num_processo": "", "autor": "", "ementa": "", "fase": "", "acao": "",
    }
    _titulo, conteudo, _url = agenda.montar_texto(sessao, materia, "x")
    assert "Autor:" not in conteudo
    assert "Ementa:" not in conteudo


# ---------------------------------------------------------------------
# _data_iso — honesto: nunca força uma data que não leu
# ---------------------------------------------------------------------

def test_data_iso_converte_formato_br():
    assert agenda._data_iso("17/09/2026") == "2026-09-17"


def test_data_iso_formato_invalido_devolve_none_em_vez_de_chutar():
    assert agenda._data_iso("não é uma data") is None
    assert agenda._data_iso("") is None
