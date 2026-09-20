-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVORA OVERSIGHT — TESTE DE ACEITE DA INTELIGÊNCIA LEGISLATIVA
-- Valida a Skill "evora-veritas-inteligencia-legislativa" v1.0 GOLD
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Conteúdo idêntico ao entregue (12_teste_legis.sql, 12/12, arquivado em
-- _versoes_anteriores/legis_resposta_parecer_entregues_v11_1/) — nenhuma
-- adaptação necessária aqui: o script só define request.jwt.claims, quem
-- lê isso são as funções (agora via evora_claims(), não auth.uid()).
--
-- RODAR DEPOIS de AO SUPABASE BLOCO1.md.txt + evora rls mvp v1.sql (Fase
-- 13) aplicados. NÃO faz rollback — cria tenant fictício ('gab-legis') e
-- dados reais que permanecem no banco. Só contra Supabase local/throwaway,
-- nunca num ambiente compartilhado ou de produção.
--
-- COMO LER: testes que imprimem PASSOU estão corretos.
-- Testes que produzem ERROR de propósito também — o erro É o sucesso.
-- Guarde a saída: é evidência para o revisor de segurança.
-- ═══════════════════════════════════════════════════════════════════════════

\set ON_ERROR_STOP off
\pset pager off

-- ---------------------------------------------------------------------------
-- CENÁRIO — uma matéria que ilustra a armadilha central da Skill
-- ---------------------------------------------------------------------------
-- O PL 84/2026 consta formalmente como "em tramitação". Mas o último evento
-- MATERIAL foi há meses; depois dele houve apenas juntada de documento, que
-- é movimentação administrativa.
--
-- Um sistema ingênuo diria "está tramitando". A Skill exige distinguir.

insert into farus_territorios (codigo_ibge, municipio, uf)
values (3552205,'Sorocaba','SP') on conflict do nothing;
select id::text as ter from farus_territorios where municipio='Sorocaba' \gset

insert into tenants (slug, nome_autoridade, municipio_sede, uf, area_atuacao,
                     nivel_separacao, perfil, ciencia_travas)
values ('gab-legis','Vereadora Teste','Sorocaba','SP','["Sorocaba"]'::jsonb,
        'logico','{}'::jsonb,true)
on conflict (slug) do nothing;
insert into farus_tenant_territorios (tenant_id, territorio_id, principal)
select t.id, :'ter'::uuid, true from tenants t where t.slug='gab-legis'
on conflict do nothing;
select id::text as tid from tenants where slug='gab-legis' \gset

-- pessoas
insert into legis_pessoas (territorio_id, nome, partido, cargo, verificado_por)
values (:'ter'::uuid,'Vereadora Autora','PARTIDO-A','Vereadora','L. Gonzaga'),
       (:'ter'::uuid,'Vereador Relator','PARTIDO-B','Vereador','L. Gonzaga'),
       (:'ter'::uuid,'Vereador Antigo','PARTIDO-C','Vereador','L. Gonzaga')
on conflict do nothing;
select id::text as p_autor from legis_pessoas where nome='Vereadora Autora' \gset
select id::text as p_rel   from legis_pessoas where nome='Vereador Relator' \gset
select id::text as p_ant   from legis_pessoas where nome='Vereador Antigo' \gset

-- órgão
insert into legis_orgaos (territorio_id, nome, natureza, competencia, inicio)
values (:'ter'::uuid,'Comissão de Educação','comissao_permanente',
        'Matérias de educação e transporte escolar','2025-01-01')
on conflict do nothing;
select id::text as org from legis_orgaos where nome='Comissão de Educação' \gset

-- § 7 — COMPOSIÇÃO COM DOIS PERÍODOS: o antigo saiu, o novo entrou
insert into legis_composicoes (orgao_id, pessoa_id, papel, inicio, termino)
values (:'org'::uuid, :'p_ant'::uuid, 'presidente', '2025-01-01','2025-12-31'),
       (:'org'::uuid, :'p_rel'::uuid, 'presidente', '2026-01-01', null)
on conflict do nothing;

-- a matéria
insert into legis_materias (territorio_id, especie, numero, ano, processo, ementa,
                            assunto, autor_id, status_formal, status_operacional,
                            orgao_atual_id, relator_id, relator_desde,
                            fonte_url, apresentada_em, verificado_por, verificado_em)
values (:'ter'::uuid,'projeto_lei','84',2026,'2437/2026',
        'Reestrutura o transporte escolar municipal e institui critérios de atendimento',
        array['transporte','escolar','educacao'], :'p_autor'::uuid,
        'em_tramitacao','aguardando_parecer',
        :'org'::uuid, :'p_rel'::uuid, '2026-03-10',
        'https://sorocaba.camarasempapel.com.br/spl/','2026-02-01',
        'L. Gonzaga', now())
on conflict do nothing;
select id::text as mat from legis_materias where numero='84' and ano=2026 \gset

-- § 6 — EVENTOS: o último MATERIAL é de março; depois, só administrativo
insert into legis_eventos (materia_id, tipo, ocorrido_em, orgao_id, pessoa_id, descricao, material)
values
 (:'mat'::uuid,'apresentacao','2026-02-01',null,:'p_autor'::uuid,'Protocolo da matéria',true),
 (:'mat'::uuid,'distribuicao','2026-02-15',:'org'::uuid,null,'Distribuída à Comissão',true),
 (:'mat'::uuid,'designacao_relator','2026-03-10',:'org'::uuid,:'p_rel'::uuid,'Relator designado',true),
 (:'mat'::uuid,'movimentacao_administrativa','2026-07-20',null,null,'Juntada de documento',false),
 (:'mat'::uuid,'movimentacao_administrativa','2026-09-01',null,null,'Conferência de autuação',false)
on conflict do nothing;

\echo ''
\echo '═══════════════════════════════════════════════════════════════════'
\echo ' TESTE 1 — § 5 · status formal e operacional são independentes'
\echo '═══════════════════════════════════════════════════════════════════'
select case when status_formal='em_tramitacao' and status_operacional='aguardando_parecer'
            then 'PASSOU — as duas dimensões coexistem sem se deduzirem'
            else 'FALHOU' end as resultado
from legis_situacao_real(:'mat'::uuid);

\echo ''
\echo '═══════════════════════════════════════════════════════════════════'
\echo ' TESTE 2 — § 6 · o último evento MATERIAL ignora o administrativo'
\echo '           A armadilha central: "em tramitação" ≠ avançando'
\echo '═══════════════════════════════════════════════════════════════════'
select case when ultimo_evento_material='designacao_relator'
             and ultima_data_material='2026-03-10'
             and eventos_administrativos_depois=2
            then 'PASSOU — vê março, e conta 2 movimentações administrativas depois'
            else 'FALHOU — confundiu juntada com avanço' end as resultado
from legis_situacao_real(:'mat'::uuid);

\echo ''
\echo '── a resposta que a Skill exige (§ 6) ──'
select 'Formalmente em ' || status_formal ||
       '. Operacionalmente, sem movimentação material desde ' ||
       to_char(ultima_data_material,'DD/MM/YYYY') || ' (' || ultimo_evento_material ||
       '), há ' || dias_sem_movimento || ' dias. Houve ' ||
       eventos_administrativos_depois || ' movimentações administrativas depois. ' ||
       'Está em ' || orgao_atual || '. Relator: ' || relator || '.' as resposta
from legis_situacao_real(:'mat'::uuid);

\echo ''
\echo '═══════════════════════════════════════════════════════════════════'
\echo ' TESTE 3 — § 9 · sem pauta, a previsão é "nenhuma"'
\echo '           Nunca inventar previsão que não existe'
\echo '═══════════════════════════════════════════════════════════════════'
select case when natureza_previsao='nenhuma_previsao' and proxima_pauta is null
            then 'PASSOU — não inventa previsão'
            else 'FALHOU' end as resultado
from legis_situacao_real(:'mat'::uuid);

\echo ''
\echo '═══════════════════════════════════════════════════════════════════'
\echo ' TESTE 4 — § 9 · reunião agendada NÃO é votação garantida'
\echo '═══════════════════════════════════════════════════════════════════'
insert into legis_pautas (territorio_id, orgao_id, sessao_numero, sessao_tipo,
                          realizada_em, horario, publicada_em, versao, fonte_url)
values (:'ter'::uuid, :'org'::uuid, '79','ordinária', current_date + 3, '08:45',
        now(), 'resumida','https://sorocaba.camarasempapel.com.br/spl/sessoes.aspx');
select id::text as pau from legis_pautas where sessao_numero='79' \gset
insert into legis_pauta_materias (pauta_id, materia_id, ordem, fase, natureza_previsao)
values (:'pau'::uuid, :'mat'::uuid, 17, '1ª discussão', 'reuniao_agendada')
on conflict do nothing;

select case when natureza_previsao='reuniao_agendada'
            then 'PASSOU — registrado como reunião agendada, NÃO como decisão prevista'
            else 'FALHOU' end as resultado
from legis_situacao_real(:'mat'::uuid);

\echo ''
\echo '═══════════════════════════════════════════════════════════════════'
\echo ' TESTE 5 — § 7 · quem presidia a comissão à época × hoje'
\echo '           A memória temporal que a Skill exige'
\echo '═══════════════════════════════════════════════════════════════════'
\echo '── composição em 01/06/2025 ──'
select pessoa, partido, papel from legis_composicao_em(:'org'::uuid, '2025-06-01');
\echo '── composição hoje ──'
select pessoa, partido, papel from legis_composicao_em(:'org'::uuid, current_date);
select case when (select pessoa from legis_composicao_em(:'org'::uuid,'2025-06-01') limit 1)
             <> (select pessoa from legis_composicao_em(:'org'::uuid, current_date) limit 1)
            then 'PASSOU — a composição de 2025 difere da atual'
            else 'FALHOU — perdeu a memória temporal' end as resultado;

\echo ''
\echo '═══════════════════════════════════════════════════════════════════'
\echo ' TESTE 6 — § 4 · localizar a matéria SEM o número, por tema'
\echo '═══════════════════════════════════════════════════════════════════'
select case when count(*)>=1 then 'PASSOU — achou pelo tema'
            else 'FALHOU' end as resultado
from legis_buscar('transporte escolar', :'ter'::uuid);

\echo ''
\echo '═══════════════════════════════════════════════════════════════════'
\echo ' TESTE 7 — § 12 · pesquisa reversa: pessoa → matérias'
\echo '═══════════════════════════════════════════════════════════════════'
select case when count(*)>=1 then 'PASSOU — pesquisa reversa por pessoa'
            else 'FALHOU' end as resultado
from legis_materias_da_pessoa(:'p_rel'::uuid);

\echo ''
\echo '═══════════════════════════════════════════════════════════════════'
\echo ' TESTE 8 — § 44 · matéria NÃO verificada não aparece na busca'
\echo '═══════════════════════════════════════════════════════════════════'
insert into legis_materias (territorio_id, especie, numero, ano, ementa, assunto,
                            status_formal, apresentada_em)
values (:'ter'::uuid,'projeto_lei','999',2026,
        'Matéria sobre transporte escolar carregada sem verificação humana',
        array['transporte'],'em_tramitacao','2026-09-01')
on conflict do nothing;
select case when count(*)=0 then 'PASSOU — matéria sem verificação não responde'
            else 'FALHOU — devolveu matéria não verificada' end as resultado
from legis_buscar('carregada sem verificação', :'ter'::uuid);

\echo ''
\echo '═══════════════════════════════════════════════════════════════════'
\echo ' TESTE 9 — § 32 · isolamento: sem credencial, nega tudo'
\echo '═══════════════════════════════════════════════════════════════════'
begin;
set local role authenticated;
select set_config('request.jwt.claims','{}',true) \gset x
select case when count(*)=0 then 'PASSOU — nega sem token' else 'FALHOU' end as resultado
from legis_materias;
rollback;

\echo ''
\echo '═══════════════════════════════════════════════════════════════════'
\echo ' TESTE 10 — § 32 · gabinete do município vê as matérias'
\echo '═══════════════════════════════════════════════════════════════════'
begin;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub',gen_random_uuid(),
  'app_metadata', json_build_object('tenant_id', :'tid','mundo','gabinete'))::text, true) \gset x
select case when count(*)>=1 then 'PASSOU — vê o acervo legislativo do município'
            else 'FALHOU' end as resultado
from legis_materias;
rollback;

\echo ''
\echo '═══════════════════════════════════════════════════════════════════'
\echo ' TESTE 11 — a aplicação NÃO grava matéria'
\echo '            DEVE DAR ERRO. Escrita é do motor.'
\echo '═══════════════════════════════════════════════════════════════════'
begin;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub',gen_random_uuid(),
  'app_metadata', json_build_object('tenant_id', :'tid','mundo','gabinete'))::text, true) \gset x
insert into legis_materias (territorio_id, especie, ementa, status_formal)
values (:'ter'::uuid,'projeto_lei','tentativa pela aplicação','em_tramitacao');
rollback;

\echo ''
\echo '═══════════════════════════════════════════════════════════════════'
\echo ' TESTE 12 — composição com período incoerente'
\echo '            DEVE DAR ERRO.'
\echo '═══════════════════════════════════════════════════════════════════'
insert into legis_composicoes (orgao_id, pessoa_id, papel, inicio, termino)
values (:'org'::uuid, :'p_ant'::uuid, 'titular', '2026-06-01','2026-01-01');

\echo ''
\echo '═══════════════════════════════════════════════════════════════════'
\echo ' FIM. Testes 1 a 10 devem imprimir PASSOU.'
\echo ' Testes 11 e 12 devem produzir ERROR — é o comportamento correto.'
\echo '═══════════════════════════════════════════════════════════════════'
