# FILA DE REGISTRO — MANUAL SUPREMO v11.1

> **20 de setembro de 2026** · itens posteriores à emissão da v11.0
> Confidencial — propriedade intelectual de Eng. de Sistemas Luiz Gonzaga Filho

---

# POR QUE ESTA FILA EXISTE

A **v11.0 foi emitida em 18/09/2026** com 30 itens incorporados. Os itens registrados depois
dessa emissão não cabiam mais nela — uma fila com o mesmo número de um manual já emitido
confunde: não se sabe o que entrou e o que espera.

**Esta fila acumula o que entra na v11.1.** Os 30 itens da v11.0 estão em
`FILA_REGISTRO_v11_0_ARQUIVADA.md`, como histórico.

---

# ITEM 1 · NOVA REGRA — verificação arquitetural antes de estruturar

**Tipo:** regra de conduta · **Origem:** determinação do fundador, 16/09/2026

> **Toda instrução nova que exija estruturar algo deve primeiro verificar se a arquitetura atual
> tem onde acomodá-la. Se não tiver, informar a lacuna e sugerir a solução — sempre, antes de
> construir.**

**Por que existe:** instrução encaixada à força em estrutura que não a comporta produz campo
livre, convenção não escrita e dado que o motor não pode confiar. É o padrão "documento diz,
disco não tem", nascendo já torto.

**Já provou o valor três vezes** nesta sessão — ver itens 2, 3 e 4.

---

# ITEM 2 · NOVO — resposta em múltiplos registros

**Tipo:** novo · **Origem:** determinação do fundador, 16/09/2026

> **"O sistema responde a alguém que pode não ser advogado — a vereadora. Precisa preparar uma
> resposta que todo mundo entenda e outra técnica, para um ofício."**

| Registro | Para quem |
| --- | --- |
| `simples` | linguagem comum, sem jargão |
| `tecnico` | com fundamentação e citação de dispositivo |
| **`ambos`** | **padrão** — as duas versões, o leitor escolhe |

**A preferência do usuário sobrepõe a do gabinete.** A chefia pode querer técnico e a autoridade,
simples.

**Lacuna 3 fechada junto:** `briefings` guardava um texto só. Ganhou `registro_entregue` e
`markdown_tecnico` — importa na trilha saber qual versão a autoridade leu.

---

# ITEM 3 · NOVO — minutas para aprovação humana

**Tipo:** novo · **Gravidade da lacuna:** **alta**

**A Skill exige minutas nas seções 2 e 36:** *"minuta de ofício para sua aprovação antes de
qualquer envio"*. **Não existia tabela nenhuma.**

**Por que era grave:** a minuta é onde o freio humano se materializa. Sem lugar para ela, ou o
sistema não gera minuta — e perde a camada 6 da Skill — ou gera sem registro de quem aprovou, o
que quebra a trilha.

## As cinco travas, impostas pelo banco

| Trava | Efeito |
| --- | --- |
| Aprovada ou descartada exige quem decidiu e quando | **freio humano no banco** |
| Descarte exige motivo | recusa sem razão não se audita |
| Só se protocola o que foi aprovado | — |
| Minuta precisa ter ao menos um texto | — |
| **Toda minuta nasce de matéria, item do acervo ou norma** | rastreabilidade |

**Alçada:** apenas autoridade e chefe de gabinete decidem.

> ## 🔒 A trava que atravessa tudo
>
> **O Évora nunca envia.** Guarda a minuta, registra a decisão, e **o envio é ato humano fora do
> sistema**. Não existe campo de "enviado por nós" — existe `protocolo_informado`, preenchido
> pela pessoa depois de protocolar.

**Construído e testado:** `evora_resposta_minutas.sql` — 12 de 12.

---

# ITEM 4 · NOVO — parecer como evento, não como etapa

**Tipo:** novo · **Origem:** determinação do fundador, 20/09/2026

> **"Os assessores são assessores. O fato de um deles ser advogado ajuda, mas não deve mudar a
> arquitetura do sistema, pois ter advogado assessor é um acaso."**

## O princípio

**Papel é posição no gabinete. Habilitação é qualidade da pessoa.**

Criar um papel `juridico` faria o sistema se comportar de formas diferentes conforme o acaso da
composição da equipe: gabinete com advogado teria um fluxo, gabinete sem teria outro. **A
arquitetura ficaria refém da sorte.**

## O que a decisão evitou construir

| Não foi criado | Por quê |
| --- | --- |
| Papel `juridico` | Habilitação é da pessoa, não posição |
| Estado `aguardando_juridico` | Parecer é evento, não etapa |
| Bloqueio de aprovação sem parecer | A autoridade decide |
| Validação de inscrição no conselho | O sistema não afirma o que não verificou |

## O que foi construído

**Habilitação como atributo da pessoa** — campos `habilitacao` e `habilitacao_registro` em
`usuarios`. Não altera alçada.

**Parecer como evento solicitado** — tabela `minuta_pareceres`, com cinco travas. Funciona igual
para parecerista interno ou externo ao gabinete.

**Quatro conclusões possíveis:** favorável · **favorável com ressalva** · contrário ·
inconclusivo. A ressalva exige dizer **o que precisa mudar** — "aprovado desde que altere o item
b" sem dizer qual não orienta ninguém.

**Dispensa registrada:** a autoridade pode seguir sem parecer, com motivo na trilha. **É proteção
dela** — mostra que assumiu conscientemente.

> ## Por que o parecer não aprova
>
> **Se o parecer aprovasse, a responsabilidade migraria do eleito para o assessor.** Quem responde
> pelo mandato é a autoridade — e o freio humano existe para proteger essa linha, não para
> diluí-la.

**Construído e testado:** `evora_parecer_evento.sql` — 11 de 11.

---

# ITEM 5 · REGISTRO — Inteligência Legislativa construída

**Tipo:** registro · **Origem:** aplicação da Skill VERITAS 1.0 GOLD

**A lacuna:** o FARUS guarda fatos, o Veritas guarda normas — **não havia onde morar a matéria**,
a proposição com tramitação, comissão, relator e status. Sem isso, as seções 4, 5, 6, 7 e 12 da
Skill não tinham como funcionar.

**Construído:** 8 tabelas, 8 políticas, 5 funções. **Teste 12 de 12.**

## As duas travas centrais

**Status formal ≠ status operacional.** Uma matéria pode constar como "em tramitação" e estar
parada há meses. São campos independentes, e **o banco nunca deduz um do outro**.

**Evento material ≠ administrativo.** Juntada, numeração e conferência não são avanço. O campo
`material` permite dizer *"sem movimentação material desde 10/03/2026, há 194 dias, com 2
movimentações administrativas depois"*.

**E a memória temporal da seção 7:** `legis_composicao_em(orgao, data)` responde quem compunha a
comissão à época, não apenas hoje.

---

# ITEM 6 · PENDENTE — fluxo do requerimento

**Tipo:** desenho em aberto · **Origem:** discussão de 16/09 e 20/09

O fundador descreveu o ciclo do requerimento: disponível por tempo determinado com aviso no
painel → vistas da tenant → liberado para protocolar → jurídico da Câmara verifica legalidade →
correção ou cancelamento → envio ao Executivo → atendimento.

## ⚠️ Colisão com trava pétrea, ainda não resolvida

**"Envia o requerimento para o sistema da Câmara processar" é o Évora protocolando.** A trava
diz: *não publica, não protocola e não contata terceiros*.

`[AGUARDA DECISÃO DO FUNDADOR]` Três leituras:

| | Desenho | Exige mudar a trava? |
| --- | --- | --- |
| **A** | A pessoa protocola; o Évora registra o número depois | não |
| **B** | O sistema protocola com autorização expressa | **sim** |
| **C** | A autoridade confirma no Évora, mas transmite pelo navegador dela | não |

## O que o desenho ainda não cobre

| # | Situação | Pergunta aberta |
| --- | --- | --- |
| 1 | **Prazo vence sem decisão** | Caduca, arquiva, ou sobe de prioridade? |
| 2 | Versão após correção da Câmara | O protocolado não pode ser sobrescrito |
| 3 | Indeferimento no protocolo | É desfecho, não pendência |
| 4 | **Silêncio do Executivo** | *"não respondeu há 47 dias"* é achado de fiscalização |

## Painel — proposta de separação em dois blocos

**São circuitos de donos diferentes.** Misturá-los faria o painel mostrar como "pendente do
gabinete" algo parado na Câmara.

| Exige decisão da autoridade | Em andamento, fora do gabinete |
| --- | --- |
| aguardando vistas | no protocolo |
| pendente de informação complementar | em análise jurídica da Câmara |
| **prazo vencendo** | com o Executivo · **sem resposta há X dias** |

`[AGUARDA CONFIRMAÇÃO]`

---

# SITUAÇÃO DA FILA v11.1

| # | Item | Tipo | Estado |
| --- | --- | --- | --- |
| 1 | Verificação arquitetural antes de estruturar | **regra** | ✅ em vigor |
| 2 | Resposta em múltiplos registros | novo | ✅ construído · 12 de 12 |
| 3 | Minutas para aprovação humana | novo | ✅ construído · 12 de 12 |
| 4 | **Parecer como evento, não etapa** | novo | ✅ construído · 11 de 11 |
| 5 | Inteligência Legislativa (Skill VERITAS) | registro | ✅ construído · 12 de 12 |
| 6 | **Fluxo do requerimento** | desenho | 🔶 **colisão com trava pétrea** |

**Total: 6 itens** — 1 regra · 3 novos construídos · 1 registro · 1 em aberto

---

# 🔶 O QUE AGUARDA DECISÃO DO FUNDADOR

## Herdado da v11.0

| # | Ponto |
| --- | --- |
| 1 | **Preço mensal do Évora Aegis Personal** |
| 2 | **Confirmar a fórmula proporcional da escada** — `min(4, teto(prazo ÷ 3))` |
| 3 | **Granularidade dos metadados do Sigma One** — três níveis ou visibilidade única |

## Novo nesta fila

| # | Ponto |
| --- | --- |
| 4 | **Fluxo do requerimento: leitura A, B ou C** — a B exige mudar a trava pétrea |
| 5 | O que fazer quando o prazo do requerimento vence sem decisão |
| 6 | Confirmar a separação do painel em dois blocos |

---

# ESTADO DO BANCO

**34 tabelas · 34 políticas · RLS forçado em todas.**

| Camada | Arquivo | Testes |
| --- | --- | --- |
| Base e isolamento | `01_schema` · `02_rls` · `04_token_hook` | 5 + 3 |
| FARUS — acervo de fatos | `05_farus` | 10 de 10 |
| Aegis — cofre | `07_aegis` | 10 de 10 |
| Veritas — acervo legal | `09_veritas` | 12 de 12 |
| Inteligência Legislativa | `11_legis_inteligencia` | 12 de 12 |
| Resposta e minutas | `13_resposta_minutas` | 12 de 12 |
| **Parecer como evento** | `15_parecer_evento` | **11 de 11** |

---

*Fila de Registro v11.1 · 20/09/2026*
*Évora Oversight · Confidencial — Eng. de Sistemas Luiz Gonzaga Filho*
*Protegido pelas Leis nº 9.610/98 e nº 9.609/98*
