-- =====================================================================
-- ÉVORA OVERSIGHT — SEGURANÇA DE ISOLAMENTO (RLS)
-- Arquivo: evora_rls_mvp_v1.sql
-- Versão:  v1.0 · 20/07/2026 · alinhado ao Manual Supremo v10.6
-- =====================================================================
--
-- Este arquivo é O CORAÇÃO DA SEPARAÇÃO. Ele traduz em regra de banco
-- dois princípios invioláveis do Manual:
--
--   · ISOLAMENTO ENTRE TENANTS — nenhum gabinete vê dado de outro.
--     (É o diferencial de venda: "nem o vereador ao lado enxerga.")
--   · SEPARAÇÃO DE MUNDOS — gabinete e campanha não se cruzam.
--     (Princípio Inviolável nº 4; única passagem é a Ponte Bia↔Nil,
--      que acontece na aplicação e fica registrada em `auditoria`.)
--
-- COMO FUNCIONA
-- O Supabase entrega, em cada requisição autenticada, um JWT. A aplicação
-- deve gravar nesse token dois campos, dentro de `app_metadata`:
--     tenant_id : uuid do gabinete
--     mundo     : 'gabinete' ou 'campanha'
-- As funções abaixo leem esses campos. Sem eles, o acesso é negado —
-- falha fechada, que é o comportamento correto para segurança.
--
-- IMPORTANTE: a chave `service_role` do Supabase IGNORA o RLS por design.
-- Ela é para trabalhos internos (o motor do briefing, por exemplo) e
-- NUNCA deve ser exposta em navegador, aplicativo ou repositório público.
--
-- ORDEM: rodar depois de evora_schema_mvp_v1.sql.
-- =====================================================================

-- ---------------------------------------------------------------------
-- FUNÇÕES DE CONTEXTO — leem o JWT da requisição
-- ---------------------------------------------------------------------
create or replace function evora_claims()
returns jsonb language sql stable as $$
  -- Robusta a três situações reais: setting ausente, setting vazio ('')
  -- e JSON malformado. Em qualquer uma delas devolve NULL, e o RLS nega
  -- o acesso — falha fechada, que é o comportamento correto.
  select case
    when coalesce(nullif(current_setting('request.jwt.claims', true), ''), '') = '' then null
    else nullif(current_setting('request.jwt.claims', true), '')::jsonb
  end;
$$;

create or replace function evora_tenant_atual()
returns uuid language sql stable as $$
  select nullif(
    coalesce(
      evora_claims() -> 'app_metadata' ->> 'tenant_id',
      evora_claims() ->> 'tenant_id'
    ), ''
  )::uuid;
$$;

create or replace function evora_mundo_atual()
returns evora_mundo language sql stable as $$
  select nullif(
    coalesce(
      evora_claims() -> 'app_metadata' ->> 'mundo',
      evora_claims() ->> 'mundo'
    ), ''
  )::evora_mundo;
$$;

-- Papéis que legitimamente enxergam os dois mundos (autoridade e auditor).
create or replace function evora_ve_os_dois_mundos()
returns boolean language sql stable as $$
  select exists (
    select 1 from usuarios u
    where u.tenant_id = evora_tenant_atual()
      and u.ativo
      and u.mundo_permitido is null
      and u.papel in ('autoridade', 'auditor')
      and u.auth_user_id = nullif(evora_claims() ->> 'sub', '')::uuid
  );
$$;

comment on function evora_tenant_atual is 'Lê tenant_id do JWT. Sem token válido devolve NULL e o RLS nega tudo (falha fechada).';

-- ---------------------------------------------------------------------
-- LIGAR O RLS EM TODAS AS TABELAS
-- ---------------------------------------------------------------------
alter table tenants               enable row level security;
alter table usuarios              enable row level security;
alter table fontes                enable row level security;
alter table briefings             enable row level security;
alter table demandas              enable row level security;
alter table lugares               enable row level security;
alter table compromissos          enable row level security;
alter table atas                  enable row level security;
alter table desdobramentos        enable row level security;
alter table desdobramento_eventos enable row level security;
alter table auditoria             enable row level security;

-- Força o RLS inclusive para o dono das tabelas (defesa em profundidade)
alter table tenants               force row level security;
alter table usuarios              force row level security;
alter table fontes                force row level security;
alter table briefings             force row level security;
alter table demandas              force row level security;
alter table lugares               force row level security;
alter table compromissos          force row level security;
alter table atas                  force row level security;
alter table desdobramentos        force row level security;
alter table desdobramento_eventos force row level security;
alter table auditoria             force row level security;

-- ---------------------------------------------------------------------
-- GRANTS DE TABELA — obrigatório para a Data API (PostgREST) enxergar a
-- tabela, ANTES mesmo da RLS entrar em jogo.
--
-- Supabase parou de expor automaticamente tabelas novas do schema `public`
-- para as roles da Data API (anon/authenticated/service_role) sem GRANT
-- explícito — é o comportamento padrão atual, tanto local (CLI) quanto na
-- nuvem. Sem isto, toda chamada via PostgREST devolve "permission denied
-- for table X" (código 42501) mesmo com policy de RLS correta, porque o
-- Postgres nega no nível de privilégio da tabela antes de a RLS ser
-- avaliada. Detectado rodando este bloco contra o Supabase local de verdade
-- (supabase start) — não aparece testando só com `set role` no SQL Editor.
--
-- Princípio do menor privilégio na concessão de tabela (a RLS acima ainda
-- é quem decide QUAIS LINHAS, isto aqui só decide quais OPERAÇÕES a role
-- pode tentar): sem DELETE para `authenticated` em nenhuma tabela — o
-- Manual já estabelece "nada é deletado", soft delete via ativo/ativa.
-- `anon` não recebe nada — todo o produto exige login (Princípio de falha
-- fechada já documentado acima).
grant select, insert, update on usuarios, fontes, briefings, demandas,
  lugares, compromissos, atas, desdobramentos, desdobramento_eventos
  to authenticated;
grant select on tenants to authenticated;         -- só leitura do próprio; update é sempre 'false' na policy
grant select, insert on auditoria to authenticated;  -- imutável: sem update/delete de propósito (ver seção 11)

-- service_role ignora RLS por design (ver nota no topo deste arquivo) — o
-- motor do briefing e outros jobs de servidor precisam de acesso irrestrito
-- às 11 tabelas, então aqui a concessão é total, não por operação.
grant all privileges on all tables in schema public to service_role;

-- ---------------------------------------------------------------------
-- 1. TENANTS — cada um enxerga apenas o próprio registro
-- ---------------------------------------------------------------------
drop policy if exists tenants_isolamento on tenants;
create policy tenants_isolamento on tenants
  for select using (id = evora_tenant_atual());

drop policy if exists tenants_sem_escrita_pelo_cliente on tenants;
create policy tenants_sem_escrita_pelo_cliente on tenants
  for update using (id = evora_tenant_atual() and false);
  -- criação e alteração de tenant são operação administrativa (service_role)

-- ---------------------------------------------------------------------
-- 2. USUARIOS — isolado por tenant
-- ---------------------------------------------------------------------
drop policy if exists usuarios_isolamento on usuarios;
create policy usuarios_isolamento on usuarios
  for all using (tenant_id = evora_tenant_atual())
          with check (tenant_id = evora_tenant_atual());

-- ---------------------------------------------------------------------
-- 3 a 10. CONTEÚDO — isolado por tenant E por mundo
--
-- Regra: a linha aparece se for do meu tenant E (for do meu mundo OU eu
-- for autoridade/auditor, que legitimamente veem os dois).
-- ---------------------------------------------------------------------

drop policy if exists fontes_isolamento on fontes;
create policy fontes_isolamento on fontes
  for all using (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  ) with check (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  );

drop policy if exists briefings_isolamento on briefings;
create policy briefings_isolamento on briefings
  for all using (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  ) with check (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  );

drop policy if exists demandas_isolamento on demandas;
create policy demandas_isolamento on demandas
  for all using (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  ) with check (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  );

-- lugares não tem mundo (endereço é endereço): isola só por tenant
drop policy if exists lugares_isolamento on lugares;
create policy lugares_isolamento on lugares
  for all using (tenant_id = evora_tenant_atual())
          with check (tenant_id = evora_tenant_atual());

drop policy if exists compromissos_isolamento on compromissos;
create policy compromissos_isolamento on compromissos
  for all using (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  ) with check (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  );

drop policy if exists atas_isolamento on atas;
create policy atas_isolamento on atas
  for all using (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  ) with check (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  );

drop policy if exists desdobramentos_isolamento on desdobramentos;
create policy desdobramentos_isolamento on desdobramentos
  for all using (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  ) with check (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  );

drop policy if exists desdob_eventos_isolamento on desdobramento_eventos;
create policy desdob_eventos_isolamento on desdobramento_eventos
  for all using (tenant_id = evora_tenant_atual())
          with check (tenant_id = evora_tenant_atual());

-- ---------------------------------------------------------------------
-- 11. AUDITORIA — leitura restrita, escrita só INSERT, nunca alteração
-- ---------------------------------------------------------------------
drop policy if exists auditoria_leitura on auditoria;
create policy auditoria_leitura on auditoria
  for select using (
    tenant_id = evora_tenant_atual() and evora_ve_os_dois_mundos()
  );  -- só autoridade e auditor leem a trilha

drop policy if exists auditoria_insercao on auditoria;
create policy auditoria_insercao on auditoria
  for insert with check (tenant_id = evora_tenant_atual());

-- Não existe policy de UPDATE nem de DELETE para auditoria: sem policy,
-- a operação é negada pelo RLS. Somado ao trigger do schema, são duas
-- camadas independentes garantindo a imutabilidade da trilha.

-- ---------------------------------------------------------------------
-- 12. FREIO HUMANO (v10.8) — só quem tem alcada_aprovacao dá ciência,
-- só de si mesmo, timestamp sempre do servidor.
--
-- A policy briefings_isolamento (seção 3) já libera UPDATE em qualquer
-- coluna para qualquer usuário do tenant+mundo — inclusive ciencia_por.
-- Sozinha, ela deixaria um assessor sem alçada preencher ciencia_por com
-- o PRÓPRIO id (autoaprovação) ou pior, com o id de outra pessoa. Esta
-- trigger fecha essa lacuna: usa evora_claims() (definida acima nesta
-- mesma seção de contexto) para exigir que quem está autenticado agora
-- SEJA o usuário referenciado em ciencia_por, com alcada_aprovacao=true
-- e ativo no mesmo tenant. Fica em BLOCO 2 (não no schema, BLOCO 1)
-- porque depende de evora_claims(), que só existe a partir daqui.
-- ---------------------------------------------------------------------
create or replace function evora_valida_ciencia_briefing()
returns trigger language plpgsql as $$
declare
  v_ok boolean;
begin
  if new.ciencia_por is distinct from old.ciencia_por then
    if new.ciencia_por is null then
      new.ciencia_em := null;  -- "desfazer" ciência (ex.: clique errado) — a ação em si fica na auditoria da aplicação
    else
      select exists (
        select 1 from usuarios u
        where u.id = new.ciencia_por
          and u.tenant_id = new.tenant_id
          and u.alcada_aprovacao
          and u.ativo
          and u.auth_user_id = nullif(evora_claims() ->> 'sub', '')::uuid
      ) into v_ok;
      if not v_ok then
        raise exception 'ciencia_por precisa ser o proprio usuario autenticado, com alcada_aprovacao e ativo no tenant (freio humano, Manual v10.8).';
      end if;
      new.ciencia_em := now();
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_briefings_ciencia on briefings;
create trigger trg_briefings_ciencia
  before update on briefings
  for each row execute function evora_valida_ciencia_briefing();

-- =====================================================================
-- TESTE DE ACEITE — a prova que vira argumento de venda
-- =====================================================================
-- Rode com dados fictícios e confirme:
--
--   1. Dois tenants, cada um com uma fonte. Autenticado como tenant A,
--      a fonte do tenant B NÃO aparece.               → isolamento entre clientes
--   2. Um tenant, duas fontes (uma 'gabinete', uma 'campanha').
--      Com mundo='campanha' no token, a fonte do gabinete NÃO aparece.
--                                                      → separação de mundos
--   3. Tentar UPDATE em `auditoria` → erro.            → trilha imutável
--   4. Requisição sem tenant_id no token → nada aparece. → falha fechada
--
-- Se os quatro passarem, o coração do multi-tenant está de pé.
-- =====================================================================
