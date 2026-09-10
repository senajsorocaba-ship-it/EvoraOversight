-- Espelho INCREMENTAL de: ao-SUPABASE-BLOCO1/evora briefing motor mvp v1.sql
-- (função evora_montar_blocos_briefing, bloco 6 — imprensa).
-- NAO EDITAR AQUI. Editar o arquivo canonico acima e copiar de novo.
-- Depende de 20260818000003_briefing_motor.sql e 20260903000001_farus_f1.sql
-- já aplicadas.
--
-- Fase 10+ (Manual v10.9.1): o bloco 6 (Imprensa) passa a somar o acervo
-- do FARUS (farus_itens, por território do tenant) às fontes declaradas e
-- às manchetes do coletor de menções — cada item marcado com "tipo" e,
-- quando vier do FARUS, também com "estado" (tipicamente 'nao_verificado'
-- neste estágio — a Cláusula de Caráter Travado exige que a redação final
-- nunca apresente isso como fato confirmado).

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

  -- ---- Bloco 3: Fiscalização (AFEx-g) ----------------------------------
  with af as (
    select numero_pncp, objeto, valor, orgao, fornecedor, relevancia, indicio, fonte
    from achados_fiscalizacao
    where tenant_id = p_tenant_id and mundo = p_mundo and ativo
    order by (relevancia = 'atenção') desc, coletado_em desc
    limit 15
  )
  select coalesce(jsonb_agg(to_jsonb(af)), '[]'::jsonb) into v_achados from af;

  -- ---- Bloco 5: Demandas (ADC-g) ---------------------------------------
  with d as (
    select protocolo, titulo, tema, bairro, urgencia, status, prazo
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
      'aviso', 'Dado real da tabela demandas. Identificação do cidadão omitida (LGPD pendente de parecer P8/P9).',
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
  'Agrega os 7 blocos canônicos do briefing matinal a partir das tabelas existentes (bloco 6 inclui FARUS desde a Fase 10+). SECURITY DEFINER: recebe tenant_id/mundo como parâmetro (sem JWT), filtra explicitamente — não depende do RLS. Uso restrito a service_role.';

revoke all on function evora_montar_blocos_briefing(uuid, evora_mundo, date) from public;
grant execute on function evora_montar_blocos_briefing(uuid, evora_mundo, date) to service_role;
