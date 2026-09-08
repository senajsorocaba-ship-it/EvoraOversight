-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVORA OVERSIGHT — FARUS F1 · Radar e Acervo de Informação Verificada
-- Migração de fundação do acervo
-- ═══════════════════════════════════════════════════════════════════════════
--
-- O QUE ESTA MIGRAÇÃO RESOLVE
-- Hoje o coletor grava em arquivo local sobrescrito a cada execução. O acervo
-- que o Manual declara desde a v7.7 não existe no banco — cada briefing
-- recomeça do zero, não há pesquisa histórica e não há economia de escala
-- entre clientes da mesma cidade.
--
-- A EXCEÇÃO AO PADRÃO DE ISOLAMENTO — leia antes de mexer
-- Todas as 11 tabelas anteriores isolam por `tenant_id`. O FARUS **inverte**:
-- o acervo público é compartilhado por MUNICÍPIO, servindo todos os clientes
-- daquela cidade. É a primeira e única exceção do sistema.
--
-- A fronteira é o campo `origem_aquisicao`:
--   coleta_programada / descoberta_radar  → acervo público, compartilhável
--   interesse_tenant  / demanda_tenant    → contexto do tenant, NUNCA sai dele
--
-- Sem esse campo, a diferenciação de planos vira vazamento entre clientes.
--
-- ORDEM: rodar DEPOIS do schema, do RLS e do hook de token.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- ---------------------------------------------------------------------------
-- 0. MIGRAÇÃO HERDADA — correção do Freio Humano (v10.8)
-- ---------------------------------------------------------------------------
-- O briefing é entregue direto às 06:45. O registro é de CIÊNCIA, não de
-- aprovação prévia. Renomeação pendente desde a v10.8.

do $$
begin
  if exists (select 1 from information_schema.columns
             where table_name='briefings' and column_name='aprovado_por') then
    alter table briefings rename column aprovado_por to ciencia_por;
    alter table briefings rename column aprovado_em  to ciencia_em;
    raise notice 'Migração v10.8 aplicada: aprovado_por -> ciencia_por';
  else
    raise notice 'Migração v10.8 já estava aplicada';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1. TIPOS
-- ---------------------------------------------------------------------------

-- Estados do Ciclo de Vida da Informação (Manual, DA-0002).
-- Apenas 'confirmado' e 'corroborado' podem sustentar afirmação de briefing.
do $$ begin
  create type farus_estado as enum (
    'confirmado',      -- fonte primária ou evidência robusta
    'corroborado',     -- duas ou mais fontes independentes compatíveis
    'indicado',        -- fonte secundária ou parcial — pede confirmação
    'inferencia',      -- conclusão lógica — NUNCA apresentada como fato original
    'hipotese',        -- possibilidade não comprovada
    'conflitante',     -- fontes incompatíveis entre si
    'desatualizado',   -- foi verdadeiro; há evidência posterior
    'nao_verificado'   -- evidência insuficiente
  );
exception when duplicate_object then null; end $$;

-- De onde veio o registro. Define se pode ou não ser compartilhado.
do $$ begin
  create type farus_origem as enum (
    'coleta_programada',   -- rotina territorial      → compartilhável
    'descoberta_radar',    -- radar autônomo (F3)     → compartilhável
    'interesse_tenant',    -- disparado por interesse → NÃO compartilhável
    'demanda_tenant'       -- pesquisa sob demanda    → NÃO compartilhável
  );
exception when duplicate_object then null; end $$;

-- Natureza do material coletado.
do $$ begin
  create type farus_especie as enum (
    'ato_oficial',     -- Diário Oficial
    'contratacao',     -- PNCP
    'materia',         -- imprensa
    'norma',           -- legislação
    'documento'        -- outros
  );
exception when duplicate_object then null; end $$;

-- Ciclo de vida da fonte. Fonte descoberta pelo radar entra como 'observada'
-- e só sustenta afirmação após liberação humana (decisão D6, Anexo 16).
do $$ begin
  create type farus_estado_fonte as enum (
    'descoberta',   -- encontrada, ainda não avaliada
    'observada',    -- em monitoramento, NÃO sustenta afirmação
    'configurada',  -- liberada por pessoa, alimenta briefing
    'suspensa',     -- pausada
    'recusada'      -- avaliada e rejeitada
  );
exception when duplicate_object then null; end $$;

-- Nível do plano contratado (E12).
do $$ begin
  create type evora_plano as enum ('municipal','estadual','nacional');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- 2. PLANO DO TENANT
-- ---------------------------------------------------------------------------
-- Gravado desde já, com todos em 'municipal'. Evita migração no dia do
-- faturamento — o campo custa nada agora e é caro de acrescentar depois.

alter table tenants add column if not exists plano evora_plano not null default 'municipal';

comment on column tenants.plano is
'Nível contratado. Define o alcance territorial do radar. Todo nível contém o inferior.';

-- ---------------------------------------------------------------------------
-- 3. TERRITÓRIOS
-- ---------------------------------------------------------------------------
-- O acervo é compartilhado por município. Esta tabela é a chave do
-- compartilhamento e da economia de escala.

create table if not exists farus_territorios (
  id            uuid primary key default gen_random_uuid(),
  codigo_ibge   integer unique,                 -- nulo quando cadastrado à mão
  municipio     text        not null,
  uf            char(2)     not null,
  regiao_imediata text,
  ativo         boolean     not null default true,
  criado_em     timestamptz not null default now(),
  constraint farus_territorio_uf_valida check (uf ~ '^[A-Z]{2}$')
);

create unique index if not exists ix_farus_territorio_municipio
  on farus_territorios (lower(municipio), uf);

comment on table farus_territorios is
'Municípios sob monitoramento. Cada um é coletado UMA VEZ e serve todos os tenants daquela cidade.';

-- Quais territórios cada tenant acompanha.
create table if not exists farus_tenant_territorios (
  tenant_id     uuid not null references tenants(id) on delete cascade,
  territorio_id uuid not null references farus_territorios(id) on delete restrict,
  principal     boolean not null default false,   -- o município-sede
  incluido_em   timestamptz not null default now(),
  incluido_por  text,
  primary key (tenant_id, territorio_id)
);

comment on table farus_tenant_territorios is
'Vínculo tenant x território. Determina qual acervo compartilhado cada cliente enxerga.';

-- ---------------------------------------------------------------------------
-- 4. FONTES
-- ---------------------------------------------------------------------------

create table if not exists farus_fontes (
  id            uuid primary key default gen_random_uuid(),
  territorio_id uuid not null references farus_territorios(id) on delete restrict,
  nome          text not null,
  especie       farus_especie not null,
  url           text,
  nivel         text,                        -- F1 registrada / F2 reconhecida
  estado        farus_estado_fonte not null default 'descoberta',
  cnpj          text,
  cnae          text,
  evidencia_cobertura text,                  -- exigida para F2
  descoberta_por text,                       -- 'radar' ou identificação humana
  liberada_por  text,                        -- quem promoveu a 'configurada'
  liberada_em   timestamptz,
  ultima_coleta timestamptz,
  criado_em     timestamptz not null default now(),

  -- TRAVA: só vira 'configurada' com registro de quem liberou.
  -- É a decisão D6 do Anexo 16 imposta pelo banco, não pelo programa.
  constraint farus_fonte_liberacao_humana check (
    estado <> 'configurada' or (liberada_por is not null and liberada_em is not null)
  )
);

create index if not exists ix_farus_fontes_territorio on farus_fontes (territorio_id, estado);

comment on constraint farus_fonte_liberacao_humana on farus_fontes is
'Decisão D6: nenhuma fonte alimenta afirmação sem liberação humana registrada. Trava no banco.';

-- ---------------------------------------------------------------------------
-- 5. O ACERVO
-- ---------------------------------------------------------------------------

create table if not exists farus_itens (
  id             uuid primary key default gen_random_uuid(),

  -- Compartilhamento
  territorio_id  uuid not null references farus_territorios(id) on delete restrict,
  origem_aquisicao farus_origem not null,
  tenant_origem  uuid references tenants(id) on delete cascade,  -- só p/ não compartilhável

  -- Procedência
  fonte_id       uuid references farus_fontes(id) on delete set null,
  especie        farus_especie not null,
  url            text,
  titulo         text not null,
  conteudo       text,
  publicado_em   date,
  capturado_em   timestamptz not null default now(),

  -- Verificação
  estado         farus_estado not null default 'nao_verificado',
  verificado_por text,
  verificado_em  timestamptz,

  -- Deduplicação
  hash_conteudo  bytea not null,

  -- Retenção indeterminada para acervo público verificado (decisão 20/07/2026)
  retencao_indeterminada boolean not null default true,

  criado_em      timestamptz not null default now(),

  -- TRAVA 1: registro compartilhável NÃO pode ter dono; registro de tenant DEVE ter.
  -- É o que impede acervo de um cliente vazar para outro pela camada compartilhada.
  constraint farus_item_origem_coerente check (
    (origem_aquisicao in ('coleta_programada','descoberta_radar') and tenant_origem is null)
    or
    (origem_aquisicao in ('interesse_tenant','demanda_tenant') and tenant_origem is not null)
  ),

  -- TRAVA 2: só sustenta afirmação o que foi verificado por alguém.
  constraint farus_item_verificacao_registrada check (
    estado not in ('confirmado','corroborado')
    or (verificado_por is not null and verificado_em is not null)
  )
);

-- Deduplicação: mesma matéria republicada não entra duas vezes no mesmo território.
create unique index if not exists ix_farus_itens_dedup
  on farus_itens (territorio_id, hash_conteudo);

create index if not exists ix_farus_itens_busca
  on farus_itens (territorio_id, especie, publicado_em desc);

create index if not exists ix_farus_itens_tenant
  on farus_itens (tenant_origem) where tenant_origem is not null;

comment on constraint farus_item_origem_coerente on farus_itens is
'Fronteira do compartilhamento: acervo público não tem dono; pesquisa de tenant nunca é compartilhada.';

comment on column farus_itens.hash_conteudo is
'sha256 de titulo||conteudo normalizados. Base da deduplicação por território.';

-- ---------------------------------------------------------------------------
-- 6. FUNÇÃO DE HASH — regra única de deduplicação
-- ---------------------------------------------------------------------------
-- Centralizada para que coletor e banco nunca divirjam. Normaliza espaços,
-- caixa e acentuação antes de calcular.

create extension if not exists pgcrypto;

-- Normalização de acentos por tabela fixa, e não por `unaccent`.
--
-- POR QUE NÃO USAR unaccent: aquela função é STABLE, não IMMUTABLE, porque
-- depende de um dicionário que pode ser alterado. Marcar como IMMUTABLE uma
-- função que chama STABLE é aceito pelo PostgreSQL — e corrompe qualquer índice
-- construído sobre ela, silenciosamente. `translate` é IMMUTABLE de verdade.
create or replace function farus_hash(p_titulo text, p_conteudo text)
returns bytea
language sql
immutable
as $$
  select digest(
    regexp_replace(
      translate(
        lower(coalesce(p_titulo,'') || ' ' || coalesce(p_conteudo,'')),
        'áàâãäéèêëíìîïóòôõöúùûüçñ',
        'aaaaaeeeeiiiiooooouuuucn'
      ),
      '\s+', ' ', 'g'
    ),
    'sha256'
  );
$$;

comment on function farus_hash(text,text) is
'Regra única de deduplicação. Coletor e banco devem usar esta função — nunca calcular hash à parte.';

-- ---------------------------------------------------------------------------
-- 7. RETENÇÃO — o acervo público não é apagado
-- ---------------------------------------------------------------------------
-- Decisão do fundador de 20/07/2026: acervo público verificado tem retenção
-- indeterminada. A trava impede exclusão acidental por rotina futura.

create or replace function farus_impedir_exclusao_acervo()
returns trigger
language plpgsql
as $$
begin
  if old.retencao_indeterminada
     and old.origem_aquisicao in ('coleta_programada','descoberta_radar') then
    raise exception
      'Acervo público com retenção indeterminada não pode ser excluído (item %). '
      'Para remover, desmarque retencao_indeterminada com justificativa registrada.',
      old.id;
  end if;
  return old;
end $$;

drop trigger if exists trg_farus_retencao on farus_itens;
create trigger trg_farus_retencao
  before delete on farus_itens
  for each row execute function farus_impedir_exclusao_acervo();

-- ---------------------------------------------------------------------------
-- 8. ISOLAMENTO — a exceção controlada
-- ---------------------------------------------------------------------------

alter table farus_territorios        enable row level security;
alter table farus_territorios        force  row level security;
alter table farus_tenant_territorios enable row level security;
alter table farus_tenant_territorios force  row level security;
alter table farus_fontes             enable row level security;
alter table farus_fontes             force  row level security;
alter table farus_itens              enable row level security;
alter table farus_itens              force  row level security;

-- Territórios que o tenant da sessão acompanha.
create or replace function farus_territorios_do_tenant()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select tt.territorio_id
  from farus_tenant_territorios tt
  where tt.tenant_id = evora_tenant_atual();
$$;

-- ─── Territórios ───
drop policy if exists farus_territorios_leitura on farus_territorios;
create policy farus_territorios_leitura on farus_territorios
  for select to authenticated
  using (id in (select farus_territorios_do_tenant()));

-- ─── Vínculo tenant x território ───
drop policy if exists farus_tt_isolamento on farus_tenant_territorios;
create policy farus_tt_isolamento on farus_tenant_territorios
  for all to authenticated
  using (tenant_id = evora_tenant_atual())
  with check (tenant_id = evora_tenant_atual());

-- ─── Fontes ───
drop policy if exists farus_fontes_leitura on farus_fontes;
create policy farus_fontes_leitura on farus_fontes
  for select to authenticated
  using (territorio_id in (select farus_territorios_do_tenant()));

-- ─── O ACERVO — a política mais delicada do sistema ───
--
-- Duas condições cumulativas:
--   1. o território precisa ser um dos que o tenant acompanha; E
--   2. o item precisa ser público OU pertencer ao próprio tenant.
--
-- A segunda condição é o que impede um cliente de ver a pesquisa que outro
-- cliente da mesma cidade mandou fazer.
drop policy if exists farus_itens_leitura on farus_itens;
create policy farus_itens_leitura on farus_itens
  for select to authenticated
  using (
    territorio_id in (select farus_territorios_do_tenant())
    and (
      tenant_origem is null                    -- acervo público
      or tenant_origem = evora_tenant_atual()  -- pesquisa do próprio tenant
    )
  );

-- Escrita de acervo é do motor (service_role), não da aplicação.
-- Nenhuma política de INSERT/UPDATE/DELETE para 'authenticated': o banco nega.

comment on policy farus_itens_leitura on farus_itens is
'Exceção controlada ao isolamento: compartilha por município, mas nunca o contexto de outro tenant.';

-- ---------------------------------------------------------------------------
-- 9. PERMISSÕES
-- ---------------------------------------------------------------------------

grant select on farus_territorios, farus_fontes, farus_itens to authenticated;
grant select, insert, delete on farus_tenant_territorios to authenticated;
revoke all on farus_territorios, farus_fontes, farus_itens, farus_tenant_territorios from anon;

commit;

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICAÇÃO — rode depois da migração
-- ═══════════════════════════════════════════════════════════════════════════
--
--  select count(*) from information_schema.tables
--   where table_name like 'farus%';                          -- esperado: 4
--
--  select count(*) from pg_policies where tablename like 'farus%';  -- esperado: 4
--
--  select relname, relrowsecurity, relforcerowsecurity
--   from pg_class where relname like 'farus%';               -- todas true/true
--
-- Teste de isolamento: ver evora_farus_teste_aceite.sql
-- ═══════════════════════════════════════════════════════════════════════════
