-- =====================================================================
-- ÉVORA OVERSIGHT — AUTENTICAÇÃO (vínculo Supabase Auth <-> usuarios)
-- Arquivo: evora_auth_mvp_v1.sql
-- Versão:  v1.0 · Fase 1 do plano de testes (pós Manual v10.8)
-- =====================================================================
--
-- Este arquivo fecha o elo que faltava para o RLS (BLOCO 2) funcionar com
-- gente de verdade, não só com set_config manual no SQL Editor:
--
--   · usuarios.auth_user_id (já existe no schema, BLOCO 1) precisa ser
--     preenchido quando a pessoa cria conta no Supabase Auth;
--   · o JWT que o Supabase emite precisa trazer, dentro de app_metadata,
--     os campos tenant_id e mundo que evora_tenant_atual()/evora_mundo_atual()
--     (BLOCO 2) já sabem ler — sem isso, falha fechada nega tudo, e esse é
--     o comportamento correto.
--
-- MODELO DE PROVISIONAMENTO ADOTADO NESTA VERSÃO:
--   1. Alguém com a service_role key cria a linha em `usuarios` PRIMEIRO
--      (tenant_id, nome, email, papel, mundo_permitido, alcada_aprovacao).
--      Isso é "convidar" a pessoa — sem essa linha, login não dá acesso a
--      nada, mesmo que a conta no Supabase Auth já exista.
--   2. A pessoa cria a conta no Supabase Auth (e-mail/senha, ou o admin
--      cria por ela pelo painel) com O MESMO e-mail. O trigger abaixo
--      (evora_vincular_auth_user) casa por e-mail e preenche
--      usuarios.auth_user_id automaticamente.
--   3. A cada login/refresh de token, o hook abaixo (custom_access_token_hook)
--      lê usuarios por auth_user_id e injeta tenant_id/mundo no JWT.
--
-- LIMITAÇÃO CONHECIDA (documentada, não resolvida aqui de propósito): um
-- e-mail só pode estar vinculado a UM auth_user_id no Supabase Auth (é
-- global, não por tenant). Se uma mesma pessoa precisar acessar dois
-- gabinetes diferentes, este BLOCO sozinho não resolve — precisa de uma
-- decisão de arquitetura do dono do projeto (ex.: e-mails distintos por
-- tenant, ou um seletor de tenant na aplicação apoiado em outra tabela).
--
-- ORDEM: rodar depois do BLOCO 1 (schema) e do BLOCO 2 (RLS). Não depende
-- do BLOCO 3 (teste de aceite da RLS) nem do BLOCO 4 (motor do briefing).
--
-- PASSO MANUAL FORA DO SQL EDITOR (obrigatório — ver BLOCO_5_AUTENTICACAO.md):
-- depois de rodar este arquivo, ainda é preciso ir em Authentication > Hooks
-- no painel do Supabase e ativar o hook "Custom Access Token (Postgres)"
-- apontando para a função custom_access_token_hook criada aqui. Sem esse
-- passo no painel, a função existe mas o Supabase Auth nunca a chama.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. VÍNCULO auth.users -> usuarios (por e-mail, no momento do signup)
-- ---------------------------------------------------------------------
create or replace function evora_vincular_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.usuarios
     set auth_user_id = new.id
   where auth_user_id is null
     and ativo
     and lower(email) = lower(new.email);
  return new;
end;
$$;

comment on function evora_vincular_auth_user is
  'Ao criar conta no Supabase Auth, vincula usuarios.auth_user_id por e-mail — só se a linha em usuarios já existia (provisionada antes) e ainda não tinha vínculo. Sem linha prévia, o login não dá acesso a nada.';

drop trigger if exists evora_on_auth_user_created on auth.users;
create trigger evora_on_auth_user_created
  after insert on auth.users
  for each row execute function evora_vincular_auth_user();

-- ---------------------------------------------------------------------
-- 2. CUSTOM ACCESS TOKEN HOOK — injeta tenant_id/mundo em TODO JWT emitido
-- ---------------------------------------------------------------------
-- Roda a cada login e a cada refresh de token (não só no signup), então
-- reflete ativo/tenant_id/mundo_permitido atualizados sem exigir logout.
create or replace function custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  claims jsonb;
  u record;
begin
  claims := coalesce(event->'claims', '{}'::jsonb);

  select tenant_id, mundo_permitido
    into u
    from public.usuarios
   where auth_user_id = (event->>'user_id')::uuid
     and ativo
   limit 1;

  if u.tenant_id is not null then
    claims := jsonb_set(
      claims, '{app_metadata}',
      coalesce(claims->'app_metadata', '{}'::jsonb)
        || jsonb_build_object('tenant_id', u.tenant_id, 'mundo', u.mundo_permitido)
    );
  end if;
  -- Se não achou usuário ativo vinculado: claims sai sem tenant_id/mundo.
  -- evora_tenant_atual() lê NULL e o RLS nega tudo — falha fechada, de propósito.

  return jsonb_set(event, '{claims}', claims);
end;
$$;

comment on function custom_access_token_hook is
  'Hook de Auth do Supabase (ativar em Authentication > Hooks no painel — ver BLOCO_5_AUTENTICACAO.md). Injeta tenant_id/mundo no app_metadata do JWT a partir de usuarios, a cada emissão de token.';

-- Só o serviço de Auth do Supabase pode chamar o hook — nunca client-side.
revoke execute on function custom_access_token_hook(jsonb) from public, anon, authenticated;
grant execute on function custom_access_token_hook(jsonb) to supabase_auth_admin;

-- O trigger e o hook leem/escrevem usuarios como SECURITY DEFINER (dono do
-- banco, que ignora até o FORCE ROW LEVEL SECURITY) de propósito: nenhum
-- dos dois pode depender de o chamador já ter tenant_id no token, porque
-- é justamente isso que eles estão calculando.

-- =====================================================================
-- TESTE DE ACEITE MANUAL (não é rollback automático como o BLOCO 3 —
-- este envolve o serviço de Auth, que fica fora do SQL puro). Passo a
-- passo completo em BLOCO_5_AUTENTICACAO.md.
-- =====================================================================
