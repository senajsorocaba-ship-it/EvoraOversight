-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVORA OVERSIGHT — AEGIS A0 · Fundação do cofre
-- ═══════════════════════════════════════════════════════════════════════════
--
-- A SITUAÇÃO QUE TORNA ESTA MIGRAÇÃO BARATA
-- Verificado em 02/09/2026: o schema não tem coluna de CPF, o motor não usa
-- dado sensível, e o front-end apenas mascara para exibição. **O CPF existe
-- somente no formulário — nunca foi gravado.**
--
-- O cofre nasce, portanto, ANTES do primeiro dado sensível. É a única vez em
-- que isso é possível: depois, seria migração de dado sensível — a operação
-- mais arriscada que existe.
--
-- O QUE A A0 FAZ E O QUE NÃO FAZ
--   Faz:      separa o dado sensível em tabela própria · restringe o acesso ·
--             registra toda LEITURA, não só alteração · guarda a máscara fora
--             do cofre · impede que a operação dependa do conteúdo cofrado.
--   Não faz:  cifragem em envelope (A1) · fragmentação por quórum (A2).
--
-- A REGRA QUE A A0 EXISTE PARA GARANTIR
--   Se o cofre precisar abrir na operação de rotina, não é cofre.
--   Nada no login, no briefing ou na tela pode depender do conteúdo cofrado.
--
-- ORDEM: rodar depois do schema, do RLS, do hook e do FARUS F1.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- ---------------------------------------------------------------------------
-- 1. ESPÉCIES DE DADO COFRADO
-- ---------------------------------------------------------------------------

do $$ begin
  create type aegis_especie as enum (
    'cpf',
    'data_nascimento',
    'documento_identidade',   -- previsto, não coletado por decisão de 02/09/2026
    'dado_saude',             -- futuro
    'dado_seguranca'          -- futuro — Sentinela
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type aegis_motivo_leitura as enum (
    'conferencia_identidade',
    'emissao_contrato',
    'emissao_nota_fiscal',
    'obrigacao_legal',
    'pedido_do_titular',
    'ordem_judicial'
  );
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- 2. O COFRE
-- ---------------------------------------------------------------------------
-- Tabela separada de `usuarios` de propósito: a tela de equipe lê `usuarios`
-- o tempo todo e **nunca** deve tocar no cofre.

create table if not exists aegis_cofre (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references tenants(id) on delete cascade,
  usuario_id    uuid not null references usuarios(id) on delete cascade,
  especie       aegis_especie not null,

  -- O conteúdo. Na A1 passa a ser cifrado em envelope com chave por tenant.
  -- Hoje conta com a cifragem em repouso do provedor.
  valor         text not null,

  -- A máscara vive FORA do conteúdo, para a tela nunca precisar abrir o cofre.
  -- Ex.: CPF 529.982.247-25 → mascara '•••.982.247-••'
  mascara       text not null,

  registrado_em timestamptz not null default now(),
  registrado_por text not null,

  -- Um valor por espécie por usuário.
  constraint aegis_cofre_unico unique (usuario_id, especie),

  -- TRAVA: máscara nunca pode conter o valor inteiro.
  constraint aegis_mascara_parcial check (mascara <> valor),

  -- TRAVA: máscara precisa ter marca de ocultação.
  constraint aegis_mascara_oculta check (mascara like '%•%' or mascara like '%*%')
);

comment on table aegis_cofre is
'Cofre de dado sensível (N5). Separado de usuarios de propósito: a operação de rotina nunca o lê.';

comment on column aegis_cofre.mascara is
'Forma de exibição, guardada fora do conteúdo. É o que a tela usa — assim o cofre permanece fechado.';

-- ---------------------------------------------------------------------------
-- 3. REGISTRO DE LEITURA
-- ---------------------------------------------------------------------------
-- Em N5, **quem viu importa tanto quanto quem alterou**. A trilha comum grava
-- alterações; esta grava acessos.

create table if not exists aegis_acessos (
  id          uuid primary key default gen_random_uuid(),
  cofre_id    uuid not null references aegis_cofre(id) on delete cascade,
  tenant_id   uuid not null references tenants(id) on delete cascade,
  quem        text not null,
  motivo      aegis_motivo_leitura not null,
  justificativa text,
  ocorrido_em timestamptz not null default now()
);

create index if not exists ix_aegis_acessos_cofre on aegis_acessos (cofre_id, ocorrido_em desc);

-- Trilha é registro perene: não se altera nem se apaga.
create or replace function aegis_trilha_imutavel()
returns trigger language plpgsql as $$
begin
  raise exception 'Registro de acesso ao cofre é imutável. Tentativa de % rejeitada.', tg_op;
end $$;

drop trigger if exists trg_aegis_acessos_imutavel on aegis_acessos;
create trigger trg_aegis_acessos_imutavel
  before update or delete on aegis_acessos
  for each row execute function aegis_trilha_imutavel();

comment on table aegis_acessos is
'Registro de LEITURA do cofre. Append-only. Em dado sensível, quem viu importa tanto quanto quem alterou.';

-- ---------------------------------------------------------------------------
-- 4. A ÚNICA PORTA DE LEITURA
-- ---------------------------------------------------------------------------
-- Não existe SELECT direto no cofre para a aplicação. Ler exige esta função,
-- que **obriga a declarar o motivo** e grava o acesso antes de devolver.

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

  -- Somente autoridade e chefe de gabinete abrem o cofre.
  select u.papel::text into v_papel
  from usuarios u where u.auth_user_id = auth.uid() and u.ativo;

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

  -- Grava ANTES de devolver: leitura sem registro não existe.
  insert into aegis_acessos (cofre_id, tenant_id, quem, motivo, justificativa)
  values (v_id, v_tenant, coalesce(auth.uid()::text,'desconhecido'), p_motivo, p_justificativa);

  return v_valor;
end $$;

comment on function aegis_ler is
'Única porta de leitura do cofre. Exige motivo declarado e grava o acesso antes de devolver o valor.';

-- ---------------------------------------------------------------------------
-- 5. LEITURA DA MÁSCARA — livre, porque não revela nada
-- ---------------------------------------------------------------------------
-- É o que as telas usam. Não abre o cofre e não gera registro de acesso.

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

-- ---------------------------------------------------------------------------
-- 6. ISOLAMENTO
-- ---------------------------------------------------------------------------

alter table aegis_cofre   enable row level security;
alter table aegis_cofre   force  row level security;
alter table aegis_acessos enable row level security;
alter table aegis_acessos force  row level security;

-- NENHUMA política de SELECT no cofre para a aplicação.
-- Ler o conteúdo só pela função aegis_ler. O banco nega o resto.
-- A ausência de política aqui é deliberada, não esquecimento.

-- A autoridade pode consultar QUEM leu o cofre do seu gabinete.
drop policy if exists aegis_acessos_leitura on aegis_acessos;
create policy aegis_acessos_leitura on aegis_acessos
  for select to authenticated
  using (tenant_id = evora_tenant_atual());

-- ---------------------------------------------------------------------------
-- 7. PERMISSÕES
-- ---------------------------------------------------------------------------

revoke all on aegis_cofre from authenticated, anon;
grant select on aegis_acessos to authenticated;
revoke all on aegis_acessos from anon;

grant execute on function aegis_ler(uuid, aegis_especie, aegis_motivo_leitura, text) to authenticated;
grant execute on function aegis_mascara(uuid, aegis_especie) to authenticated;
revoke execute on function aegis_ler(uuid, aegis_especie, aegis_motivo_leitura, text) from anon;

commit;

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICAÇÃO
-- ═══════════════════════════════════════════════════════════════════════════
--
--  1. O cofre não tem política de SELECT?  (a ausência é a proteção)
--     select count(*) from pg_policies
--      where tablename='aegis_cofre' and cmd='SELECT';        -- esperado: 0
--
--  2. A aplicação não tem permissão direta?
--     select count(*) from information_schema.role_table_grants
--      where table_name='aegis_cofre' and grantee='authenticated';  -- esperado: 0
--
--  3. Nada na operação depende do cofre?
--     Confirmar que login, briefing e telas usam apenas aegis_mascara.
--
-- Teste completo: evora_aegis_teste_aceite.sql
-- ═══════════════════════════════════════════════════════════════════════════
