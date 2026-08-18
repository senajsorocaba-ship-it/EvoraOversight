# BLOCO 5 — Autenticação (Fase 1 do plano de testes)

**Pré-requisitos:** BLOCO 1 (schema) e BLOCO 2 (RLS) já rodados no seu projeto Supabase.
Não depende do BLOCO 3 nem do BLOCO 4.

Este bloco tem **duas partes**: SQL (cole e rode) + **um passo manual no painel do
Supabase** que o SQL Editor não faz por você. Sem o passo manual, nada funciona.

---

## Parte 1 — SQL Editor

Abra `evora auth mvp v1.sql` (nesta mesma pasta), copie o arquivo inteiro e cole no SQL
Editor do Supabase. Não duplicamos o SQL aqui para não ter duas fontes da verdade do
mesmo script — igual ao padrão já usado pelos BLOCOs 2/3/4.

**Esperado:** duas funções criadas (`evora_vincular_auth_user`, `custom_access_token_hook`)
e um trigger em `auth.users`. Sem erro em vermelho.

**Conferir depois de rodar:**
```sql
select proname from pg_proc where proname in ('evora_vincular_auth_user','custom_access_token_hook');
```
Deve devolver as duas linhas.

---

## Parte 2 — Painel do Supabase (passo manual, obrigatório)

O SQL cria a função, mas **só o painel ativa o hook** — o Supabase Auth não chama
funções de hook sozinho.

1. Vá em **Authentication → Hooks** (às vezes aparece como "Auth Hooks").
2. Em **Custom Access Token**, escolha **Postgres function** e selecione
   `custom_access_token_hook`.
3. Salve. Não precisa reiniciar nada — vale a partir do próximo login/refresh de token.

Se essa tela não existir na sua versão do painel: procure em
**Project Settings → Auth → Hooks**, o nome muda entre versões do Supabase, mas a função
é sempre "Custom Access Token Hook (Postgres)".

---

## Parte 3 — Teste de aceite manual (fazer uma vez, com dado fictício)

Diferente do BLOCO 3, este teste não é um script com `ROLLBACK` automático — ele
envolve o serviço de Auth, que é externo ao SQL puro. Faça manualmente:

1. **Provisione um tenant e um usuário de teste** (via SQL Editor, com a service_role
   implícita do editor):
   ```sql
   insert into tenants (id, slug, nome_autoridade, cargo, municipio_sede, uf)
   values ('11111111-1111-1111-1111-111111111111', 'teste-fase1', 'Teste Fase 1', 'vereador(a)', 'Sorocaba', 'SP')
   on conflict (id) do nothing;

   insert into usuarios (tenant_id, email, nome, papel, mundo_permitido, alcada_aprovacao)
   values ('11111111-1111-1111-1111-111111111111', 'teste.fase1@example.com', 'Teste Fase 1',
           'autoridade', null, true);
   ```
2. **Crie a conta correspondente no Supabase Auth** com o mesmo e-mail — caminho mais
   rápido para teste manual: **Authentication → Users → Add user** (marque
   "Auto Confirm User"), e-mail `teste.fase1@example.com`, senha qualquer.
3. **Confira o vínculo automático:**
   ```sql
   select auth_user_id from usuarios where email = 'teste.fase1@example.com';
   ```
   Deve vir preenchido (não `null`) — prova que o trigger `evora_on_auth_user_created` rodou.
4. **Faça login de verdade** (fora do SQL Editor) contra a API do Supabase, por exemplo:
   ```bash
   curl -s -X POST 'https://SEU-PROJETO.supabase.co/auth/v1/token?grant_type=password' \
     -H "apikey: SUA_ANON_KEY" -H "Content-Type: application/json" \
     -d '{"email":"teste.fase1@example.com","password":"SENHA_QUE_VOCE_DEFINIU"}'
   ```
5. **Decodifique o `access_token`** retornado (é um JWT — cole em jwt.io ou
   `echo "$TOKEN" | cut -d. -f2 | base64 -d`) e confirme que `app_metadata` contém:
   ```json
   {"tenant_id": "11111111-1111-1111-1111-111111111111", "mundo": null}
   ```
   Isso prova que o hook rodou e a Fase 1 está de pé: da próxima vez que esse token for
   usado numa chamada PostgREST, `evora_tenant_atual()` vai ler `11111111-...` em vez de
   `NULL`, e o RLS do BLOCO 2 passa a deixar esse usuário ver os dados do próprio tenant.
6. **Limpeza:** apague o usuário de teste em Authentication → Users, e rode
   `delete from usuarios where email='teste.fase1@example.com'; delete from tenants where id='11111111-1111-1111-1111-111111111111';`

Se o passo 5 mostrar `app_metadata` vazio: confira se a Parte 2 (ativar o hook no painel)
foi mesmo salva, e se o usuário de teste está com `ativo = true` em `usuarios`.

---

## O que este BLOCO não resolve (fica para as próximas fases)

- **Tela de login** — isto aqui é só o lado do banco. A Fase 4 (ligar o frontend ao
  Supabase) precisa de uma UI real chamando `supabase.auth.signInWithPassword(...)`
  em vez do `curl` acima.
- **Convite por e-mail / auto-signup público** — hoje o provisionamento em `usuarios` é
  manual (você roda o INSERT). Um fluxo de convite automatizado é uma decisão de
  produto separada, não faz parte da Fase 1.
- **Uma pessoa em dois tenants** — ver a limitação documentada no cabeçalho de
  `evora_auth_mvp_v1.sql`.
