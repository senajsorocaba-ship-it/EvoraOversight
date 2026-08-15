# 09.1 — Tela: Dashboard Principal (Sala de Comando) · Évora

> Especificação de interface · v1 · Base: Manual Master v9.4 · Design System: `09-design-system.md`
> Referência viva (maquete aprovada): `Evora_Dashboard_Castelo_v8.6.html`

---

## Objetivo da tela
Ser a **porta de entrada e a casa** do usuário no Évora: a "sala de comando" de onde ele alcança tudo — o Briefing do dia, o Radar, a Fiscalização, as Demandas, a Agenda, as Estatísticas e a Configuração — em poucos cliques, por texto ou por voz. É a primeira tela após o login.

## Quem pode acessá-la
Todos os papéis autenticados, **com o conteúdo filtrado pela alçada** (papel não é pessoa):
- **Autoridade (Tatiane):** vê tudo, inclusive o que é sensível/N5.
- **Chefe de Gabinete (Sabrina):** tudo, sem o cofre N5.
- **Jurídico (Dra. Íria):** ocorrências, fiscalização, riscos.
- **Demandas (Tatê, Maria Alice):** demandas, requerimentos, agenda.
- **Mídia (Gustavo):** comunicação, material a produzir.
- **Apoio de campanha:** não acessa esta tela do gabinete (só a camada de campanha, temporal).
A barra lateral **só mostra os blocos que o papel pode abrir** — o que não é permitido não aparece (discrição).

## Layout
Herda o layout mestre do Design System:
- **Barra lateral fixa e integrada** (esquerda, 250px), agrupada: **Ativo agora (Genesis)** — Briefing · Radar · Fiscalização · Demandas · Agenda · Banco de Dados; **Novo** — Estatísticas; **Próximas fases** — Comunicação (GEC) · Campanha; **Configuração** — Usuários e Segurança. No topo da barra, o brasão (clicável → volta ao início). No rodapé, nome do tenant.
- **Topo:** migalhas (Início) · campo de busca por texto · botão de voz 🎙 · indicador da Bia · no canto direito, o quadro **"Como Estou Hoje"** (carinhas + nome, até as 10h).
- **Área de trabalho:** ao entrar, mostra o **resumo do dia** (o Briefing condensado) como conteúdo inicial; ao escolher um item da barra, a área troca para aquele setor.
- **Celular:** barra vira ☰; o resumo do dia ocupa a largura.

## Componentes
- **Item de navegação** (barra) — ícone + rótulo + selo (MVP/novo/fase/config); hover = **ícone cresce como lupa**; ativo = barra dourada.
- **Cartões de setor** na área de trabalho (Briefing, Radar, etc.), clicáveis, abrindo em camadas.
- **Campo de busca por texto** e **botão de voz** (topo).
- **Migalhas** reversíveis.
- **Quadro "Como Estou Hoje"** (canto superior direito).
- **Toast** para confirmações.

## Ações do usuário
- Clicar num item da barra → abre o setor na área de trabalho.
- Digitar na busca ("radar", "voltar", "imprimir") → navega direto.
- Falar (🎙 / "Bia, abrir fiscalização") → mesma navegação por voz.
- Passar o mouse num ícone → cresce (lupa), indicando que é selecionável.
- Clicar no brasão ou "Início" → volta ao resumo do dia.
- Ajustar o próprio estado no quadro "Como Estou Hoje".
- Esc / Voltar → recua uma camada.

## Dados exibidos
- **Resumo do dia** (Briefing condensado): manchetes priorizadas, contagem do Radar (nomeações/exonerações), alertas de Fiscalização, demandas com movimento, próximos compromissos.
- **Selos de status** por setor (ex.: "3 novos" no Radar).
- **Estado emocional** do gabinete (carinhas), conforme regras do quadro.

## Origem dos dados
- Briefing/resumo: agente **AIM-g — Inteligência e Monitoramento** (via Bia), a partir do Veritas-Dados.
- Radar/Fiscalização: **AFEx-g — Fiscalização do Executivo** (Diário Oficial via COM, PNCP).
- Demandas/Requerimentos: **ADC-g — Demandas Cidadãs** (Câmara Sem Papel).
- Agenda: **AAG-g — Agenda**.
- Todo dado carrega sua fonte (CVI); nada sem origem verificável.

## Mensagens de erro e estados vazios
- **Sem briefing ainda hoje** (antes das 06:45 ou motor não rodou): "O briefing de hoje ainda não está pronto. Última edição: [data/hora]." + botão "Ver briefing de ontem". Nunca tela em branco.
- **Fonte fora do ar** (ex.: Diário Oficial inacessível): faixa discreta "Radar indisponível no momento — as demais seções seguem atualizadas." (degradação avisada, Painel de Saúde).
- **Papel sem acesso a um setor:** o item nem aparece na barra (não mostra "acesso negado" — discrição).
- **Busca sem resultado:** "Não encontrei '[termo]'. Tente: briefing, radar, demandas, agenda." (voz da interface, sem culpar o usuário).

## Regras específicas desta tela
- A barra lateral **reflete a alçada**: só aparece o que o papel pode abrir.
- O **título da aba do navegador** é sempre neutro ("Évora") — nunca o assunto (sigilo).
- Conteúdo sensível (N4/N5) só renderiza após step-up de autenticação; antes, placeholder neutro.
- Tudo é reversível (migalhas, Voltar, Esc); conteúdo externo (ex.: mapa) abre **dentro** da tela.
- Acesso por texto e voz alcança qualquer setor — sem exceção.

## Critérios de aceitação
1. Ao logar, a tela abre em ≤ 2s mostrando o resumo do dia (ou o estado vazio correto se não houver briefing).
2. A barra lateral mostra **apenas** os blocos permitidos ao papel autenticado (testar com 3 papéis diferentes).
3. Passar o mouse num ícone da barra o faz crescer (lupa) de forma visível; o item ativo tem barra dourada.
4. Digitar "fiscalização" na busca abre o setor de Fiscalização; falar "Bia, abrir demandas" abre Demandas.
5. Todo dado na área de trabalho mostra a fonte; nenhum item aparece sem origem.
6. O título da aba do navegador permanece "Évora" mesmo com conteúdo sensível aberto.
7. Contraste de todo texto ≥ AA; navegação completa por teclado; Esc volta uma camada.
8. Em 360px de largura, a barra colapsa em ☰ e o resumo do dia permanece legível.
9. Com uma fonte fora do ar, a tela mostra a faixa de degradação, não um erro cru nem tela branca.
