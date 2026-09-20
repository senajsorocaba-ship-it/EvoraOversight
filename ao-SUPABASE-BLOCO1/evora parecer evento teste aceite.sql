-- ═══════════════════════════════════════════════════════════════════════════
-- TESTE DE ACEITE — PARECER COMO EVENTO
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Conteúdo idêntico ao entregue (16_teste_parecer.sql, 11/11, arquivado em
-- _versoes_anteriores/legis_resposta_parecer_entregues_v11_1/) — nenhuma
-- adaptação necessária: minuta_pedir_parecer já foi ajustada (usa
-- evora_claims(), não auth.uid()) nos arquivos canônicos.
--
-- RODAR DEPOIS de "evora resposta minutas teste aceite.sql" (usa a minuta
-- e os usuários aut@gab.gov.br/ass@gab.gov.br criados lá). NÃO faz
-- rollback. Só contra Supabase local/throwaway.
--
-- Testes 1 a 6 devem imprimir PASSOU. Testes 7 a 11 devem dar ERROR.
-- ═══════════════════════════════════════════════════════════════════════════
\set ON_ERROR_STOP off
\pset pager off

select id::text as tid from tenants where municipio_sede='Sorocaba' order by criado_em limit 1 \gset
select id::text as mat from legis_materias where numero='84' and ano=2026 limit 1 \gset
select id::text as u_aut, auth_user_id::text as a_aut from usuarios where email='aut@gab.gov.br' \gset
select id::text as u_ass, auth_user_id::text as a_ass from usuarios where email='ass@gab.gov.br' \gset

-- o assessor É advogado — mas continua assessor
update usuarios set habilitacao='advogado', habilitacao_registro='OAB/SP 000000'
 where id=:'u_ass'::uuid;

insert into minutas (tenant_id, especie, assunto, texto_simples, texto_tecnico, materia_id, gerada_por)
values (:'tid'::uuid,'requerimento','Requerimento de teste do parecer',
        'Pedido em linguagem comum.',
        'REQUEIRO, nos termos regimentais, seja oficiado o Executivo.',
        :'mat'::uuid,'motor');
select id::text as min from minutas where assunto='Requerimento de teste do parecer' \gset

\echo ''
\echo '═══ TESTE 1 — assessor advogado continua com papel de ASSESSOR ═══'
select case when papel::text='assessor' and habilitacao='advogado'
            then 'PASSOU — habilitação não virou papel' else 'FALHOU' end
from usuarios where id=:'u_ass'::uuid;

\echo ''
\echo '═══ TESTE 2 — autoridade pede parecer ao assessor advogado ═══'
begin;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub',:'a_aut',
 'app_metadata',json_build_object('tenant_id',:'tid','mundo','gabinete'))::text,true) \gset x
select case when (minuta_pedir_parecer(:'min'::uuid,
        'Verificar se o requerimento observa o prazo regimental do art. 176',
        :'u_ass'::uuid)).id is not null
            then 'PASSOU — parecer solicitado' else 'FALHOU' end;
commit;

\echo ''
\echo '═══ TESTE 3 — a habilitação foi copiada no momento do pedido ═══'
select case when parecerista_habilitacao='advogado'
            then 'PASSOU — habilitação preservada no tempo' else 'FALHOU' end
from minuta_pareceres where minuta_id=:'min'::uuid;

\echo ''
\echo '═══ TESTE 4 — a minuta sabe que há parecer pendente ═══'
select case when tem_parecer_pendente and not tem_parecer_emitido
            then 'PASSOU — pendência visível' else 'FALHOU' end
from minuta_situacao_parecer(:'min'::uuid);

\echo ''
\echo '═══ TESTE 5 — parecer favorável com ressalva ═══'
update minuta_pareceres
   set conclusao='favoravel_com_ressalva',
       texto='O pedido é regimental, mas o prazo indicado não corresponde ao art. 176.',
       ressalva='Ajustar o prazo para o previsto no art. 176 antes de protocolar.',
       emitido_em=now()
 where minuta_id=:'min'::uuid;
select case when conclusao='favoravel_com_ressalva' and ressalva is not null
            then 'PASSOU — ressalva registrada com o que mudar' else 'FALHOU' end
from minuta_situacao_parecer(:'min'::uuid);

\echo ''
\echo '═══ TESTE 6 — a autoridade aprova MESMO ASSIM; parecer não bloqueia ═══'
update minutas set estado='aguardando_aprovacao', submetida_em=now() where id=:'min'::uuid;
begin;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub',:'a_aut',
 'app_metadata',json_build_object('tenant_id',:'tid','mundo','gabinete'))::text,true) \gset x
select case when (minuta_decidir(:'min'::uuid,'aprovada','ciente da ressalva')).estado='aprovada'
            then 'PASSOU — decisão é da autoridade, não do parecer' else 'FALHOU' end;
commit;

\echo ''
\echo '═══ TESTE 7 — ASSESSOR tenta pedir parecer (DEVE DAR ERRO) ═══'
begin;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub',:'a_ass',
 'app_metadata',json_build_object('tenant_id',:'tid','mundo','gabinete'))::text,true) \gset x
select minuta_pedir_parecer(:'min'::uuid,'questao qualquer para testar', :'u_ass'::uuid);
rollback;

\echo ''
\echo '═══ TESTE 8 — pedir parecer SEM parecerista (DEVE DAR ERRO) ═══'
begin;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub',:'a_aut',
 'app_metadata',json_build_object('tenant_id',:'tid','mundo','gabinete'))::text,true) \gset x
select minuta_pedir_parecer(:'min'::uuid,'questao sem parecerista informado');
rollback;

\echo ''
\echo '═══ TESTE 9 — ressalva SEM dizer o que mudar (DEVE DAR ERRO) ═══'
insert into minuta_pareceres (minuta_id, tenant_id, solicitado_por, questao,
                              parecerista_nome, conclusao, texto, emitido_em)
values (:'min'::uuid,:'tid'::uuid,:'u_aut'::uuid,'questao teste ressalva vazia',
        'Dr. Externo','favoravel_com_ressalva','texto do parecer', now());

\echo ''
\echo '═══ TESTE 10 — parecer emitido SEM autor (DEVE DAR ERRO) ═══'
insert into minuta_pareceres (minuta_id, tenant_id, solicitado_por, questao,
                              conclusao, texto, emitido_em)
values (:'min'::uuid,:'tid'::uuid,:'u_aut'::uuid,'questao sem autor nenhum',
        'favoravel','texto', now());

\echo ''
\echo '═══ TESTE 11 — dispensa SEM motivo (DEVE DAR ERRO) ═══'
insert into minuta_pareceres (minuta_id, tenant_id, solicitado_por, questao, dispensado)
values (:'min'::uuid,:'tid'::uuid,:'u_aut'::uuid,'questao com dispensa sem motivo', true);

\echo ''
\echo '═══ FIM — 1 a 6 PASSOU · 7 a 11 ERROR ═══'
