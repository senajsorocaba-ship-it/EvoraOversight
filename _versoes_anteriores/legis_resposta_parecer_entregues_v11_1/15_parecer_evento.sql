-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVORA OVERSIGHT — PARECER COMO EVENTO
-- ═══════════════════════════════════════════════════════════════════════════
--
-- ── O PRINCÍPIO, DETERMINADO PELO FUNDADOR EM 20/09/2026 ─────────────────
--
--   "Os assessores são assessores. O fato de um deles ser advogado ajuda,
--    mas não deve mudar a arquitetura do sistema, pois ter advogado assessor
--    é um acaso."
--
-- PAPEL é posição no gabinete. HABILITAÇÃO é qualidade da pessoa.
--
-- Criar um papel 'juridico' faria o sistema se comportar de formas diferentes
-- conforme o acaso da composição da equipe: gabinete com advogado teria um
-- fluxo, gabinete sem teria outro. A arquitetura ficaria refém da sorte.
--
-- ── A CONSEQUÊNCIA DE DESENHO ────────────────────────────────────────────
-- O parecer é um EVENTO na vida da minuta, solicitado pela autoridade caso a
-- caso — NÃO uma etapa obrigatória do fluxo.
--
--   • Nenhum estado novo de minuta. O fluxo continua o mesmo.
--   • Nenhum papel novo. Assessor continua assessor.
--   • Parecer NÃO aprova nada. Quem aprova é a autoridade, como já era.
--   • Funciona igual com parecerista interno ou externo.
--
-- ── POR QUE O PARECER NÃO PODE APROVAR ───────────────────────────────────
-- Se o parecer aprovasse, a responsabilidade migraria do eleito para o
-- assessor. Quem responde pelo mandato é a autoridade — e o freio humano
-- existe para proteger essa linha, não para diluí-la.
--
-- ORDEM: rodar depois de evora_resposta_minutas.sql.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- ---------------------------------------------------------------------------
-- 1. HABILITAÇÃO PROFISSIONAL — atributo da pessoa, não papel
-- ---------------------------------------------------------------------------

alter table usuarios
  add column if not exists habilitacao text,
  add column if not exists habilitacao_registro text;

comment on column usuarios.habilitacao is
'Qualificação profissional da pessoa (ex.: advogado, contador). NÃO é papel: não altera alçada.';
comment on column usuarios.habilitacao_registro is
'Número de inscrição profissional, quando houver. Informativo — o sistema não valida junto ao conselho.';

-- ---------------------------------------------------------------------------
-- 2. PARECERES SOBRE MINUTA
-- ---------------------------------------------------------------------------
-- Distinto de `legis_pareceres`, que trata de parecer em matéria legislativa
-- (o parecer do relator na comissão). Este é parecer solicitado pela
-- autoridade sobre uma minuta do próprio gabinete.

do $$ begin
  create type minuta_parecer_conclusao as enum (
    'favoravel',
    'favoravel_com_ressalva',   -- "aprovado desde que altere o item b"
    'contrario',
    'inconclusivo'              -- faltou elemento para opinar
  );
exception when duplicate_object then null; end $$;

create table if not exists minuta_pareceres (
  id          uuid primary key default gen_random_uuid(),
  minuta_id   uuid not null references minutas(id) on delete cascade,
  tenant_id   uuid not null references tenants(id) on delete cascade,

  -- Quem pediu, e sobre o quê
  solicitado_por uuid not null references usuarios(id) on delete restrict,
  solicitado_em  timestamptz not null default now(),
  questao        text not null,           -- o ponto específico sobre o qual se pede

  -- Quem respondeu — interno OU externo, o registro é o mesmo
  parecerista_usuario uuid references usuarios(id) on delete set null,
  parecerista_nome    text,               -- quando externo ao gabinete
  parecerista_habilitacao text,           -- copiada no momento, para valer no tempo
  parecerista_registro    text,

  -- O parecer
  conclusao   minuta_parecer_conclusao,
  texto       text,
  ressalva    text,                       -- o que precisa mudar, se for o caso
  emitido_em  timestamptz,

  -- Quando a autoridade segue sem parecer, ou contra ele
  dispensado          boolean not null default false,
  dispensa_motivo     text,
  dispensado_por      uuid references usuarios(id) on delete set null,
  dispensado_em       timestamptz,

  criado_em   timestamptz not null default now(),

  -- TRAVA 1: parecer emitido exige quem o emitiu.
  -- Interno (usuário do gabinete) ou externo (nome informado) — mas algum.
  constraint parecer_tem_autor check (
    emitido_em is null
    or parecerista_usuario is not null
    or (parecerista_nome is not null and length(trim(parecerista_nome)) > 2)
  ),

  -- TRAVA 2: parecer emitido exige conclusão e texto.
  constraint parecer_emitido_completo check (
    emitido_em is null or (conclusao is not null and texto is not null)
  ),

  -- TRAVA 3: ressalva exige dizer o que precisa mudar.
  -- "Favorável com ressalva" sem dizer qual não orienta ninguém.
  constraint parecer_ressalva_explicita check (
    conclusao <> 'favoravel_com_ressalva' or ressalva is not null
  ),

  -- TRAVA 4: dispensar o parecer exige motivo e quem dispensou.
  -- É proteção da autoridade: a trilha mostra que ela assumiu conscientemente.
  constraint parecer_dispensa_registrada check (
    not dispensado
    or (dispensa_motivo is not null and dispensado_por is not null
        and dispensado_em is not null)
  ),

  -- TRAVA 5: ou se emite, ou se dispensa — nunca os dois.
  constraint parecer_nao_emitido_e_dispensado check (
    not (dispensado and emitido_em is not null)
  )
);

create index if not exists ix_minuta_pareceres on minuta_pareceres (minuta_id, criado_em desc);
create index if not exists ix_pareceres_pendentes on minuta_pareceres (tenant_id)
  where emitido_em is null and not dispensado;

comment on table minuta_pareceres is
'Parecer é EVENTO solicitado caso a caso, não etapa obrigatória. Não aprova: quem aprova é a autoridade.';
comment on column minuta_pareceres.parecerista_habilitacao is
'Copiada no momento do parecer. Se a pessoa mudar de habilitação depois, o parecer preserva a da época.';
comment on column minuta_pareceres.dispensado is
'A autoridade pode seguir sem parecer. A dispensa fica registrada — proteção dela, não do sistema.';

-- ---------------------------------------------------------------------------
-- 3. SOLICITAR PARECER
-- ---------------------------------------------------------------------------

create or replace function minuta_pedir_parecer(
  p_minuta      uuid,
  p_questao     text,
  p_usuario     uuid default null,        -- parecerista interno
  p_nome_externo text default null        -- ou externo
)
returns minuta_pareceres
language plpgsql
security definer
set search_path = public
as $$
declare
  v_solicitante uuid;
  v_papel text;
  v_linha minuta_pareceres;
  v_hab text; v_reg text;
begin
  select u.id, u.papel::text into v_solicitante, v_papel
  from usuarios u where u.auth_user_id = auth.uid() and u.ativo;

  if v_solicitante is null then
    raise exception 'Sem identidade ativa.';
  end if;

  -- Pedir parecer é ato de quem conduz a minuta
  if v_papel not in ('autoridade','chefe_gabinete') then
    raise exception 'Papel % não solicita parecer sobre minuta.', v_papel;
  end if;

  if p_questao is null or length(trim(p_questao)) < 10 then
    raise exception 'Informe sobre qual ponto se pede o parecer.';
  end if;

  if p_usuario is null and p_nome_externo is null then
    raise exception 'Informe o parecerista: usuário do gabinete ou nome do externo.';
  end if;

  -- Habilitação copiada no momento, para valer no tempo
  if p_usuario is not null then
    select u.habilitacao, u.habilitacao_registro into v_hab, v_reg
    from usuarios u where u.id = p_usuario;
  end if;

  insert into minuta_pareceres (
    minuta_id, tenant_id, solicitado_por, questao,
    parecerista_usuario, parecerista_nome,
    parecerista_habilitacao, parecerista_registro
  )
  select p_minuta, m.tenant_id, v_solicitante, p_questao,
         p_usuario, p_nome_externo, v_hab, v_reg
  from minutas m
  where m.id = p_minuta and m.tenant_id = evora_tenant_atual()
  returning * into v_linha;

  if v_linha.id is null then
    raise exception 'Minuta não encontrada neste gabinete.';
  end if;

  return v_linha;
end $$;

comment on function minuta_pedir_parecer is
'A autoridade pede parecer caso a caso. Funciona igual para parecerista interno ou externo.';

-- ---------------------------------------------------------------------------
-- 4. A MINUTA SABE SE TEM PARECER
-- ---------------------------------------------------------------------------
-- Não bloqueia a aprovação — informa. A decisão continua sendo da autoridade.

create or replace function minuta_situacao_parecer(p_minuta uuid)
returns table (
  tem_parecer_pendente boolean,
  tem_parecer_emitido  boolean,
  conclusao            text,
  ressalva             text,
  parecerista          text,
  habilitacao          text,
  dispensado           boolean,
  dispensa_motivo      text
)
language sql
stable
as $$
  select
    bool_or(p.emitido_em is null and not p.dispensado),
    bool_or(p.emitido_em is not null),
    (array_agg(p.conclusao::text order by p.emitido_em desc nulls last))[1],
    (array_agg(p.ressalva order by p.emitido_em desc nulls last))[1],
    (array_agg(coalesce(u.nome, p.parecerista_nome)
               order by p.emitido_em desc nulls last))[1],
    (array_agg(p.parecerista_habilitacao order by p.emitido_em desc nulls last))[1],
    bool_or(p.dispensado),
    (array_agg(p.dispensa_motivo order by p.dispensado_em desc nulls last))[1]
  from minuta_pareceres p
  left join usuarios u on u.id = p.parecerista_usuario
  where p.minuta_id = p_minuta;
$$;

comment on function minuta_situacao_parecer is
'Informa se há parecer e qual a conclusão. NÃO bloqueia a aprovação — a decisão é da autoridade.';

-- ---------------------------------------------------------------------------
-- 5. ISOLAMENTO
-- ---------------------------------------------------------------------------

alter table minuta_pareceres enable row level security;
alter table minuta_pareceres force  row level security;

drop policy if exists minuta_pareceres_isolamento on minuta_pareceres;
create policy minuta_pareceres_isolamento on minuta_pareceres
  for select to authenticated
  using (tenant_id = evora_tenant_atual());

grant select on minuta_pareceres to authenticated;
revoke all on minuta_pareceres from anon;
grant execute on function minuta_pedir_parecer(uuid, text, uuid, text) to authenticated;
grant execute on function minuta_situacao_parecer(uuid) to authenticated;

commit;

-- ═══════════════════════════════════════════════════════════════════════════
-- O QUE ESTA MIGRAÇÃO DELIBERADAMENTE NÃO FAZ
-- ═══════════════════════════════════════════════════════════════════════════
--
-- ✗ Não cria papel 'juridico'         — habilitação é da pessoa, não posição
-- ✗ Não cria estado 'aguardando_juridico' — parecer é evento, não etapa
-- ✗ Não bloqueia aprovação sem parecer — a autoridade decide
-- ✗ Não valida inscrição junto ao conselho — o sistema não afirma o que não verificou
-- ✗ Não faz o parecer aprovar nada     — diluiria a responsabilidade do eleito
--
-- Teste: evora_parecer_teste_aceite.sql
-- ═══════════════════════════════════════════════════════════════════════════
