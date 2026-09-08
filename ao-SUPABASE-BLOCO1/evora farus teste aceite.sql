-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVORA OVERSIGHT — TESTE DE ACEITE DO FARUS F1
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Prova que as travas do acervo funcionam. Rode DEPOIS de evora_farus_f1.sql.
--
-- COMO LER O RESULTADO
-- Cada teste imprime PASSOU ou FALHOU. Os testes 4 a 7 provocam erro de
-- propósito — neles, **ver o erro é o sucesso**.
--
-- Este arquivo é a evidência que se mostra ao cliente e ao revisor de
-- segurança. Guarde a saída.
-- ═══════════════════════════════════════════════════════════════════════════

\set ON_ERROR_STOP off
\pset pager off

-- ---------------------------------------------------------------------------
-- CENÁRIO: dois gabinetes na MESMA cidade + um em cidade diferente
-- ---------------------------------------------------------------------------

insert into farus_territorios (codigo_ibge, municipio, uf)
values (3552205, 'Sorocaba', 'SP'), (3509502, 'Campinas', 'SP')
on conflict do nothing;

insert into tenants (slug, nome_autoridade, municipio_sede, uf, area_atuacao,
                     nivel_separacao, perfil, ciencia_travas)
values
 ('gab-a','Vereadora A','Sorocaba','SP','["Sorocaba"]'::jsonb,'logico','{}'::jsonb,true),
 ('gab-b','Vereador B','Sorocaba','SP','["Sorocaba"]'::jsonb,'logico','{}'::jsonb,true),
 ('gab-c','Vereadora C','Campinas','SP','["Campinas"]'::jsonb,'logico','{}'::jsonb,true)
on conflict (slug) do nothing;

insert into farus_tenant_territorios (tenant_id, territorio_id, principal)
select t.id, ter.id, true
from tenants t join farus_territorios ter
  on ter.municipio = t.municipio_sede and ter.uf = t.uf
where t.slug in ('gab-a','gab-b','gab-c')
on conflict do nothing;

-- Acervo público de Sorocaba (sem dono) + pesquisa privada do gabinete A
insert into farus_itens (territorio_id, origem_aquisicao, tenant_origem, especie,
                         titulo, conteudo, estado, verificado_por, verificado_em, hash_conteudo)
select ter.id, 'coleta_programada', null, 'ato_oficial',
       'Decreto 27.412 — acessibilidade', 'texto do decreto',
       'confirmado', 'motor', now(), farus_hash('Decreto 27.412 — acessibilidade','texto do decreto')
from farus_territorios ter where ter.municipio='Sorocaba'
on conflict do nothing;

insert into farus_itens (territorio_id, origem_aquisicao, tenant_origem, especie,
                         titulo, conteudo, estado, hash_conteudo)
select ter.id, 'demanda_tenant', t.id, 'materia',
       'Pesquisa privada do gabinete A', 'conteudo reservado',
       'indicado', farus_hash('Pesquisa privada do gabinete A','conteudo reservado')
from farus_territorios ter, tenants t
where ter.municipio='Sorocaba' and t.slug='gab-a'
on conflict do nothing;

-- Capturar os identificadores ANTES de trocar de papel.
-- Já como 'authenticated', a sessão não lê `tenants` — e é assim que deve ser.
select id::text as id_a from tenants where slug='gab-a' \gset
select id::text as id_b from tenants where slug='gab-b' \gset
select id::text as id_c from tenants where slug='gab-c' \gset

\echo ''
\echo '════════════════════════════════════════════════════════════════'
\echo ' TESTE 1 — Gabinete A enxerga o acervo público da sua cidade'
\echo '════════════════════════════════════════════════════════════════'
begin;
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', gen_random_uuid(),
    'app_metadata', json_build_object(
      'tenant_id', :'id_a',
      'mundo','gabinete'))::text, true);

select case when count(*) >= 1 then 'PASSOU — vê o acervo público'
            else 'FALHOU — deveria ver' end as resultado
from farus_itens where origem_aquisicao='coleta_programada';
rollback;

\echo ''
\echo '════════════════════════════════════════════════════════════════'
\echo ' TESTE 2 — Gabinete B (mesma cidade) COMPARTILHA o acervo público'
\echo '           É a economia de escala do negócio'
\echo '════════════════════════════════════════════════════════════════'
begin;
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', gen_random_uuid(),
    'app_metadata', json_build_object(
      'tenant_id', :'id_b',
      'mundo','gabinete'))::text, true);

select case when count(*) >= 1 then 'PASSOU — compartilha o acervo da cidade'
            else 'FALHOU — deveria compartilhar' end as resultado
from farus_itens where origem_aquisicao='coleta_programada';
rollback;

\echo ''
\echo '════════════════════════════════════════════════════════════════'
\echo ' TESTE 3 — Gabinete B NÃO vê a pesquisa privada do gabinete A'
\echo '           É a trava mais importante do módulo'
\echo '════════════════════════════════════════════════════════════════'
begin;
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', gen_random_uuid(),
    'app_metadata', json_build_object(
      'tenant_id', :'id_b',
      'mundo','gabinete'))::text, true);

select case when count(*) = 0 then 'PASSOU — não vê pesquisa alheia'
            else 'FALHOU — VAZAMENTO ENTRE CLIENTES' end as resultado
from farus_itens where origem_aquisicao='demanda_tenant';
rollback;

\echo ''
\echo '════════════════════════════════════════════════════════════════'
\echo ' TESTE 4 — Gabinete de OUTRA cidade não vê nada de Sorocaba'
\echo '════════════════════════════════════════════════════════════════'
begin;
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', gen_random_uuid(),
    'app_metadata', json_build_object(
      'tenant_id', :'id_c',
      'mundo','gabinete'))::text, true);

select case when count(*) = 0 then 'PASSOU — território isolado'
            else 'FALHOU — vê acervo de cidade alheia' end as resultado
from farus_itens fi join farus_territorios ft on ft.id=fi.territorio_id
where ft.municipio='Sorocaba';
rollback;

\echo ''
\echo '════════════════════════════════════════════════════════════════'
\echo ' TESTE 5 — Sessão SEM credencial não vê nada (falha fechada)'
\echo '════════════════════════════════════════════════════════════════'
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{}', true);
select case when count(*) = 0 then 'PASSOU — nega sem credencial'
            else 'FALHOU — vazou sem token' end as resultado
from farus_itens;
rollback;

\echo ''
\echo '════════════════════════════════════════════════════════════════'
\echo ' TESTE 6 — Fonte NÃO vira configurada sem liberação humana'
\echo '           DEVE DAR ERRO. Ver o erro é o sucesso. (decisão D6)'
\echo '════════════════════════════════════════════════════════════════'
insert into farus_fontes (territorio_id, nome, especie, estado)
select id, 'Portal Descoberto pelo Radar', 'materia', 'configurada'
from farus_territorios where municipio='Sorocaba';

\echo ''
\echo '════════════════════════════════════════════════════════════════'
\echo ' TESTE 7 — Acervo público NÃO pode ter dono'
\echo '           DEVE DAR ERRO. Impede pesquisa privada virar pública.'
\echo '════════════════════════════════════════════════════════════════'
insert into farus_itens (territorio_id, origem_aquisicao, tenant_origem, especie,
                         titulo, hash_conteudo)
select ter.id, 'coleta_programada', t.id, 'materia', 'item incoerente',
       farus_hash('item incoerente', null)
from farus_territorios ter, tenants t
where ter.municipio='Sorocaba' and t.slug='gab-a';

\echo ''
\echo '════════════════════════════════════════════════════════════════'
\echo ' TESTE 8 — Item confirmado SEM verificador registrado'
\echo '           DEVE DAR ERRO. Só afirma o que alguém verificou.'
\echo '════════════════════════════════════════════════════════════════'
insert into farus_itens (territorio_id, origem_aquisicao, especie, titulo,
                         estado, hash_conteudo)
select id, 'coleta_programada', 'materia', 'sem verificador',
       'confirmado', farus_hash('sem verificador', null)
from farus_territorios where municipio='Sorocaba';

\echo ''
\echo '════════════════════════════════════════════════════════════════'
\echo ' TESTE 9 — Acervo público NÃO pode ser excluído'
\echo '           DEVE DAR ERRO. Retenção indeterminada.'
\echo '════════════════════════════════════════════════════════════════'
delete from farus_itens where origem_aquisicao='coleta_programada';

\echo ''
\echo '════════════════════════════════════════════════════════════════'
\echo ' TESTE 10 — Deduplicação: mesmo conteúdo não entra duas vezes'
\echo '            DEVE DAR ERRO na segunda inserção.'
\echo '════════════════════════════════════════════════════════════════'
insert into farus_itens (territorio_id, origem_aquisicao, especie, titulo, conteudo,
                         estado, verificado_por, verificado_em, hash_conteudo)
select ter.id, 'coleta_programada', 'ato_oficial',
       'Decreto  27.412 —  ACESSIBILIDADE', 'TEXTO DO DECRETO',
       'confirmado','motor', now(),
       farus_hash('Decreto  27.412 —  ACESSIBILIDADE','TEXTO DO DECRETO')
from farus_territorios ter where ter.municipio='Sorocaba';

\echo ''
\echo '════════════════════════════════════════════════════════════════'
\echo ' FIM. Testes 1 a 5 devem imprimir PASSOU.'
\echo ' Testes 6 a 10 devem imprimir ERROR — é o comportamento correto.'
\echo '════════════════════════════════════════════════════════════════'
