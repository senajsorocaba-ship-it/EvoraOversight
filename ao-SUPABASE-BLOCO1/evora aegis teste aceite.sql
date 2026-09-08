-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVORA OVERSIGHT — TESTE DE ACEITE DO AEGIS A0
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Prova que o cofre de dado sensível está fechado. Rode DEPOIS de
-- evora_aegis_a0.sql, com os dados de teste do FARUS já semeados.
--
-- COMO LER: testes 2, 3, 4, 9 e 10 imprimem PASSOU.
-- Testes 1, 5, 6, 7 e 8 DEVEM produzir erro — ver o erro é o sucesso.
--
-- Esta saída é evidência para o revisor de segurança. Guarde-a.
-- ═══════════════════════════════════════════════════════════════════════════

\set ON_ERROR_STOP off
\pset pager off

-- semear: usuário autoridade com CPF no cofre
-- Adaptação: auth.users.id não tem default nesta instância do Supabase Auth
-- (confirmado via \d auth.users) — o arquivo entregue assumia um default
-- que não existe aqui. Único ajuste necessário no arquivo (fora isso,
-- idêntico ao entregue).
insert into auth.users (id, email) values (gen_random_uuid(), 'autoridade@gab.gov.br') on conflict do nothing;
insert into usuarios (tenant_id, auth_user_id, nome, email, papel, ativo)
select t.id, u.id, 'Autoridade A', 'autoridade@gab.gov.br', 'autoridade', true
from tenants t, auth.users u where t.slug='gab-a' and u.email='autoridade@gab.gov.br'
on conflict do nothing;

insert into aegis_cofre (tenant_id, usuario_id, especie, valor, mascara, registrado_por)
select t.id, us.id, 'cpf', '52998224725', '•••.982.247-••', 'cadastro'
from tenants t join usuarios us on us.tenant_id=t.id
where t.slug='gab-a' and us.email='autoridade@gab.gov.br'
on conflict do nothing;

select id::text as tid from tenants where slug='gab-a' \gset
select u.id::text as uid, u.auth_user_id::text as auid from usuarios u
 where u.email='autoridade@gab.gov.br' \gset

\echo ''
\echo '═══ TESTE 1 — aplicação NÃO consegue ler o cofre direto (deve dar erro) ═══'
begin;
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', :'auid', 'app_metadata',
    json_build_object('tenant_id', :'tid','mundo','gabinete'))::text, true);
select valor from aegis_cofre;
rollback;

\echo ''
\echo '═══ TESTE 2 — máscara é livre e não abre o cofre ═══'
begin;
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', :'auid', 'app_metadata',
    json_build_object('tenant_id', :'tid','mundo','gabinete'))::text, true);
select case when aegis_mascara(:'uid'::uuid,'cpf') = '•••.982.247-••'
            then 'PASSOU — máscara sem abrir o cofre' else 'FALHOU' end;
rollback;

\echo ''
\echo '═══ TESTE 3 — leitura pela porta oficial, com motivo declarado ═══'
begin;
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', :'auid', 'app_metadata',
    json_build_object('tenant_id', :'tid','mundo','gabinete'))::text, true);
select case when aegis_ler(:'uid'::uuid,'cpf','emissao_contrato','contrato de adesão') = '52998224725'
            then 'PASSOU — autoridade lê declarando motivo' else 'FALHOU' end;
commit;

\echo ''
\echo '═══ TESTE 4 — a leitura ficou registrada? ═══'
select case when count(*)=1 then 'PASSOU — acesso gravado com motivo'
            else 'FALHOU — leitura sem registro' end from aegis_acessos;

\echo ''
\echo '═══ TESTE 5 — registro de acesso é imutável (deve dar erro) ═══'
delete from aegis_acessos;

\echo ''
\echo '═══ TESTE 6 — máscara igual ao valor é recusada (deve dar erro) ═══'
insert into aegis_cofre (tenant_id, usuario_id, especie, valor, mascara, registrado_por)
select t.id, us.id, 'data_nascimento', '1980-01-01', '1980-01-01', 'teste'
from tenants t join usuarios us on us.tenant_id=t.id
where t.slug='gab-a' and us.email='autoridade@gab.gov.br';

\echo ''
\echo '═══ TESTE 7 — máscara sem marca de ocultação é recusada (deve dar erro) ═══'
insert into aegis_cofre (tenant_id, usuario_id, especie, valor, mascara, registrado_por)
select t.id, us.id, 'data_nascimento', '1980-01-01', '01/01/1980', 'teste'
from tenants t join usuarios us on us.tenant_id=t.id
where t.slug='gab-a' and us.email='autoridade@gab.gov.br';
\set ON_ERROR_STOP off
insert into auth.users (id, email) values (gen_random_uuid(), 'assessor@gab.gov.br') on conflict do nothing;
insert into usuarios (tenant_id, auth_user_id, nome, email, papel, ativo)
select t.id, u.id, 'Assessor Comum', 'assessor@gab.gov.br', 'assessor', true
from tenants t, auth.users u where t.slug='gab-a' and u.email='assessor@gab.gov.br'
on conflict do nothing;

select id::text as tid from tenants where slug='gab-a' \gset
select auth_user_id::text as asid from usuarios where email='assessor@gab.gov.br' \gset
select id::text as uid from usuarios where email='autoridade@gab.gov.br' \gset

\echo '═══ TESTE 8 — ASSESSOR tenta abrir o cofre (deve dar erro) ═══'
begin;
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', :'asid', 'app_metadata',
    json_build_object('tenant_id', :'tid','mundo','gabinete'))::text, true);
select aegis_ler(:'uid'::uuid,'cpf','conferencia_identidade','curiosidade');
rollback;

\echo ''
\echo '═══ TESTE 9 — assessor VÊ a máscara (isso é permitido e suficiente) ═══'
begin;
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', :'asid', 'app_metadata',
    json_build_object('tenant_id', :'tid','mundo','gabinete'))::text, true);
select case when aegis_mascara(:'uid'::uuid,'cpf') is not null
            then 'PASSOU — assessor vê a máscara, nunca o valor' else 'FALHOU' end;
rollback;

\echo ''
\echo '═══ TESTE 10 — gabinete VIZINHO não vê nem a máscara ═══'
select id::text as tid_b from tenants where slug='gab-b' \gset
begin;
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', gen_random_uuid(), 'app_metadata',
    json_build_object('tenant_id', :'tid_b','mundo','gabinete'))::text, true);
select case when aegis_mascara(:'uid'::uuid,'cpf') is null
            then 'PASSOU — cofre isolado entre gabinetes' else 'FALHOU — VAZAMENTO' end;
rollback;
