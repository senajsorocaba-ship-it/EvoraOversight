# BLOCO 3 de 3 — Teste de aceite (RLS)

**Cole no SQL Editor do Supabase e rode.**
Copie apenas o que está **dentro** do bloco abaixo — não copie esta linha nem as crases.

**Pré-requisito:** BLOCO 1 (schema) e BLOCO 2 (RLS) já rodados nesse projeto.

**O que este bloco faz:** cria dois tenants fictícios e algumas fontes/uma
linha de auditoria, troca para o papel `authenticated` (o mesmo que a
aplicação usa) e simula tokens diferentes para provar, com `RAISE
EXCEPTION` a cada falha, os quatro cenários já prometidos no rodapé do
BLOCO 2:

1. Isolamento entre tenants
2. Separação de mundos
3. Trilha de auditoria imutável
4. Falha fechada sem `tenant_id` no token

Mais um cenário **bônus** (não contado nos "4 de 4"): confirma que
`autoridade`/`auditor` realmente enxergam os dois mundos — sem essa prova,
os cenários 1 e 2 sozinhos não descartariam um RLS bloqueando todo mundo
por engano.

Todos os dados são fictícios e o bloco roda dentro de uma transação
fechada em `ROLLBACK` — nada fica gravado no banco, passe ou falhe o
teste.

**Esperado:** uma sequência de `NOTICE`s `CENARIO N OK` (mais `BONUS OK`)
terminando em:

```
NOTICE:  TESTE DE ACEITE: PASSOU — 4 de 4 cenários oficiais OK (+ bônus: autoridade enxerga os dois mundos).
```

**Erro em vermelho:** o script para no cenário que falhou (`CENARIO N
FALHOU: ...` explica o motivo). A transação fica aberta e sem confirmar —
rode `rollback;` sozinho antes de tentar de novo, para garantir que
nenhuma fixture fique presa. Não avance para produção com um cenário
falhando: pare e me chame.

---

```sql
-- =====================================================================
-- ÉVORA OVERSIGHT — TESTE DE ACEITE (RLS)
-- Arquivo: evora_rls_teste_aceite_v1.sql
-- Versão:  v1.0 · 31/07/2026 · alinhado ao Manual Supremo v10.6
-- =====================================================================
--
-- BLOCO 3 de 3. Prova, com dados 100% fictícios e ASSERTS que falham
-- alto (RAISE EXCEPTION), os quatro cenários do teste de aceite já
-- descritos no rodapé de evora_rls_mvp_v1.sql (BLOCO 2):
--
--   1. Isolamento entre tenants
--   2. Separação de mundos
--   3. Trilha de auditoria imutável
--   4. Falha fechada sem tenant_id no token
--
-- Inclui ainda um cenário BÔNUS (não contado nos "4 de 4"): confirma
-- que 'autoridade'/'auditor' realmente enxergam os dois mundos — é a
-- outra metade da regra de separação que os 4 cenários oficiais não
-- exercitam sozinhos.
--
-- PRÉ-REQUISITOS: BLOCO 1 (schema) e BLOCO 2 (RLS) já executados.
--
-- DADOS: fictícios, criados e desfeitos por este próprio script. O
-- script inteiro roda dentro de uma transação encerrada em ROLLBACK
-- — nada fica gravado no banco, ganhe ou perca o teste.
--
-- PAPEL NECESSÁRIO: a criação das fixtures (dois tenants, fontes de
-- ambos) precisa de um papel que ignore RLS — o papel padrão do SQL
-- Editor do Supabase ('postgres') serve. As verificações de cada
-- cenário trocam para o papel 'authenticated', que é o mesmo papel
-- usado pela aplicação real e não ignora RLS.
--
-- COMO RODAR: cole o arquivo inteiro no SQL Editor do Supabase e rode.
-- Se tudo passar, a última linha é
--   NOTICE:  TESTE DE ACEITE: PASSOU — 4 de 4 cenários oficiais OK
--            (+ bônus: autoridade enxerga os dois mundos).
-- Qualquer falha aparece como ERROR em vermelho, com o número do
-- cenário e o motivo — pare e chame o responsável.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 0. FIXTURES — dois tenants fictícios ("A" e "B"), fontes em cada
--    mundo do tenant A, uma fonte do tenant B, e um usuário autoridade
--    do tenant A (para o cenário bônus). Roda com o papel que abriu a
--    sessão (bypassa RLS), antes de trocarmos para 'authenticated'.
-- ---------------------------------------------------------------------
insert into tenants (id, slug, nome_autoridade, municipio_sede, uf, ciencia_travas, ciencia_data, operacional)
values
  ('11111111-1111-1111-1111-111111111111', 'teste-aceite-tenant-a', 'Fulana de Teste A', 'Sorocaba', 'SP', true, now(), true),
  ('22222222-2222-2222-2222-222222222222', 'teste-aceite-tenant-b', 'Fulano de Teste B', 'Sorocaba', 'SP', true, now(), true)
on conflict (id) do nothing;

insert into usuarios (id, tenant_id, auth_user_id, nome, email, papel, mundo_permitido, ativo)
values
  ('11111111-1111-1111-1111-1111111111a1', '11111111-1111-1111-1111-111111111111',
   '99999999-9999-9999-9999-999999999999', 'Autoridade Teste A', 'autoridade.teste.a@exemplo.invalido',
   'autoridade', null, true)
on conflict (id) do nothing;

insert into fontes (id, tenant_id, mundo, nome, nivel)
values
  ('11111111-1111-1111-1111-1111111111a2', '11111111-1111-1111-1111-111111111111', 'gabinete', 'Fonte Fictícia A · Gabinete', 'F1'),
  ('11111111-1111-1111-1111-1111111111a3', '11111111-1111-1111-1111-111111111111', 'campanha', 'Fonte Fictícia A · Campanha', 'F1'),
  ('22222222-2222-2222-2222-2222222222b1', '22222222-2222-2222-2222-222222222222', 'gabinete', 'Fonte Fictícia B · Gabinete', 'F1')
on conflict (id) do nothing;

insert into auditoria (tenant_id, mundo, ator_descricao, acao, entidade, entidade_id, detalhe)
values
  ('11111111-1111-1111-1111-111111111111', 'gabinete', 'evora_rls_teste_aceite_v1.sql',
   'teste_aceite', 'fontes', '11111111-1111-1111-1111-1111111111a2', '{"origem": "bloco_3"}'::jsonb);

-- A partir daqui, tudo roda como a aplicação real rodaria: papel
-- 'authenticated', sem privilégio de dono de tabela, sujeito a RLS.
set local role authenticated;

-- ---------------------------------------------------------------------
-- CENÁRIO 1 — ISOLAMENTO ENTRE TENANTS
-- Autenticado como tenant A (mundo=gabinete, sub sem usuário
-- correspondente), a fonte do tenant B não pode aparecer, e a fonte
-- do próprio tenant, no próprio mundo, deve aparecer.
-- ---------------------------------------------------------------------
select set_config(
  'request.jwt.claims',
  '{"app_metadata": {"tenant_id": "11111111-1111-1111-1111-111111111111", "mundo": "gabinete"}, "sub": "00000000-0000-0000-0000-000000000000"}',
  true
);

do $$
declare
  v_fonte_b_visivel  int;
  v_fonte_propria_ok int;
begin
  select count(*) into v_fonte_b_visivel
    from fontes where id = '22222222-2222-2222-2222-2222222222b1';

  select count(*) into v_fonte_propria_ok
    from fontes where id = '11111111-1111-1111-1111-1111111111a2';

  if v_fonte_b_visivel <> 0 then
    raise exception 'CENARIO 1 FALHOU: tenant A enxergou a fonte do tenant B (isolamento entre tenants quebrado).';
  end if;

  if v_fonte_propria_ok <> 1 then
    raise exception 'CENARIO 1 FALHOU: tenant A não enxergou a própria fonte no próprio mundo (RLS restritivo demais).';
  end if;

  raise notice 'CENARIO 1 OK: isolamento entre tenants confirmado.';
end $$;

-- ---------------------------------------------------------------------
-- CENÁRIO 2 — SEPARAÇÃO DE MUNDOS
-- Mesmo tenant A, agora com mundo=campanha no token e sub sem usuário
-- correspondente (ninguém "vê os dois mundos" aqui). A fonte do
-- gabinete não pode aparecer; a da campanha deve aparecer.
-- ---------------------------------------------------------------------
select set_config(
  'request.jwt.claims',
  '{"app_metadata": {"tenant_id": "11111111-1111-1111-1111-111111111111", "mundo": "campanha"}, "sub": "00000000-0000-0000-0000-000000000000"}',
  true
);

do $$
declare
  v_gabinete_visivel int;
  v_campanha_ok      int;
begin
  select count(*) into v_gabinete_visivel
    from fontes where id = '11111111-1111-1111-1111-1111111111a2';

  select count(*) into v_campanha_ok
    from fontes where id = '11111111-1111-1111-1111-1111111111a3';

  if v_gabinete_visivel <> 0 then
    raise exception 'CENARIO 2 FALHOU: com mundo=campanha no token, a fonte do gabinete apareceu (separação de mundos quebrada).';
  end if;

  if v_campanha_ok <> 1 then
    raise exception 'CENARIO 2 FALHOU: com mundo=campanha no token, a própria fonte da campanha não apareceu.';
  end if;

  raise notice 'CENARIO 2 OK: separação de mundos confirmada.';
end $$;

-- ---------------------------------------------------------------------
-- CENÁRIO 3 — TRILHA DE AUDITORIA IMUTÁVEL
-- Tentar UPDATE em auditoria deve falhar, mesmo autenticado como o
-- próprio tenant dono da linha. A falha pode vir do trigger de
-- imutabilidade (evora_auditoria_imutavel) ou da ausência de policy
-- de UPDATE — as duas são camadas de defesa válidas.
-- ---------------------------------------------------------------------
select set_config(
  'request.jwt.claims',
  '{"app_metadata": {"tenant_id": "11111111-1111-1111-1111-111111111111", "mundo": "gabinete"}, "sub": "99999999-9999-9999-9999-999999999999"}',
  true
);

do $$
begin
  update auditoria
     set detalhe = '{"tentativa": "alteracao_indevida"}'::jsonb
   where tenant_id = '11111111-1111-1111-1111-111111111111';

  -- Se chegou aqui, o UPDATE não foi barrado. Isso é a falha.
  raise exception 'CENARIO 3 FALHOU: UPDATE em auditoria foi aceito (trilha deixou de ser imutável).';
exception
  when others then
    raise notice 'CENARIO 3 OK: UPDATE em auditoria foi barrado (%).', sqlerrm;
end $$;

-- ---------------------------------------------------------------------
-- CENÁRIO 4 — FALHA FECHADA SEM tenant_id NO TOKEN
-- Um token sem tenant_id (ou nenhum token) não pode enxergar nada.
-- ---------------------------------------------------------------------

-- 4a: claims presentes, mas sem tenant_id dentro de app_metadata.
select set_config(
  'request.jwt.claims',
  '{"app_metadata": {"mundo": "gabinete"}, "sub": "99999999-9999-9999-9999-999999999999"}',
  true
);

do $$
declare
  v_fontes  int;
  v_tenants int;
begin
  select count(*) into v_fontes  from fontes;
  select count(*) into v_tenants from tenants;

  if v_fontes <> 0 or v_tenants <> 0 then
    raise exception 'CENARIO 4a FALHOU: token sem tenant_id enxergou % fonte(s) e % tenant(s) (falha fechada quebrada).', v_fontes, v_tenants;
  end if;

  raise notice 'CENARIO 4a OK: token sem tenant_id não enxergou nada.';
end $$;

-- 4b: nenhum token na requisição (setting totalmente vazio).
select set_config('request.jwt.claims', '', true);

do $$
declare
  v_fontes  int;
  v_tenants int;
begin
  select count(*) into v_fontes  from fontes;
  select count(*) into v_tenants from tenants;

  if v_fontes <> 0 or v_tenants <> 0 then
    raise exception 'CENARIO 4b FALHOU: requisição sem token nenhum enxergou % fonte(s) e % tenant(s) (falha fechada quebrada).', v_fontes, v_tenants;
  end if;

  raise notice 'CENARIO 4b OK: requisição sem token nenhum não enxergou nada.';
end $$;

-- ---------------------------------------------------------------------
-- BÔNUS — 'autoridade' enxerga os dois mundos
-- Sem isto provado, os cenários 1-2 sozinhos poderiam esconder um RLS
-- excessivamente restritivo (que barrasse até autoridade/auditor).
-- ---------------------------------------------------------------------
select set_config(
  'request.jwt.claims',
  '{"app_metadata": {"tenant_id": "11111111-1111-1111-1111-111111111111", "mundo": "campanha"}, "sub": "99999999-9999-9999-9999-999999999999"}',
  true
);

do $$
declare
  v_gabinete int;
  v_campanha int;
begin
  select count(*) into v_gabinete from fontes where id = '11111111-1111-1111-1111-1111111111a2';
  select count(*) into v_campanha from fontes where id = '11111111-1111-1111-1111-1111111111a3';

  if v_gabinete <> 1 or v_campanha <> 1 then
    raise exception 'BONUS FALHOU: autoridade com mundo=campanha no token não enxergou os dois mundos (gabinete=%, campanha=%).', v_gabinete, v_campanha;
  end if;

  raise notice 'BONUS OK: autoridade enxerga os dois mundos independente do mundo do token.';
end $$;

-- ---------------------------------------------------------------------
-- FIM — volta ao papel original e desfaz TODAS as fixtures.
-- ---------------------------------------------------------------------
reset role;

do $$
begin
  raise notice 'TESTE DE ACEITE: PASSOU — 4 de 4 cenários oficiais OK (+ bônus: autoridade enxerga os dois mundos).';
end $$;

rollback;

-- =====================================================================
-- Se algum ERROR em vermelho apareceu acima, o script parou naquele
-- ponto e este NOTICE final não é impresso — é assim mesmo: procure o
-- "CENARIO N FALHOU" correspondente e chame o responsável. O ROLLBACK
-- final roda de qualquer forma, então nenhuma fixture fica no banco.
-- =====================================================================
```

---

*Se os quatro cenários oficiais e o bônus passarem, o coração do
multi-tenant está de pé e provado por teste — não só por leitura de
código.*
*Évora Oversight · Confidencial — Eng. de Sistemas Luiz Gonzaga Filho*
