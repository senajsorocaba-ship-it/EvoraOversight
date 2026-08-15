# 09 — Design System · Évora Oversight

> Especificação de interface · v1 · Base: Manual Master v9.4
> Este arquivo define os tokens e componentes que TODA tela do Évora usa. O Claude Code deve derivar cada cor, medida e componente daqui — nenhuma tela inventa estilo próprio.

---

## 0. Princípios de design (inegociáveis)

1. **Não parecer feito por IA.** Nada de layout genérico "cream + serifa + terracota", nada de card flutuante padrão. A identidade é institucional, sóbria, de sala de comando — parece um sistema de governo sério, feito sob medida.
2. **Discrição e sigilo (padrão ouro).** A interface nunca expõe mais do que o necessário. Sem rótulos que revelem lógica interna, sem nomes de agentes crus para o usuário final quando um nome humano serve melhor. Telas sensíveis não deixam vazar conteúdo em preview, título de aba do navegador ou notificação.
3. **Contraste perfeito.** Todo texto atinge no mínimo WCAG AA (4.5:1 para corpo, 3:1 para títulos grandes). Nada de cinza claro sobre claro. Legibilidade acima de estética.
4. **Eficiência.** Caminho curto para tudo. O que o usuário faz todo dia está a um clique ou um comando de voz.
5. **Acesso universal por texto e voz.** Qualquer parte do sistema é alcançável digitando ou falando ("Bia, abrir fiscalização"). A navegação por clique é uma conveniência, não a única via.

---

## 1. Cores (tokens)

| Token | Hex | Uso |
| --- | --- | --- |
| `--navy` | `#213A5C` | Cor institucional primária: barra lateral, cabeçalhos, títulos |
| `--navy-deep` | `#182B42` | Fundo da barra lateral (gradiente com --navy) |
| `--navy-ink` | `#0E1A2B` | Fundo mais escuro / topo de tela |
| `--gold` | `#B5985A` | Acento: seleção, foco, bordas de destaque, o brasão |
| `--gold-light` | `#D8C08A` | Eyebrows, rótulos de seção, texto de acento sobre escuro |
| `--paper` | `#FBFAF6` | Fundo de folhas de conteúdo (área de leitura clara) |
| `--ink` | `#23272E` | Texto principal sobre fundo claro (contraste 12:1) |
| `--muted` | `#5B6470` | Texto secundário sobre claro (contraste 5.8:1) |
| `--line` | `#E4DED1` | Divisórias e bordas sobre claro |

**Cores de estado (semânticas) — sempre com par fundo-claro / tinta-escura para contraste:**

| Estado | Fundo | Tinta | Uso |
| --- | --- | --- | --- |
| Atenção | `#FBF1DE` | `#8A5A12` | Indícios, prazos, itens que pedem olhar |
| Rotina/OK | `#E7F0E9` | `#1E5233` | Tudo em ordem, concluído |
| Risco/Urgente | `#F7E9E9` | `#8A2F2F` | Alertas sérios, sensível |
| Estratégico | `#E8EEF6` | `#254A72` | Contexto de longo prazo |

Regra: **nunca** usar cor de estado como texto colorido sobre fundo escuro. Sempre o par acima (fundo claro + tinta escura), que garante leitura.

---

## 2. Tipografia

| Papel | Fonte | Uso |
| --- | --- | --- |
| Display | **Georgia** (serifa) | Títulos de tela, nomes de seção, o wordmark. Transmite instituição, permanência (a etimologia de Évora). Usada com restrição — só títulos. |
| Corpo | **system-ui** (-apple-system, Segoe UI, Roboto) | Todo o texto de leitura e interface. Neutra, altíssima legibilidade em qualquer tela. |
| Dados/mono | **ui-monospace** (Consolas, Menlo) | Números de protocolo, valores, códigos, trilha de auditoria. |

**Escala (px):** 26 título de tela · 19 subtítulo · 16 título de card · 14.5 corpo · 12.5 secundário · 11 eyebrow/rótulo. Pesos: 700 títulos, 600 ênfase, 400 corpo. Eyebrows em CAIXA ALTA com `letter-spacing: .14em`.

---

## 3. Layout mestre (todas as telas herdam)

```
┌────────────┬──────────────────────────────────────────────┐
│            │  TOPO: migalhas · busca (texto) · 🎙 voz · Bia │
│  BARRA     ├──────────────────────────────────────────────┤
│  LATERAL   │                                              │
│  (fixa,    │   ÁREA DE TRABALHO                            │
│  integrada)│   (conteúdo da tela, clicável em camadas)     │
│            │                                              │
│  agrupada  │                                              │
│  por bloco │                                              │
│            │                                              │
│  [☰ no     │                                              │
│  celular]  │                                              │
└────────────┴──────────────────────────────────────────────┘
```

- **Barra lateral fixa e integrada** (250px no desktop): agrupada por bloco (Ativo/Genesis · Novo · Próximas fases · Configuração). Cada item = ícone + rótulo + selo de status. No celular, colapsa em botão ☰.
- **Item da barra — interação-assinatura:** ao passar o mouse, o **ícone cresce como uma lupa** (`transform: scale(1.18)`, transição 130ms) para indicar que está selecionável; o item ativo ganha barra dourada à esquerda e fundo levemente dourado. Isso é o gesto característico do Évora — discreto, mas inconfundível.
- **Topo:** migalhas (Início › Seção › Assunto, sempre clicáveis) · campo de **busca por texto** · botão de **voz** 🎙 · indicador da **Bia**.
- **Área de trabalho:** o conteúdo abre em camadas (resumo → detalhe → fonte), nunca joga o usuário para fora do sistema.

---

## 4. Componentes-padrão

| Componente | Regra |
| --- | --- |
| **Item de navegação** | ícone + rótulo + selo; hover = ícone-lupa (scale 1.18); ativo = barra dourada + fundo dourado 14% |
| **Card de assunto** | fundo navy translúcido, borda dourada 28%; hover = borda dourada cheia + leve elevação; clicável |
| **Folha de conteúdo** | fundo `--paper`, borda dourada 2px; cabeçalho navy; corpo em `--ink`; sempre com origem do dado no rodapé |
| **Flag de estado** | pílula com par fundo-claro/tinta-escura da tabela de estados; texto ≤ 2 palavras |
| **Tabela** | linhas zebradas (`#FFFFFF` / `#F6F3EC`); cabeçalho navy com texto branco; números em fonte mono |
| **Botão primário** | gradiente dourado (`#C2A45F`→`#8F7740`), texto `#20130A`, peso 800 |
| **Botão secundário** | contorno em `--line`, fundo `--paper`, texto `--navy`; hover inverte para navy |
| **Campo de busca** | fundo translúcido, borda dourada 40%; foco = contorno dourado 2px |
| **Migalhas** | dourado clicável + item atual em branco; separador `›` |
| **Toast** | navy com borda dourada, centralizado embaixo, some em ~3s |

---

## 5. Movimento (comedido — para não parecer IA)

- Hover do ícone-lupa: `transform` 130ms ease.
- Card hover: elevação sutil 150ms.
- Trocas de camada: sem animação chamativa (fade rápido no máximo).
- `prefers-reduced-motion: reduce` → todas as transições desligadas.
- **Nada** de partículas, gradientes animados, brilhos. Discrição é a estética.

---

## 6. Sigilo e discrição na interface (padrão ouro)

- **Sem vazamento em preview:** título da aba do navegador é neutro ("Évora"), nunca o assunto sensível. Notificações não mostram conteúdo N4/N5.
- **Conteúdo sensível** só renderiza após autenticação de nível; antes, mostra placeholder neutro ("conteúdo protegido"), nunca uma prévia.
- **Origem sempre visível, conteúdo sempre mínimo:** cada dado mostra sua fonte, mas a tela expõe só o necessário para a tarefa.
- **Trilha discreta:** ações ficam registradas na auditoria, mas a UI não "exibe vigilância" ao usuário comum — discrição, não ostentação.

---

## 7. Acessibilidade e piso de qualidade

- Contraste AA mínimo em tudo (medir).
- Foco de teclado visível (contorno dourado) em todo elemento interativo.
- Navegável 100% por teclado; Esc sempre volta uma camada.
- Responsivo até 360px (celular — a Tatiane viaja).
- Todo ícone tem rótulo textual (nunca ícone sozinho sem significado acessível).

---

## 8. Acesso por texto e voz (universal)

- **Busca por texto** (topo): digitar "fiscalização", "radar", "voltar", "imprimir" navega direto — busca em toda a árvore do sistema.
- **Voz** (🎙 ou "Bia, ..."): mesmos comandos por fala (pt-BR). "Bia, abrir demandas" · "Bia, pesquise sobre a LDO" · "voltar" · "início".
- Todo destino alcançável por clique também é alcançável por texto e por voz — sem exceção.
