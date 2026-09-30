# Roteiro de Deploy — Évora Oversight

> Passo a passo pra colocar o projeto no ar (Supabase + Vercel + GitHub Actions).
> Ordem importa — siga na sequência. Cada bloco tem uma verificação no final;
> não avance pro próximo bloco sem confirmar a verificação do anterior.
>
> Estado no momento em que este roteiro foi escrito: 17 migrations prontas,
> nada rodado contra Supabase na nuvem ainda, `origin/main` 1 commit atrás do
> local. Beta — sem cliente real ainda, período de testes.

---

## Antes de começar — o que você precisa ter em mãos

- [ ] Conta no [supabase.com](https://supabase.com) com o projeto já criado na nuvem
      (ref esperado: `zdweqfxskvcyhckrplux` — confirme em Project Settings → General
      → Reference ID, pode ter mudado)
- [ ] Conta na [vercel.com](https://vercel.com), com acesso ao repositório no GitHub
- [ ] Acesso admin ao repositório no GitHub (`Settings` → `Secrets and variables`)
- [ ] Uma chave real da Anthropic (`console.anthropic.com` → API Keys → Create Key)
- [ ] `.env` da raiz aberto ao lado — é o mapa de qual chave vai em qual lugar
      (não é lido por nada, só documentação)

---

## PARTE A — Supabase (banco na nuvem)

### A1 · Login da CLI

```bash
supabase login
```

Abre o navegador, autentica. Se preferir sem interação: gere um token pessoal em
`supabase.com/dashboard/account/tokens` → "Generate new token" (começa com `sbp_`)
e exporte `SUPABASE_ACCESS_TOKEN` na sessão do terminal antes de rodar os comandos
abaixo.

### A2 · Linkar o projeto local ao projeto da nuvem

```bash
supabase link --project-ref zdweqfxskvcyhckrplux
```

Vai pedir a senha do banco (a que você definiu ao criar o projeto — Project
Settings → Database → Database password; se esqueceu, reset ali mesmo).

### A3 · Aplicar as migrations

```bash
supabase db push
```

Aplica as 17 migrations em `supabase/migrations/` na ordem (schema, RLS, motor,
auth, atlas, vigia de vereadores, FARUS, Aegis, travessia de mundo, rename do
hook, trava de Demandas, rate limit, Veritas, Inteligência Legislativa/Resposta/
Parecer). Cada migration roda em transação — se uma falhar, ela reverte sozinha
e te mostra a linha exata do erro. **Se algo falhar, me cola o erro aqui antes
de tentar de novo.**

**Verificação A3** — no SQL Editor do dashboard (ou via `psql`):

```sql
select count(*) from information_schema.tables where table_schema = 'public';
-- esperado: 39
select count(*) from pg_policies where schemaname = 'public';
-- esperado: bem mais que 17 (cada tabela isolada tem sua policy) — não se assuste
-- com o número, só confirme que não é zero
```

### A4 · Ativar o hook do token (BLOQUEADOR — não pule)

Sem isso, todo JWT nasce sem `tenant_id`/`mundo`, e a RLS nega tudo pra todo
mundo — o produto abre e não mostra nada.

1. Dashboard → **Authentication** → **Hooks**
2. Em **Customize Access Token (JWT) Claims hook**, clique **Enable**
3. Selecione a função **`public.evora_token_hook`**
4. Salve

**Verificação A4** — depois de qualquer login real (pode ser o seu, depois da
Parte B), rode logado:

```sql
select evora_tenant_atual() as tenant, evora_mundo_atual() as mundo;
```

Se vier `NULL` nas duas colunas, o hook não está ativo ou o e-mail que logou
não tem uma linha ativa em `usuarios`.

### A5 · Confirmação de e-mail — decisão rápida

Dashboard → **Authentication** → **Providers** → **Email** → toggle **Confirm
email**.

- **Beta sem cliente real (seu caso agora)**: deixe **desligado** — evita
  precisar configurar SMTP só pra testar. Login funciona na hora do cadastro.
- **Quando for pra cliente de verdade**: ligue, e configure SMTP em
  Authentication → Settings → SMTP Settings antes.

### A6 · URL Configuration — volta depois da Parte B

Dashboard → **Authentication** → **URL Configuration**:
- **Site URL** = o domínio real do Vercel (você só vai ter isso depois da
  Parte B — volte aqui depois)
- **Redirect URLs** = adicione o mesmo domínio (com `/**` no fim, se o campo
  aceitar wildcard)

Marque este passo como pendente e siga pra Parte B; volte aqui no fim.

### A7 · Provisionar o primeiro gabinete real

Não existe tela de "criar conta" genérica — só `/cadastro`, que é **específica
pra vereador(a)** (exige o e-mail já estar numa lista verificada de vereadores
do município). Duas rotas, dependendo de quem é a primeira pessoa:

**Se for vereador(a) de verdade** (rota recomendada — usa o fluxo real):

1. Cadastre o município e o vereador real (nome + e-mail institucional
   verificado) via o CLI do Atlas:
   ```bash
   cd ao-SUPABASE-BLOCO1
   python evora_atlas_municipal.py vereadores adicionar --municipio "Sorocaba" --uf SP \
     --nome "Nome Real" --email "email@camarasorocaba.sp.gov.br"
   ```
   (rode contra a nuvem — `.env` local precisa apontar `SUPABASE_URL`/
   `SUPABASE_SERVICE_ROLE_KEY` pro projeto da nuvem nesse momento, não o local)
2. A pessoa acessa `/cadastro` no domínio publicado, informa o e-mail — o
   sistema verifica contra `municipio_vereadores`, cria o tenant e o usuário
   sozinho (`evora_autocadastro_vereador`), e ela define senha ali mesmo.

**Se não for vereador (ex.: você mesmo testando primeiro)** — provisionamento
manual, via SQL Editor do dashboard:

1. Crie o tenant:
   ```sql
   insert into tenants (slug, nome_autoridade, cargo, municipio_sede, uf,
                        nivel_separacao, perfil, ciencia_travas, operacional)
   values ('seu-slug-aqui', 'Nome Real', 'cargo real', 'Sorocaba', 'SP',
           'logico', '{}'::jsonb, true, true)
   returning id;
   -- guarde o id retornado
   ```
2. Dashboard → **Authentication** → **Users** → **Add user** → crie com e-mail
   real (marque "Auto Confirm User" se A5 estiver desligado, ou envie convite)
3. Vincule esse usuário ao tenant:
   ```sql
   insert into usuarios (tenant_id, auth_user_id, nome, email, papel,
                         mundo_permitido, alcada_aprovacao, ativo)
   values ('<id do tenant do passo 1>', '<id do auth.users do passo 2>',
           'Nome Real', 'email@real.com', 'autoridade', null, true, true);
   ```
4. Login normal em `/login` com o e-mail e a senha definidos no passo 2.

**Verificação A7** — login funciona, `/briefing` carrega sem erro (mesmo que
vazio, sem 401/403), e a query de A4 devolve o `tenant`/`mundo` certos.

---

## PARTE B — Vercel (front-end)

### B1 · Importar o projeto

1. vercel.com → **Add New** → **Project** → selecione o repositório no GitHub
2. **Root Directory**: clique em "Edit" e defina **`web`** (crítico — o
   repositório é um monorepo, sem isso o build falha procurando `package.json`
   na raiz errada)
3. Framework Preset: Next.js (detecta sozinho)

### B2 · Variáveis de ambiente

Em **Environment Variables**, adicione (Production, e Preview se quiser
testar branches):

| Nome | Valor | Onde achar |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | `https://zdweqfxskvcyhckrplux.supabase.co` | Project Settings → API → Project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | — | Project Settings → API → Project API keys → `anon`/`public` |
| `ANTHROPIC_API_KEY` | — | console.anthropic.com → API Keys |

### B3 · Deploy

Clique **Deploy**. Acompanhe o log de build — se falhar, a causa mais comum
nesse projeto é `Root Directory` errado (passo B1) ou uma env var faltando.

### B4 · Pegar o domínio e voltar pro Supabase

Depois do deploy, copie o domínio (`seu-projeto.vercel.app` ou o customizado).
**Volte pra Parte A6** e preencha Site URL + Redirect URLs com esse domínio.

**Verificação B4** — abra o domínio, deve cair em `/login` (redirect
automático — confirma que o `proxy.ts` está protegendo rota). Tente logar com
a conta criada em A7.

---

## PARTE C — GitHub Actions (agendador do briefing)

### C1 · Cadastrar os secrets

GitHub → repositório → **Settings** → **Secrets and variables** → **Actions**
→ **New repository secret**, 3 vezes:

| Nome | Mesmo valor de |
|---|---|
| `SUPABASE_URL` | `NEXT_PUBLIC_SUPABASE_URL` (sem o `NEXT_PUBLIC_`) |
| `SUPABASE_SERVICE_ROLE_KEY` | Project Settings → API → `service_role` (secret — **nunca** a mesma da `anon`) |
| `ANTHROPIC_API_KEY` | mesma chave da Parte B |

### C2 · Rodar manualmente pra validar

Aba **Actions** → workflow **"Briefing diário"** → **Run workflow** (botão à
direita, existe porque o workflow tem `workflow_dispatch`).

Acompanhe os 5 passos no log:
1. `evora_coletor_mencoes.py` — deve rodar sem erro
2. `evora_coletor_farus.py` — idem
3. `evora_coletor_pncp_farus.py` — **vai pular** (skip, não erro) até alguém
   liberar uma `farus_fontes` pra `especie='contratacao'` — comportamento
   esperado (Decisão D6), ver Parte E abaixo
4. `evora_conector_agenda_legislativa.py` — mesma coisa, `especie='ato_oficial'`
5. `evora_motor_execucao.py` — gera o briefing de verdade, grava em `briefings`

**Verificação C2** — depois de rodar, confira no dashboard:
```sql
select tenant_id, data_referencia, gerado_em from briefings
order by gerado_em desc limit 5;
```
Deve ter uma linha nova. Abra `/briefing` no site — o conteúdo deve aparecer.

O cron automático roda `30 8 * * *` (05:30 América/São Paulo) todo dia — não
precisa mexer em nada pra isso continuar rodando sozinho depois de hoje.

---

## PARTE D — Checklist final de verificação

- [ ] `select count(*) from information_schema.tables where table_schema='public'` = 39
- [ ] Hook ativo, `evora_tenant_atual()` devolve valor real numa sessão logada
- [ ] Login em `/login` funciona com a conta provisionada
- [ ] `/briefing` mostra conteúdo real depois do C2
- [ ] Bia (ícone de voz) responde a uma pergunta — confirma `ANTHROPIC_API_KEY`
      funcionando no servidor da Vercel
- [ ] Cabeçalhos de segurança presentes: `curl -I https://seu-dominio` deve
      trazer `x-frame-options: DENY`, `strict-transport-security: ...`

---

## PARTE E — Opcional, não bloqueia o "está no ar"

**Liberar fontes reais do FARUS** (PNCP + Câmara Sem Papel), usando
`Evora_Catalogo_Fontes.md` como referência — sem isso os coletores 3 e 4 do
workflow continuam pulando (não é erro, só fica sem esse dado extra até
alguém liberar):

```sql
insert into farus_fontes (territorio_id, nome, especie, url, estado,
                          liberada_por, liberada_em)
values (
  (select id from farus_territorios where municipio ilike 'Sorocaba'),
  'PNCP — Sorocaba', 'contratacao', 'https://pncp.gov.br',
  'configurada', 'Seu Nome', now()
);
-- repita para especie='ato_oficial' com a URL da Câmara Sem Papel
```

Isso é uma decisão humana deliberada (Decisão D6) — nunca faça isso em lote
sem checar o Catálogo primeiro.

---

*Roteiro escrito com o estado do repositório em 21/09/2026. Se migrations
novas entrarem depois, o número "39 tabelas"/"17 migrations" acima fica
desatualizado — confira `ls supabase/migrations/*.sql | wc -l` antes de
confiar cegamente neste documento.*
