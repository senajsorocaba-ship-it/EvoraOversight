-- Espelho INCREMENTAL gerado de: ao-SUPABASE-BLOCO1/AO SUPABASE BLOCO1.md.txt
-- (tabelas 14-16) + ao-SUPABASE-BLOCO1/evora rls mvp v1.sql (trechos novos)
-- NAO EDITAR AQUI. Editar os arquivos canonicos acima e copiar de novo.
--
-- Fase 7 do plano de testes: Atlas Municipal do Brasil (Anexo 16), migrado
-- do protótipo em arquivo (`atlas municipal.py`) para o banco. Este arquivo
-- é incremental (só o que mudou), igual às migrations 3 e 4 anteriores —
-- não repete o conteúdo das migrations 1/2.

-- =====================================================================
-- BLOCO 1 — schema: tabelas 14-16
-- =====================================================================

-- ---------------------------------------------------------------------
-- 14. MUNICIPIOS — Atlas Municipal (Anexo 16). CAMADA COMPARTILHADA DA
-- PLATAFORMA: fatos públicos sobre a cidade, NÃO do tenant. Por isso, ao
-- contrário de toda tabela de conteúdo acima, esta e as duas seguintes
-- NÃO carregam tenant_id nem mundo — mesma exceção que `tenants` já é,
-- pelo mesmo motivo (ver comment on table tenants acima). Colunas reais
-- só para o que algo consulta estruturalmente (nome/uf/slug/codigo_ibge);
-- o resto fica em jsonb por seção, no formato {valor,fonte,selo,data} que
-- o protótipo em arquivo (`atlas municipal.py`, migrado nesta Fase 7) já
-- usa — mesmo precedente de tenants.perfil jsonb.
--
-- mapa_politico_factual fica presente na FORMA (compatibilidade com o
-- protótipo) mas SEM ingestão nesta fase: não existe coletor de TSE no
-- repositório, e o CLAUDE.md deste schema proíbe fabricar dado antes de
-- existir um coletor real. diario_oficial.conector_com idem — "a
-- escrever" em todo o projeto (nenhum conector de Diário Oficial existe).
-- ---------------------------------------------------------------------
create table if not exists municipios (
  id                     uuid primary key default gen_random_uuid(),
  nome                   text not null,
  uf                     char(2) not null,
  slug                   text not null unique,                -- ex.: 'sorocaba-sp'
  codigo_ibge            text,
  identificacao          jsonb not null default '{}'::jsonb,  -- regiao, microrregiao, populacao
  executivo              jsonb not null default '{}'::jsonb,  -- prefeito, vice, cnpj_prefeitura, portal, secretarias[]
  legislativo            jsonb not null default '{}'::jsonb,  -- num_vereadores, presidente_camara, composicao_partidaria[], portal, sistema_tramitacao
  diario_oficial         jsonb not null default '{}'::jsonb,  -- onde_publica, formato, plataforma, periodicidade, conector_com
  contratacoes           jsonb not null default '{}'::jsonb,  -- cnpjs_pncp[] {orgao, cnpj:{valor,fonte,selo,data}}
  mapa_politico_factual  jsonb not null default '{}'::jsonb,  -- ultima_eleicao_municipal, eleitos[] — sem ingestão nesta fase
  ativo                  boolean not null default true,
  criado_em              timestamptz not null default now(),
  atualizado_em          timestamptz not null default now()
);

comment on table municipios is 'Atlas Municipal (Anexo 16) — camada compartilhada da plataforma, NÃO do tenant. Selo/procedência de cada campo vivem dentro do jsonb como {valor,fonte,selo,data}, mesmo formato do protótipo em arquivo que esta tabela substitui.';
comment on column municipios.mapa_politico_factual is 'Estrutura presente para compatibilidade com o protótipo (Anexo 16 §4); SEM ingestão automatizada nesta fase — não existe coletor de TSE no projeto. Não fabricar dado aqui.';

-- ---------------------------------------------------------------------
-- 15. MUNICIPIO_FONTES — veículos de mídia F1/F2 do Atlas (Anexo 16 §3).
-- Espelha as colunas de `fontes` (tabela 3), mas com uma correção: o
-- check `fontes_f3_nunca_compartilhada` de lá é tautológico (mundo nunca
-- é null, então nunca dispara de verdade). Aqui a trava é incondicional,
-- porque esta tabela SÓ existe como camada compartilhada — F3 nunca pode
-- ser uma linha aqui, ponto final.
-- ---------------------------------------------------------------------
create table if not exists municipio_fontes (
  id                   uuid primary key default gen_random_uuid(),
  municipio_id         uuid not null references municipios(id),
  nome                 text not null,
  url                  text,
  nivel                evora_nivel_fonte not null default 'F2',  -- F1/F2 apenas (ver check abaixo)
  cobertura            text,
  evidencia_cobertura  text,                          -- obrigatória para F2
  cnpj                 text,
  situacao_receita     text,
  cnae                 text,
  cnae_descricao       text,
  identificacao        text not null default 'pendente',  -- verificada | pendente
  fonte                text,                           -- proveniência do próprio registro do Atlas
  selo                 evora_selo_cvi not null default 'a_confirmar',
  proxima_revalidacao  date,
  ativa                boolean not null default true,
  criada_em            timestamptz not null default now(),
  atualizado_em        timestamptz not null default now(),
  constraint municipio_fontes_nunca_f3
    check (nivel <> 'F3'),                            -- incondicional — corrige a versão tautológica de `fontes`
  constraint municipio_fontes_f2_exige_evidencia
    check (nivel <> 'F2' or evidencia_cobertura is not null),
  constraint municipio_fontes_verificado_exige_fonte
    check (selo <> 'verificado' or fonte is not null),
  unique (municipio_id, nome)
);

comment on constraint municipio_fontes_nunca_f3 on municipio_fontes is 'Anexo 16 §3: F3 (influencer/perfil pessoal) nunca é compartilhado — vive só no perfil isolado do tenant.';

-- ---------------------------------------------------------------------
-- 16. MUNICIPIO_TRILHA — trilha de edição imutável do Atlas. Proteção
-- anti-envenenamento: como o Atlas serve todos os tenants de uma cidade,
-- uma edição ruim contaminaria o briefing de todos de uma vez, então
-- toda mudança fica registrada, só INSERT. Análoga a `auditoria`, mas
-- por municipio_id em vez de tenant_id — não dá pra reusar `auditoria`
-- aqui sem afrouxar sua FK obrigatória, e o Atlas não pertence a
-- nenhum tenant.
-- ---------------------------------------------------------------------
create table if not exists municipio_trilha (
  id            uuid primary key default gen_random_uuid(),
  municipio_id  uuid not null references municipios(id),
  ocorrido_em   timestamptz not null default now(),
  acao          text not null,
  autor         text not null,
  obs           text
);

comment on table municipio_trilha is 'Trilha imutável de edição do Atlas (Anexo 16). Só INSERT — nem RLS nem grant liberam UPDATE/DELETE para nenhuma role de cliente.';

-- índices
create index if not exists idx_municipios_uf              on municipios(uf) where ativo;
create index if not exists idx_municipio_fontes_municipio  on municipio_fontes(municipio_id) where ativa;
create index if not exists idx_municipio_trilha_municipio  on municipio_trilha(municipio_id, ocorrido_em desc);

-- triggers atualizado_em (evora_toca_atualizado_em() já existe desde a migration 1)
drop trigger if exists trg_municipios_atualizado on municipios;
create trigger trg_municipios_atualizado before update on municipios
  for each row execute function evora_toca_atualizado_em();

drop trigger if exists trg_municipio_fontes_atualizado on municipio_fontes;
create trigger trg_municipio_fontes_atualizado before update on municipio_fontes
  for each row execute function evora_toca_atualizado_em();

-- =====================================================================
-- BLOCO 2 — RLS: enable/force, grants, policies para as 3 tabelas novas
-- + correção de um gap pré-existente (achados_fiscalizacao/mencoes_imprensa
-- estavam enabled mas não forced desde a Fase 6)
-- =====================================================================

-- service_role: a migration 2 (20260818000002_rls.sql) já rodou seu
-- "grant all privileges on all tables in schema public to service_role"
-- ANTES de estas 3 tabelas existirem — GRANT não é retroativo a tabelas
-- criadas depois. Sem esta linha, service_role toma "permission denied"
-- nas tabelas novas mesmo sendo a role que ignora RLS por design. O
-- arquivo canônico completo (BLOCO 1 + BLOCO 2 rodados do zero, em
-- ordem, num projeto novo) não tem este problema, porque lá as 16
-- tabelas já existem todas antes do grant geral rodar — o gap é
-- específico desta migration incremental.
grant all privileges on municipios, municipio_fontes, municipio_trilha to service_role;

alter table municipios            enable row level security;
alter table municipio_fontes      enable row level security;
alter table municipio_trilha      enable row level security;

alter table achados_fiscalizacao  force row level security;  -- gap da Fase 6, corrigido aqui
alter table mencoes_imprensa      force row level security;  -- gap da Fase 6, corrigido aqui
alter table municipios            force row level security;
alter table municipio_fontes      force row level security;
alter table municipio_trilha      force row level security;

-- Atlas Municipal (Anexo 16, Fase 7): leitura aberta a QUALQUER tenant
-- autenticado — é o ponto todo do Atlas, dado de cidade não é isolado por
-- tenant. Escrita travada ao service_role só: sem insert/update/delete
-- para authenticated aqui, a trava anti-envenenamento começa neste
-- grant, antes mesmo da RLS.
grant select on municipios, municipio_fontes to authenticated;
-- municipio_trilha: SEM grant para authenticated nesta fase — não existe
-- visualizador (nenhuma UI foi construída na Fase 7).

drop policy if exists municipios_leitura_publica on municipios;
create policy municipios_leitura_publica on municipios
  for select using (true);

drop policy if exists municipio_fontes_leitura_publica on municipio_fontes;
create policy municipio_fontes_leitura_publica on municipio_fontes
  for select using (true);

-- municipio_trilha: nenhuma policy — sem grant para authenticated (acima)
-- e RLS enabled+forced já nega tudo por padrão. Só service_role lê/escreve.
