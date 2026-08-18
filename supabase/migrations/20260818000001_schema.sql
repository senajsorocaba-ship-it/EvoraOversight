-- Espelho gerado de: ao-SUPABASE-BLOCO1/AO SUPABASE BLOCO1.md.txt (BLOCO 1 - schema)
-- NAO EDITAR AQUI. Editar o arquivo canonico acima e copiar de novo.

-- =====================================================================
-- ÉVORA OVERSIGHT — SCHEMA DO NÚCLEO (MVP)
-- Arquivo: evora_schema_mvp_v1.sql
-- Versão:  v1.0 · 20/07/2026 · alinhado ao Manual Supremo v10.6
-- =====================================================================
--
-- Cria as 11 TABELAS OFICIAIS do núcleo (contagem ratificada no Anexo 14
-- da v10.6; guias antigos falavam em 12 — a lista nominal sempre teve 11):
--
--   1. tenants                 7. compromissos
--   2. usuarios                8. atas
--   3. fontes                  9. desdobramentos
--   4. briefings              10. desdobramento_eventos
--   5. demandas               11. auditoria
--   6. lugares
--
-- PRINCÍPIOS QUE ESTE SCHEMA RESPEITA (não quebrar sem decisão do fundador):
--
--  1. MULTI-TENANT — toda linha de conteúdo pertence a um tenant_id.
--  2. SEPARAÇÃO DE MUNDOS — tabelas de conteúdo carregam `mundo`
--     (gabinete | campanha). É o Princípio Inviolável nº 4 em forma de coluna.
--  3. DOIS NÍVEIS DE SEPARAÇÃO — tenants.nivel_separacao = 'logico'
--     (padrão/MVP) ou 'fisico' (premium). O mesmo schema serve aos dois.
--     Depende do parecer da pergunta P25 (Dra. Íria).
--  4. LGPD PREPARADA — `demandas` já tem consentimento, base legal, marcação
--     de dado sensível e retenção. NÃO usar dado real de cidadão antes do
--     parecer (P8/P9). Testar com dados fictícios.
--  5. NADA É APAGADO — soft delete (ativo/ativa) em vez de DELETE.
--     `auditoria` é imutável: só INSERT (garantido por trigger e por RLS).
--  6. FONTE OU SILÊNCIO — campos de proveniência (fonte, url, selo CVI,
--     consultado_em) acompanham o dado que veio de fora.
--
-- ORDEM DE EXECUÇÃO: este arquivo primeiro; depois evora_rls_mvp_v1.sql.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. EXTENSÕES E TIPOS
-- ---------------------------------------------------------------------
create extension if not exists "pgcrypto";     -- gen_random_uuid()

do $$ begin
  create type evora_mundo as enum ('gabinete', 'campanha');
exception when duplicate_object then null; end $$;

do $$ begin
  create type evora_nivel_separacao as enum ('logico', 'fisico');
exception when duplicate_object then null; end $$;

do $$ begin
  create type evora_papel as enum
    ('autoridade', 'chefe_gabinete', 'assessor', 'operador_vrx', 'auditor', 'convidado');
exception when duplicate_object then null; end $$;

do $$ begin
  create type evora_selo_cvi as enum ('verificado', 'a_confirmar', 'descartado');
exception when duplicate_object then null; end $$;

do $$ begin
  create type evora_nivel_fonte as enum ('F1', 'F2', 'F3', 'oficial');
exception when duplicate_object then null; end $$;

do $$ begin
  create type evora_status_demanda as enum
    ('registrada', 'em_andamento', 'aguardando_terceiro', 'resolvida', 'nao_atendida');
exception when duplicate_object then null; end $$;

do $$ begin
  create type evora_status_desdobramento as enum
    ('aberto', 'em_andamento', 'concluido', 'cancelado');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- 1. TENANTS — cada gabinete cliente
-- ---------------------------------------------------------------------
create table if not exists tenants (
  id                 uuid primary key default gen_random_uuid(),
  slug               text not null unique,           -- ex.: 'tatiane-costa-sorocaba'
  nome_autoridade    text not null,
  cargo              text,
  partido            text,
  municipio_sede     text not null,
  uf                 char(2) not null,
  area_atuacao       jsonb not null default '[]'::jsonb,  -- multi-município (Anexo 16 §5)
  nivel_separacao    evora_nivel_separacao not null default 'logico',
  perfil             jsonb not null default '{}'::jsonb,  -- o perfil_<tenant>.json inteiro
  ciencia_travas     boolean not null default false,      -- decisão D5: sem isto, não opera
  ciencia_data       timestamptz,
  operacional        boolean not null default false,
  ativo              boolean not null default true,       -- soft delete
  criado_em          timestamptz not null default now(),
  atualizado_em      timestamptz not null default now(),
  constraint tenants_ciencia_coerente
    check (operacional = false or ciencia_travas = true)  -- trava D5 no banco
);

comment on table  tenants is 'Gabinetes clientes. operacional só pode ser true se ciencia_travas for true (decisão D5, Anexo 16 §5).';
comment on column tenants.nivel_separacao is 'logico = MVP; fisico = premium. Depende do parecer P25.';

-- ---------------------------------------------------------------------
-- 2. USUARIOS — quem entra no sistema, e com que papel
-- ---------------------------------------------------------------------
create table if not exists usuarios (
  id                 uuid primary key default gen_random_uuid(),
  tenant_id          uuid not null references tenants(id),
  auth_user_id       uuid,                       -- vínculo com auth.users do Supabase
  nome               text not null,
  email              text not null,
  papel              evora_papel not null default 'assessor',
  mundo_permitido    evora_mundo,                -- null = ambos (só autoridade/auditor)
  alcada_aprovacao   boolean not null default false,  -- pode dar o freio humano?
  ativo              boolean not null default true,
  ultimo_acesso      timestamptz,
  criado_em          timestamptz not null default now(),
  unique (tenant_id, email)
);

comment on column usuarios.mundo_permitido is 'Separação de mundos por pessoa. NULL só para papéis que legitimamente veem os dois (autoridade, auditor).';

-- ---------------------------------------------------------------------
-- 3. FONTES — a Central de Inteligência de Fontes por tenant
-- ---------------------------------------------------------------------
create table if not exists fontes (
  id                 uuid primary key default gen_random_uuid(),
  tenant_id          uuid not null references tenants(id),
  mundo              evora_mundo not null default 'gabinete',
  nome               text not null,
  url                text,
  nivel              evora_nivel_fonte not null default 'F2',  -- F1/F2/F3 (Anexo 16 §3)
  esfera             text,                       -- municipal | regional | estadual | federal
  cobertura          text,                       -- o que o veículo cobre (teste de entrada)
  evidencia_cobertura text,                      -- obrigatória para F2
  cnpj               text,                       -- identificação, não credencial de qualidade
  situacao_receita   text,
  cnae               text,
  identificacao      text not null default 'pendente',  -- verificada | pendente
  procedencia        text not null default 'declarado', -- declarado | atlas | verificado
  selo               evora_selo_cvi not null default 'a_confirmar',
  proxima_revalidacao date,                      -- CNPJ: revalidação semestral
  prioridade         smallint not null default 5,
  ativa              boolean not null default true,     -- soft delete
  criada_em          timestamptz not null default now(),
  constraint fontes_f2_exige_evidencia
    check (nivel <> 'F2' or evidencia_cobertura is not null),
  constraint fontes_f3_nunca_compartilhada
    check (nivel <> 'F3' or mundo is not null)   -- F3 vive no tenant, nunca no Atlas
);

comment on constraint fontes_f2_exige_evidencia on fontes is 'Anexo 16 §3: F2 exige evidência de cobertura arquivada.';

-- ---------------------------------------------------------------------
-- 4. BRIEFINGS — cada edição entregue
-- ---------------------------------------------------------------------
create table if not exists briefings (
  id                 uuid primary key default gen_random_uuid(),
  tenant_id          uuid not null references tenants(id),
  mundo              evora_mundo not null default 'gabinete',
  data_referencia    date not null,
  gerado_em          timestamptz not null default now(),
  entregue_em        timestamptz,
  blocos             jsonb not null default '[]'::jsonb,  -- os 7 blocos canônicos
  markdown           text,
  html               text,
  aprovado_por       uuid references usuarios(id),        -- FREIO HUMANO
  aprovado_em        timestamptz,
  modelo_ia          text,
  custo_estimado     numeric(10,4),
  ativo              boolean not null default true,
  unique (tenant_id, mundo, data_referencia)
);

comment on column briefings.aprovado_por is 'Freio humano: briefing sem aprovação não deve ser entregue.';

-- ---------------------------------------------------------------------
-- 5. DEMANDAS — pedidos do cidadão (módulo com gatilho LGPD)
-- ---------------------------------------------------------------------
create table if not exists demandas (
  id                 uuid primary key default gen_random_uuid(),
  tenant_id          uuid not null references tenants(id),
  mundo              evora_mundo not null default 'gabinete',
  protocolo          text not null,
  titulo             text not null,
  descricao          text,
  tema               text,
  bairro             text,
  urgencia           smallint not null default 3,       -- 1 alta .. 5 baixa
  status             evora_status_demanda not null default 'registrada',
  responsavel_id     uuid references usuarios(id),
  prazo              date,
  resolvida_em       timestamptz,
  retorno_ao_cidadao text,
  -- --- bloco LGPD (preencher conforme parecer P8/P9) ---
  cidadao_nome       text,
  cidadao_contato    text,
  consentimento      boolean not null default false,
  consentimento_data timestamptz,
  base_legal         text,                              -- a definir no parecer
  dado_sensivel      boolean not null default false,
  retencao_ate       date,
  -- ----------------------------------------------------
  registrada_por     uuid references usuarios(id),
  ativa              boolean not null default true,
  criada_em          timestamptz not null default now(),
  atualizada_em      timestamptz not null default now(),
  unique (tenant_id, protocolo),
  constraint demandas_dado_pessoal_exige_consentimento
    check (cidadao_nome is null or consentimento = true)
);

comment on constraint demandas_dado_pessoal_exige_consentimento on demandas is
  'Sem consentimento registrado, não se grava dado pessoal identificado. LGPD desde o dia 1 (ADC-g).';

-- ---------------------------------------------------------------------
-- 6. LUGARES — locais recorrentes (base da agenda)
-- ---------------------------------------------------------------------
create table if not exists lugares (
  id                 uuid primary key default gen_random_uuid(),
  tenant_id          uuid not null references tenants(id),
  nome               text not null,
  endereco           text,
  municipio          text,
  uf                 char(2),
  latitude           numeric(9,6),
  longitude          numeric(9,6),
  observacoes        text,
  ativo              boolean not null default true,
  criado_em          timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 7. COMPROMISSOS — a agenda (AAG-g)
-- ---------------------------------------------------------------------
create table if not exists compromissos (
  id                 uuid primary key default gen_random_uuid(),
  tenant_id          uuid not null references tenants(id),
  mundo              evora_mundo not null default 'gabinete',
  titulo             text not null,
  descricao          text,
  lugar_id           uuid references lugares(id),
  inicio             timestamptz not null,
  fim                timestamptz,
  com_quem           text,
  pauta              text,
  quem_anotou        uuid references usuarios(id),
  confirmado         boolean not null default false,
  confirmado_por     uuid references usuarios(id),      -- só a autoridade confirma a dela
  prioridade         smallint not null default 3,
  adiado_de          timestamptz,                        -- histórico de adiamento
  cancelado          boolean not null default false,
  motivo_cancelamento text,
  ativo              boolean not null default true,
  criado_em          timestamptz not null default now(),
  constraint compromissos_fim_depois_do_inicio check (fim is null or fim >= inicio)
);

-- ---------------------------------------------------------------------
-- 8. ATAS — registro do que se passou em reunião/compromisso
-- ---------------------------------------------------------------------
create table if not exists atas (
  id                 uuid primary key default gen_random_uuid(),
  tenant_id          uuid not null references tenants(id),
  mundo              evora_mundo not null default 'gabinete',
  compromisso_id     uuid references compromissos(id),
  titulo             text not null,
  conteudo           text,
  participantes      jsonb not null default '[]'::jsonb,
  redigida_por       uuid references usuarios(id),
  aprovada_por       uuid references usuarios(id),
  aprovada_em        timestamptz,
  ativa              boolean not null default true,
  criada_em          timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 9. DESDOBRAMENTOS — o que nasceu de uma ata, demanda ou briefing
-- ---------------------------------------------------------------------
create table if not exists desdobramentos (
  id                 uuid primary key default gen_random_uuid(),
  tenant_id          uuid not null references tenants(id),
  mundo              evora_mundo not null default 'gabinete',
  origem_tipo        text not null,               -- ata | demanda | briefing | manual
  origem_id          uuid,
  titulo             text not null,
  descricao          text,
  responsavel_id     uuid references usuarios(id),
  prazo              date,
  status             evora_status_desdobramento not null default 'aberto',
  concluido_em       timestamptz,
  ativo              boolean not null default true,
  criado_em          timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 10. DESDOBRAMENTO_EVENTOS — a linha do tempo de cada desdobramento
-- ---------------------------------------------------------------------
create table if not exists desdobramento_eventos (
  id                 uuid primary key default gen_random_uuid(),
  tenant_id          uuid not null references tenants(id),
  desdobramento_id   uuid not null references desdobramentos(id),
  evento             text not null,               -- criado | cobrado | atualizado | concluido
  detalhe            text,
  autor_id           uuid references usuarios(id),
  ocorrido_em        timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 11. AUDITORIA — trilha imutável (AAS-Évora / AAudLog-sis)
-- ---------------------------------------------------------------------
create table if not exists auditoria (
  id                 bigserial primary key,
  tenant_id          uuid references tenants(id),
  mundo              evora_mundo,
  ator_id            uuid references usuarios(id),
  ator_descricao     text,                        -- quando não há usuário (job, agente)
  acao               text not null,               -- login | leitura | criacao | aprovacao | recusa | travessia_ponte
  entidade           text,                        -- tabela ou objeto afetado
  entidade_id        text,
  detalhe            jsonb not null default '{}'::jsonb,
  ip                 inet,
  ocorrido_em        timestamptz not null default now()
);

comment on table auditoria is 'Trilha imutável: só INSERT. UPDATE e DELETE bloqueados por trigger e por RLS. Nem o criador reescreve.';

-- Trigger que torna a auditoria imutável no próprio banco
create or replace function evora_auditoria_imutavel()
returns trigger language plpgsql as $$
begin
  raise exception 'A tabela auditoria e imutavel: somente INSERT e permitido (AAS-Evora).';
end $$;

drop trigger if exists trg_auditoria_sem_update on auditoria;
create trigger trg_auditoria_sem_update
  before update or delete on auditoria
  for each row execute function evora_auditoria_imutavel();

-- Segundo trigger, em nível de COMANDO: dispara mesmo quando o RLS já
-- filtrou todas as linhas. Sem ele, um UPDATE indevido retornaria
-- "UPDATE 0" silenciosamente — seguro, porém mudo. Aqui a tentativa
-- falha alto, e um erro de aplicação aparece em vez de passar batido.
drop trigger if exists trg_auditoria_sem_update_cmd on auditoria;
create trigger trg_auditoria_sem_update_cmd
  before update or delete on auditoria
  for each statement execute function evora_auditoria_imutavel();

-- ---------------------------------------------------------------------
-- ÍNDICES — consultas do dia a dia
-- ---------------------------------------------------------------------
create index if not exists idx_usuarios_tenant        on usuarios(tenant_id) where ativo;
create index if not exists idx_fontes_tenant_mundo    on fontes(tenant_id, mundo) where ativa;
create index if not exists idx_briefings_tenant_data  on briefings(tenant_id, data_referencia desc);
create index if not exists idx_demandas_tenant_status on demandas(tenant_id, status) where ativa;
create index if not exists idx_demandas_prazo         on demandas(prazo) where ativa and status <> 'resolvida';
create index if not exists idx_compromissos_inicio    on compromissos(tenant_id, inicio) where ativo;
create index if not exists idx_desdob_tenant_status   on desdobramentos(tenant_id, status) where ativo;
create index if not exists idx_desdob_eventos_pai     on desdobramento_eventos(desdobramento_id);
create index if not exists idx_auditoria_tenant_data  on auditoria(tenant_id, ocorrido_em desc);
create index if not exists idx_auditoria_acao         on auditoria(acao, ocorrido_em desc);

-- ---------------------------------------------------------------------
-- ATUALIZAÇÃO AUTOMÁTICA DE atualizado_em
-- ---------------------------------------------------------------------
create or replace function evora_toca_atualizado_em()
returns trigger language plpgsql as $$
begin
  new.atualizado_em = now();
  return new;
end $$;

drop trigger if exists trg_tenants_atualizado on tenants;
create trigger trg_tenants_atualizado before update on tenants
  for each row execute function evora_toca_atualizado_em();

drop trigger if exists trg_demandas_atualizado on demandas;
create trigger trg_demandas_atualizado before update on demandas
  for each row execute function evora_toca_atualizado_em();

-- =====================================================================
-- FIM DO SCHEMA — 11 tabelas criadas.
-- Próximo passo obrigatório: rodar evora_rls_mvp_v1.sql
-- Sem o RLS, o banco NÃO tem isolamento entre clientes.
-- =====================================================================
