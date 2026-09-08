-- Espelho INCREMENTAL gerado de: ao-SUPABASE-BLOCO1/AO SUPABASE BLOCO1.md.txt
-- (tipos + tabelas 23-24 + trigger imutável) + ao-SUPABASE-BLOCO1/evora rls
-- mvp v1.sql (seção 17).
-- NAO EDITAR AQUI. Editar os arquivos canonicos acima e copiar de novo.
-- Depende da migration 20260903000001_farus_f1.sql já aplicada.
--
-- Fase 11 (Manual v10.9.1): Aegis A0 — cofre de dado sensível (CPF, data de
-- nascimento). Adaptado de `evora aegis a0.sql` (entregue já testado
-- 10/10, ver `ao-SUPABASE-BLOCO1/evora aegis teste aceite.sql`). Única
-- adaptação real: `auth.uid()` do arquivo entregue trocado por
-- `evora_claims() ->> 'sub'`, o idioma que este projeto já usa em toda
-- parte (evora_valida_ciencia_briefing) — a trava em si não muda.

-- =====================================================================
-- BLOCO 1 — schema: tipos + tabelas 23-24 + trigger imutável
-- =====================================================================

do $$ begin
  create type aegis_especie as enum (
    'cpf', 'data_nascimento', 'documento_identidade', 'dado_saude', 'dado_seguranca'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type aegis_motivo_leitura as enum (
    'conferencia_identidade', 'emissao_contrato', 'emissao_nota_fiscal',
    'obrigacao_legal', 'pedido_do_titular', 'ordem_judicial'
  );
exception when duplicate_object then null; end $$;

create table if not exists aegis_cofre (
  id             uuid primary key default gen_random_uuid(),
  tenant_id      uuid not null references tenants(id) on delete cascade,
  usuario_id     uuid not null references usuarios(id) on delete cascade,
  especie        aegis_especie not null,
  valor          text not null,
  mascara        text not null,
  registrado_em  timestamptz not null default now(),
  registrado_por text not null,
  constraint aegis_cofre_unico unique (usuario_id, especie),
  constraint aegis_mascara_parcial check (mascara <> valor),
  constraint aegis_mascara_oculta check (mascara like '%•%' or mascara like '%*%')
);

comment on table aegis_cofre is 'Fase 11 — cofre de dado sensível (N5). Separado de usuarios de propósito: a operação de rotina nunca o lê.';
comment on column aegis_cofre.mascara is 'Forma de exibição, guardada fora do conteúdo. É o que a tela usa — assim o cofre permanece fechado.';

create table if not exists aegis_acessos (
  id            uuid primary key default gen_random_uuid(),
  cofre_id      uuid not null references aegis_cofre(id) on delete cascade,
  tenant_id     uuid not null references tenants(id) on delete cascade,
  quem          text not null,
  motivo        aegis_motivo_leitura not null,
  justificativa text,
  ocorrido_em   timestamptz not null default now()
);

comment on table aegis_acessos is 'Fase 11 — registro de leitura do cofre. Append-only.';

create index if not exists ix_aegis_acessos_cofre on aegis_acessos (cofre_id, ocorrido_em desc);

create or replace function aegis_trilha_imutavel()
returns trigger language plpgsql as $$
begin
  raise exception 'Registro de acesso ao cofre é imutável. Tentativa de % rejeitada.', tg_op;
end $$;

drop trigger if exists trg_aegis_acessos_imutavel on aegis_acessos;
create trigger trg_aegis_acessos_imutavel
  before update or delete on aegis_acessos
  for each row execute function aegis_trilha_imutavel();

-- =====================================================================
-- BLOCO 2 — RLS: seção 17
-- =====================================================================

alter table aegis_cofre   enable row level security;
alter table aegis_acessos enable row level security;
alter table aegis_cofre   force row level security;
alter table aegis_acessos force row level security;

-- SEM grant nenhum em aegis_cofre para authenticated/anon — a ausência é a
-- proteção. aegis_acessos tem select (a autoridade audita quem leu).
grant select on aegis_acessos to authenticated;

create or replace function aegis_ler(
  p_usuario_id uuid,
  p_especie    aegis_especie,
  p_motivo     aegis_motivo_leitura,
  p_justificativa text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid := evora_tenant_atual();
  v_id     uuid;
  v_valor  text;
  v_papel  text;
begin
  if v_tenant is null then
    raise exception 'Sem identidade no token.';
  end if;

  select u.papel::text into v_papel
  from usuarios u
  where u.auth_user_id = nullif(evora_claims() ->> 'sub', '')::uuid
    and u.ativo;

  if v_papel is null or v_papel not in ('autoridade','chefe_gabinete') then
    raise exception 'Papel % não tem alçada para abrir o cofre.', coalesce(v_papel,'indefinido');
  end if;

  select c.id, c.valor into v_id, v_valor
  from aegis_cofre c
  where c.usuario_id = p_usuario_id
    and c.especie = p_especie
    and c.tenant_id = v_tenant;

  if v_id is null then
    raise exception 'Não há registro desta espécie para este usuário neste gabinete.';
  end if;

  insert into aegis_acessos (cofre_id, tenant_id, quem, motivo, justificativa)
  values (v_id, v_tenant, coalesce(evora_claims() ->> 'sub', 'desconhecido'), p_motivo, p_justificativa);

  return v_valor;
end $$;

comment on function aegis_ler is
  'Única porta de leitura do cofre. Exige motivo declarado e grava o acesso antes de devolver o valor.';

create or replace function aegis_mascara(p_usuario_id uuid, p_especie aegis_especie)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select c.mascara
  from aegis_cofre c
  where c.usuario_id = p_usuario_id
    and c.especie = p_especie
    and c.tenant_id = evora_tenant_atual();
$$;

comment on function aegis_mascara is
  'Devolve apenas a forma mascarada. É o que a tela consome — o cofre permanece fechado.';

drop policy if exists aegis_acessos_leitura on aegis_acessos;
create policy aegis_acessos_leitura on aegis_acessos
  for select to authenticated
  using (tenant_id = evora_tenant_atual());

grant execute on function aegis_ler(uuid, aegis_especie, aegis_motivo_leitura, text) to authenticated;
grant execute on function aegis_mascara(uuid, aegis_especie) to authenticated;
revoke execute on function aegis_ler(uuid, aegis_especie, aegis_motivo_leitura, text) from anon;
revoke execute on function aegis_mascara(uuid, aegis_especie) from anon;
