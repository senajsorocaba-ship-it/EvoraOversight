-- Espelho INCREMENTAL gerado de: ao-SUPABASE-BLOCO1/AO SUPABASE BLOCO1.md.txt
-- (tabela 17) + ao-SUPABASE-BLOCO1/evora rls mvp v1.sql (trechos novos) +
-- ao-SUPABASE-BLOCO1/evora auth mvp v1.sql (seção 3, funções novas).
-- NAO EDITAR AQUI. Editar os arquivos canonicos acima e copiar de novo.
--
-- Fase 8 do plano de testes: autocadastro de vereador. Só quem selecionar
-- estado+cidade e cujo e-mail bater com a lista de vereadores verificados
-- daquela cidade (municipio_vereadores, semeada manualmente via
-- evora_atlas_municipal.py) consegue criar conta sozinho — sem essa lista
-- semeada, nenhuma cidade tem elegibilidade nenhuma ainda.

-- =====================================================================
-- BLOCO 1 — schema: tabela 17
-- =====================================================================

-- ---------------------------------------------------------------------
-- 17. MUNICIPIO_VEREADORES — Fase 8 (autocadastro de vereador). Lista de
-- vereadores em exercício por município, com e-mail institucional — a
-- porta de entrada do cadastro público ("só se cadastra quem estiver
-- nesta lista"). Mesma família compartilhada de municipio_fontes/
-- municipio_trilha: sem tenant_id/mundo, só service_role escreve.
--
-- Diferente de municipio_fontes/municipios, esta tabela NÃO tem grant de
-- select para `authenticated` nem `anon` — o e-mail de um vereador nunca
-- é exposto a um tenant qualquer via REST; o acesso acontece só através
-- das funções security definer evora_verificar_vereador/
-- evora_autocadastro_vereador (abaixo), que respondem 1 e-mail por vez e
-- nunca vazam a lista inteira.
--
-- Sem coletor de TSE/Câmara Municipal automatizado (cada Câmara tem seu
-- próprio site) — esta tabela é semeada manualmente via
-- evora_atlas_municipal.py (subcomando `vereadores`), com dado real
-- conferido por um humano, mesmo modelo de municipio_fontes.
-- ---------------------------------------------------------------------
create table if not exists municipio_vereadores (
  id            uuid primary key default gen_random_uuid(),
  municipio_id  uuid not null references municipios(id),
  nome          text not null,
  email         text not null,
  partido       text,
  fonte         text,                                -- proveniência (ex.: "portal da Câmara, conferido em dd/mm/aaaa")
  selo          evora_selo_cvi not null default 'a_confirmar',
  ativo         boolean not null default true,       -- perdeu mandato/mudou de e-mail etc. (soft delete)
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint municipio_vereadores_verificado_exige_fonte
    check (selo <> 'verificado' or fonte is not null)
);

comment on table municipio_vereadores is 'Fase 8 — lista de vereadores em exercício por município (e-mail institucional), porta de entrada do autocadastro. Camada compartilhada da plataforma, sem grant de select para authenticated/anon — só acessível via função security definer.';

create unique index if not exists idx_municipio_vereadores_email on municipio_vereadores (municipio_id, lower(email));
create index if not exists idx_municipio_vereadores_municipio on municipio_vereadores(municipio_id) where ativo;

drop trigger if exists trg_municipio_vereadores_atualizado on municipio_vereadores;
create trigger trg_municipio_vereadores_atualizado before update on municipio_vereadores
  for each row execute function evora_toca_atualizado_em();

-- =====================================================================
-- BLOCO 2 — RLS: enable/force para a tabela nova (sem policy, sem grant
-- para authenticated/anon — mesmo caso de municipio_trilha)
-- =====================================================================

-- service_role: a migration 2 (20260818000002_rls.sql) já rodou seu
-- "grant all privileges on all tables in schema public to service_role"
-- ANTES desta tabela existir — GRANT não é retroativo (mesmo motivo já
-- documentado na migration 5, Fase 7).
grant all privileges on municipio_vereadores to service_role;

alter table municipio_vereadores enable row level security;
alter table municipio_vereadores force row level security;
-- Nenhuma policy, nenhum grant para authenticated/anon: o e-mail de
-- vereador é sensível o suficiente para nunca ser exposto via REST
-- direto. O autocadastro consulta esta tabela só através das funções
-- abaixo.

-- =====================================================================
-- BLOCO 3 — funções security definer (autocadastro de vereador)
-- =====================================================================

create or replace function evora_listar_municipios_uf(p_uf text)
returns table(id uuid, nome text, slug text)
language sql
stable
security definer
set search_path = ''
as $$
  select id, nome, slug
    from public.municipios
   where uf = upper(p_uf) and ativo
   order by nome;
$$;

comment on function evora_listar_municipios_uf is
  'Fase 8: lista municípios do Atlas por UF, para o <select> de cidade da tela de cadastro. Só cidades já semeadas aparecem.';

create or replace function evora_verificar_vereador(p_municipio_id uuid, p_email text)
returns table(elegivel boolean, nome text)
language sql
stable
security definer
set search_path = ''
as $$
  select true, v.nome
    from public.municipio_vereadores v
   where v.municipio_id = p_municipio_id
     and v.ativo
     and lower(v.email) = lower(p_email)
   limit 1;
$$;

comment on function evora_verificar_vereador is
  'Fase 8: confirma se um e-mail está na lista de vereadores verificados de um município. Sem match, o result set vem vazio — o front trata como não elegível.';

create or replace function evora_autocadastro_vereador(p_municipio_id uuid, p_email text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nome      text;
  v_uf        text;
  v_municipio text;
  v_slug      text;
  v_tenant_id uuid;
begin
  select v.nome into v_nome
    from public.municipio_vereadores v
   where v.municipio_id = p_municipio_id
     and v.ativo
     and lower(v.email) = lower(p_email)
   limit 1;

  if v_nome is null then
    raise exception 'E-mail não consta na lista de vereadores verificados desta cidade.';
  end if;

  if exists (select 1 from public.usuarios where lower(email) = lower(p_email)) then
    raise exception 'Já existe cadastro com este e-mail.';
  end if;

  select nome, uf into v_municipio, v_uf
    from public.municipios
   where id = p_municipio_id;

  v_slug := lower(regexp_replace(v_nome || '-' || v_municipio, '[^a-zA-Z0-9]+', '-', 'g'))
            || '-' || substr(gen_random_uuid()::text, 1, 6);

  insert into public.tenants (slug, nome_autoridade, cargo, municipio_sede, uf)
  values (v_slug, v_nome, 'vereador(a)', v_municipio, v_uf)
  returning id into v_tenant_id;

  insert into public.usuarios (tenant_id, nome, email, papel, mundo_permitido, alcada_aprovacao)
  values (v_tenant_id, v_nome, p_email, 'autoridade', null, true);

  return v_tenant_id;
end;
$$;

comment on function evora_autocadastro_vereador is
  'Fase 8: cria tenant+usuario para um vereador cujo e-mail bateu com municipio_vereadores. Revalida elegibilidade e duplicidade internamente. Chamar supabase.auth.signUp() logo em seguida, mesmo e-mail, para criar a conta de login.';

revoke execute on function evora_listar_municipios_uf(text) from public;
revoke execute on function evora_verificar_vereador(uuid, text) from public;
revoke execute on function evora_autocadastro_vereador(uuid, text) from public;
grant execute on function evora_listar_municipios_uf(text) to anon, authenticated;
grant execute on function evora_verificar_vereador(uuid, text) to anon, authenticated;
grant execute on function evora_autocadastro_vereador(uuid, text) to anon, authenticated;
