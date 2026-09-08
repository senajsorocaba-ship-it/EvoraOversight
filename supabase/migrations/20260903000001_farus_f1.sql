-- Espelho INCREMENTAL gerado de: ao-SUPABASE-BLOCO1/AO SUPABASE BLOCO1.md.txt
-- (tipos + coluna tenants.plano + tabelas 19-22 + farus_hash + trigger de
-- retenção) + ao-SUPABASE-BLOCO1/evora rls mvp v1.sql (seção 16).
-- NAO EDITAR AQUI. Editar os arquivos canonicos acima e copiar de novo.
--
-- Fase 10 (Manual v10.9.1): FARUS — Acervo Territorial de Informação
-- Verificada, sucessor do "Veritas-Dados". Adaptado de `evora farus
-- f1.sql`/`evora aegis a0.sql` (entregues já testados 10/10, ver
-- `ao-SUPABASE-BLOCO1/evora farus teste aceite.sql`) pra conviver com as 18
-- tabelas já existentes deste repositório, em vez das 11 que o arquivo
-- entregue assumia. Sobreposição conhecida e não resolvida nesta fase com
-- achados_fiscalizacao/mencoes_imprensa/municipio_fontes — ver CLAUDE.md.

-- =====================================================================
-- BLOCO 1 — schema: tipos + coluna + tabelas 19-22 + função + trigger
-- =====================================================================

do $$ begin
  create type farus_estado as enum (
    'confirmado', 'corroborado', 'indicado', 'inferencia',
    'hipotese', 'conflitante', 'desatualizado', 'nao_verificado'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type farus_origem as enum (
    'coleta_programada', 'descoberta_radar', 'interesse_tenant', 'demanda_tenant'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type farus_especie as enum (
    'ato_oficial', 'contratacao', 'materia', 'norma', 'documento'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type farus_estado_fonte as enum (
    'descoberta', 'observada', 'configurada', 'suspensa', 'recusada'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type evora_plano as enum ('municipal', 'estadual', 'nacional');
exception when duplicate_object then null; end $$;

alter table tenants add column if not exists plano evora_plano not null default 'municipal';
comment on column tenants.plano is 'Fase 10 — nível contratado (Manual E12). Define o alcance territorial do radar. Todo nível contém o inferior.';

create table if not exists farus_territorios (
  id              uuid primary key default gen_random_uuid(),
  codigo_ibge     integer unique,
  municipio       text        not null,
  uf              char(2)     not null,
  regiao_imediata text,
  ativo           boolean     not null default true,
  criado_em       timestamptz not null default now(),
  constraint farus_territorio_uf_valida check (uf ~ '^[A-Z]{2}$')
);

comment on table farus_territorios is 'Fase 10 — municípios sob monitoramento do FARUS. Compartilhado da plataforma, não do tenant.';

create table if not exists farus_tenant_territorios (
  tenant_id     uuid not null references tenants(id) on delete cascade,
  territorio_id uuid not null references farus_territorios(id) on delete restrict,
  principal     boolean not null default false,
  incluido_em   timestamptz not null default now(),
  incluido_por  text,
  primary key (tenant_id, territorio_id)
);

comment on table farus_tenant_territorios is 'Fase 10 — vínculo tenant x território do FARUS.';

create table if not exists farus_fontes (
  id             uuid primary key default gen_random_uuid(),
  territorio_id  uuid not null references farus_territorios(id) on delete restrict,
  nome           text not null,
  especie        farus_especie not null,
  url            text,
  nivel          text,
  estado         farus_estado_fonte not null default 'descoberta',
  cnpj           text,
  cnae           text,
  evidencia_cobertura text,
  descoberta_por text,
  liberada_por   text,
  liberada_em    timestamptz,
  ultima_coleta  timestamptz,
  criado_em      timestamptz not null default now(),
  constraint farus_fonte_liberacao_humana check (
    estado <> 'configurada' or (liberada_por is not null and liberada_em is not null)
  )
);

comment on table farus_fontes is 'Fase 10 — fontes do acervo FARUS, por território.';
comment on constraint farus_fonte_liberacao_humana on farus_fontes is 'Decisão D6: nenhuma fonte alimenta afirmação sem liberação humana registrada. Trava no banco.';

create table if not exists farus_itens (
  id               uuid primary key default gen_random_uuid(),
  territorio_id    uuid not null references farus_territorios(id) on delete restrict,
  origem_aquisicao farus_origem not null,
  tenant_origem    uuid references tenants(id) on delete cascade,
  fonte_id         uuid references farus_fontes(id) on delete set null,
  especie          farus_especie not null,
  url              text,
  titulo           text not null,
  conteudo         text,
  publicado_em     date,
  capturado_em     timestamptz not null default now(),
  estado           farus_estado not null default 'nao_verificado',
  verificado_por   text,
  verificado_em    timestamptz,
  hash_conteudo    bytea not null,
  retencao_indeterminada boolean not null default true,
  criado_em        timestamptz not null default now(),
  constraint farus_item_origem_coerente check (
    (origem_aquisicao in ('coleta_programada','descoberta_radar') and tenant_origem is null)
    or
    (origem_aquisicao in ('interesse_tenant','demanda_tenant') and tenant_origem is not null)
  ),
  constraint farus_item_verificacao_registrada check (
    estado not in ('confirmado','corroborado')
    or (verificado_por is not null and verificado_em is not null)
  )
);

comment on table farus_itens is 'Fase 10 — o acervo FARUS. Compartilhado por município ou privado do tenant, conforme origem_aquisicao.';
comment on constraint farus_item_origem_coerente on farus_itens is 'Fronteira do compartilhamento: acervo público não tem dono; pesquisa de tenant nunca é compartilhada.';
comment on column farus_itens.hash_conteudo is 'sha256 de titulo||conteudo normalizados (farus_hash). Base da deduplicação por território.';

create unique index if not exists ix_farus_territorio_municipio on farus_territorios (lower(municipio), uf);
create index if not exists ix_farus_fontes_territorio on farus_fontes (territorio_id, estado);
create unique index if not exists ix_farus_itens_dedup on farus_itens (territorio_id, hash_conteudo);
create index if not exists ix_farus_itens_busca on farus_itens (territorio_id, especie, publicado_em desc);
create index if not exists ix_farus_itens_tenant on farus_itens (tenant_origem) where tenant_origem is not null;

create extension if not exists pgcrypto;

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

comment on function farus_hash(text,text) is 'Fase 10 — regra única de deduplicação. Coletor e banco devem usar esta função, nunca calcular hash à parte.';

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

-- =====================================================================
-- BLOCO 2 — RLS: seção 16
-- =====================================================================

alter table farus_territorios        enable row level security;
alter table farus_tenant_territorios enable row level security;
alter table farus_fontes             enable row level security;
alter table farus_itens              enable row level security;
alter table farus_territorios        force row level security;
alter table farus_tenant_territorios force row level security;
alter table farus_fontes             force row level security;
alter table farus_itens              force row level security;

grant select on farus_territorios, farus_fontes, farus_itens to authenticated;
grant select, insert, delete on farus_tenant_territorios to authenticated;

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

drop policy if exists farus_territorios_leitura on farus_territorios;
create policy farus_territorios_leitura on farus_territorios
  for select to authenticated
  using (id in (select farus_territorios_do_tenant()));

drop policy if exists farus_tt_isolamento on farus_tenant_territorios;
create policy farus_tt_isolamento on farus_tenant_territorios
  for all to authenticated
  using (tenant_id = evora_tenant_atual())
  with check (tenant_id = evora_tenant_atual());

drop policy if exists farus_fontes_leitura on farus_fontes;
create policy farus_fontes_leitura on farus_fontes
  for select to authenticated
  using (territorio_id in (select farus_territorios_do_tenant()));

drop policy if exists farus_itens_leitura on farus_itens;
create policy farus_itens_leitura on farus_itens
  for select to authenticated
  using (
    territorio_id in (select farus_territorios_do_tenant())
    and (
      tenant_origem is null
      or tenant_origem = evora_tenant_atual()
    )
  );

comment on policy farus_itens_leitura on farus_itens is
  'Exceção controlada ao isolamento: compartilha por município, mas nunca o contexto de outro tenant.';
