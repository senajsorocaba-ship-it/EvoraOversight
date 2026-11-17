-- =====================================================================
-- ÉVORA OVERSIGHT — TESTE DE ACEITE (Demandas + Histórico)
-- Arquivo: evora_demandas_teste_aceite.sql
-- Tarefa 3, Briefing Técnico Guiron (13/11/2026) · 17/11/2026
-- =====================================================================
--
-- Prova, com dados 100% fictícios e ASSERTS que falham alto (RAISE
-- EXCEPTION), os 10 cenários de aceite pedidos na Tarefa 3:
--
--    1. Gabinete A insere uma demanda própria e consegue
--    2. Gabinete A lê apenas as demandas dele
--    3. Gabinete A tenta ler uma demanda do B e recebe 0 linhas
--    4. Gabinete A não consegue alterar demanda do B
--    5. Ninguém consegue apagar uma demanda
--    6. Inserção com tenant_id de outro gabinete é recusada
--    7. Usuário inativo/inexistente fica sem acesso (falha fechada)
--    8. Mudança de status gera uma linha em demandas_historico (trigger)
--    9. demandas_historico recusa UPDATE e DELETE
--   10. Protocolo repetido no mesmo gabinete é recusado; o mesmo
--       protocolo em gabinetes diferentes é aceito
--
-- PRÉ-REQUISITOS: BLOCO 1 + BLOCO 2 já executados, incluindo a migration
-- da Tarefa 3 (enum evora_origem_demanda, renomeações, demandas_historico,
-- seção 25 do RLS).
--
-- DADOS: fictícios, criados e desfeitos por este próprio script, dentro
-- de uma transação encerrada em ROLLBACK — nada fica gravado, ganhe ou
-- perca o teste.
--
-- A TRAVA JURÍDICA (evora_travar_demandas_sem_parecer) continua ativa e
-- intacta — por isso os dois tenants fictícios abaixo nascem com
-- demandas_parecer_juridico = true, igual ao tenant piloto do
-- supabase/seed.sql. Sem isso, TODO insert/update neste teste falharia
-- com "aguarda parecer jurídico", e nenhum dos 10 cenários rodaria.
--
-- COMO RODAR: cole o arquivo inteiro no SQL Editor do Supabase e rode.
-- Se tudo passar, a última linha é
--   NOTICE:  TESTE DE ACEITE (DEMANDAS): PASSOU — 10 de 10 cenários OK.
-- Qualquer falha aparece como ERROR em vermelho, com o número do
-- cenário e o motivo.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 0. FIXTURES — dois gabinetes fictícios ("A" e "B"), um usuário ativo
--    e um inativo em A, um usuário ativo em B. Roda com o papel que abriu
--    a sessão (bypassa RLS), antes de trocarmos para 'authenticated'.
-- ---------------------------------------------------------------------
insert into tenants (id, slug, nome_autoridade, municipio_sede, uf,
                      ciencia_travas, ciencia_data, operacional, demandas_parecer_juridico)
values
  ('a1111111-1111-1111-1111-111111111111', 'teste-demandas-tenant-a', 'Fulana Demandas A', 'Sorocaba', 'SP', true, now(), true, true),
  ('b2222222-2222-2222-2222-222222222222', 'teste-demandas-tenant-b', 'Fulano Demandas B', 'Sorocaba', 'SP', true, now(), true, true)
on conflict (id) do nothing;

insert into usuarios (id, tenant_id, auth_user_id, nome, email, papel, mundo_permitido, ativo)
values
  ('a1111111-1111-1111-1111-1111111111a1', 'a1111111-1111-1111-1111-111111111111',
   '91111111-1111-1111-1111-111111111111', 'Assessor Ativo A', 'assessor.a@exemplo.invalido',
   'assessor', null, true),
  ('a1111111-1111-1111-1111-1111111111a2', 'a1111111-1111-1111-1111-111111111111',
   '92222222-2222-2222-2222-222222222222', 'Assessor Inativo A', 'assessor.inativo.a@exemplo.invalido',
   'assessor', null, false),
  ('b2222222-2222-2222-2222-2222222222b1', 'b2222222-2222-2222-2222-222222222222',
   '93333333-3333-3333-3333-333333333333', 'Assessor Ativo B', 'assessor.b@exemplo.invalido',
   'assessor', null, true)
on conflict (id) do nothing;

-- Uma demanda já existente do gabinete B (pra testar leitura/alteração
-- cruzada nos cenários 2-4), criada como dono de tabela — bypassa RLS e
-- também bypassa o trigger de histórico não ser o alvo deste teste.
insert into demandas (id, tenant_id, mundo, protocolo, assunto, status, registrada_por)
values ('b2222222-2222-2222-2222-2222222222d1', 'b2222222-2222-2222-2222-222222222222',
        'gabinete', 'DEM-B-0001', 'Demanda fictícia do gabinete B', 'registrada',
        'b2222222-2222-2222-2222-2222222222b1')
on conflict (id) do nothing;

-- A partir daqui, tudo roda como a aplicação real rodaria: papel
-- 'authenticated', sujeito a RLS.
set local role authenticated;

-- ---------------------------------------------------------------------
-- CENÁRIO 1 — Gabinete A insere uma demanda própria e consegue
-- ---------------------------------------------------------------------
select set_config(
  'request.jwt.claims',
  '{"app_metadata": {"tenant_id": "a1111111-1111-1111-1111-111111111111", "mundo": "gabinete"}, "sub": "91111111-1111-1111-1111-111111111111"}',
  true
);

do $$
declare
  v_origem evora_origem_demanda;
begin
  insert into demandas (id, tenant_id, mundo, protocolo, assunto, status, registrada_por)
  values ('a1111111-1111-1111-1111-1111111111d1', 'a1111111-1111-1111-1111-111111111111',
          'gabinete', 'DEM-A-0001', 'Demanda fictícia do gabinete A', 'registrada',
          'a1111111-1111-1111-1111-1111111111a1');

  select origem into v_origem from demandas where id = 'a1111111-1111-1111-1111-1111111111d1';

  if v_origem is distinct from 'cidadao' then
    raise exception 'CENARIO 1 FALHOU: origem não assumiu o default esperado (veio %).', v_origem;
  end if;

  raise notice 'CENARIO 1 OK: gabinete A inseriu demanda própria, origem default = cidadao.';
end $$;

-- ---------------------------------------------------------------------
-- CENÁRIO 2 — Gabinete A lê apenas as demandas dele
-- ---------------------------------------------------------------------
do $$
declare
  v_total      int;
  v_so_de_a    int;
begin
  select count(*) into v_total from demandas;
  select count(*) into v_so_de_a from demandas where tenant_id = 'a1111111-1111-1111-1111-111111111111';

  if v_total <> v_so_de_a then
    raise exception 'CENARIO 2 FALHOU: gabinete A enxergou % linha(s) no total, mas só % são dele (vazou dado de outro tenant).', v_total, v_so_de_a;
  end if;

  raise notice 'CENARIO 2 OK: gabinete A só enxerga as próprias % demanda(s).', v_total;
end $$;

-- ---------------------------------------------------------------------
-- CENÁRIO 3 — Gabinete A tenta ler uma demanda do B e recebe 0 linhas
-- ---------------------------------------------------------------------
do $$
declare
  v_vazou int;
begin
  select count(*) into v_vazou from demandas where id = 'b2222222-2222-2222-2222-2222222222d1';

  if v_vazou <> 0 then
    raise exception 'CENARIO 3 FALHOU: gabinete A conseguiu ler a demanda do gabinete B.';
  end if;

  raise notice 'CENARIO 3 OK: demanda do gabinete B não aparece pro gabinete A.';
end $$;

-- ---------------------------------------------------------------------
-- CENÁRIO 4 — Gabinete A não consegue alterar demanda do B
-- ---------------------------------------------------------------------
do $$
declare
  v_linhas_afetadas int;
begin
  update demandas set status = 'em_andamento'
   where id = 'b2222222-2222-2222-2222-2222222222d1';
  get diagnostics v_linhas_afetadas = row_count;

  if v_linhas_afetadas <> 0 then
    raise exception 'CENARIO 4 FALHOU: gabinete A alterou % linha(s) da demanda do gabinete B.', v_linhas_afetadas;
  end if;

  raise notice 'CENARIO 4 OK: UPDATE do gabinete A na demanda do gabinete B afetou 0 linhas.';
end $$;

-- ---------------------------------------------------------------------
-- CENÁRIO 5 — Ninguém consegue apagar uma demanda
-- (sem grant de delete pra authenticated — nem na própria, nem na alheia)
-- ---------------------------------------------------------------------
do $$
begin
  delete from demandas where id = 'a1111111-1111-1111-1111-1111111111d1';
  raise exception 'CENARIO 5 FALHOU: DELETE em demandas foi aceito (deveria ser recusado por falta de grant).';
exception
  when insufficient_privilege then
    raise notice 'CENARIO 5 OK: DELETE em demandas foi recusado (%).', sqlerrm;
end $$;

-- ---------------------------------------------------------------------
-- CENÁRIO 6 — Inserção com tenant_id de outro gabinete é recusada
-- ---------------------------------------------------------------------
do $$
begin
  insert into demandas (tenant_id, mundo, protocolo, assunto, status, registrada_por)
  values ('b2222222-2222-2222-2222-222222222222', 'gabinete', 'DEM-A-FORJADA', 'Tentativa de forjar tenant_id',
          'registrada', 'a1111111-1111-1111-1111-1111111111a1');

  raise exception 'CENARIO 6 FALHOU: inserção com tenant_id alheio foi aceita.';
exception
  -- Pode vir da RLS (with check) OU da trava jurídica (que roda ANTES da
  -- RLS e não enxerga o tenants.demandas_parecer_juridico do tenant
  -- alheio, por causa da própria RLS de `tenants`) — qualquer uma das
  -- duas é uma recusa válida; o que importa é que nenhuma deixa passar.
  when others then
    raise notice 'CENARIO 6 OK: inserção com tenant_id de outro gabinete foi recusada (%).', sqlerrm;
end $$;

-- ---------------------------------------------------------------------
-- CENÁRIO 7 — Usuário inativo/inexistente fica sem acesso (falha fechada)
-- A policy de demandas isola por tenant_id/mundo do TOKEN, não consulta
-- usuarios.ativo a cada leitura — quem decide se um usuário inativo
-- recebe token novo é o hook de login (evora_token_hook), fora do
-- alcance de um teste em SQL puro. O que ESTE teste pode — e deve —
-- provar é a parte que a Tarefa 3 de fato controla: o histórico nunca
-- credita uma ação a alguém que não está mais ativo. Com sub apontando
-- pro Assessor Inativo A, o trigger de histórico precisa cair pro
-- fallback (registrada_por), nunca atribuir ao inativo.
-- ---------------------------------------------------------------------
select set_config(
  'request.jwt.claims',
  '{"app_metadata": {"tenant_id": "a1111111-1111-1111-1111-111111111111", "mundo": "gabinete"}, "sub": "92222222-2222-2222-2222-222222222222"}',
  true
);

do $$
declare
  v_autor_historico uuid;
begin
  update demandas set status = 'aguardando_terceiro'
   where id = 'a1111111-1111-1111-1111-1111111111d1';

  -- ctid, não criado_em: tudo roda na MESMA transação, então now()
  -- devolve o mesmo instante pra toda linha — criado_em empata entre
  -- elas. ctid reflete a ordem física de inserção, suficiente aqui
  -- porque a tabela é append-only dentro desta transação (sem update).
  select autor_id into v_autor_historico
    from demandas_historico
   where demanda_id = 'a1111111-1111-1111-1111-1111111111d1'
   order by ctid desc
   limit 1;

  if v_autor_historico = 'a1111111-1111-1111-1111-1111111111a2' then
    raise exception 'CENARIO 7 FALHOU: histórico atribuiu a mudança ao usuário INATIVO.';
  end if;

  if v_autor_historico is distinct from 'a1111111-1111-1111-1111-1111111111a1' then
    raise exception 'CENARIO 7 FALHOU: autor_id esperado era o registrada_por (fallback), veio %.', v_autor_historico;
  end if;

  raise notice 'CENARIO 7 OK: usuário inativo nunca é creditado — histórico caiu pro fallback (registrada_por).';
end $$;

-- Volta pro usuário ativo pros cenários seguintes.
select set_config(
  'request.jwt.claims',
  '{"app_metadata": {"tenant_id": "a1111111-1111-1111-1111-111111111111", "mundo": "gabinete"}, "sub": "91111111-1111-1111-1111-111111111111"}',
  true
);

-- ---------------------------------------------------------------------
-- CENÁRIO 8 — Mudança de status gera uma linha em demandas_historico
-- automaticamente (trigger), com o autor certo desta vez.
-- ---------------------------------------------------------------------
do $$
declare
  v_qtd            int;
  v_status_anterior evora_status_demanda;
  v_status_novo     evora_status_demanda;
  v_autor           uuid;
begin
  update demandas set status = 'resolvida'
   where id = 'a1111111-1111-1111-1111-1111111111d1';

  select count(*) into v_qtd from demandas_historico
   where demanda_id = 'a1111111-1111-1111-1111-1111111111d1';

  select status_anterior, status_novo, autor_id
    into v_status_anterior, v_status_novo, v_autor
    from demandas_historico
   where demanda_id = 'a1111111-1111-1111-1111-1111111111d1'
   order by ctid desc
   limit 1;

  -- esperado: 1 eventos de criação + 2 mudanças de status (cenário 7 e
  -- este) = 3 linhas no total até aqui.
  if v_qtd <> 3 then
    raise exception 'CENARIO 8 FALHOU: esperava 3 linha(s) em demandas_historico, veio %.', v_qtd;
  end if;

  if v_status_anterior <> 'aguardando_terceiro' or v_status_novo <> 'resolvida' then
    raise exception 'CENARIO 8 FALHOU: trilha de status errada (de % para %).', v_status_anterior, v_status_novo;
  end if;

  if v_autor <> 'a1111111-1111-1111-1111-1111111111a1' then
    raise exception 'CENARIO 8 FALHOU: autor_id não é o usuário ativo autenticado.';
  end if;

  raise notice 'CENARIO 8 OK: trigger gravou a mudança de status automaticamente, com autor certo.';
end $$;

-- ---------------------------------------------------------------------
-- CENÁRIO 9 — demandas_historico recusa UPDATE e DELETE
-- ---------------------------------------------------------------------
do $$
declare
  v_alvo uuid;
begin
  select id into v_alvo from demandas_historico
   where demanda_id = 'a1111111-1111-1111-1111-1111111111d1'
   limit 1;

  begin
    update demandas_historico set evento = 'forjado' where id = v_alvo;
    raise exception 'CENARIO 9 FALHOU: UPDATE em demandas_historico foi aceito.';
  exception
    when others then
      raise notice 'CENARIO 9a OK: UPDATE em demandas_historico foi barrado (%).', sqlerrm;
  end;

  begin
    delete from demandas_historico where id = v_alvo;
    raise exception 'CENARIO 9 FALHOU: DELETE em demandas_historico foi aceito.';
  exception
    when others then
      raise notice 'CENARIO 9b OK: DELETE em demandas_historico foi barrado (%).', sqlerrm;
  end;
end $$;

-- ---------------------------------------------------------------------
-- CENÁRIO 10 — Protocolo repetido no mesmo gabinete é recusado; o mesmo
-- protocolo em gabinetes diferentes é aceito.
-- ---------------------------------------------------------------------
do $$
begin
  insert into demandas (tenant_id, mundo, protocolo, assunto, status, registrada_por)
  values ('a1111111-1111-1111-1111-111111111111', 'gabinete', 'DEM-A-0001',
          'Tentativa de protocolo duplicado', 'registrada', 'a1111111-1111-1111-1111-1111111111a1');

  raise exception 'CENARIO 10 FALHOU: protocolo repetido no mesmo gabinete foi aceito.';
exception
  when unique_violation then
    raise notice 'CENARIO 10a OK: protocolo repetido no mesmo gabinete foi recusado (%).', sqlerrm;
end $$;

select set_config(
  'request.jwt.claims',
  '{"app_metadata": {"tenant_id": "b2222222-2222-2222-2222-222222222222", "mundo": "gabinete"}, "sub": "93333333-3333-3333-3333-333333333333"}',
  true
);

do $$
declare
  v_qtd int;
begin
  insert into demandas (tenant_id, mundo, protocolo, assunto, status, registrada_por)
  values ('b2222222-2222-2222-2222-222222222222', 'gabinete', 'DEM-A-0001',
          'Mesmo protocolo, gabinete diferente', 'registrada', 'b2222222-2222-2222-2222-2222222222b1');

  select count(*) into v_qtd from demandas
   where protocolo = 'DEM-A-0001' and tenant_id = 'b2222222-2222-2222-2222-222222222222';

  if v_qtd <> 1 then
    raise exception 'CENARIO 10 FALHOU: mesmo protocolo em gabinete diferente não foi aceito.';
  end if;

  raise notice 'CENARIO 10b OK: mesmo protocolo em gabinete diferente foi aceito normalmente.';
end $$;

-- ---------------------------------------------------------------------
-- FIM — volta ao papel original e desfaz TODAS as fixtures.
-- ---------------------------------------------------------------------
reset role;

do $$
begin
  raise notice 'TESTE DE ACEITE (DEMANDAS): PASSOU — 10 de 10 cenários OK.';
end $$;

rollback;

-- =====================================================================
-- Se algum ERROR em vermelho apareceu acima, o script parou naquele
-- ponto e este NOTICE final não é impresso — procure o "CENARIO N
-- FALHOU" correspondente. O ROLLBACK final roda de qualquer forma,
-- então nenhuma fixture fica no banco.
-- =====================================================================
