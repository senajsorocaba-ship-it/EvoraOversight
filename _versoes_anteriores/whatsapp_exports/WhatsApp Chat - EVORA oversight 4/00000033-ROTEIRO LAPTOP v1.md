# ROTEIRO DE LAPTOP — Évora Oversight (v1)

> **Para o Claude Code.** Leia este arquivo primeiro. Ele é o mapa único da sessão:
> diz **o que fazer, em que ordem e por quê**. Os detalhes de cada etapa estão nos
> guias apontados abaixo — não precisa decorar, só seguir a ordem.
>
> Dono: **Luiz** (fundador, aprendendo a codar, no **Windows**). Fale português do Brasil,
> com franqueza técnica, explicando cada passo. **Nunca invente resultado.** Se algo
> falhar, diga que falhou — esse é o princípio nº 1 do projeto (Caráter Travado).

---

## O que é o Évora (contexto de 30 segundos)

Plataforma de **inteligência política legislativa** (SaaS multi-tenant). Cliente zero:
**Vereadora Tatiane Costa (PL · Sorocaba/SP)**. O sistema lê fontes públicas (jornais,
Diário Oficial, PNCP, pauta da Câmara) e entrega um **briefing diário** e módulos de
gestão. Duas gestoras de IA: **Bia** (mundo Gabinete) e **Nil** (mundo Campanha).

**Onde estão os arquivos** (duas pastas ao lado deste roteiro):
- `motor/` → o motor do briefing (Python, biblioteca padrão, sem instalar nada).
- `banco/` → o banco de dados (dois arquivos SQL para o Supabase).

---

## A ORDEM (siga assim — do resultado rápido à fundação)

| Etapa | O que entrega | Precisa de quê |
|------|----------------|----------------|
| **1** | Coleta de imprensa rodando no laptop (resultado visível hoje) | nada — só Python |
| **2** | Briefing completo, a Bia escrevendo de verdade | chave da API |
| **3** | Banco no Supabase (a fundação de dados) | conta Supabase |
| **4** | Primeira tela real ligada ao banco (vira app) | etapas 2 e 3 prontas |

A ordem é proposital: começa pelo que dá **prova rápida sem custo** (etapa 1),
depois liga o conteúdo (2), depois a fundação (3). Não pule para a 3 antes de
ver a 1 funcionar — é a forma mais rápida de confirmar que a máquina está ok.

---

## ETAPA 0 — Preparar (uma vez só, 2 min)

```powershell
# confirmar Python 3.10 ou superior
python --version
```
Se não houver Python, instale de python.org (marque **"Add to PATH"** no instalador).
**Não rode `pip install`** — o motor usa só a biblioteca padrão.

Entre na pasta do motor:
```powershell
cd caminho\para\motor
```

---

## ETAPA 1 — Coleta de imprensa (roda HOJE, sem chave, sem custo)

Isto prova que a coleta funciona na sua máquina. No laptop, a rede alcança o
Google News, então o coletor puxa as notícias de Sorocaba sozinho.

```powershell
python imprensa_coletor_evora.py
```

**Resultado esperado:** uma lista de notícias no terminal + o arquivo `noticias.json`
na pasta. Se algum dos 5 jornais vier parcial, é **esperado** no primeiro run —
relate ao Luiz quais responderam e quais não (não é erro crítico).

> ✅ **Marco 1:** você viu notícias reais de Sorocaba no terminal e o `noticias.json`
> foi criado. A coleta funciona. Pode seguir.

---

## ETAPA 2 — Briefing completo (a Bia escreve — precisa da chave)

Agora o passo em que a **Bia** (a IA) escreve o briefing a partir do que foi coletado.
Isso chama a API da Anthropic e **exige** a chave `ANTHROPIC_API_KEY`.

**Conseguir a chave (uma vez só):** siga a **Parte 1** do `motor/GUIA_Primeiro_Briefing.md`
(console.anthropic.com → Billing com um crédito pequeno → API Keys → Create Key `Evora-Briefing`).
Sem billing, a chave existe mas as chamadas falham (erro 402).

**Colar a chave no terminal (Windows / PowerShell):**
```powershell
$env:ANTHROPIC_API_KEY = "sk-ant-COLE-A-SUA-AQUI"
```
> Regras da chave: **nunca** grave em arquivo do projeto, nunca escreva em log,
> nunca repita de volta na conversa. Ela vive só nesta sessão de terminal.

**Rodar o pipeline completo:**
```powershell
python orquestrador_evora.py
```
O orquestrador roda na ordem: coletor de imprensa → coletor PNCP → **Bia escreve** →
render. É tolerante a falha: se uma fonte cai, ele registra em `avisos_evora.log` e
segue com o que tem (degrada avisando, nunca falha em silêncio).

**Resultado esperado:** um arquivo `briefing_AAAAMMDD.html` na pasta. Abra no navegador.

> ✅ **Marco 2:** o briefing do dia foi gerado pela Bia, em HTML, com dados reais.
> Esse é o produto de conteúdo funcionando na sua máquina.

**Se der erro:** `401` = chave errada/espaço extra ao colar (refaça o `$env:`).
`402` = falta crédito no console (Billing). Coletor sem resultado = não é crítico,
veja `avisos_evora.log`. (Detalhes em `motor/CLAUDE.md`, seção "Como lidar com erros".)

---

## ETAPA 3 — Banco no Supabase (a fundação de dados)

Até aqui o briefing de imprensa roda, mas os blocos de **Demandas, Radar e
Fiscalização** ficam "sem dado" — porque dependem do banco. Esta etapa liga a fundação.

Vá para a pasta do banco e **siga o guia dedicado** (ele tem o passo a passo do painel Supabase):
```
banco/CLAUDE_setup_banco.md
```

Resumo do que esse guia manda fazer (não pule a ordem):
1. Criar projeto no Supabase, **Region: South America (São Paulo)** — dados no Brasil (LGPD).
2. SQL Editor → rodar **primeiro** `banco/evora_schema_mvp_v1.sql` (cria as tabelas).
3. SQL Editor → rodar **depois** `banco/evora_rls_mvp_v1.sql` (as travas de isolamento).
4. Teste de separação com dados **fictícios**: provar que o mundo Campanha não vê
   dado do mundo Gabinete, e que um cliente não vê o de outro. **Esse teste é o
   argumento de venda.**

> ⚠️ **Trava LGPD (não quebrar):** não conectar **nenhum dado real de cidadão**
> até o parecer da Dra. Íria (perguntas 8 e 9, ainda pendentes). Teste só com dados fictícios.

> ✅ **Marco 3:** as 12 tabelas existem, o RLS está ativo, e o teste de separação
> passou com dados fictícios.

---

## ETAPA 4 — Primeira tela real (o que transforma maquete em app)

Com o banco no ar, o próximo tijolo é ligar **uma** tela de verdade às tabelas,
pela API do Supabase. **Não faça isso sozinho — pergunte ao Luiz por onde começar**
(sugestão: Briefing ou Demandas). É o passo que sai das maquetes HTML estáticas para
um app que lê e grava dados reais.

---

## Regras de conduta nesta sessão (valem em todas as etapas)

- **Honestidade acima de tudo.** Se uma fonte falhou ou um passo não funcionou, diga
  claramente. Não maquie resultado. "Não sei / sem dado" é uma resposta válida.
- **Pode corrigir bugs óbvios** (imports, typos, um `</div>` solto). Mas **mudança de
  comportamento** do pipeline ou da lógica de separação precisa de OK do Luiz antes.
- **Explique cada passo** em português, direto e técnico — o Luiz está aprendendo.
- **Windows:** use `$env:VAR = "..."` (PowerShell), não `export`. Caminhos com `\`.
- **Ao terminar cada etapa**, diga qual Marco foi atingido e o que ficou pendente.

---

## Checklist final (a sessão está "pronta" quando)

- [ ] **Marco 1** — `noticias.json` gerado; coleta de imprensa funcionando.
- [ ] **Marco 2** — `briefing_AAAAMMDD.html` gerado pela Bia com a chave.
- [ ] **Marco 3** — banco no Supabase (São Paulo): 12 tabelas + RLS + teste de separação ok.
- [ ] **Etapa 4** — alinhada com o Luiz qual tela ligar primeiro (não executar sem o OK dele).

> Quando os três Marcos estiverem verdes, o Évora deixou de ser maquete: tem coleta
> real, briefing real e fundação de dados real. A etapa 4 é o começo do app.
