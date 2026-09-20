-- Espelho INCREMENTAL de:
--   ao-SUPABASE-BLOCO1/AO SUPABASE BLOCO1.md.txt (tipos veritas_* + tabelas
--     25-27 + índices + trigger de imutabilidade de veritas_carga)
--   ao-SUPABASE-BLOCO1/evora rls mvp v1.sql (enable/force RLS nas 3 tabelas,
--     seção 20 — veritas_consultar/veritas_vigente_em)
-- NAO EDITAR AQUI. Editar os arquivos canonicos acima e copiar de novo.
--
-- Fase 12 (Manual v11.0): VERITAS — acervo legal curado. Irmão do FARUS,
-- não sucessor: FARUS guarda O QUE ACONTECEU (nunca envelhece); Veritas
-- guarda O QUE VALE (envelhece — norma revogada servida como vigente
-- produz resposta errada). Carga sempre curada, nunca automática — feita
-- por ao-SUPABASE-BLOCO1/extrator_veritas.py (3 etapas, a do meio humana).
-- Depende de 20260903000001_farus_f1.sql já aplicada (referencia
-- farus_territorios e reusa farus_territorios_do_tenant()).

-- =====================================================================
-- BLOCO 1 — schema: tipos + tabelas 25-27 + índices + trigger
-- =====================================================================

do $$ begin
  create type veritas_especie as enum (
    'resolucao', 'lei_complementar', 'lei_organica', 'lei_ordinaria',
    'decreto_legislativo', 'decreto', 'portaria', 'ato_da_mesa'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type veritas_situacao as enum ('vigente', 'alterada', 'revogada');
exception when duplicate_object then null; end $$;

do $$ begin
  create type veritas_nivel as enum ('artigo', 'paragrafo', 'inciso', 'alinea', 'item');
exception when duplicate_object then null; end $$;

create table if not exists veritas_normas (
  id                uuid primary key default gen_random_uuid(),
  territorio_id     uuid not null references farus_territorios(id) on delete restrict,
  especie           veritas_especie not null,
  numero            text,
  ano               integer,
  ementa            text not null,
  apelido           text,
  situacao          veritas_situacao not null default 'vigente',
  data_publicacao   date,
  vigencia_inicio   date not null,
  vigencia_fim      date,
  texto_integral    text,
  url_oficial       text not null,
  consultado_em     timestamptz,
  carregado_por     text not null,
  verificado_por    text not null,
  verificado_em     timestamptz not null,
  criado_em         timestamptz not null default now(),
  constraint veritas_norma_vigencia_coerente
    check (vigencia_fim is null or vigencia_fim >= vigencia_inicio)
);

comment on table veritas_normas is 'Fase 12 — o Veritas: acervo legal curado, uma linha por VERSÃO da norma. Carga sempre curada (extrator_veritas.py), nunca ingestão automática.';
comment on column veritas_normas.situacao is 'vigente = em vigor hoje; alterada = ainda vale mas foi emendada por norma posterior; revogada = não vale mais. veritas_consultar só devolve situacao = vigente.';
comment on column veritas_normas.vigencia_inicio is 'Início da janela em que ESTA VERSÃO do texto valeu — não necessariamente a data de publicação da norma original.';

create table if not exists veritas_dispositivos (
  id          uuid primary key default gen_random_uuid(),
  norma_id    uuid not null references veritas_normas(id) on delete cascade,
  nivel       veritas_nivel not null,
  rotulo      text not null,
  artigo_pai  text,
  ordem       integer not null,
  texto       text not null
);

comment on table veritas_dispositivos is 'Fase 12 — dispositivos (artigo/parágrafo/inciso/alínea/item) de uma versão de norma do Veritas.';

create table if not exists veritas_carga (
  id            uuid primary key default gen_random_uuid(),
  norma_id      uuid not null references veritas_normas(id) on delete cascade,
  territorio_id uuid not null references farus_territorios(id) on delete restrict,
  origem_url    text not null,
  metodo        text not null default 'extracao',
  quem          text not null,
  resultado     text not null default 'sucesso',
  ocorrido_em   timestamptz not null default now()
);

comment on table veritas_carga is 'Fase 12 — trilha de carregamento do Veritas. Append-only (trigger abaixo).';

create index if not exists ix_veritas_normas_territorio on veritas_normas (territorio_id, situacao);
create index if not exists ix_veritas_normas_url_versao on veritas_normas (url_oficial, verificado_em desc);
create index if not exists ix_veritas_normas_busca on veritas_normas using gin (to_tsvector('portuguese', ementa));
create index if not exists ix_veritas_dispositivos_norma on veritas_dispositivos (norma_id, ordem);
create index if not exists ix_veritas_dispositivos_busca on veritas_dispositivos using gin (to_tsvector('portuguese', texto));
create index if not exists ix_veritas_carga_norma on veritas_carga (norma_id, ocorrido_em desc);

-- Só a trilha (veritas_carga) é imutável — veritas_normas/veritas_dispositivos
-- de propósito NÃO recebem esta trigger (uma norma carregada errado precisa
-- poder ser corrigida via SQL direto; só a prova de quem carregou é que
-- nunca pode ser apagada).
create or replace function veritas_carga_imutavel()
returns trigger language plpgsql as $$
begin
  raise exception 'Trilha de carga do Veritas é imutável. Tentativa de % rejeitada.', tg_op;
end $$;

drop trigger if exists trg_veritas_carga_imutavel on veritas_carga;
create trigger trg_veritas_carga_imutavel
  before update or delete on veritas_carga
  for each row execute function veritas_carga_imutavel();

-- =====================================================================
-- BLOCO 2 — RLS: enable/force sem policy nenhuma (mesmo padrão do Aegis,
-- "ausência é a proteção") + funções de leitura security definer
-- =====================================================================

alter table veritas_normas       enable row level security;
alter table veritas_dispositivos enable row level security;
alter table veritas_carga        enable row level security;
alter table veritas_normas       force row level security;
alter table veritas_dispositivos force row level security;
alter table veritas_carga        force row level security;

create or replace function veritas_consultar(
  p_termo        text,
  p_territorio_id uuid,
  p_limite       int default 5
)
returns table (
  norma_id           uuid,
  especie            veritas_especie,
  numero             text,
  ano                integer,
  apelido            text,
  ementa             text,
  dispositivo_nivel  veritas_nivel,
  dispositivo_rotulo text,
  dispositivo_texto  text,
  verificado_por     text,
  url_oficial        text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_territorio_id not in (select farus_territorios_do_tenant()) then
    raise exception 'Território fora do que este gabinete acompanha.';
  end if;

  return query
  select n.id, n.especie, n.numero, n.ano, n.apelido, n.ementa,
         d.nivel, d.rotulo, d.texto, n.verificado_por, n.url_oficial
  from veritas_normas n
  join veritas_dispositivos d on d.norma_id = n.id
  where n.territorio_id = p_territorio_id
    and n.situacao = 'vigente'
    and to_tsvector('portuguese', d.texto || ' ' || n.ementa)
        @@ plainto_tsquery('portuguese', p_termo)
  order by ts_rank(
    to_tsvector('portuguese', d.texto || ' ' || n.ementa),
    plainto_tsquery('portuguese', p_termo)
  ) desc
  limit p_limite;
end;
$$;

comment on function veritas_consultar(text, uuid, int) is
  'Fase 12 — única forma de a aplicação ler o Veritas. Só devolve norma/dispositivo vigente, verificado por pessoa, do território que o tenant acompanha.';

create or replace function veritas_vigente_em(
  p_norma_id uuid,
  p_data     date
)
returns table (
  norma_id           uuid,
  especie            veritas_especie,
  numero             text,
  ano                integer,
  situacao           veritas_situacao,
  vigencia_inicio    date,
  vigencia_fim       date,
  dispositivo_nivel  veritas_nivel,
  dispositivo_rotulo text,
  dispositivo_texto  text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_ref record;
begin
  select especie, numero, ano, territorio_id into v_ref
  from veritas_normas where id = p_norma_id;

  if not found then
    raise exception 'Norma % não encontrada.', p_norma_id;
  end if;

  if v_ref.territorio_id not in (select farus_territorios_do_tenant()) then
    raise exception 'Território fora do que este gabinete acompanha.';
  end if;

  return query
  select n.id, n.especie, n.numero, n.ano, n.situacao,
         n.vigencia_inicio, n.vigencia_fim,
         d.nivel, d.rotulo, d.texto
  from veritas_normas n
  join veritas_dispositivos d on d.norma_id = n.id
  where n.especie = v_ref.especie
    and coalesce(n.numero, '') = coalesce(v_ref.numero, '')
    and coalesce(n.ano, 0)     = coalesce(v_ref.ano, 0)
    and n.vigencia_inicio <= p_data
    and (n.vigencia_fim is null or n.vigencia_fim > p_data)
  order by d.ordem;
end;
$$;

comment on function veritas_vigente_em(uuid, date) is
  'Fase 12 — devolve a versão da norma (mesma espécie+número+ano de p_norma_id) que valia em p_data, com seus dispositivos. Para auditar ato antigo com o texto que valia na época.';

revoke execute on function veritas_consultar(text, uuid, int) from public, anon;
grant execute on function veritas_consultar(text, uuid, int) to authenticated;
revoke execute on function veritas_vigente_em(uuid, date) from public, anon;
grant execute on function veritas_vigente_em(uuid, date) to authenticated;
