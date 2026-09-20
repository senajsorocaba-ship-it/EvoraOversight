-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVORA OVERSIGHT — INTELIGÊNCIA LEGISLATIVA
-- Implementa a Skill "evora-veritas-inteligencia-legislativa" v1.0 GOLD
-- ═══════════════════════════════════════════════════════════════════════════
--
-- ── A LACUNA QUE ESTA MIGRAÇÃO FECHA ─────────────────────────────────────
-- O FARUS guarda FATOS (o que foi publicado). O Veritas guarda NORMAS (o que
-- vale). Mas não existia onde morar a MATÉRIA — a proposição com sua
-- tramitação, comissão, relator e status.
--
-- Sem a matéria, as seções 4, 5, 6, 7 e 12 da Skill não funcionam:
-- identificar matéria sem o número, distinguir status formal de operacional,
-- detectar matéria parada, lembrar quem compunha a comissão à época, e fazer
-- pesquisa reversa.
--
-- ── AS DUAS TRAVAS CENTRAIS DA SKILL ─────────────────────────────────────
--
-- § 5 — STATUS FORMAL ≠ STATUS OPERACIONAL
--   "em tramitação" não significa que esteja avançando. O banco guarda os
--   dois separadamente e nunca deduz um do outro.
--
-- § 9 — PREVISÃO DE DECISÃO TEM CINCO NATUREZAS
--   Decisão oficial prevista · reunião agendada · pauta publicada ·
--   expectativa não oficial · nenhuma previsão. Nunca converter expectativa
--   em previsão oficial.
--
-- § 7 — MEMÓRIA TEMPORAL DA COMISSÃO
--   "Quem fazia parte quando a matéria foi analisada?" é pergunta diferente
--   de "quem faz parte hoje?". A composição é versionada por período.
--
-- ORDEM: rodar depois do schema, RLS, hook, FARUS, Aegis e Veritas.
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- ---------------------------------------------------------------------------
-- 1. TIPOS
-- ---------------------------------------------------------------------------

-- § 4 — espécies de matéria, conforme o ente legislativo
do $$ begin
  create type legis_especie as enum (
    'projeto_lei','projeto_lei_complementar','proposta_emenda',
    'medida_provisoria','decreto_legislativo','resolucao',
    'requerimento','indicacao','mocao','veto',
    'parecer','substitutivo','emenda','relatorio','materia_correlata'
  );
exception when duplicate_object then null; end $$;

-- § 5 — STATUS FORMAL: o que a Casa declara
do $$ begin
  create type legis_status_formal as enum (
    'em_tramitacao','aprovado','rejeitado','arquivado','retirado',
    'convertido_em_norma','vetado','aguardando_sancao','promulgado'
  );
exception when duplicate_object then null; end $$;

-- § 5 — STATUS OPERACIONAL: onde a matéria realmente está
-- NUNCA é deduzido do formal. São dimensões independentes.
do $$ begin
  create type legis_status_operacional as enum (
    'aguardando_parecer','aguardando_distribuicao','aguardando_pauta',
    'aguardando_votacao','aguardando_manifestacao_comissao',
    'sem_movimentacao_material','pauta_publicada','reuniao_agendada',
    'decisao_sem_data','dependente_de_outra_materia'
  );
exception when duplicate_object then null; end $$;

-- § 9 — as CINCO naturezas de previsão. A trava contra converter
-- expectativa em previsão oficial vive aqui.
do $$ begin
  create type legis_natureza_previsao as enum (
    'decisao_oficial_prevista',   -- A · há informação oficial de data
    'reuniao_agendada',           -- B · há reunião, a matéria pode não constar
    'pauta_publicada',            -- C · a matéria está expressamente incluída
    'expectativa_nao_oficial',    -- D · indicação pública, sem confirmação
    'nenhuma_previsao'            -- E · nada localizado
  );
exception when duplicate_object then null; end $$;

-- § 7 e § 10 — natureza do órgão
do $$ begin
  create type legis_natureza_orgao as enum (
    'comissao_permanente','comissao_temporaria','comissao_especial',
    'comissao_estudo','cpi','subcomissao','grupo_trabalho',
    'mesa_diretora','plenario','secretaria_legislativa','orgao_tecnico'
  );
exception when duplicate_object then null; end $$;

-- § 8 — eventos de tramitação
do $$ begin
  create type legis_tipo_evento as enum (
    'apresentacao','distribuicao','designacao_relator','parecer_emitido',
    'pedido_vista','inclusao_pauta','retirada_pauta','votacao',
    'aprovacao','rejeicao','redistribuicao','devolucao','arquivamento',
    'desarquivamento','movimentacao_administrativa'
  );
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- 2. PESSOAS E ÓRGÃOS
-- ---------------------------------------------------------------------------

create table if not exists legis_pessoas (
  id            uuid primary key default gen_random_uuid(),
  territorio_id uuid not null references farus_territorios(id) on delete restrict,
  nome          text not null,
  partido       text,
  cargo         text,
  ativo         boolean not null default true,
  fonte_url     text,
  verificado_por text,
  criado_em     timestamptz not null default now()
);

create unique index if not exists ix_legis_pessoa_unica
  on legis_pessoas (territorio_id, lower(nome));

comment on table legis_pessoas is
'§ 40 — entidade Person. Parlamentares, relatores e autoridades. Partido vem da própria pauta.';

create table if not exists legis_orgaos (
  id            uuid primary key default gen_random_uuid(),
  territorio_id uuid not null references farus_territorios(id) on delete restrict,
  nome          text not null,
  natureza      legis_natureza_orgao not null,
  competencia   text,
  -- § 10 — órgão temporário tem começo e fim
  criado_em_ato text,
  inicio        date,
  termino       date,
  fonte_url     text,
  registrado_em timestamptz not null default now()
);

create unique index if not exists ix_legis_orgao_unico
  on legis_orgaos (territorio_id, lower(nome), coalesce(inicio, '1900-01-01'::date));

comment on table legis_orgaos is
'§ 7 e § 10 — comissões permanentes, temporárias, CPIs, grupos de trabalho e órgãos técnicos.';

-- ---------------------------------------------------------------------------
-- 3. COMPOSIÇÃO COM MEMÓRIA TEMPORAL — § 7
-- ---------------------------------------------------------------------------
-- A Skill é explícita: "nunca substituir simplesmente a composição histórica
-- pela atual". O sistema precisa responder quem compunha a comissão QUANDO a
-- matéria foi analisada, não apenas quem compõe hoje.

create table if not exists legis_composicoes (
  id          uuid primary key default gen_random_uuid(),
  orgao_id    uuid not null references legis_orgaos(id) on delete cascade,
  pessoa_id   uuid not null references legis_pessoas(id) on delete restrict,
  papel       text not null,              -- presidente · vice · titular · suplente
  inicio      date not null,
  termino     date,                       -- nulo = ainda em exercício
  substituiu  uuid references legis_pessoas(id) on delete set null,
  fonte_url   text,
  registrado_em timestamptz not null default now(),

  -- TRAVA: período coerente
  constraint legis_comp_periodo check (termino is null or termino >= inicio)
);

create index if not exists ix_legis_comp_periodo
  on legis_composicoes (orgao_id, inicio, termino);

comment on table legis_composicoes is
'§ 7 — composição versionada por período. Responde "quem fazia parte à época", não só "quem faz hoje".';

-- ---------------------------------------------------------------------------
-- 4. A MATÉRIA — § 4, § 5, § 40
-- ---------------------------------------------------------------------------

create table if not exists legis_materias (
  id            uuid primary key default gen_random_uuid(),
  territorio_id uuid not null references farus_territorios(id) on delete restrict,

  -- § 4 — identificação; a matéria deve ser localizável sem o número
  especie       legis_especie not null,
  numero        text,
  ano           integer,
  processo      text,                     -- número do processo na Casa
  ementa        text not null,
  assunto       text[],                   -- palavras-chave para busca por tema
  autor_id      uuid references legis_pessoas(id) on delete set null,
  coautores     uuid[],

  -- § 5 — AS DUAS DIMENSÕES, INDEPENDENTES
  status_formal      legis_status_formal not null default 'em_tramitacao',
  status_operacional legis_status_operacional,

  -- localização atual
  orgao_atual_id uuid references legis_orgaos(id) on delete set null,
  relator_id     uuid references legis_pessoas(id) on delete set null,
  relator_desde  date,

  -- § 13 — memória legislativa: matéria reapresentada
  materia_anterior uuid references legis_materias(id) on delete set null,

  -- § 15 — relação com o acervo normativo
  norma_relacionada uuid references veritas_normas(id) on delete set null,

  -- § 39 — rastreabilidade
  fonte_url      text,
  apresentada_em date,
  capturada_em   timestamptz not null default now(),
  verificado_por text,
  verificado_em  timestamptz,

  -- TRAVA § 20: matéria não pode ser sua própria antecessora
  constraint legis_materia_nao_circular check (materia_anterior is distinct from id),

  -- TRAVA § 44: só afirma o que foi verificado
  constraint legis_materia_verificacao check (
    verificado_por is null or verificado_em is not null
  )
);

create unique index if not exists ix_legis_materia_unica
  on legis_materias (territorio_id, especie, coalesce(numero,''), coalesce(ano,0));

-- § 4 — busca por tema, sem o número
create index if not exists ix_legis_materia_ementa
  on legis_materias using gin (to_tsvector('portuguese', ementa));
create index if not exists ix_legis_materia_assunto
  on legis_materias using gin (assunto);

-- § 12 — pesquisa reversa: pessoa → matérias
create index if not exists ix_legis_materia_autor on legis_materias (autor_id);
create index if not exists ix_legis_materia_relator on legis_materias (relator_id);
create index if not exists ix_legis_materia_orgao on legis_materias (orgao_atual_id);

comment on column legis_materias.status_formal is
'§ 5 — o que a Casa declara. NUNCA deduzir o operacional a partir deste campo.';
comment on column legis_materias.status_operacional is
'§ 5 — onde a matéria realmente está. Constar como "em tramitação" não significa avançar.';

-- ---------------------------------------------------------------------------
-- 5. EVENTOS DE TRAMITAÇÃO — § 6, § 8
-- ---------------------------------------------------------------------------
-- O campo `material` é a chave da detecção de matéria parada: movimentação
-- administrativa (juntada, numeração, conferência) NÃO conta como avanço.

create table if not exists legis_eventos (
  id          uuid primary key default gen_random_uuid(),
  materia_id  uuid not null references legis_materias(id) on delete cascade,
  tipo        legis_tipo_evento not null,
  ocorrido_em date not null,
  orgao_id    uuid references legis_orgaos(id) on delete set null,
  pessoa_id   uuid references legis_pessoas(id) on delete set null,
  descricao   text,

  -- § 6 — distingue avanço real de movimentação meramente administrativa
  material    boolean not null default true,

  fonte_url   text,
  capturado_em timestamptz not null default now()
);

create index if not exists ix_legis_evento_materia
  on legis_eventos (materia_id, ocorrido_em desc);
create index if not exists ix_legis_evento_material
  on legis_eventos (materia_id, ocorrido_em desc) where material;

comment on column legis_eventos.material is
'§ 6 — false para juntada, numeração e conferência. Movimentação administrativa não é avanço.';

-- ---------------------------------------------------------------------------
-- 6. PARECERES — § 8
-- ---------------------------------------------------------------------------

create table if not exists legis_pareceres (
  id          uuid primary key default gen_random_uuid(),
  materia_id  uuid not null references legis_materias(id) on delete cascade,
  orgao_id    uuid references legis_orgaos(id) on delete set null,
  relator_id  uuid references legis_pessoas(id) on delete set null,
  tipo        text not null,              -- parecer · relatório · voto · substitutivo
  conclusao   text,                       -- favorável · contrário · com emendas
  emitido_em  date,
  fonte_url   text,
  capturado_em timestamptz not null default now()
);

create index if not exists ix_legis_parecer_materia on legis_pareceres (materia_id, emitido_em desc);

-- ---------------------------------------------------------------------------
-- 7. PAUTAS E PREVISÕES — § 9
-- ---------------------------------------------------------------------------

create table if not exists legis_pautas (
  id            uuid primary key default gen_random_uuid(),
  territorio_id uuid not null references farus_territorios(id) on delete restrict,
  orgao_id      uuid references legis_orgaos(id) on delete set null,
  sessao_numero text,
  sessao_tipo   text,                     -- ordinária · extraordinária
  realizada_em  date not null,
  horario       time,
  publicada_em  timestamptz,              -- data e hora exatas da publicação
  versao        text,                     -- 'completa' · 'resumida' · 'resumida_atualizada'
  fonte_url     text,
  capturada_em  timestamptz not null default now()
);

create index if not exists ix_legis_pauta_data on legis_pautas (territorio_id, realizada_em desc);

-- Matéria incluída na pauta, com a natureza da previsão
create table if not exists legis_pauta_materias (
  id          uuid primary key default gen_random_uuid(),
  pauta_id    uuid not null references legis_pautas(id) on delete cascade,
  materia_id  uuid not null references legis_materias(id) on delete cascade,
  ordem       integer,
  fase        text,                       -- 1ª discussão · 2ª discussão · votação única
  natureza_previsao legis_natureza_previsao not null,
  resultado   text,                       -- preenchido após a sessão
  observacao  text,

  constraint legis_pauta_materia_unica unique (pauta_id, materia_id)
);

comment on column legis_pauta_materias.natureza_previsao is
'§ 9 e § 42 — nunca converter reunião marcada em votação garantida, nem expectativa em previsão oficial.';

-- ---------------------------------------------------------------------------
-- 8. § 6 — DETECÇÃO DE MATÉRIA PARADA
-- ---------------------------------------------------------------------------
-- A Skill proíbe chamar matéria de "parada" sem verificar o histórico.
-- Esta função devolve os elementos para a resposta, nunca o julgamento.

create or replace function legis_situacao_real(p_materia uuid)
returns table (
  status_formal          text,
  status_operacional     text,
  ultimo_evento_material text,
  ultima_data_material   date,
  dias_sem_movimento     integer,
  eventos_administrativos_depois integer,
  orgao_atual            text,
  relator                text,
  tem_parecer            boolean,
  proxima_pauta          date,
  natureza_previsao      text
)
language sql
stable
as $$
  with ultimo_material as (
    select e.tipo::text as tipo, e.ocorrido_em
    from legis_eventos e
    where e.materia_id = p_materia and e.material
    order by e.ocorrido_em desc limit 1
  ),
  admin_depois as (
    select count(*)::int as n
    from legis_eventos e, ultimo_material um
    where e.materia_id = p_materia and not e.material
      and e.ocorrido_em > um.ocorrido_em
  ),
  prox as (
    select p.realizada_em, pm.natureza_previsao::text
    from legis_pauta_materias pm
    join legis_pautas p on p.id = pm.pauta_id
    where pm.materia_id = p_materia and p.realizada_em >= current_date
    order by p.realizada_em limit 1
  )
  select
    m.status_formal::text,
    m.status_operacional::text,
    um.tipo,
    um.ocorrido_em,
    (current_date - um.ocorrido_em)::int,
    coalesce(ad.n, 0),
    o.nome,
    r.nome,
    exists (select 1 from legis_pareceres pa where pa.materia_id = p_materia),
    prox.realizada_em,
    coalesce(prox.natureza_previsao, 'nenhuma_previsao')
  from legis_materias m
  left join ultimo_material um on true
  left join admin_depois ad on true
  left join prox on true
  left join legis_orgaos o on o.id = m.orgao_atual_id
  left join legis_pessoas r on r.id = m.relator_id
  where m.id = p_materia;
$$;

comment on function legis_situacao_real is
'§ 6 — devolve os elementos da situação. O julgamento "está parada" é da pessoa, nunca do banco.';

-- ---------------------------------------------------------------------------
-- 9. § 7 — COMPOSIÇÃO DA COMISSÃO EM DATA PASSADA
-- ---------------------------------------------------------------------------

create or replace function legis_composicao_em(p_orgao uuid, p_data date)
returns table (pessoa text, partido text, papel text)
language sql
stable
as $$
  select p.nome, p.partido, c.papel
  from legis_composicoes c
  join legis_pessoas p on p.id = c.pessoa_id
  where c.orgao_id = p_orgao
    and c.inicio <= p_data
    and (c.termino is null or c.termino >= p_data)
  order by
    case c.papel when 'presidente' then 1 when 'vice-presidente' then 2
                 when 'relator' then 3 when 'titular' then 4 else 5 end,
    p.nome;
$$;

comment on function legis_composicao_em is
'§ 7 — "quem fazia parte quando a matéria foi analisada?" — não confundir com a composição atual.';

-- ---------------------------------------------------------------------------
-- 10. § 4 e § 11 — BUSCA POR TEMA, SEM O NÚMERO
-- ---------------------------------------------------------------------------

create or replace function legis_buscar(
  p_termo      text,
  p_territorio uuid default null,
  p_limite     integer default 10
)
returns table (
  materia_id uuid, identificacao text, ementa text,
  autor text, status_formal text, status_operacional text,
  orgao text, dias_sem_movimento integer, fonte text
)
language sql
stable
as $$
  select
    m.id,
    m.especie::text || ' ' || coalesce(m.numero,'') ||
      coalesce('/' || m.ano::text, ''),
    m.ementa,
    a.nome,
    m.status_formal::text,
    m.status_operacional::text,
    o.nome,
    (select (current_date - max(e.ocorrido_em))::int
       from legis_eventos e where e.materia_id = m.id and e.material),
    m.fonte_url
  from legis_materias m
  left join legis_pessoas a on a.id = m.autor_id
  left join legis_orgaos o on o.id = m.orgao_atual_id
  where (p_territorio is null or m.territorio_id = p_territorio)
    and m.verificado_por is not null          -- § 44: só o verificado responde
    and (
      to_tsvector('portuguese', m.ementa) @@ plainto_tsquery('portuguese', p_termo)
      or m.assunto && string_to_array(lower(p_termo), ' ')
      or m.numero = p_termo
      or m.processo = p_termo
    )
  order by
    ts_rank(to_tsvector('portuguese', m.ementa),
            plainto_tsquery('portuguese', p_termo)) desc
  limit p_limite;
$$;

comment on function legis_buscar is
'§ 4 e § 11 — localiza a matéria sem o número: por tema, ementa, palavra-chave, número ou processo.';

-- ---------------------------------------------------------------------------
-- 11. § 12 — PESQUISA REVERSA
-- ---------------------------------------------------------------------------

create or replace function legis_materias_da_pessoa(p_pessoa uuid)
returns table (identificacao text, ementa text, papel text, status text)
language sql stable as $$
  select m.especie::text || ' ' || coalesce(m.numero,'') || coalesce('/'||m.ano::text,''),
         m.ementa,
         case when m.autor_id = p_pessoa then 'autor'
              when m.relator_id = p_pessoa then 'relator'
              else 'coautor' end,
         m.status_formal::text
  from legis_materias m
  where m.autor_id = p_pessoa or m.relator_id = p_pessoa
     or p_pessoa = any(m.coautores)
  order by m.apresentada_em desc nulls last;
$$;

create or replace function legis_materias_do_orgao(p_orgao uuid)
returns table (identificacao text, ementa text, status text, quando date)
language sql stable as $$
  select distinct
    m.especie::text || ' ' || coalesce(m.numero,'') || coalesce('/'||m.ano::text,''),
    m.ementa, m.status_formal::text,
    (select max(e.ocorrido_em) from legis_eventos e
      where e.materia_id = m.id and e.orgao_id = p_orgao)
  from legis_materias m
  where m.orgao_atual_id = p_orgao
     or exists (select 1 from legis_eventos e
                 where e.materia_id = m.id and e.orgao_id = p_orgao)
  order by 4 desc nulls last;
$$;

comment on function legis_materias_da_pessoa is '§ 12 — pesquisa reversa: pessoa → matérias.';
comment on function legis_materias_do_orgao is '§ 12 — pesquisa reversa: comissão → matérias.';

-- ---------------------------------------------------------------------------
-- 12. ISOLAMENTO
-- ---------------------------------------------------------------------------

alter table legis_pessoas        enable row level security;
alter table legis_pessoas        force  row level security;
alter table legis_orgaos         enable row level security;
alter table legis_orgaos         force  row level security;
alter table legis_composicoes    enable row level security;
alter table legis_composicoes    force  row level security;
alter table legis_materias       enable row level security;
alter table legis_materias       force  row level security;
alter table legis_eventos        enable row level security;
alter table legis_eventos        force  row level security;
alter table legis_pareceres      enable row level security;
alter table legis_pareceres      force  row level security;
alter table legis_pautas         enable row level security;
alter table legis_pautas         force  row level security;
alter table legis_pauta_materias enable row level security;
alter table legis_pauta_materias force  row level security;

-- § 32 — compartilhado por município, como o FARUS e o Veritas.
-- A pauta da Câmara de Sorocaba é a mesma para todos os vereadores da cidade.
drop policy if exists legis_pessoas_leitura on legis_pessoas;
create policy legis_pessoas_leitura on legis_pessoas for select to authenticated
  using (territorio_id in (select farus_territorios_do_tenant()));

drop policy if exists legis_orgaos_leitura on legis_orgaos;
create policy legis_orgaos_leitura on legis_orgaos for select to authenticated
  using (territorio_id in (select farus_territorios_do_tenant()));

drop policy if exists legis_materias_leitura on legis_materias;
create policy legis_materias_leitura on legis_materias for select to authenticated
  using (territorio_id in (select farus_territorios_do_tenant()));

drop policy if exists legis_pautas_leitura on legis_pautas;
create policy legis_pautas_leitura on legis_pautas for select to authenticated
  using (territorio_id in (select farus_territorios_do_tenant()));

drop policy if exists legis_comp_leitura on legis_composicoes;
create policy legis_comp_leitura on legis_composicoes for select to authenticated
  using (orgao_id in (select o.id from legis_orgaos o
          where o.territorio_id in (select farus_territorios_do_tenant())));

drop policy if exists legis_eventos_leitura on legis_eventos;
create policy legis_eventos_leitura on legis_eventos for select to authenticated
  using (materia_id in (select m.id from legis_materias m
          where m.territorio_id in (select farus_territorios_do_tenant())));

drop policy if exists legis_pareceres_leitura on legis_pareceres;
create policy legis_pareceres_leitura on legis_pareceres for select to authenticated
  using (materia_id in (select m.id from legis_materias m
          where m.territorio_id in (select farus_territorios_do_tenant())));

drop policy if exists legis_pm_leitura on legis_pauta_materias;
create policy legis_pm_leitura on legis_pauta_materias for select to authenticated
  using (pauta_id in (select p.id from legis_pautas p
          where p.territorio_id in (select farus_territorios_do_tenant())));

-- Escrita é do motor (service_role). Nenhuma política de INSERT/UPDATE/DELETE.

-- ---------------------------------------------------------------------------
-- 13. PERMISSÕES
-- ---------------------------------------------------------------------------

grant select on legis_pessoas, legis_orgaos, legis_composicoes, legis_materias,
                legis_eventos, legis_pareceres, legis_pautas, legis_pauta_materias
  to authenticated;
revoke all on legis_pessoas, legis_orgaos, legis_composicoes, legis_materias,
              legis_eventos, legis_pareceres, legis_pautas, legis_pauta_materias
  from anon;
grant execute on function legis_situacao_real(uuid) to authenticated;
grant execute on function legis_composicao_em(uuid, date) to authenticated;
grant execute on function legis_buscar(text, uuid, integer) to authenticated;
grant execute on function legis_materias_da_pessoa(uuid) to authenticated;
grant execute on function legis_materias_do_orgao(uuid) to authenticated;

commit;

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICAÇÃO
-- ═══════════════════════════════════════════════════════════════════════════
--   select count(*) from information_schema.tables where table_name like 'legis%';  -- 8
--   select count(*) from pg_policies where tablename like 'legis%';                 -- 8
-- Teste completo: evora_legis_teste_aceite.sql
-- ═══════════════════════════════════════════════════════════════════════════
