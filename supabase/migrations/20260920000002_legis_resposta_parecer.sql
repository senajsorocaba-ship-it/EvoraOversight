-- Espelho INCREMENTAL de:
--   ao-SUPABASE-BLOCO1/AO SUPABASE BLOCO1.md.txt (tipos + colunas +
--     tabelas 28-38 + índices + triggers de minuta)
--   ao-SUPABASE-BLOCO1/evora rls mvp v1.sql (enable/force RLS + grants +
--     seções 21-23 — Inteligência Legislativa, Resposta/Minutas, Parecer)
-- NAO EDITAR AQUI. Editar os arquivos canonicos acima e copiar de novo.
--
-- Fase 13 (Manual v11.1): 3 módulos, adaptados de
-- _versoes_anteriores/legis_resposta_parecer_entregues_v11_1/
-- (11_legis_inteligencia.sql 12/12, 13_resposta_minutas.sql 12/12,
-- 15_parecer_evento.sql 11/11, todos entregues já testados). ÚNICA
-- ADAPTAÇÃO REAL: troca auth.uid() por evora_claims() ->> 'sub' em
-- minuta_decidir/minuta_pedir_parecer (mesmo idioma já usado no Aegis).
-- Depende de 20260920000001_veritas.sql já aplicada (legis_materias.
-- norma_relacionada e minutas.norma_id referenciam veritas_normas).

-- =====================================================================
-- BLOCO 1 — schema: tipos + colunas + tabelas 28-38 + índices + triggers
-- =====================================================================

do $$ begin
  create type legis_especie as enum (
    'projeto_lei','projeto_lei_complementar','proposta_emenda',
    'medida_provisoria','decreto_legislativo','resolucao',
    'requerimento','indicacao','mocao','veto',
    'parecer','substitutivo','emenda','relatorio','materia_correlata'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type legis_status_formal as enum (
    'em_tramitacao','aprovado','rejeitado','arquivado','retirado',
    'convertido_em_norma','vetado','aguardando_sancao','promulgado'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type legis_status_operacional as enum (
    'aguardando_parecer','aguardando_distribuicao','aguardando_pauta',
    'aguardando_votacao','aguardando_manifestacao_comissao',
    'sem_movimentacao_material','pauta_publicada','reuniao_agendada',
    'decisao_sem_data','dependente_de_outra_materia'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type legis_natureza_previsao as enum (
    'decisao_oficial_prevista', 'reuniao_agendada', 'pauta_publicada',
    'expectativa_nao_oficial', 'nenhuma_previsao'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type legis_natureza_orgao as enum (
    'comissao_permanente','comissao_temporaria','comissao_especial',
    'comissao_estudo','cpi','subcomissao','grupo_trabalho',
    'mesa_diretora','plenario','secretaria_legislativa','orgao_tecnico'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type legis_tipo_evento as enum (
    'apresentacao','distribuicao','designacao_relator','parecer_emitido',
    'pedido_vista','inclusao_pauta','retirada_pauta','votacao',
    'aprovacao','rejeicao','redistribuicao','devolucao','arquivamento',
    'desarquivamento','movimentacao_administrativa'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type evora_registro as enum ('simples', 'tecnico', 'ambos');
exception when duplicate_object then null; end $$;

do $$ begin
  create type minuta_especie as enum (
    'requerimento','oficio','pedido_informacao','indicacao','mocao',
    'nota_publica','relatorio'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type minuta_estado as enum (
    'rascunho','aguardando_aprovacao','aprovada','descartada','protocolada'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type minuta_parecer_conclusao as enum (
    'favoravel', 'favoravel_com_ressalva', 'contrario', 'inconclusivo'
  );
exception when duplicate_object then null; end $$;

alter table tenants
  add column if not exists registro_padrao evora_registro not null default 'ambos';
comment on column tenants.registro_padrao is 'Fase 13 — registro de linguagem do gabinete (simples/tecnico/ambos). Definido na Entrevista de Fundação.';

alter table usuarios
  add column if not exists registro_preferido evora_registro,
  add column if not exists habilitacao text,
  add column if not exists habilitacao_registro text;
comment on column usuarios.registro_preferido is 'Fase 13 — sobrepõe o padrão do tenant. Nulo = usa o do gabinete.';
comment on column usuarios.habilitacao is 'Fase 13 — qualificação profissional da pessoa. NÃO é papel: não altera alçada.';
comment on column usuarios.habilitacao_registro is 'Fase 13 — número de inscrição profissional, quando houver. Informativo.';

alter table briefings
  add column if not exists registro_entregue evora_registro,
  add column if not exists markdown_tecnico text,
  add column if not exists html_tecnico text;
comment on column briefings.registro_entregue is 'Fase 13 — qual registro a autoridade recebeu.';
comment on column briefings.markdown_tecnico is 'Fase 13 — versão técnica, quando o registro for tecnico ou ambos.';

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
comment on table legis_pessoas is 'Fase 13 — § 40 da Skill. Parlamentares, relatores e autoridades.';

create table if not exists legis_orgaos (
  id            uuid primary key default gen_random_uuid(),
  territorio_id uuid not null references farus_territorios(id) on delete restrict,
  nome          text not null,
  natureza      legis_natureza_orgao not null,
  competencia   text,
  criado_em_ato text,
  inicio        date,
  termino       date,
  fonte_url     text,
  registrado_em timestamptz not null default now()
);
comment on table legis_orgaos is 'Fase 13 — § 7 e § 10. Comissões, CPIs, grupos de trabalho, órgãos técnicos.';

create table if not exists legis_composicoes (
  id          uuid primary key default gen_random_uuid(),
  orgao_id    uuid not null references legis_orgaos(id) on delete cascade,
  pessoa_id   uuid not null references legis_pessoas(id) on delete restrict,
  papel       text not null,
  inicio      date not null,
  termino     date,
  substituiu  uuid references legis_pessoas(id) on delete set null,
  fonte_url   text,
  registrado_em timestamptz not null default now(),
  constraint legis_comp_periodo check (termino is null or termino >= inicio)
);
comment on table legis_composicoes is 'Fase 13 — § 7. Composição versionada por período.';

create table if not exists legis_materias (
  id            uuid primary key default gen_random_uuid(),
  territorio_id uuid not null references farus_territorios(id) on delete restrict,
  especie       legis_especie not null,
  numero        text,
  ano           integer,
  processo      text,
  ementa        text not null,
  assunto       text[],
  autor_id      uuid references legis_pessoas(id) on delete set null,
  coautores     uuid[],
  status_formal      legis_status_formal not null default 'em_tramitacao',
  status_operacional legis_status_operacional,
  orgao_atual_id uuid references legis_orgaos(id) on delete set null,
  relator_id     uuid references legis_pessoas(id) on delete set null,
  relator_desde  date,
  materia_anterior uuid references legis_materias(id) on delete set null,
  norma_relacionada uuid references veritas_normas(id) on delete set null,
  fonte_url      text,
  apresentada_em date,
  capturada_em   timestamptz not null default now(),
  verificado_por text,
  verificado_em  timestamptz,
  constraint legis_materia_nao_circular check (materia_anterior is distinct from id),
  constraint legis_materia_verificacao check (
    verificado_por is null or verificado_em is not null
  )
);
comment on column legis_materias.status_formal is 'Fase 13 — § 5. O que a Casa declara. NUNCA deduzir o operacional a partir deste campo.';
comment on column legis_materias.status_operacional is 'Fase 13 — § 5. Onde a matéria realmente está.';

create table if not exists legis_eventos (
  id          uuid primary key default gen_random_uuid(),
  materia_id  uuid not null references legis_materias(id) on delete cascade,
  tipo        legis_tipo_evento not null,
  ocorrido_em date not null,
  orgao_id    uuid references legis_orgaos(id) on delete set null,
  pessoa_id   uuid references legis_pessoas(id) on delete set null,
  descricao   text,
  material    boolean not null default true,
  fonte_url   text,
  capturado_em timestamptz not null default now()
);
comment on column legis_eventos.material is 'Fase 13 — § 6. false para juntada, numeração e conferência.';

create table if not exists legis_pareceres (
  id          uuid primary key default gen_random_uuid(),
  materia_id  uuid not null references legis_materias(id) on delete cascade,
  orgao_id    uuid references legis_orgaos(id) on delete set null,
  relator_id  uuid references legis_pessoas(id) on delete set null,
  tipo        text not null,
  conclusao   text,
  emitido_em  date,
  fonte_url   text,
  capturado_em timestamptz not null default now()
);

create table if not exists legis_pautas (
  id            uuid primary key default gen_random_uuid(),
  territorio_id uuid not null references farus_territorios(id) on delete restrict,
  orgao_id      uuid references legis_orgaos(id) on delete set null,
  sessao_numero text,
  sessao_tipo   text,
  realizada_em  date not null,
  horario       time,
  publicada_em  timestamptz,
  versao        text,
  fonte_url     text,
  capturada_em  timestamptz not null default now()
);

create table if not exists legis_pauta_materias (
  id          uuid primary key default gen_random_uuid(),
  pauta_id    uuid not null references legis_pautas(id) on delete cascade,
  materia_id  uuid not null references legis_materias(id) on delete cascade,
  ordem       integer,
  fase        text,
  natureza_previsao legis_natureza_previsao not null,
  resultado   text,
  observacao  text,
  constraint legis_pauta_materia_unica unique (pauta_id, materia_id)
);
comment on column legis_pauta_materias.natureza_previsao is 'Fase 13 — § 9 e § 42. Nunca converter reunião marcada em votação garantida.';

create table if not exists minutas (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references tenants(id) on delete cascade,
  mundo       evora_mundo not null default 'gabinete',
  especie     minuta_especie not null,
  assunto     text not null,
  destinatario text,
  texto_simples text,
  texto_tecnico text,
  materia_id  uuid references legis_materias(id) on delete set null,
  item_farus  uuid references farus_itens(id) on delete set null,
  norma_id    uuid references veritas_normas(id) on delete set null,
  fundamento  text,
  estado      minuta_estado not null default 'rascunho',
  gerada_em   timestamptz not null default now(),
  gerada_por  text not null default 'motor',
  submetida_em timestamptz,
  decidida_por uuid references usuarios(id) on delete set null,
  decidida_em timestamptz,
  motivo_decisao text,
  protocolo_informado text,
  protocolo_em        date,
  constraint minuta_decisao_registrada check (
    estado not in ('aprovada','descartada')
    or (decidida_por is not null and decidida_em is not null)
  ),
  constraint minuta_descarte_com_motivo check (
    estado <> 'descartada' or motivo_decisao is not null
  ),
  constraint minuta_protocolo_exige_aprovacao check (
    estado <> 'protocolada' or decidida_por is not null
  ),
  constraint minuta_tem_texto check (
    texto_simples is not null or texto_tecnico is not null
  ),
  constraint minuta_tem_origem check (
    materia_id is not null or item_farus is not null or norma_id is not null
  )
);
comment on table minutas is 'Fase 13 — § 2 e § 36 da Skill. Documentos para aprovação humana. O Évora nunca envia.';
comment on column minutas.protocolo_informado is 'Fase 13 — preenchido pela PESSOA, após protocolar fora do sistema.';

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
comment on table minuta_eventos is 'Fase 13 — trilha de mudança de estado da minuta. Append-only.';

create table if not exists minuta_pareceres (
  id          uuid primary key default gen_random_uuid(),
  minuta_id   uuid not null references minutas(id) on delete cascade,
  tenant_id   uuid not null references tenants(id) on delete cascade,
  solicitado_por uuid not null references usuarios(id) on delete restrict,
  solicitado_em  timestamptz not null default now(),
  questao        text not null,
  parecerista_usuario uuid references usuarios(id) on delete set null,
  parecerista_nome    text,
  parecerista_habilitacao text,
  parecerista_registro    text,
  conclusao   minuta_parecer_conclusao,
  texto       text,
  ressalva    text,
  emitido_em  timestamptz,
  dispensado          boolean not null default false,
  dispensa_motivo     text,
  dispensado_por      uuid references usuarios(id) on delete set null,
  dispensado_em       timestamptz,
  criado_em   timestamptz not null default now(),
  constraint parecer_tem_autor check (
    emitido_em is null
    or parecerista_usuario is not null
    or (parecerista_nome is not null and length(trim(parecerista_nome)) > 2)
  ),
  constraint parecer_emitido_completo check (
    emitido_em is null or (conclusao is not null and texto is not null)
  ),
  constraint parecer_ressalva_explicita check (
    conclusao <> 'favoravel_com_ressalva' or ressalva is not null
  ),
  constraint parecer_dispensa_registrada check (
    not dispensado
    or (dispensa_motivo is not null and dispensado_por is not null
        and dispensado_em is not null)
  ),
  constraint parecer_nao_emitido_e_dispensado check (
    not (dispensado and emitido_em is not null)
  )
);
comment on table minuta_pareceres is 'Fase 13 — parecer é EVENTO solicitado caso a caso, não etapa obrigatória. Não aprova.';
comment on column minuta_pareceres.parecerista_habilitacao is 'Fase 13 — copiada no momento do parecer, vale no tempo.';
comment on column minuta_pareceres.dispensado is 'Fase 13 — a autoridade pode seguir sem parecer, com motivo registrado.';

create unique index if not exists ix_legis_pessoa_unica on legis_pessoas (territorio_id, lower(nome));
create unique index if not exists ix_legis_orgao_unico on legis_orgaos (territorio_id, lower(nome), coalesce(inicio, '1900-01-01'::date));
create index if not exists ix_legis_comp_periodo on legis_composicoes (orgao_id, inicio, termino);
create unique index if not exists ix_legis_materia_unica on legis_materias (territorio_id, especie, coalesce(numero,''), coalesce(ano,0));
create index if not exists ix_legis_materia_ementa on legis_materias using gin (to_tsvector('portuguese', ementa));
create index if not exists ix_legis_materia_assunto on legis_materias using gin (assunto);
create index if not exists ix_legis_materia_autor on legis_materias (autor_id);
create index if not exists ix_legis_materia_relator on legis_materias (relator_id);
create index if not exists ix_legis_materia_orgao on legis_materias (orgao_atual_id);
create index if not exists ix_legis_evento_materia on legis_eventos (materia_id, ocorrido_em desc);
create index if not exists ix_legis_evento_material on legis_eventos (materia_id, ocorrido_em desc) where material;
create index if not exists ix_legis_parecer_materia on legis_pareceres (materia_id, emitido_em desc);
create index if not exists ix_legis_pauta_data on legis_pautas (territorio_id, realizada_em desc);
create index if not exists ix_minutas_tenant on minutas (tenant_id, estado, gerada_em desc);
create index if not exists ix_minutas_pendentes on minutas (tenant_id) where estado = 'aguardando_aprovacao';
create index if not exists ix_minuta_eventos on minuta_eventos (minuta_id, ocorrido_em desc);
create index if not exists ix_minuta_pareceres on minuta_pareceres (minuta_id, criado_em desc);
create index if not exists ix_pareceres_pendentes on minuta_pareceres (tenant_id) where emitido_em is null and not dispensado;

create or replace function minuta_trilha_imutavel()
returns trigger language plpgsql as $$
begin
  raise exception 'Trilha de minuta é imutável. Tentativa de % rejeitada.', tg_op;
end $$;

drop trigger if exists trg_minuta_trilha on minuta_eventos;
create trigger trg_minuta_trilha
  before update or delete on minuta_eventos
  for each row execute function minuta_trilha_imutavel();

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

-- =====================================================================
-- BLOCO 2 — RLS: enable/force + policies + grants + funções
-- =====================================================================

alter table legis_pessoas        enable row level security;
alter table legis_orgaos         enable row level security;
alter table legis_composicoes    enable row level security;
alter table legis_materias       enable row level security;
alter table legis_eventos        enable row level security;
alter table legis_pareceres      enable row level security;
alter table legis_pautas         enable row level security;
alter table legis_pauta_materias enable row level security;
alter table minutas           enable row level security;
alter table minuta_eventos    enable row level security;
alter table minuta_pareceres  enable row level security;
alter table legis_pessoas        force row level security;
alter table legis_orgaos         force row level security;
alter table legis_composicoes    force row level security;
alter table legis_materias       force row level security;
alter table legis_eventos        force row level security;
alter table legis_pareceres      force row level security;
alter table legis_pautas         force row level security;
alter table legis_pauta_materias force row level security;
alter table minutas           force row level security;
alter table minuta_eventos    force row level security;
alter table minuta_pareceres  force row level security;

grant select on legis_pessoas, legis_orgaos, legis_composicoes, legis_materias,
  legis_eventos, legis_pareceres, legis_pautas, legis_pauta_materias
  to authenticated;
grant select on minutas, minuta_eventos, minuta_pareceres to authenticated;

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

drop policy if exists minutas_isolamento on minutas;
create policy minutas_isolamento on minutas
  for select to authenticated
  using (tenant_id = evora_tenant_atual()
         and (mundo = evora_mundo_atual() or evora_mundo_atual() is null));

drop policy if exists minuta_eventos_leitura on minuta_eventos;
create policy minuta_eventos_leitura on minuta_eventos
  for select to authenticated
  using (tenant_id = evora_tenant_atual());

drop policy if exists minuta_pareceres_isolamento on minuta_pareceres;
create policy minuta_pareceres_isolamento on minuta_pareceres
  for select to authenticated
  using (tenant_id = evora_tenant_atual());

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
    and m.verificado_por is not null
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

revoke execute on function legis_situacao_real(uuid) from public, anon;
grant execute on function legis_situacao_real(uuid) to authenticated;
revoke execute on function legis_composicao_em(uuid, date) from public, anon;
grant execute on function legis_composicao_em(uuid, date) to authenticated;
revoke execute on function legis_buscar(text, uuid, integer) from public, anon;
grant execute on function legis_buscar(text, uuid, integer) to authenticated;
revoke execute on function legis_materias_da_pessoa(uuid) from public, anon;
grant execute on function legis_materias_da_pessoa(uuid) to authenticated;
revoke execute on function legis_materias_do_orgao(uuid) from public, anon;
grant execute on function legis_materias_do_orgao(uuid) to authenticated;

create or replace function evora_registro_de(p_usuario uuid)
returns evora_registro
language sql
stable
as $$
  select coalesce(u.registro_preferido, t.registro_padrao, 'ambos'::evora_registro)
  from usuarios u join tenants t on t.id = u.tenant_id
  where u.id = p_usuario;
$$;

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
  from usuarios u
  where u.auth_user_id = nullif(evora_claims() ->> 'sub', '')::uuid
    and u.ativo;

  if v_usuario is null then
    raise exception 'Sem identidade ativa.';
  end if;

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

create or replace function minuta_pedir_parecer(
  p_minuta      uuid,
  p_questao     text,
  p_usuario     uuid default null,
  p_nome_externo text default null
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
  from usuarios u
  where u.auth_user_id = nullif(evora_claims() ->> 'sub', '')::uuid
    and u.ativo;

  if v_solicitante is null then
    raise exception 'Sem identidade ativa.';
  end if;

  if v_papel not in ('autoridade','chefe_gabinete') then
    raise exception 'Papel % não solicita parecer sobre minuta.', v_papel;
  end if;

  if p_questao is null or length(trim(p_questao)) < 10 then
    raise exception 'Informe sobre qual ponto se pede o parecer.';
  end if;

  if p_usuario is null and p_nome_externo is null then
    raise exception 'Informe o parecerista: usuário do gabinete ou nome do externo.';
  end if;

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

revoke execute on function minuta_decidir(uuid, minuta_estado, text) from public, anon;
grant execute on function minuta_decidir(uuid, minuta_estado, text) to authenticated;
revoke execute on function evora_registro_de(uuid) from public, anon;
grant execute on function evora_registro_de(uuid) to authenticated;
revoke execute on function minuta_pedir_parecer(uuid, text, uuid, text) from public, anon;
grant execute on function minuta_pedir_parecer(uuid, text, uuid, text) to authenticated;
revoke execute on function minuta_situacao_parecer(uuid) from public, anon;
grant execute on function minuta_situacao_parecer(uuid) to authenticated;
