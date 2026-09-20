-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVORA OVERSIGHT — CAMADA DE RESPOSTA E MINUTAS
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Fecha três lacunas identificadas em 16/09/2026, ao aplicar a regra de
-- verificação arquitetural a uma instrução nova.
--
-- ── LACUNA 1 · REGISTRO DE LINGUAGEM ─────────────────────────────────────
-- O sistema responde a quem pode não ser advogado. A mesma informação precisa
-- sair em linguagem comum E em linguagem técnica — e quem escolhe é o leitor.
-- Havia apenas `tenants.perfil` como jsonb livre: cabia, mas nada obrigava
-- estrutura, e o motor não podia confiar no formato.
--
-- ── LACUNA 2 · MINUTAS (a mais grave) ────────────────────────────────────
-- A Skill exige minutas nas seções 2 e 36: "minuta de ofício para sua
-- aprovação antes de qualquer envio". **Não existia tabela nenhuma.**
--
-- A minuta é onde o freio humano se materializa. Sem lugar para ela, ou o
-- sistema não gera minuta — e perde a camada 6 da Skill — ou gera sem
-- registro de quem aprovou, o que quebra a trilha.
--
-- ── LACUNA 3 · QUAL REGISTRO FOI ENTREGUE ────────────────────────────────
-- `briefings` guardava um texto só. Se a informação sai em dois registros,
-- não havia como saber qual a autoridade leu — e isso importa se houver
-- questionamento sobre o que ela sabia e quando.
--
-- ── A TRAVA QUE ATRAVESSA TUDO ───────────────────────────────────────────
-- O Évora **nunca envia**. Guarda a minuta, registra a decisão de aprovar,
-- e o envio é ato humano fora do sistema. Não há campo de "enviado por nós".
--
-- ORDEM: rodar depois do schema, RLS, hook, FARUS, Aegis, Veritas e Legis.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- ---------------------------------------------------------------------------
-- 1. TIPOS
-- ---------------------------------------------------------------------------

-- LACUNA 1 — os registros de linguagem
do $$ begin
  create type evora_registro as enum (
    'simples',   -- linguagem comum, sem jargão; para quem não é da área
    'tecnico',   -- com fundamentação, citação de dispositivo e termo próprio
    'ambos'      -- as duas versões, o leitor escolhe  ← PADRÃO
  );
exception when duplicate_object then null; end $$;

-- LACUNA 2 — espécies de minuta que a Skill prevê
do $$ begin
  create type minuta_especie as enum (
    'requerimento',
    'oficio',
    'pedido_informacao',
    'indicacao',
    'mocao',
    'nota_publica',
    'relatorio'
  );
exception when duplicate_object then null; end $$;

-- LACUNA 2 — o ciclo de vida, com o freio humano no meio
do $$ begin
  create type minuta_estado as enum (
    'rascunho',              -- o sistema montou, ninguém viu
    'aguardando_aprovacao',  -- submetida à autoridade
    'aprovada',              -- autorizada — o envio é ato humano FORA do sistema
    'descartada',            -- recusada, com motivo
    'protocolada'            -- a pessoa informou que protocolou
  );
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- 2. LACUNA 1 — PREFERÊNCIA DE REGISTRO
-- ---------------------------------------------------------------------------
-- No tenant: o padrão do gabinete, definido na Entrevista de Fundação.
-- No usuário: sobrepõe o do gabinete, porque a chefia e a autoridade podem
-- querer coisas diferentes.

alter table tenants
  add column if not exists registro_padrao evora_registro not null default 'ambos';

alter table usuarios
  add column if not exists registro_preferido evora_registro;

comment on column tenants.registro_padrao is
'Registro de linguagem do gabinete. Definido na Entrevista de Fundação, alterável a qualquer tempo.';
comment on column usuarios.registro_preferido is
'Sobrepõe o do gabinete. Nulo = usa o padrão do tenant. A chefia pode querer técnico e a autoridade simples.';

-- Resolve qual registro usar para uma pessoa
create or replace function evora_registro_de(p_usuario uuid)
returns evora_registro
language sql
stable
as $$
  select coalesce(u.registro_preferido, t.registro_padrao, 'ambos'::evora_registro)
  from usuarios u join tenants t on t.id = u.tenant_id
  where u.id = p_usuario;
$$;

-- ---------------------------------------------------------------------------
-- 3. LACUNA 3 — QUAL REGISTRO FOI ENTREGUE
-- ---------------------------------------------------------------------------

alter table briefings
  add column if not exists registro_entregue evora_registro,
  add column if not exists markdown_tecnico text,
  add column if not exists html_tecnico text;

comment on column briefings.registro_entregue is
'Qual registro a autoridade recebeu. Importa na trilha: "o briefing dizia X" precisa dizer em qual versão.';
comment on column briefings.markdown_tecnico is
'Versão técnica, quando o registro for tecnico ou ambos. A coluna markdown guarda a versão simples.';

-- ---------------------------------------------------------------------------
-- 4. LACUNA 2 — MINUTAS
-- ---------------------------------------------------------------------------

create table if not exists minutas (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references tenants(id) on delete cascade,
  mundo       evora_mundo not null default 'gabinete',

  especie     minuta_especie not null,
  assunto     text not null,
  destinatario text,                       -- a quem se dirige

  -- Os dois registros. O simples explica; o técnico é o que se protocola.
  texto_simples text,
  texto_tecnico text,

  -- § 39 — de onde veio: a minuta sempre nasce de um fato ou de uma matéria
  materia_id  uuid references legis_materias(id) on delete set null,
  item_farus  uuid references farus_itens(id) on delete set null,
  norma_id    uuid references veritas_normas(id) on delete set null,
  fundamento  text,                         -- dispositivo que ampara o pedido

  -- O freio humano
  estado      minuta_estado not null default 'rascunho',
  gerada_em   timestamptz not null default now(),
  gerada_por  text not null default 'motor',
  submetida_em timestamptz,
  decidida_por uuid references usuarios(id) on delete set null,
  decidida_em timestamptz,
  motivo_decisao text,

  -- Quando a pessoa informa que protocolou — o sistema não protocola
  protocolo_informado text,
  protocolo_em        date,

  -- TRAVA 1: minuta aprovada ou descartada exige quem decidiu e quando.
  -- É o freio humano imposto pelo banco, não pelo programa.
  constraint minuta_decisao_registrada check (
    estado not in ('aprovada','descartada')
    or (decidida_por is not null and decidida_em is not null)
  ),

  -- TRAVA 2: descarte exige motivo. Recusa sem razão não se audita.
  constraint minuta_descarte_com_motivo check (
    estado <> 'descartada' or motivo_decisao is not null
  ),

  -- TRAVA 3: só se protocola o que foi aprovado.
  constraint minuta_protocolo_exige_aprovacao check (
    estado <> 'protocolada' or decidida_por is not null
  ),

  -- TRAVA 4: a minuta precisa ter ao menos um texto.
  constraint minuta_tem_texto check (
    texto_simples is not null or texto_tecnico is not null
  ),

  -- TRAVA 5: § 39 — toda minuta nasce de algo verificável.
  constraint minuta_tem_origem check (
    materia_id is not null or item_farus is not null or norma_id is not null
  )
);

create index if not exists ix_minutas_tenant on minutas (tenant_id, estado, gerada_em desc);
create index if not exists ix_minutas_pendentes on minutas (tenant_id)
  where estado = 'aguardando_aprovacao';

comment on table minutas is
'§ 2 e § 36 da Skill — documentos para APROVAÇÃO HUMANA. O Évora nunca envia: guarda a minuta e o registro da decisão.';
comment on column minutas.protocolo_informado is
'Preenchido pela PESSOA, após protocolar fora do sistema. O Évora não protocola.';

-- ---------------------------------------------------------------------------
-- 5. TRILHA DAS MINUTAS
-- ---------------------------------------------------------------------------
-- Append-only, como a do Aegis e a do Veritas.

create table if not exists minuta_eventos (
  id         uuid primary key default gen_random_uuid(),
  minuta_id  uuid not null references minutas(id) on delete cascade,
  tenant_id  uuid not null references tenants(id) on delete cascade,
  de_estado  minuta_estado,
  para_estado minuta_estado not null,
  quem       text not null,
  motivo     text,
  ocorrido_em timestamptz not null default now()
);

create index if not exists ix_minuta_eventos on minuta_eventos (minuta_id, ocorrido_em desc);

create or replace function minuta_trilha_imutavel()
returns trigger language plpgsql as $$
begin
  raise exception 'Trilha de minuta é imutável. Tentativa de % rejeitada.', tg_op;
end $$;

drop trigger if exists trg_minuta_trilha on minuta_eventos;
create trigger trg_minuta_trilha
  before update or delete on minuta_eventos
  for each row execute function minuta_trilha_imutavel();

-- Registra toda mudança de estado automaticamente
create or replace function minuta_registrar_mudanca()
returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' or old.estado is distinct from new.estado then
    insert into minuta_eventos (minuta_id, tenant_id, de_estado, para_estado, quem, motivo)
    values (new.id, new.tenant_id,
            case when tg_op='INSERT' then null else old.estado end,
            new.estado,
            coalesce(
              (select u.nome from usuarios u where u.id = new.decidida_por),
              new.gerada_por),
            new.motivo_decisao);
  end if;
  return new;
end $$;

drop trigger if exists trg_minuta_mudanca on minutas;
create trigger trg_minuta_mudanca
  after insert or update on minutas
  for each row execute function minuta_registrar_mudanca();

-- ---------------------------------------------------------------------------
-- 6. A PORTA DE APROVAÇÃO
-- ---------------------------------------------------------------------------
-- Aprovar é ato de alçada. Não é UPDATE solto.

create or replace function minuta_decidir(
  p_minuta  uuid,
  p_decisao minuta_estado,
  p_motivo  text default null
)
returns minutas
language plpgsql
security definer
set search_path = public
as $$
declare
  v_usuario uuid;
  v_papel   text;
  v_linha   minutas;
begin
  if p_decisao not in ('aprovada','descartada') then
    raise exception 'Decisão deve ser aprovada ou descartada.';
  end if;

  select u.id, u.papel::text into v_usuario, v_papel
  from usuarios u where u.auth_user_id = auth.uid() and u.ativo;

  if v_usuario is null then
    raise exception 'Sem identidade ativa.';
  end if;

  -- Só autoridade e chefe de gabinete decidem sobre minuta
  if v_papel not in ('autoridade','chefe_gabinete') then
    raise exception 'Papel % não tem alçada para decidir sobre minuta.', v_papel;
  end if;

  if p_decisao = 'descartada' and (p_motivo is null or length(trim(p_motivo)) < 3) then
    raise exception 'Descarte exige motivo registrado.';
  end if;

  update minutas
     set estado = p_decisao,
         decidida_por = v_usuario,
         decidida_em = now(),
         motivo_decisao = p_motivo
   where id = p_minuta and tenant_id = evora_tenant_atual()
  returning * into v_linha;

  if v_linha.id is null then
    raise exception 'Minuta não encontrada neste gabinete.';
  end if;

  return v_linha;
end $$;

comment on function minuta_decidir is
'Única porta de decisão. Exige alçada, registra quem e quando, e motivo no descarte.';

-- ---------------------------------------------------------------------------
-- 7. ISOLAMENTO
-- ---------------------------------------------------------------------------

alter table minutas        enable row level security;
alter table minutas        force  row level security;
alter table minuta_eventos enable row level security;
alter table minuta_eventos force  row level security;

-- Minuta é do gabinete — NUNCA compartilhada, ao contrário do acervo
drop policy if exists minutas_isolamento on minutas;
create policy minutas_isolamento on minutas
  for select to authenticated
  using (tenant_id = evora_tenant_atual()
         and (mundo = evora_mundo_atual() or evora_mundo_atual() is null));

drop policy if exists minuta_eventos_leitura on minuta_eventos;
create policy minuta_eventos_leitura on minuta_eventos
  for select to authenticated
  using (tenant_id = evora_tenant_atual());

-- Escrita pelo motor; decisão pela função. Nenhuma política de UPDATE direto.

comment on policy minutas_isolamento on minutas is
'Minuta é contexto do gabinete — nunca entra na camada compartilhada por município.';

-- ---------------------------------------------------------------------------
-- 8. PERMISSÕES
-- ---------------------------------------------------------------------------

grant select on minutas, minuta_eventos to authenticated;
revoke all on minutas, minuta_eventos from anon;
grant execute on function minuta_decidir(uuid, minuta_estado, text) to authenticated;
grant execute on function evora_registro_de(uuid) to authenticated;

commit;

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICAÇÃO
-- ═══════════════════════════════════════════════════════════════════════════
--   select count(*) from information_schema.tables
--    where table_name in ('minutas','minuta_eventos');            -- 2
--   select registro_padrao from tenants limit 1;                  -- 'ambos'
--   select count(*) from pg_policies where tablename like 'minuta%';  -- 2
-- Teste completo: evora_resposta_teste_aceite.sql
-- ═══════════════════════════════════════════════════════════════════════════
