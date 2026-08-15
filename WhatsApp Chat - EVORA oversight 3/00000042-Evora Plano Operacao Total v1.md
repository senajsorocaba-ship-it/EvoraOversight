# Évora Oversight — Plano de Operação Total (v1)

> **Para quê este documento.** Responder, sem enrolação, à pergunta do Gustavo — *"quando isso
> funciona de verdade, a pleno vapor?"* — com **cronograma real, custo real e a lista do que falta**.
> Escrito com honestidade de engenheiro: onde é estimativa, está dito; onde depende de terceiro
> (jurídico, você executando), está apontado. Dono: Luiz Gonzaga Filho · 16/07/2026.

---

## 1. Primeiro, alinhar o que é "pleno vapor"

"Funcionar a pleno vapor" tem **três níveis diferentes** — e confundi-los é o que gera ansiedade e promessa exagerada. Sejamos precisos:

| Nível | O que significa | Realista quando |
|---|---|---|
| **N1 — Núcleo Fundador útil** | A Tatiane recebe o **briefing diário real** e o gabinete registra demandas no sistema. Um mandato usa de verdade. | **Semanas** (o mais próximo) |
| **N2 — SaaS vendável** | Multi-tenant no ar, com login, segurança do PAC, e você consegue **implantar num segundo gabinete** sem retrabalho. | **1–3 meses** após N1 |
| **N3 — Plataforma completa** | Campanha (Nil), Sentinela, Cidadão, todos os 26 agentes, cadeia com validação. | **Muitos meses / faseado** |

> **A resposta honesta ao Gustavo:** o que ele viu vira **uso real (N1) em semanas** — não meses — *se* o banco subir e o parecer da Dra. Íria sair. O "tudo funcionando" (N3) é longo e não precisa estar pronto para o produto ser útil e vendável. **Vende-se o N2, entrega-se valor no N1.** Ninguém espera o N3 para começar.

---

## 2. Onde estamos hoje (sem maquiagem)

**Funciona de verdade:**
- O motor do briefing roda e gera briefing real com dados de Sorocaba (provado).
- O coletor de imprensa puxa as fontes locais; o render gera o HTML on-brand.
- O caráter travado funciona (diz "sem dado" em vez de inventar).

**Está desenhado mas não ligado:**
- Banco (schema + RLS prontos; **não está no Supabase ainda**).
- Telas (maquetes navegáveis; **não ligadas a banco**).
- Segurança do PAC (especificada; **não implementada**).

**Só existe no papel:**
- Registro de Sessão (o pedido de hoje — ver seção 5).
- 23 dos 26 agentes (fichas prontas; instrução de trabalho só o AIM-g).
- Campanha (Nil), Sentinela, Cidadão.

> **Tradução:** o coração bate. Falta o corpo (banco + telas + login) para virar um app que um cliente usa sozinho. **O gargalo não é ideia nem código — é subir a infraestrutura e destravar o jurídico.**

---

## 3. Cronograma físico (por marcos, não por datas cravadas)

Você é **um desenvolvedor**, aprendendo, com o Claude Code. Prometer datas de equipe seria desonesto. O cronograma abaixo é em **marcos encadeados**; a velocidade depende de quantas horas/semana você dedica e de quando a Íria responde.

### Fase A — Núcleo Fundador no ar (meta: N1)

| # | Marco | Depende de | Esforço |
|---|---|---|---|
| A1 | Coletor de imprensa rodando no seu laptop | nada | 1 sessão |
| A2 | Briefing completo gerado pela Bia (com chave API) | crédito Anthropic | 1 sessão |
| A3 | Banco no Supabase (São Paulo) + RLS + teste de separação | conta Supabase | 1–2 sessões |
| A4 | Login + papéis (auth do Supabase) | A3 | 2–3 sessões |
| A5 | **1ª tela ligada ao banco** (Briefing OU Demandas) | A3, A4 | 3–5 sessões |
| A6 | Parecer Íria J1/J2 (base legal + termo LGPD) | **advogada** | externo |

> **Fim da Fase A = N1:** a Tatiane usa o briefing e o gabinete registra demandas **legalmente** (A6 destrava o dado real de cidadão). Sem A6, opera só com o que não é dado pessoal (briefing de fontes públicas já vale).

### Fase B — SaaS vendável (meta: N2)

Segurança do PAC (MFA, marca d'água, Sessão de Apresentação) · onboarding de um 2º tenant sem retrabalho · Supabase Pro (backup automático) · domínio próprio · contrato pronto (Íria). **Ao fim da Fase B, você vende e implanta num gabinete novo.**

### Fase C+ — Profundidade (rumo ao N3)

Mais agentes conforme a fase (AFEx-g fiscalização completa, ADC-g, Agenda, Registro de Sessão), depois Campanha (Nil) e Sentinela. **Faseado — nunca tudo de uma vez.**

---

## 4. Financeiro real (estrutura de custo, ordem de grandeza)

Valores são **ordem de grandeza a confirmar na contratação** (planos e câmbio mudam). O que importa é a **estrutura**: o Évora é barato de rodar, e a margem é alta.

### Custo mensal para rodar (fixo)

| Item | Para que | Ordem de grandeza |
|---|---|---|
| Supabase Pro | Banco + backup diário + PITR | ~US$ 25 (~R$ 140) |
| Vercel | Publicar o app (Hobby grátis no início; Pro no comercial) | US$ 0–20 (~R$ 0–110) |
| Domínio | endereço próprio (.com.br) | ~R$ 40–200/ano (≈ R$ 5–15/mês) |
| **Subtotal fixo** | | **~R$ 150–270/mês** |

### Custo variável (por uso da IA)

| Item | Direção | Ordem de grandeza |
|---|---|---|
| API Anthropic — briefing diário | ~centavos por briefing; 30/mês | ~US$ 2–10/mês por tenant |
| API — demais agentes/uso | cresce com módulos ativos | ~US$ 5–30/mês por tenant (fase madura) |
| Transcrição de sessão (módulo novo) | ~US$ 0,006/min; sessão 3h ≈ US$ 1 | ~US$ 4–12/mês por tenant |

### Custos únicos

INPI (marcas): ~R$ 142–355 por classe por marca (GRU) — já em curso. · Eventual hardware do Nível 2 físico (só se um cliente premium exigir "da tomada") — sob demanda, custeado pelo cliente.

### O número que importa

- **Rodar o MVP para a Tatiane (1 tenant):** ordem de **R$ 300–500/mês** tudo somado.
- **Rodar 5 tenants:** a infra é compartilhada; só o uso de IA multiplica → ordem de **R$ 600–1.100/mês total**.
- **Se cobrar R$ 500–2.000/mês por gabinete**, o custo por tenant (~R$ 120–220) deixa **margem alta** — é um SaaS saudável já com poucos clientes.

> **Conclusão financeira:** o projeto **não precisa de captação para operar** o Núcleo Fundador. Ele se paga com 1–2 clientes. Captação (o Q3 do manual) é para **acelerar**, não para **existir**.

---

## 5. Módulo Registro de Sessão — o caso de hoje (ponto 4)

**Primeiro, a verdade, para você não se expor:** hoje o Évora **ainda não grava as sessões**. Quando você disse à equipe *"temos isso garantido no Évora"*, você falou do **plano** — é uma função **desenhável e viável**, mas **ainda não construída**. Melhor alinhar com a Maria Alice: *"está no sistema como função a ativar; enquanto ligamos, vamos ter um protocolo manual à prova de falha."* Prometer que já existe e falhar de novo faria o oposto do que você quer.

### O caminho completo da função (como vai funcionar)

1. **Captura redundante** — a fonte é a transmissão da **TV Legislativa** (as sessões, mesmo bloqueadas no YouTube por causa da regra eleitoral, são transmitidas). Duas capturas simultâneas e independentes (a "segunda estrada" do ponto 2): se uma falha, a outra segue e o sistema **avisa** que a captura 1 caiu. **Nunca mais depender de celular com bateria.**
2. **Armazenamento** — o arquivo vai para o acervo interno do tenant (storage do Supabase/nuvem Brasil), **fulltime, disponível só dentro do Évora** (não público — respeita a regra eleitoral de não superexposição).
3. **Transcrição automática** — o áudio vira texto com marcação de tempo (quem falou, quando).
4. **Indexação e busca** — a Bia indexa por **fala, autor e ato**, de modo que a assessora digita *"o que a vereadora falou sobre cultura na sessão de 07/07"* e recebe **o trecho e o minuto exato**. Aqueles 3 minutos que faltaram seriam achados em segundos.
5. **Cortes sob demanda** — gerar o clipe do trecho exato (com marca d'água, respeitando o PAC).

### As duas travas jurídicas (não pular)

- **Direito autoral da transmissão (J4 do doc jurídico):** as transmissões oficiais têm titularidade; a Tatiane, como vereadora, tem direito de acesso ao conteúdo das próprias sessões, mas **arquivar e derivar** precisa de aval da Dra. Íria. É uso **interno**, o que ajuda.
- **Regra eleitoral:** exatamente por isso o acervo é **interno e privado** — nada vai a público no período vedado. O Évora aqui **protege** a candidata (guarda sem expor).

### O paliativo imediato (esta semana, sem código)

Enquanto o módulo não sobe, um protocolo simples elimina a dor:
- **Um aparelho dedicado** (um celular antigo ou gravador) **na tomada**, só para gravar a sessão inteira, sem depender de bateria.
- **Backup redundante:** um segundo aparelho grava em paralelo.
- **Rotina fixa:** alguém da equipe confere no início da sessão que os dois estão gravando.
- Ao fim, o arquivo sobe para uma pasta única (Drive do gabinete) — fonte única, achável.

> Isto resolve a Maria Alice **hoje** e vira o **teste real** do módulo quando ele existir. É honesto e é padrão ouro: paliativo humano confiável antes da automação.

---

## 6. Redundância / failover — onde a "segunda estrada" vale (ponto 2)

Sua intuição está certa, **em pontos específicos** — redundar tudo seria caro e lento; redundar o crítico é sabedoria. Onde vale a estrada dupla que avisa:

| Ponto crítico | Estrada 1 | Estrada 2 (failover) | Avisa? |
|---|---|---|---|
| Cérebro de IA | API Anthropic (Claude) | provedor de fallback | sim, loga e alerta |
| Coleta de fontes | fonte responde | segue com as demais, marca a lacuna | sim (já faz) |
| Dados do gabinete | banco ativo | backup + PITR (volta no tempo) | sim, em incidente |
| **Gravação de sessão** | captura 1 | captura 2 simultânea | **sim — o caso de hoje** |

> **Onde NÃO redundar:** telas, relatórios, coisas recriáveis. Redundância custa; aplica-se onde a perda é irreversível (dado, prova, gravação única de um ato que não se repete).

---

## 7. Finalização das funções dos agentes (roadmap honesto)

Você quer fechar as funções dos 26. O certo **não** é escrever os 26 agora — é escrever a instrução completa **de cada um quando a fase dele entra**, para não trabalhar no vácuo (decisões mudam). Ordem:

1. **AIM-g** — feito (Anexo 12, o molde).
2. **AFEx-g — Fiscalização do Executivo** — próximo: limiares e linguagem de indício são críticos e já há dado (PNCP).
3. **ADC-g — Demandas Cidadãs** — depende do parecer LGPD (Íria), mas a instrução pode adiantar.
4. **AAG-g — Agenda** e o **Registro de Sessão** — alto valor de uso diário.
5. Demais do Gabinete (Bia) conforme uso.
6. **Nil e os 9 de Campanha** — bloco sazonal; instrução quando a campanha for ativada.
7. Governança (AAS-Évora, AMA-Évora, AIP) e Sentinela — fases avançadas.

> Cada agente segue o molde de 14 seções do Anexo 12. **Fechar "a função" de um agente = escrever essa instrução** — e isso a gente faz um a um, rápido, quando cada um vai rodar.

---

## 8. A lista-mãe: o que falta para o SaaS funcional

Checklist única, priorizada. **Tudo que trava o N2 (vendável) está no topo.**

**Bloqueia o produto (fazer primeiro):**
- [ ] Banco no Supabase (São Paulo) + RLS + teste de separação.
- [ ] Login + papéis (auth).
- [ ] 1ª tela ligada ao banco (Briefing ou Demandas).
- [ ] Parecer Íria J1/J2 (base legal + termo LGPD) — **externo, cobrar**.
- [ ] Segurança do PAC mínima: MFA + marca d'água + Sessão de Apresentação.
- [ ] Supabase Pro (backup automático) + Git/GitHub (ponto de retorno).

**Necessário para vender com confiança:**
- [ ] Contrato SaaS (Íria) + preço definido com os primeiros clientes.
- [ ] Onboarding de um 2º tenant sem retrabalho (prova do multi-tenant).
- [ ] Demo de venda pronta (Sessão de Apresentação com o briefing real).
- [ ] Domínio próprio.

**Aumenta o valor (depois):**
- [ ] Módulo Registro de Sessão (gravação + transcrição + busca).
- [ ] AFEx-g fiscalização completa (PNCP + limiares).
- [ ] Agenda, Ata & Seguimentos, Preparação de Sessão ligados.
- [ ] Instruções de trabalho dos demais agentes (uma a uma).

**Perene / governança:**
- [ ] Consolidação editorial do Manual.
- [ ] INPI concluído. · [ ] CTO co-founder (maior risco do roadmap).

---

## 9. Operação de apresentação, venda e implantação (ponto 5)

Como funciona na prática, do primeiro contato ao gabinete rodando.

### Etapa 1 — Apresentação (fazer o cliente sentir)

- **O que mostrar:** o **briefing real da pessoa** — o dele, com o que saiu sobre ele esta semana, fonte em cada linha. Concreto, sobre ele, hoje.
- **O que NÃO mostrar:** a arquitetura (dashboard dos dois mundos, organogramas) — revela o motor.
- **Como mostrar com segurança:** pela **Sessão de Apresentação** do PAC — você cria um convidado com o nome do vereador, prazo de 30–120 min, marca d'água no nome dele na tela. Ele vê, sente que é sério, e o acesso **expira sozinho**. Isso já é parte da venda: *"repare que nem para te mostrar eu deixo uma porta aberta."*
- **A frase de segurança** (do PAC): *"aqui ninguém sem nome olha uma tela… bisbilhotice não tem porta."*

### Etapa 2 — Venda (o que fechar)

- **Modelo:** assinatura mensal, contrato de 12 meses.
- **Preço:** faixa **R$ 500–2.000/mês por gabinete** conforme módulos (validar com os 3–5 primeiros; a Tatiane é referência fundadora, provavelmente simbólica).
- **Contrato:** confidencialidade + PI sua + LGPD (controlador/operador) + foro — **redigido pela Íria**, não improvisado.
- **O diferencial que fecha:** isolamento **vereador × vereador** ("seus dados e seus eleitores nunca encostam no gabinete de outro") + o briefing diário que faz o vereador "chegar na frente".

### Etapa 3 — Implantação (onboarding de um gabinete)

Passo a passo repetível — o que torna o N2 real:
1. **Criar o tenant** (linha em `tenants`, nível de separação lógico padrão).
2. **Cadastrar as pessoas nomeadas** e seus papéis (chefe de gabinete, mídia, jurídico, demandas).
3. **Montar o perfil** do mandato (nome e variações, temas-bandeira, fontes locais, foco) — como o `perfil_tatiane.json`.
4. **Ligar as fontes** da cidade dele (jornais locais, Diário Oficial, Câmara).
5. **Primeiro briefing de teste** → ajustar tom e relevância com o cliente.
6. **Termo LGPD** assinado antes de qualquer dado de cidadão.
7. **Treinar a equipe** (30 min: como ler o briefing, registrar demanda, criar Sessão de Apresentação).
8. **Go-live** + rotina de acompanhamento (o VRX Runbook).

> Cada gabinete novo repete estes 8 passos. Quando isso roda liso, você tem uma **operação de implantação** — e o Évora virou negócio, não projeto.

---

## 10. Resumo para o Gustavo (e para você dormir melhor)

- **Quando funciona de verdade?** Uso real (N1) em **semanas**; vendável (N2) em **1–3 meses** depois; a plataforma inteira (N3) é longa e **não precisa estar pronta para começar a vender**.
- **O que trava?** Subir o banco + o parecer da Íria. Não é código, não é ideia.
- **Quanto custa rodar?** Ordem de **R$ 300–500/mês** para a Tatiane; margem alta ao cobrar por gabinete. **Não precisa de investidor para operar.**
- **A gravação de sessão?** Ainda não existe — **paliativo manual esta semana**, módulo depois. Não prometa que já roda.
- **Pressa?** Sim, com foco: **Núcleo Fundador primeiro**. A pressa que mata é querer o N3 antes do N1.
