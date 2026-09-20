-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVORA OVERSIGHT — TESTE DE ACEITE DA CAMADA DE RESPOSTA E MINUTAS
-- ═══════════════════════════════════════════════════════════════════════════
-- Testes 1 a 7 devem imprimir PASSOU.
-- Testes 8 a 12 devem produzir ERROR — o erro É o sucesso.
-- ═══════════════════════════════════════════════════════════════════════════
\set ON_ERROR_STOP off
\pset pager off

select id::text as ter from farus_territorios where municipio='Sorocaba' limit 1 \gset
select id::text as tid from tenants where municipio_sede='Sorocaba' order by criado_em limit 1 \gset
select id::text as mat from legis_materias where numero='84' and ano=2026 limit 1 \gset

insert into auth.users (email) values ('aut@gab.gov.br'),('ass@gab.gov.br') on conflict do nothing;
insert into usuarios (tenant_id, auth_user_id, nome, email, papel, ativo)
select :'tid'::uuid, u.id, 'Autoridade R', 'aut@gab.gov.br', 'autoridade', true
from auth.users u where u.email='aut@gab.gov.br' on conflict do nothing;
insert into usuarios (tenant_id, auth_user_id, nome, email, papel, ativo)
select :'tid'::uuid, u.id, 'Assessor R', 'ass@gab.gov.br', 'assessor', true
from auth.users u where u.email='ass@gab.gov.br' on conflict do nothing;
select id::text as u_aut, auth_user_id::text as a_aut from usuarios where email='aut@gab.gov.br' \gset
select id::text as u_ass, auth_user_id::text as a_ass from usuarios where email='ass@gab.gov.br' \gset

\echo ''
\echo '═══ TESTE 1 — LACUNA 1 · padrão do gabinete é "ambos" ═══'
select case when evora_registro_de(:'u_aut'::uuid)='ambos'
            then 'PASSOU — padrão entrega as duas versões' else 'FALHOU' end;

\echo ''
\echo '═══ TESTE 2 — LACUNA 1 · preferência do usuário sobrepõe a do gabinete ═══'
update usuarios set registro_preferido='tecnico' where id=:'u_ass'::uuid;
select case when evora_registro_de(:'u_ass'::uuid)='tecnico'
             and evora_registro_de(:'u_aut'::uuid)='ambos'
            then 'PASSOU — assessor técnico, autoridade ambos' else 'FALHOU' end;

\echo ''
\echo '═══ TESTE 3 — LACUNA 2 · minuta nasce em rascunho, com origem ═══'
insert into minutas (tenant_id, especie, assunto, destinatario,
                     texto_simples, texto_tecnico, materia_id, fundamento, gerada_por)
values (:'tid'::uuid,'pedido_informacao',
        'Fila de espera na UBS do Éden','Secretaria Municipal de Saúde',
        'Pedido para a Secretaria informar quantas pessoas aguardam consulta especializada e qual o tempo médio de espera.',
        'REQUEIRO, nos termos regimentais, seja oficiada a Secretaria Municipal de Saúde para que informe, no prazo legal: a) o número de munícipes em fila de espera para consulta especializada; b) o tempo médio de atendimento.',
        :'mat'::uuid,'Art. 176 do Regimento Interno','motor');
select id::text as min from minutas where assunto like 'Fila de espera%' \gset
select case when estado='rascunho' then 'PASSOU — nasce em rascunho' else 'FALHOU' end from minutas where id=:'min'::uuid;

\echo ''
\echo '═══ TESTE 4 — LACUNA 2 · a trilha registrou a criação sozinha ═══'
select case when count(*)=1 and max(para_estado::text)='rascunho'
            then 'PASSOU — trilha gravada automaticamente' else 'FALHOU' end
from minuta_eventos where minuta_id=:'min'::uuid;

\echo ''
\echo '═══ TESTE 5 — LACUNA 2 · autoridade aprova pela porta oficial ═══'
begin;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub',:'a_aut',
 'app_metadata',json_build_object('tenant_id',:'tid','mundo','gabinete'))::text,true) \gset x
update minutas set estado='aguardando_aprovacao', submetida_em=now() where id=:'min'::uuid;
rollback;
update minutas set estado='aguardando_aprovacao', submetida_em=now() where id=:'min'::uuid;
begin;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub',:'a_aut',
 'app_metadata',json_build_object('tenant_id',:'tid','mundo','gabinete'))::text,true) \gset x
select case when (minuta_decidir(:'min'::uuid,'aprovada','de acordo')).estado='aprovada'
            then 'PASSOU — autoridade aprovou, com registro' else 'FALHOU' end;
commit;

\echo ''
\echo '═══ TESTE 6 — LACUNA 2 · a decisão ficou registrada com quem e quando ═══'
select case when decidida_por is not null and decidida_em is not null
            then 'PASSOU — quem e quando gravados' else 'FALHOU' end from minutas where id=:'min'::uuid;

\echo ''
\echo '═══ TESTE 7 — LACUNA 3 · briefing guarda qual registro foi entregue ═══'
insert into briefings (tenant_id, mundo, data_referencia, blocos, markdown,
                       markdown_tecnico, registro_entregue, entregue_em)
values (:'tid'::uuid,'gabinete',current_date,'{}'::jsonb,
        'Versão em linguagem comum','Versão com fundamentação','ambos',now());
select case when registro_entregue='ambos' and markdown_tecnico is not null
            then 'PASSOU — sabe qual versão a autoridade recebeu' else 'FALHOU' end
from briefings where data_referencia=current_date order by gerado_em desc limit 1;

\echo ''
\echo '═══ TESTE 8 — ASSESSOR tenta decidir sobre minuta (DEVE DAR ERRO) ═══'
insert into minutas (tenant_id, especie, assunto, texto_simples, materia_id, gerada_por)
values (:'tid'::uuid,'oficio','Segunda minuta','texto',:'mat'::uuid,'motor');
select id::text as m2 from minutas where assunto='Segunda minuta' \gset
begin;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub',:'a_ass',
 'app_metadata',json_build_object('tenant_id',:'tid','mundo','gabinete'))::text,true) \gset x
select minuta_decidir(:'m2'::uuid,'aprovada','tentativa');
rollback;

\echo ''
\echo '═══ TESTE 9 — DESCARTE sem motivo (DEVE DAR ERRO) ═══'
begin;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub',:'a_aut',
 'app_metadata',json_build_object('tenant_id',:'tid','mundo','gabinete'))::text,true) \gset x
select minuta_decidir(:'m2'::uuid,'descartada',null);
rollback;

\echo ''
\echo '═══ TESTE 10 — minuta SEM ORIGEM (DEVE DAR ERRO) ═══'
insert into minutas (tenant_id, especie, assunto, texto_simples, gerada_por)
values (:'tid'::uuid,'oficio','Minuta sem origem','texto solto','motor');

\echo ''
\echo '═══ TESTE 11 — minuta aprovada SEM quem decidiu (DEVE DAR ERRO) ═══'
insert into minutas (tenant_id, especie, assunto, texto_simples, materia_id, estado, gerada_por)
values (:'tid'::uuid,'oficio','Aprovada sem decisor','texto',:'mat'::uuid,'aprovada','motor');

\echo ''
\echo '═══ TESTE 12 — trilha de minuta é imutável (DEVE DAR ERRO) ═══'
delete from minuta_eventos;

\echo ''
\echo '═══ FIM — 1 a 7 PASSOU · 8 a 12 devem dar ERROR ═══'
