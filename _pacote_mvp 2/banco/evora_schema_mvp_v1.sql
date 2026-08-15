-- ============================================================
-- ÉVORA OVERSIGHT — Banco de Dados · Núcleo do MVP · v1
-- PostgreSQL / Supabase
-- Base: Manual v10.1 · preparado para os DOIS níveis de separação de mundos
-- ------------------------------------------------------------
-- PRINCÍPIOS APLICADOS NESTE SCHEMA:
--  (1) Multi-tenant: toda linha pertence a um tenant (cliente).
--  (2) Separação de mundos: toda linha carrega o "mundo" (gabinete/campanha).
--      -> Nível 1 (lógico): um banco, isolado por tenant_id + mundo + RLS.
--      -> Nível 2 (físico): o mesmo schema roda numa instância separada; nada muda no código.
--  (3) LGPD preparada: consentimento, dado sensível, soft delete, trilha.
--  (4) Nada é apagado de verdade (soft delete) — auditoria sempre.
-- ============================================================

-- Extensões úteis (Supabase já traz)
create extension if not exists "pgcrypto";      -- gen_random_uuid()

-- ============================================================
-- TIPOS (enums) — o vocabulário do sistema
-- ============================================================
create type mundo_tipo        as enum ('gabinete', 'campanha');
create type papel_tipo        as enum ('autoridade','chefe_gabinete','juridico','demandas','midia','assessor','admin');
create type nivel_separacao   as enum ('logico','fisico');       -- a "chave" comercial
create type fonte_categoria   as enum ('diario_oficial','jornal','portal','tribunal','redes','api','rss','pncp','camara','outro');
create type fonte_esfera      as enum ('municipal','regional','estadual','federal','outro');
create type agenda_status     as enum ('aguardando','confirmado','recusado','cancelado','em_cancelamento');
create type desdobro_tipo     as enum ('acao','agendamento','andamento');
create type desdobro_status   as enum ('aberto','concluido','transferido');
create type auditoria_acao    as enum ('criar','alterar','desativar','reativar','confirmar','recusar','transferir','login','acesso');

-- ============================================================
-- 1) TENANTS — os clientes (gabinetes) e a configuração de separação
-- ============================================================
create table tenants (
  id                uuid primary key default gen_random_uuid(),
  nome              text not null,                       -- ex.: "Gabinete Vereadora Tatiane Costa"
  municipio         text,
  uf                text,
  nivel_separacao   nivel_separacao not null default 'logico',  -- a chave: logico (padrão) ou fisico (premium)
  regiao_dados      text default 'br',                   -- 'br' = dados no Brasil (LGPD)
  ativo             boolean not null default true,
  criado_em         timestamptz not null default now()
);
comment on column tenants.nivel_separacao is 'logico = separação por software (padrão/MVP); fisico = infraestrutura separada (premium)';

-- ============================================================
-- 2) USUÁRIOS e PAPÉIS — quem acessa, com qual alçada
--    (liga-se ao auth do Supabase por auth_user_id)
-- ============================================================
create table usuarios (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null references tenants(id),
  auth_user_id      uuid,                                -- id do usuário no Supabase Auth
  nome              text not null,
  email             text,
  papel             papel_tipo not null default 'assessor',
  nivel_acesso      int not null default 1 check (nivel_acesso between 1 and 5),  -- N1..N5
  ativo             boolean not null default true,       -- soft delete (exoneração encerra acesso)
  criado_em         timestamptz not null default now(),
  unique (tenant_id, email)
);

-- ============================================================
-- 3) FONTES — Central de Inteligência de Fontes (por mundo)
-- ============================================================
create table fontes (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null references tenants(id),
  mundo             mundo_tipo not null,                 -- separação de mundos
  nome              text not null,
  categoria         fonte_categoria not null,
  esfera            fonte_esfera not null default 'municipal',
  url               text,
  palavras_chave    text[],                              -- termos monitorados
  periodicidade     text,                                -- ex.: 'diaria'
  prioridade        int default 3 check (prioridade between 1 and 5),
  ativa             boolean not null default true,       -- soft delete: desativa, nunca apaga
  criada_por        uuid references usuarios(id),
  criada_em         timestamptz not null default now(),
  desativada_por    uuid references usuarios(id),
  desativada_em     timestamptz
);

-- ============================================================
-- 4) BRIEFINGS — o que o motor gera (por mundo)
-- ============================================================
create table briefings (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null references tenants(id),
  mundo             mundo_tipo not null default 'gabinete',
  data_ref          date not null,                       -- o dia do briefing
  titulo            text,
  conteudo_md       text,                                -- o briefing em markdown
  gerado_em         timestamptz not null default now(),
  fontes_ok         text[],                              -- quais fontes responderam
  fontes_falha      text[],                              -- quais falharam (honestidade)
  unique (tenant_id, mundo, data_ref)
);

-- ============================================================
-- 5) DEMANDAS — o módulo do cidadão (LGPD preparada)
-- ============================================================
create table demandas (
  id                    uuid primary key default gen_random_uuid(),
  tenant_id             uuid not null references tenants(id),
  mundo                 mundo_tipo not null default 'gabinete',
  assunto               text not null,
  descricao             text,
  -- dados do cidadão (dado pessoal — LGPD)
  cidadao_nome          text,
  cidadao_contato       text,
  local_texto           text,
  local_lat             numeric,
  local_lng             numeric,
  foto_url              text,
  -- LGPD: base legal e consentimento (preenchido conforme parecer da advogada)
  consentimento_aceito  boolean default false,
  consentimento_texto   text,                            -- versão do termo aceita
  consentimento_em      timestamptz,
  dado_sensivel         boolean default false,           -- marca se há dado sensível
  base_legal            text,                            -- ex.: 'consentimento' | 'interesse_legitimo'
  retencao_ate          date,                            -- quando descartar (LGPD)
  -- andamento
  status                text default 'aberta',
  criada_por            uuid references usuarios(id),
  criada_em             timestamptz not null default now(),
  ativa                 boolean not null default true    -- soft delete
);
comment on table demandas is 'Dados pessoais de cidadão. Campos de consentimento/base legal aguardam parecer (perguntas 8 e 9).';

-- ============================================================
-- 6) AGENDA — compromissos com caixa de confirmação
-- ============================================================
-- lugares salvos (apelido -> endereço), por tenant
create table lugares (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null references tenants(id),
  apelido           text not null,
  endereco          text not null,
  ativo             boolean not null default true,
  unique (tenant_id, apelido)
);

create table compromissos (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null references tenants(id),
  mundo             mundo_tipo not null default 'gabinete',
  -- de quem é a caixa (a tenant/autoridade ou um assessor)
  caixa_de          uuid not null references usuarios(id),
  assunto           text not null,
  com_quem          text,
  pautas            text,
  quando            timestamptz,
  local_texto       text,
  lugar_id          uuid references lugares(id),         -- se veio de um lugar salvo
  -- confirmação e semáforo
  status            agenda_status not null default 'aguardando',
  prazo_decisao     timestamptz,                         -- até quando decidir
  anotado_por       uuid references usuarios(id),
  cancelamento_em   timestamptz,                         -- quando entrou em cancelamento
  criado_em         timestamptz not null default now()
);
comment on column compromissos.caixa_de is 'Dono da caixa: só a autoridade confirma a dela; cada assessor a sua.';

-- ============================================================
-- 7) ATAS & SEGUIMENTOS — nada se perde depois da reunião
-- ============================================================
create table atas (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null references tenants(id),
  mundo             mundo_tipo not null default 'gabinete',
  compromisso_id    uuid references compromissos(id),    -- de qual reunião nasceu
  titulo            text not null,
  decisoes          text,                                -- as deliberações
  criada_por        uuid references usuarios(id),
  criada_em         timestamptz not null default now(),
  audio_url         text,                                -- fase avançada (consentimento/LGPD)
  transcricao       text
);

create table desdobramentos (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null references tenants(id),
  mundo             mundo_tipo not null default 'gabinete',
  ata_id            uuid references atas(id),
  tipo              desdobro_tipo not null,              -- acao | agendamento | andamento
  texto             text not null,
  dono              uuid references usuarios(id),        -- responsável pelo andamento/encerramento
  prazo             timestamptz,
  status            desdobro_status not null default 'aberto',
  restrito          boolean not null default false,      -- de fábrica: só tenant+chefe veem
  criado_em         timestamptz not null default now(),
  concluido_em      timestamptz
);

-- linha do tempo do desdobramento (viaja junto na transferência)
create table desdobramento_eventos (
  id                uuid primary key default gen_random_uuid(),
  desdobramento_id  uuid not null references desdobramentos(id),
  evento            text not null,                       -- 'criado','andamento','transferido','concluido'
  detalhe           text,                                -- ex.: 'de Sabrina para Tatê — no ponto: ...'
  por               uuid references usuarios(id),
  em                timestamptz not null default now()
);

-- ============================================================
-- 8) TRILHA DE AUDITORIA (Aegis) — registra TODA operação, imutável
-- ============================================================
create table auditoria (
  id                bigserial primary key,
  tenant_id         uuid not null references tenants(id),
  mundo             mundo_tipo,                          -- em qual mundo ocorreu
  usuario_id        uuid references usuarios(id),
  acao              auditoria_acao not null,
  entidade          text not null,                       -- ex.: 'fontes','demandas','compromissos'
  entidade_id       uuid,
  valor_antes       jsonb,                               -- estado anterior
  valor_depois      jsonb,                               -- estado posterior
  justificativa     text,
  ip                text,
  sessao            text,
  em                timestamptz not null default now()
);
comment on table auditoria is 'Imutável: só INSERT. Nunca UPDATE/DELETE. É a prova de integridade e de separação.';

-- ============================================================
-- ÍNDICES — desempenho nas buscas mais comuns
-- ============================================================
create index idx_usuarios_tenant     on usuarios(tenant_id);
create index idx_fontes_tenant_mundo on fontes(tenant_id, mundo);
create index idx_briefings_tenant    on briefings(tenant_id, mundo, data_ref);
create index idx_demandas_tenant     on demandas(tenant_id, mundo);
create index idx_compromissos_caixa  on compromissos(tenant_id, caixa_de, status);
create index idx_desdobros_dono      on desdobramentos(tenant_id, dono, status);
create index idx_auditoria_tenant    on auditoria(tenant_id, em);

-- ============================================================
-- FIM DO NÚCLEO DO MVP
-- Próximos (fase 2): mundo campanha completo (AFC-p financeiro),
-- documentos+OCR, CRM/contatos, legislação, projetos, sentinela.
-- ============================================================
