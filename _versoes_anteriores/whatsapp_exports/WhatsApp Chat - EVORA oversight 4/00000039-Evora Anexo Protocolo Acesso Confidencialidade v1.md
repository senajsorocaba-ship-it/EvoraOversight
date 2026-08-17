# Anexo — Protocolo de Acesso e Confidencialidade (PAC)

> **Para o Manual Supremo (série v10).** Rascunho a validar com o fundador antes de integrar.
> Define **quem vê o quê, como se prova quem viu, e como se mostra o sistema a terceiros sem
> abrir a porta**. Nasce de uma decisão de arquitetura: o Évora é **SaaS web** — o código vive
> no servidor e o cliente só recebe telas. Não existe instalação, não existe cópia local,
> não existe binário para piratear. A proteção, portanto, não é "chave de instalação"
> (modelo Office): é **controle de acesso, rastreabilidade e prova**.
>
> Conecta-se a: Classificação de Dados N1–N5 (Anexo 4) · Matriz de Alçada (Anexo 5) ·
> Anexo de Segurança, Backup e Recuperação · SISEC · Aegis · AAS-Évora (Auditoria Soberana).
> Legenda: 🟢 MVP (liga agora) · 🟠 ao subir a servidor · 🔵 V1.5/V2.
>
> Versão 1 · 15/07/2026.

---

> **Em resumo:** Ninguém não-identificado olha uma tela do Évora. Cada tenant cadastra as
> **Y pessoas nomeadas** que podem entrar; cada pessoa entra com **dois fatores**; tudo que se vê
> fica **registrado em trilha imutável**; toda tela carrega a **marca d'água nominal** de quem está
> olhando; e para mostrar o sistema a um terceiro existe a **Sessão de Apresentação** — um acesso
> que nasce com hora para morrer (até 120 min, configurável) e se apaga sozinho.

---

## 1. O princípio: identidade antes da tela

Regra única, sem exceção: **nenhuma tela do Évora é exibida a uma pessoa não identificada.**

- O acesso é **cadastrado por tenant**: o sistema é do cliente X, para uso de **Y pessoas nomeadas**
  (a autoridade + a equipe que ela designar). Não existe "login genérico do gabinete".
- **Papel não é pessoa** (Anexo 5): as permissões ligam-se ao papel (chefe de gabinete, jurídico,
  mídia, demandas); a pessoa é vinculada e desvinculada sem reescrever nada. Saiu da equipe,
  perdeu o acesso **no ato** — e a trilha guarda tudo que ela viu enquanto esteve dentro.
- Cada pessoa vê **só o que o papel dela alcança** (alçada), e só dentro do **mundo** dela
  (gabinete/campanha) — o isolamento por RLS garante isso no banco, não só na tela.

---

## 2. O mapa ameaça → defesa

Cada medo real do cliente tem uma defesa nomeada. É este quadro que se apresenta quando
perguntarem "o sistema é seguro?".

| # | Ameaça (o medo) | Defesa | Estado |
|---|---|---|---|
| 1 | "Pegam meu celular/laptop aberto e leem" | **Trava por inatividade**: a tela borra e exige reautenticação após N minutos (configurável por tenant). | 🟠 |
| 2 | "Tiram print ou foto da tela e vazam" | **Marca d'água nominal dinâmica**: nome + documento de quem está logado, sobrepostos sutilmente em toda tela. Foto vazada = autor identificado. | 🟠 |
| 3 | "Roubam a senha de alguém da equipe" | **MFA (dois fatores)** obrigatório + **dispositivos autorizados**: aparelho novo só entra com aprovação do gestor do tenant. | 🟠 MFA · 🔵 dispositivos |
| 4 | "Um ex-assessor continua vendo" | **Papéis revogáveis** com efeito imediato + trilha do que viu. | 🟢 modelado |
| 5 | "Alguém da equipe bisbilhota o que não é da alçada" | **Alçada por papel + RLS**: a tela e o banco negam; a tentativa fica **registrada**. | 🟢 modelado |
| 6 | "Quero mostrar a um terceiro sem dar acesso" | **Sessão de Apresentação** (seção 3): acesso temporário que expira em até 120 min e se apaga. | 🟠 |
| 7 | "O próprio fornecedor lê meus segredos" | **Zero-Knowledge no cofre (Aegis)**: o Évora é custodiante técnico; não lê o conteúdo do cofre pessoal. | 🔵 |
| 8 | "Adulteram o registro de quem acessou" | **Trilha imutável (só INSERT)** + 🔵 **âncora externa** (seção 4): nem o criador altera o passado. | 🟢 trilha · 🔵 âncora |
| 9 | "Copiam o sistema / crackeiam" | **Não há o que copiar**: o código nunca sai do servidor. A PI é protegida por contrato + INPI, não por chave de instalação. | 🟢 por arquitetura |
| 10 | "Concorrente vê a demo e clona a ideia" | Demo mostra **resultado** (o briefing), nunca a arquitetura; Sessão de Apresentação com marca d'água do convidado; contrato de confidencialidade quando couber. | 🟢 prática vigente |

---

## 3. Sessão de Apresentação — mostrar sem abrir a porta

O recurso para demonstrações, visitas e curiosos legítimos. **Ninguém "dá uma olhadinha"
por cima do ombro: cria-se um convidado, com nome, prazo e lacre.**

**Como funciona:**
1. Um usuário com alçada de gestor cria o **convite**: nome do convidado + documento +
   duração (**5 a 120 minutos**, padrão 30 — configurável por tenant).
2. O sistema gera um **acesso temporário** (link/QR + código de uso único).
3. O convidado entra e vê **apenas o recorte de apresentação** definido pelo gestor
   (ex.: o briefing do dia) — nunca demandas de cidadãos (N4) ou dados sensíveis (N5).
4. **Toda tela** exibe a marca d'água com o **nome do convidado** — a foto que ele tirar
   carrega o nome dele.
5. No fim do prazo, a sessão **expira sozinha e trava tudo**; o acesso não é reutilizável.
6. Fica na trilha: quem convidou, quem entrou, o que foi visto, quando expirou.

**Regras pétreas da Sessão de Apresentação:**
- Nunca dá acesso a dado pessoal de cidadão (N4/N5) — só conteúdo de vitrine.
- Não pode ser prorrogada silenciosamente: prorrogar = novo convite, nova trilha.
- O convidado não navega fora do recorte definido.
- Vale também para o **próprio fundador** em prospecção: a demo a vereadores usa este
  mecanismo, nunca o sistema real do tenant.

---

## 4. A trilha que ninguém altera — e o uso honesto de blockchain

A base já existe no desenho: a tabela `auditoria` é **só INSERT** (imutável) e materializa o
Aegis no MVP; a **AAS-Évora** audita inclusive o criador.

**Evolução 🔵 (V2) — âncora externa:** periodicamente, o sistema calcula a **impressão digital
(hash)** do bloco de registros da trilha e a **ancora fora do Évora** (em blockchain pública ou
serviço de carimbo de tempo). Efeito: fica **matematicamente provado** que o registro de acessos
não foi adulterado depois do fato — **nem pelo dono do sistema**.

**Fronteira de honestidade (decisão de arquitetura):**
- **Blockchain NÃO guarda dado.** Blockchain é pública e replicada — o oposto de confidencial.
  Nenhum dado de gabinete, campanha ou cidadão entra em blockchain, nunca.
- O que se ancora é **só o hash** (a impressão digital), que não revela conteúdo.
- Frase correta para o cliente: *"o registro de quem acessou é lacrado num cartório digital
  que nem o criador do sistema consegue alterar"* — e nada além disso.

---

## 5. O que o protocolo NÃO adota (e por quê)

Registrado para não voltar ao assunto a cada conversa:

- **Chaves de instalação / anticópia estilo Office** — modelo errado para SaaS: não há
  instalação nem cópia local. A arquitetura já resolve o que a chave tentaria resolver.
- **Segurança por obscuridade** (ofuscar código, labirintos para "confundir hacker") —
  não é segurança: dá trabalho, protege pouco e cria falsa confiança. O que protege é
  acesso controlado, trilha, contrato e PI registrada.
- **Blockchain como banco de dados** — vide seção 4: seria o contrário de confidencial.
- **Paranoia uniforme** — segurança é proporcional ao risco (N1–N5). Travar tudo o tempo
  todo derruba a operação; o padrão ouro é forte onde importa, leve onde não.

---

## 6. Faseamento (o que liga quando)

| Fase | Entra |
|---|---|
| **🟢 Agora (modelado/vigente)** | RLS por tenant e mundo · papéis revogáveis · trilha só-INSERT · segredos em variável de ambiente · demo só de resultado. |
| **🟠 Ao subir a servidor (MVP no ar)** | MFA · trava por inatividade · **marca d'água nominal** · **Sessão de Apresentação** · dados na região São Paulo. |
| **🔵 V1.5 / V2** | Dispositivos autorizados · Zero-Knowledge pleno no Aegis · âncora externa da trilha (blockchain/carimbo) · SISEC automático · biometria (após DPIA — J9). |

---

## 7. A frase que resume (para a venda)

> *"Aqui, ninguém sem nome olha uma tela. Cada pessoa entra com dois fatores, vê só o que o
> papel dela permite, e tudo que vê fica registrado num livro que ninguém — nem nós — consegue
> reescrever. E se você quiser mostrar a alguém, o sistema cria um convidado com hora marcada
> para nascer e para morrer, com o nome dele estampado na tela. Bisbilhotice aqui não tem porta."*
