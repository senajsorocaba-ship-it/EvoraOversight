-- Espelho gerado de: ao-SUPABASE-BLOCO1/evora briefing motor mvp v1.sql (BLOCO 4 - motor do briefing)
-- NAO EDITAR AQUI. Editar o arquivo canonico acima e copiar de novo.

-- =====================================================================
-- ÉVORA OVERSIGHT — MOTOR DO BRIEFING MATINAL (agregador de dados)
-- Arquivo: evora_briefing_motor_mvp_v1.sql
-- Versão:  v1.0 · 09/08/2026 · alinhado ao Manual Supremo v10.6
-- =====================================================================
--
-- Este é o BLOCO 4 (depois de schema, RLS e teste de aceite). Ele NÃO
-- inventa uma estrutura nova de briefing — implementa exatamente os
-- "7 blocos canônicos" citados no comentário da coluna briefings.blocos
-- (AO SUPABASE BLOCO1.md.txt, tabela 4), cuja definição está registrada
-- fora deste repositório, no mesmo projeto Évora:
--
--   · D:\motor\GUIA_Primeiro_Briefing.md  ("Blocos do briefing: Resumo ·
--     Radar de Nomeações · Fiscalização · Pulso da Câmara/DO · Demandas ·
--     Imprensa · Movimento sugerido (72h)")
--   · Evora Manual v10_4.md, Anexo 12 (tabela "Bloco do briefing / Dono"),
--     dentro do escopo do Núcleo Fundador Fase 1 (linha 179 do Manual).
--
-- OS 7 BLOCOS, NESTA ORDEM CANÔNICA:
--   1. resumo_do_dia          (Bia — síntese)
--   2. radar_de_nomeacoes     (AFEx-g — lê Diário Oficial)
--   3. fiscalizacao           (AFEx-g — indícios do PNCP; indício, nunca acusação)
--   4. pulso_da_camara_do     (ARI-g · APL-g)
--   5. demandas               (ADC-g)
--   6. imprensa               (AIM-g — monitoramento/menções)
--   7. movimento_sugerido_72h (Bia — sempre sob freio humano)
--
-- O QUE ESTE BLOCO FAZ E O QUE NÃO FAZ (honestidade de escopo):
-- As 11 tabelas oficiais (Anexo 14) só guardam, hoje, dado estruturado
-- para os blocos 1, 5, 6 (parcial) e 7 — vindo de `demandas`,
-- `compromissos`, `desdobramentos` e `fontes`. Os blocos 2, 3, 4 e a
-- parte de "manchetes" do bloco 6 dependem dos coletores externos do
-- motor Python (D:\motor\coletor_pncp_evora.py, imprensa_coletor_evora.py),
-- que hoje escrevem em JSON fora do Postgres — não existe tabela para
-- itens coletados no schema de 11 tabelas, e este arquivo NÃO cria uma
-- (mudança de schema exige decisão explícita do dono, por norma do
-- CLAUDE.md deste repositório). Por isso esses blocos voltam marcados
-- status = 'pendente_integracao_externa', nunca preenchidos com invenção
-- — é a Cláusula de Caráter Travado (D:\motor\montador_briefing_evora.py:
-- "Não invente nada... Se algo não vier, diga que não há registro hoje").
--
-- ARQUITETURA DE CHAMADA:
-- Estas funções são para o "motor do briefing" citado no rodapé de
-- evora_rls_mvp_v1.sql — um job de servidor confiável, autenticado com a
-- chave service_role (que ignora RLS por design do Supabase). Por isso:
--   · são SECURITY DEFINER (rodam com o privilégio de quem as criou,
--     tipicamente o role `postgres`, que no Supabase já ignora RLS);
--   · NÃO leem tenant/mundo do JWT (evora_tenant_atual()/evora_mundo_atual()
--     dependem de request.jwt.claims, que não existe num job de backend) —
--     recebem tenant_id e mundo como PARÂMETROS EXPLÍCITOS e filtram toda
--     consulta por eles. A fronteira de isolamento aqui é o corpo da
--     função, não o RLS — falha fechada: parâmetro nulo é erro, não "tudo".
--   · a permissão de executar é revogada de público e concedida só a
--     service_role — nunca exponha estas funções a `authenticated`/`anon`,
--     do contrário qualquer usuário logado poderia montar o briefing de
--     qualquer tenant só passando o uuid como parâmetro.
--
-- ORDEM: rodar depois de evora_schema_mvp_v1.sql e evora_rls_mvp_v1.sql.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. AGREGADOR — monta o jsonb dos 7 blocos a partir do banco (sem IA,
--    sem redigir texto; é o "dossiê estruturado" que o Anexo 12 descreve
--    o AIM-g entregando à Bia — aqui, a fatia que o banco sustenta).
-- ---------------------------------------------------------------------
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
  -- A prosa final é redigida pela Bia (camada de IA fora deste BLOCO);
  -- aqui só os insumos numéricos, reais, para essa redação.
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

  -- ---- Bloco 5: Demandas (ADC-g) — dado real, tabela demandas ---------
  -- Campos de identificação de cidadão (cidadao_nome/cidadao_contato)
  -- ficam FORA do briefing por padrão: LGPD ainda pendente do parecer
  -- P8/P9 (ver CLAUDE.md / constraint demandas_dado_pessoal_exige_consentimento).
  with d as (
    select protocolo, titulo, tema, bairro, urgencia, status, prazo
    from demandas
    where tenant_id = p_tenant_id and mundo = p_mundo and ativa
      and status not in ('resolvida', 'nao_atendida')
    order by urgencia asc, prazo asc nulls last
    limit 15
  )
  select coalesce(jsonb_agg(to_jsonb(d)), '[]'::jsonb) into v_demandas from d;

  -- ---- Bloco 6 (parcial): Imprensa — lista de fontes declaradas -------
  -- O Anexo 12 (saídas do AIM-g) inclui explicitamente "lista de fontes
  -- declaradas" — isso a tabela `fontes` sustenta de verdade. As
  -- manchetes coletadas (noticias.json) não têm tabela ainda: ficam
  -- marcadas como pendentes, não inventadas.
  with f as (
    select nome, url, nivel, esfera, selo
    from fontes
    where tenant_id = p_tenant_id and mundo = p_mundo and ativa
    order by prioridade asc, nome asc
    limit 20
  )
  select coalesce(jsonb_agg(to_jsonb(f)), '[]'::jsonb) into v_fontes from f;

  -- ---- Bloco 7: Movimento sugerido (72h) (Bia — freio humano) ---------
  -- Candidatos reais a virarem sugestão de movimento: desdobramentos
  -- prestes a vencer e compromissos ainda não confirmados nos próximos
  -- 3 dias. Nada aqui sai sozinho — depende de aprovação humana
  -- (briefings.aprovado_por), como em qualquer bloco deste tipo.
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
      'aviso', 'Depende do coletor de Diário Oficial (D:\motor\imprensa_coletor_evora.py e afins); não há tabela no schema de 11 tabelas para itens coletados. Sem registro hoje.',
      'itens', '[]'::jsonb
    ),
    jsonb_build_object(
      'bloco', 'fiscalizacao', 'ordem', 3, 'titulo', 'Fiscalização',
      'dono_agente', 'AFEx-g',
      'status', 'pendente_integracao_externa',
      'aviso', 'Depende do coletor PNCP (D:\motor\coletor_pncp_evora.py); indício para acompanhar, nunca acusação. Sem tabela própria hoje — sem registro.',
      'itens', '[]'::jsonb
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
      'aviso', 'Dado real da tabela demandas. Identificação do cidadão omitida (LGPD pendente de parecer P8/P9).',
      'itens', v_demandas
    ),
    jsonb_build_object(
      'bloco', 'imprensa', 'ordem', 6, 'titulo', 'Imprensa',
      'dono_agente', 'AIM-g',
      'status', case when jsonb_array_length(v_fontes) = 0 then 'sem_dado_hoje' else 'parcial_fontes_declaradas' end,
      'aviso', 'Lista de fontes declaradas é dado real (tabela fontes). Manchetes do dia dependem do coletor de imprensa, ainda sem tabela — sem registro.',
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

-- ---------------------------------------------------------------------
-- 2. GERADOR — chama o agregador, grava/atualiza a linha em `briefings`
--    e registra a geração na trilha imutável (Anexo 12, passo 9: "entregar
--    à Bia e gravar na trilha"). Não mexe em markdown/html/aprovado_por —
--    isso é a etapa seguinte (redação por IA + freio humano), fora deste
--    BLOCO SQL.
-- ---------------------------------------------------------------------
create or replace function evora_gerar_briefing_diario(
  p_tenant_id       uuid,
  p_mundo           evora_mundo,
  p_data_referencia date default current_date
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_blocos      jsonb;
  v_briefing_id uuid;
begin
  v_blocos := evora_montar_blocos_briefing(p_tenant_id, p_mundo, p_data_referencia);

  insert into briefings (tenant_id, mundo, data_referencia, blocos, gerado_em)
  values (p_tenant_id, p_mundo, p_data_referencia, v_blocos, now())
  on conflict (tenant_id, mundo, data_referencia)
  do update set blocos = excluded.blocos, gerado_em = now()
  returning id into v_briefing_id;

  insert into auditoria (tenant_id, mundo, ator_descricao, acao, entidade, entidade_id, detalhe)
  values (
    p_tenant_id, p_mundo, 'motor_briefing (evora_gerar_briefing_diario)',
    'criacao', 'briefings', v_briefing_id::text,
    jsonb_build_object('data_referencia', p_data_referencia)
  );

  return v_briefing_id;
end;
$$;

comment on function evora_gerar_briefing_diario is
  'Gera/atualiza o briefing do dia (upsert em briefings) e grava a geração na auditoria. Uso restrito a service_role — é o "motor do briefing" citado em evora_rls_mvp_v1.sql.';

-- ---------------------------------------------------------------------
-- 3. PERMISSÕES — só o motor (service_role) pode chamar. Nunca conceder
--    a `authenticated`/`anon`: como as funções recebem tenant_id/mundo
--    por parâmetro (sem checagem de JWT), conceder a um role de usuário
--    final abriria caminho para montar o briefing de QUALQUER tenant.
-- ---------------------------------------------------------------------
revoke all on function evora_montar_blocos_briefing(uuid, evora_mundo, date) from public;
revoke all on function evora_gerar_briefing_diario(uuid, evora_mundo, date)   from public;

grant execute on function evora_montar_blocos_briefing(uuid, evora_mundo, date) to service_role;
grant execute on function evora_gerar_briefing_diario(uuid, evora_mundo, date)   to service_role;

-- =====================================================================
-- COMO TESTAR (SQL Editor do Supabase, com dados fictícios já existentes
-- de um tenant real ou de fixtures manuais — NUNCA dado real de cidadão):
--
--   select evora_montar_blocos_briefing('<uuid-do-tenant>', 'gabinete');
--
--   select evora_gerar_briefing_diario('<uuid-do-tenant>', 'gabinete');
--   select data_referencia, blocos from briefings
--     where tenant_id = '<uuid-do-tenant>' order by data_referencia desc limit 1;
--
-- Confirme visualmente: 7 blocos, na ordem 1..7; blocos 2/3/4 com
-- status 'pendente_integracao_externa' (até existir tabela/ingestão
-- para os coletores externos); blocos 1/5/7 com dado real quando houver
-- linha correspondente hoje; bloco 6 mostrando as fontes cadastradas.
--
-- PRÓXIMO PASSO (fora deste BLOCO): a camada externa (Edge Function ou
-- job equivalente ao motor Python) que chama evora_gerar_briefing_diario
-- com a service_role key, pega o jsonb salvo, chama o modelo de IA para
-- redigir markdown/html a partir dele — e não libera nada sem
-- briefings.aprovado_por preenchido (freio humano).
-- =====================================================================
