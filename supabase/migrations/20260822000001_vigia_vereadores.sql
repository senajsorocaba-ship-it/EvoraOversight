-- Espelho INCREMENTAL gerado de: ao-SUPABASE-BLOCO1/AO SUPABASE BLOCO1.md.txt
-- (coluna municipios.vereadores_fonte_url + tabela 18) + ao-SUPABASE-BLOCO1/
-- evora rls mvp v1.sql (trecho novo).
-- NAO EDITAR AQUI. Editar os arquivos canonicos acima e copiar de novo.
--
-- Fase 9 do plano de testes: vigia de vereadores. Revisita periodicamente a
-- URL oficial de cada cidade já configurada, usa a API da Claude pra extrair
-- nome+e-mail da página, e só REGISTRA diferenças numa fila de revisão —
-- nunca escreve direto em municipio_vereadores. Aplicar continua sendo uma
-- ação humana explícita via CLI.

-- =====================================================================
-- BLOCO 1 — schema: coluna nova + tabela 18
-- =====================================================================

alter table municipios add column if not exists vereadores_fonte_url text;
comment on column municipios.vereadores_fonte_url is 'Fase 9 — URL da página oficial (Câmara Municipal) com a lista de vereadores, usada pelo vigia (vereadores vigiar). Configurada manualmente, uma vez por cidade, via vereadores configurar-fonte-url. Coluna real (não jsonb) porque vigiar-todas precisa consultar estruturalmente "toda cidade com URL configurada".';

-- ---------------------------------------------------------------------
-- 18. MUNICIPIO_VEREADORES_PENDENCIAS — Fase 9 (vigia de vereadores). Fila
-- de revisão: o vigia (evora_atlas_municipal.py vereadores vigiar) revisita
-- a URL de municipios.vereadores_fonte_url, usa a API da Claude pra extrair
-- nome+e-mail da página, compara com municipio_vereadores e só REGISTRA a
-- diferença aqui — nunca escreve direto na tabela que alimenta o
-- autocadastro. Aplicar uma pendência é sempre uma ação humana explícita
-- (vereadores pendencias aplicar), que reusa o mesmo _upsert_vereador da
-- Fase 8.
-- ---------------------------------------------------------------------
create table if not exists municipio_vereadores_pendencias (
  id             uuid primary key default gen_random_uuid(),
  municipio_id   uuid not null references municipios(id),
  tipo           text not null,   -- 'novo' | 'email_alterado' | 'possivel_saida'
  nome           text,
  email          text not null,
  email_anterior text,            -- só para tipo='email_alterado'
  detectado_em   timestamptz not null default now(),
  status         text not null default 'pendente',  -- 'pendente' | 'aplicada' | 'rejeitada'
  revisado_por   text,
  revisado_em    timestamptz,
  constraint municipio_vereadores_pendencias_tipo_valido
    check (tipo in ('novo','email_alterado','possivel_saida')),
  constraint municipio_vereadores_pendencias_status_valido
    check (status in ('pendente','aplicada','rejeitada'))
);

comment on table municipio_vereadores_pendencias is 'Fase 9 — fila de revisão do vigia de vereadores. Nunca alimenta o autocadastro diretamente; aplicar é sempre ação humana via vereadores pendencias aplicar.';

create index if not exists idx_municipio_vereadores_pendencias_status on municipio_vereadores_pendencias(municipio_id, status);

-- =====================================================================
-- BLOCO 2 — RLS: enable/force para a tabela nova (sem policy, sem grant
-- para authenticated/anon — mesmo caso de municipio_vereadores)
-- =====================================================================

-- service_role: a migration 2 (20260818000002_rls.sql) já rodou seu
-- "grant all privileges on all tables in schema public to service_role"
-- ANTES desta tabela existir — GRANT não é retroativo (mesmo motivo já
-- documentado nas migrations 5/6).
grant all privileges on municipio_vereadores_pendencias to service_role;

alter table municipio_vereadores_pendencias enable row level security;
alter table municipio_vereadores_pendencias force row level security;
-- Nenhuma policy, nenhum grant para authenticated/anon: fila operacional
-- interna, só a CLI (service_role) lê e escreve.
