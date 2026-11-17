-- Espelho INCREMENTAL de:
--   ao-SUPABASE-BLOCO1/AO SUPABASE BLOCO1.md.txt (enum evora_origem_demanda +
--     renomeações de demandas + coluna origem + tabela demandas_historico +
--     índice + trigger de imutabilidade)
--   ao-SUPABASE-BLOCO1/evora rls mvp v1.sql (enable/force RLS + grant +
--     seção 25 — política de leitura + trigger demandas_registrar_historico)
--   ao-SUPABASE-BLOCO1/evora briefing motor mvp v1.sql (evora_montar_blocos_
--     briefing — bloco 5 ajustado pro rename titulo→assunto)
-- NAO EDITAR AQUI. Editar os arquivos canonicos acima e copiar de novo.
--
-- Tarefa 3 (Briefing Técnico Guiron, 13/11/2026): alinha `demandas` ao
-- vocabulário pedido (origem/solicitante/base_legal_lgpd/encerrado_em) e
-- cria o histórico append-only (demandas_historico). Só renomeia e
-- acrescenta — nenhuma coluna existente perde dado, a trava jurídica
-- (evora_travar_demandas_sem_parecer) e a exigência de consentimento
-- (demandas_dado_pessoal_exige_consentimento) continuam exatamente como
-- estavam, inalteradas por esta migration.
--
-- ACHADO ao renomear: o trigger trg_demandas_atualizado sempre escreveu
-- em `new.atualizado_em`, nome que a coluna de `demandas` nunca teve
-- (era `atualizada_em`). Todo UPDATE em demandas vinha falhando com
-- "record new has no field atualizado_em" — mascarado até agora porque o
-- módulo está travado e nenhum UPDATE real chegou a rodar. Este rename
-- conserta esse bug de produção, não é só estética.

-- =====================================================================
-- BLOCO 1 — schema: enum, renomeações, coluna nova, tabela nova, índice
-- =====================================================================
do $$ begin
  create type evora_origem_demanda as enum ('cidadao', 'orgao', 'interno');
exception when duplicate_object then null; end $$;

alter table demandas rename column titulo          to assunto;
alter table demandas rename column cidadao_nome    to solicitante_nome;
alter table demandas rename column cidadao_contato to solicitante_contato;
alter table demandas rename column base_legal      to base_legal_lgpd;
alter table demandas rename column resolvida_em    to encerrado_em;
alter table demandas rename column criada_em       to criado_em;
alter table demandas rename column atualizada_em   to atualizado_em;
alter table demandas add column if not exists origem evora_origem_demanda not null default 'cidadao';
comment on column demandas.origem is 'Tarefa 3 — quem originou a demanda. Default cidadao preserva o sentido de todo registro anterior a esta coluna existir.';

create table if not exists demandas_historico (
  id             uuid primary key default gen_random_uuid(),
  demanda_id     uuid not null references demandas(id) on delete cascade,
  tenant_id      uuid not null references tenants(id) on delete cascade,
  evento         text not null,
  status_anterior evora_status_demanda,
  status_novo    evora_status_demanda not null,
  autor_id       uuid references usuarios(id),
  criado_em      timestamptz not null default now()
);
comment on table demandas_historico is 'Tarefa 3 — trilha de mudança de status de uma demanda. Append-only (trigger impede update/delete), gravada automaticamente por demandas_registrar_historico.';

create index if not exists ix_demandas_historico on demandas_historico (demanda_id, criado_em desc);

create or replace function demandas_historico_imutavel()
returns trigger language plpgsql as $$
begin
  raise exception 'Histórico de demandas é imutável. Tentativa de % rejeitada.', tg_op;
end $$;

drop trigger if exists trg_demandas_historico_imutavel on demandas_historico;
create trigger trg_demandas_historico_imutavel
  before update or delete on demandas_historico
  for each row execute function demandas_historico_imutavel();

-- =====================================================================
-- BLOCO 2 — RLS: enable/force, grant, política de leitura, trigger de
-- gravação automática (security definer — ver justificativa no arquivo
-- canônico: demandas aceita UPDATE direto de authenticated, então o
-- trigger que grava o histórico precisa de privilégio elevado pra
-- escrever numa tabela onde authenticated só tem select).
-- =====================================================================
alter table demandas_historico enable row level security;
alter table demandas_historico force row level security;

grant select on demandas_historico to authenticated;

drop policy if exists demandas_historico_leitura on demandas_historico;
create policy demandas_historico_leitura on demandas_historico
  for select using (tenant_id = evora_tenant_atual());

create or replace function demandas_registrar_historico()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_autor uuid;
begin
  if tg_op = 'INSERT' or old.status is distinct from new.status then
    select u.id into v_autor
      from public.usuarios u
     where u.auth_user_id = nullif(public.evora_claims() ->> 'sub', '')::uuid
       and u.ativo
     limit 1;

    insert into public.demandas_historico
      (demanda_id, tenant_id, evento, status_anterior, status_novo, autor_id)
    values (
      new.id, new.tenant_id,
      case when tg_op = 'INSERT' then 'criacao' else 'mudanca_status' end,
      case when tg_op = 'INSERT' then null else old.status end,
      new.status,
      coalesce(v_autor, new.registrada_por)
    );
  end if;
  return new;
end;
$$;

comment on function demandas_registrar_historico is
  'Tarefa 3 — grava automaticamente em demandas_historico a cada criação ou mudança de status. autor_id vem do usuário autenticado (evora_claims); sem sessão (seed/service_role), cai pra registrada_por.';

drop trigger if exists trg_demandas_historico on demandas;
create trigger trg_demandas_historico
  after insert or update on demandas
  for each row execute function demandas_registrar_historico();

-- =====================================================================
-- BLOCO 4 — motor do briefing: bloco 5 (Demandas) lia a coluna titulo,
-- que não existe mais depois do rename acima. Substitui a função
-- inteira (Postgres exige o corpo completo em create or replace).
-- =====================================================================
create or replace function evora_montar_blocos_briefing(
  p_tenant_id       uuid,
  p_mundo           evora_mundo,
  p_data_referencia date default current_date
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_tenant_ativo boolean;
  v_resumo       jsonb;
  v_demandas     jsonb;
  v_fontes       jsonb;
  v_achados      jsonb;
  v_tem_mencoes  boolean;
  v_tem_farus    boolean;
  v_movimento    jsonb;
  v_blocos       jsonb;
begin
  -- Falha fechada: sem tenant/mundo explícitos, não monta briefing nenhum.
  if p_tenant_id is null then
    raise exception 'evora_montar_blocos_briefing: p_tenant_id é obrigatório (falha fechada).';
  end if;
  if p_mundo is null then
    raise exception 'evora_montar_blocos_briefing: p_mundo é obrigatório (falha fechada).';
  end if;

  select ativo into v_tenant_ativo from tenants where id = p_tenant_id;
  if v_tenant_ativo is null then
    raise exception 'evora_montar_blocos_briefing: tenant % não existe.', p_tenant_id;
  end if;
  if not v_tenant_ativo then
    raise exception 'evora_montar_blocos_briefing: tenant % está inativo (soft delete).', p_tenant_id;
  end if;

  -- ---- Bloco 1: Resumo do dia -----------------------------------------
  select jsonb_build_object(
    'compromissos_hoje', (
      select count(*) from compromissos c
      where c.tenant_id = p_tenant_id and c.mundo = p_mundo and c.ativo
        and not c.cancelado and c.inicio::date = p_data_referencia
    ),
    'demandas_em_aberto', (
      select count(*) from demandas d
      where d.tenant_id = p_tenant_id and d.mundo = p_mundo and d.ativa
        and d.status not in ('resolvida', 'nao_atendida')
    ),
    'desdobramentos_vencendo_72h', (
      select count(*) from desdobramentos ds
      where ds.tenant_id = p_tenant_id and ds.mundo = p_mundo and ds.ativo
        and ds.status in ('aberto', 'em_andamento')
        and ds.prazo is not null and ds.prazo <= p_data_referencia + 3
    )
  ) into v_resumo;

  -- ---- Bloco 3: Fiscalização (AFEx-g) — dado real, tabela achados_fiscalizacao
  with af as (
    select numero_pncp, objeto, valor, orgao, fornecedor, relevancia, indicio, fonte
    from achados_fiscalizacao
    where tenant_id = p_tenant_id and mundo = p_mundo and ativo
    order by (relevancia = 'atenção') desc, coletado_em desc
    limit 15
  )
  select coalesce(jsonb_agg(to_jsonb(af)), '[]'::jsonb) into v_achados from af;

  -- ---- Bloco 5: Demandas (ADC-g) — dado real, tabela demandas ---------
  -- Campos de identificação de solicitante (solicitante_nome/
  -- solicitante_contato, renomeados na Tarefa 3) ficam FORA do briefing
  -- por padrão: LGPD ainda pendente do parecer P8/P9 (ver CLAUDE.md /
  -- constraint demandas_dado_pessoal_exige_consentimento).
  with d as (
    select protocolo, assunto, tema, bairro, urgencia, status, prazo
    from demandas
    where tenant_id = p_tenant_id and mundo = p_mundo and ativa
      and status not in ('resolvida', 'nao_atendida')
    order by urgencia asc, prazo asc nulls last
    limit 15
  )
  select coalesce(jsonb_agg(to_jsonb(d)), '[]'::jsonb) into v_demandas from d;

  -- ---- Bloco 6: Imprensa — fontes declaradas + manchetes reais + FARUS ---
  with f as (
    select 'fonte_declarada'::text as tipo, nome, url, nivel, esfera, selo,
           null::text as titulo, null::text as link, null::timestamptz as publicado_em,
           null::text as estado
    from fontes
    where tenant_id = p_tenant_id and mundo = p_mundo and ativa
    order by prioridade asc, nome asc
    limit 20
  ),
  m as (
    select 'noticia'::text as tipo, fonte_nome as nome, link as url,
           null::evora_nivel_fonte as nivel, null::text as esfera, null::evora_selo_cvi as selo,
           titulo, link, publicado_em,
           null::text as estado
    from mencoes_imprensa
    where tenant_id = p_tenant_id and mundo = p_mundo and ativo
    order by publicado_em desc nulls last
    limit 20
  ),
  fa as (
    select 'farus'::text as tipo, null::text as nome, url, url as link,
           null::evora_nivel_fonte as nivel, null::text as esfera, null::evora_selo_cvi as selo,
           titulo, publicado_em::timestamptz as publicado_em,
           estado::text as estado
    from farus_itens
    where territorio_id in (
      select territorio_id from farus_tenant_territorios where tenant_id = p_tenant_id
    )
    and (tenant_origem is null or tenant_origem = p_tenant_id)
    order by capturado_em desc
    limit 20
  )
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v_fontes
  from (
    select tipo, nome, url, nivel, esfera, selo, titulo, link, publicado_em, estado from f
    union all
    select tipo, nome, url, nivel, esfera, selo, titulo, link, publicado_em, estado from m
    union all
    select tipo, nome, url, nivel, esfera, selo, titulo, link, publicado_em, estado from fa
  ) x;

  select exists (
    select 1 from mencoes_imprensa
    where tenant_id = p_tenant_id and mundo = p_mundo and ativo
  ) into v_tem_mencoes;

  select exists (
    select 1 from farus_itens
    where territorio_id in (
      select territorio_id from farus_tenant_territorios where tenant_id = p_tenant_id
    )
    and (tenant_origem is null or tenant_origem = p_tenant_id)
  ) into v_tem_farus;

  -- ---- Bloco 7: Movimento sugerido (72h) (Bia — freio humano) ---------
  with alvo as (
    select 'desdobramento'::text as tipo, id, titulo,
           prazo::text as quando, status::text as detalhe
    from desdobramentos
    where tenant_id = p_tenant_id and mundo = p_mundo and ativo
      and status in ('aberto', 'em_andamento')
      and prazo is not null and prazo <= p_data_referencia + 3
    union all
    select 'compromisso'::text as tipo, id, titulo,
           to_char(inicio, 'YYYY-MM-DD HH24:MI') as quando,
           'nao_confirmado'::text as detalhe
    from compromissos
    where tenant_id = p_tenant_id and mundo = p_mundo and ativo
      and not cancelado and not confirmado
      and inicio::date between p_data_referencia and p_data_referencia + 3
  )
  select coalesce(jsonb_agg(to_jsonb(alvo)), '[]'::jsonb) into v_movimento from alvo;

  -- ---- Monta os 7 blocos, na ordem canônica ----------------------------
  v_blocos := jsonb_build_array(
    jsonb_build_object(
      'bloco', 'resumo_do_dia', 'ordem', 1, 'titulo', 'Resumo do dia',
      'dono_agente', 'Bia',
      'status', 'preenchido',
      'aviso', 'Insumos numéricos reais; a redação final do resumo é feita pela camada de IA (fora deste BLOCO SQL).',
      'itens', v_resumo
    ),
    jsonb_build_object(
      'bloco', 'radar_de_nomeacoes', 'ordem', 2, 'titulo', 'Radar de Nomeações',
      'dono_agente', 'AFEx-g',
      'status', 'pendente_integracao_externa',
      'aviso', 'Depende de um coletor de Diário Oficial que ainda não existe como código (só o do PNCP e o de imprensa existem hoje). Sem registro hoje.',
      'itens', '[]'::jsonb
    ),
    jsonb_build_object(
      'bloco', 'fiscalizacao', 'ordem', 3, 'titulo', 'Fiscalização',
      'dono_agente', 'AFEx-g',
      'status', case when jsonb_array_length(v_achados) = 0 then 'sem_dado_hoje' else 'preenchido' end,
      'aviso', 'Dado real da tabela achados_fiscalizacao (coletor PNCP, Fase 6). Indício para verificação humana — nunca acusação.',
      'itens', v_achados
    ),
    jsonb_build_object(
      'bloco', 'pulso_da_camara_do', 'ordem', 4, 'titulo', 'Pulso da Câmara/DO',
      'dono_agente', 'ARI-g · APL-g',
      'status', 'pendente_integracao_externa',
      'aviso', 'Depende de coletor de Câmara/Diário Oficial ainda não persistido em tabela própria. Sem registro hoje.',
      'itens', '[]'::jsonb
    ),
    jsonb_build_object(
      'bloco', 'demandas', 'ordem', 5, 'titulo', 'Demandas',
      'dono_agente', 'ADC-g',
      'status', case when jsonb_array_length(v_demandas) = 0 then 'sem_dado_hoje' else 'preenchido' end,
      'aviso', 'Dado real da tabela demandas. Identificação do solicitante omitida (LGPD pendente de parecer P8/P9).',
      'itens', v_demandas
    ),
    jsonb_build_object(
      'bloco', 'imprensa', 'ordem', 6, 'titulo', 'Imprensa',
      'dono_agente', 'AIM-g',
      'status', case
        when jsonb_array_length(v_fontes) = 0 then 'sem_dado_hoje'
        when v_tem_mencoes or v_tem_farus then 'preenchido'
        else 'parcial_fontes_declaradas'
      end,
      'aviso', 'Fontes declaradas (tabela fontes), manchetes reais do coletor de imprensa por nome (mencoes_imprensa, Fase 6) e acervo do FARUS por território (farus_itens, Fase 10+) — cada item marcado com "tipo". Itens do FARUS trazem "estado": quando "nao_verificado", a redação final NÃO deve apresentar como fato confirmado.',
      'itens', v_fontes
    ),
    jsonb_build_object(
      'bloco', 'movimento_sugerido_72h', 'ordem', 7, 'titulo', 'Movimento sugerido (72h)',
      'dono_agente', 'Bia',
      'status', case when jsonb_array_length(v_movimento) = 0 then 'sem_dado_hoje' else 'preenchido' end,
      'aviso', 'Candidatos reais (desdobramentos a vencer, compromissos não confirmados). Nada sai sem aprovação humana (freio humano).',
      'itens', v_movimento
    )
  );

  return v_blocos;
end;
$$;

comment on function evora_montar_blocos_briefing is
  'Agrega os 7 blocos canônicos do briefing matinal a partir das tabelas existentes. SECURITY DEFINER: recebe tenant_id/mundo como parâmetro (sem JWT), filtra explicitamente — não depende do RLS. Uso restrito a service_role.';
