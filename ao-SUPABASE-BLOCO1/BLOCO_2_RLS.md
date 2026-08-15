# BLOCO 2 de 3 — Travas de isolamento (RLS)

**Cole no SQL Editor do Supabase e rode.**
Copie apenas o que está **dentro** do bloco abaixo — não copie esta linha nem as crases.

**Esperado:** 13 políticas criadas · 11 tabelas com isolamento forçado.
Avisos com `NOTICE ... does not exist, skipping` são normais.
Erro em vermelho: pare e me chame.

**Conferir depois de rodar:**

```
select count(*) as politicas from pg_policies where schemaname='public';
```
Deve devolver **13**.

---

```sql
-- =====================================================================
-- ÉVORA OVERSIGHT — SEGURANÇA DE ISOLAMENTO (RLS)
-- Arquivo: evora_rls_mvp_v1.sql
-- Versão:  v1.0 · 20/07/2026 · alinhado ao Manual Supremo v10.6
-- =====================================================================
--
-- Este arquivo é O CORAÇÃO DA SEPARAÇÃO. Ele traduz em regra de banco
-- dois princípios invioláveis do Manual:
--
--   · ISOLAMENTO ENTRE TENANTS — nenhum gabinete vê dado de outro.
--     (É o diferencial de venda: "nem o vereador ao lado enxerga.")
--   · SEPARAÇÃO DE MUNDOS — gabinete e campanha não se cruzam.
--     (Princípio Inviolável nº 4; única passagem é a Ponte Bia↔Nil,
--      que acontece na aplicação e fica registrada em `auditoria`.)
--
-- COMO FUNCIONA
-- O Supabase entrega, em cada requisição autenticada, um JWT. A aplicação
-- deve gravar nesse token dois campos, dentro de `app_metadata`:
--     tenant_id : uuid do gabinete
--     mundo     : 'gabinete' ou 'campanha'
-- As funções abaixo leem esses campos. Sem eles, o acesso é negado —
-- falha fechada, que é o comportamento correto para segurança.
--
-- IMPORTANTE: a chave `service_role` do Supabase IGNORA o RLS por design.
-- Ela é para trabalhos internos (o motor do briefing, por exemplo) e
-- NUNCA deve ser exposta em navegador, aplicativo ou repositório público.
--
-- ORDEM: rodar depois de evora_schema_mvp_v1.sql.
-- =====================================================================

-- ---------------------------------------------------------------------
-- FUNÇÕES DE CONTEXTO — leem o JWT da requisição
-- ---------------------------------------------------------------------
create or replace function evora_claims()
returns jsonb language sql stable as $$
  -- Robusta a três situações reais: setting ausente, setting vazio ('')
  -- e JSON malformado. Em qualquer uma delas devolve NULL, e o RLS nega
  -- o acesso — falha fechada, que é o comportamento correto.
  select case
    when coalesce(nullif(current_setting('request.jwt.claims', true), ''), '') = '' then null
    else nullif(current_setting('request.jwt.claims', true), '')::jsonb
  end;
$$;

create or replace function evora_tenant_atual()
returns uuid language sql stable as $$
  select nullif(
    coalesce(
      evora_claims() -> 'app_metadata' ->> 'tenant_id',
      evora_claims() ->> 'tenant_id'
    ), ''
  )::uuid;
$$;

create or replace function evora_mundo_atual()
returns evora_mundo language sql stable as $$
  select nullif(
    coalesce(
      evora_claims() -> 'app_metadata' ->> 'mundo',
      evora_claims() ->> 'mundo'
    ), ''
  )::evora_mundo;
$$;

-- Papéis que legitimamente enxergam os dois mundos (autoridade e auditor).
create or replace function evora_ve_os_dois_mundos()
returns boolean language sql stable as $$
  select exists (
    select 1 from usuarios u
    where u.tenant_id = evora_tenant_atual()
      and u.ativo
      and u.mundo_permitido is null
      and u.papel in ('autoridade', 'auditor')
      and u.auth_user_id = nullif(evora_claims() ->> 'sub', '')::uuid
  );
$$;

comment on function evora_tenant_atual is 'Lê tenant_id do JWT. Sem token válido devolve NULL e o RLS nega tudo (falha fechada).';

-- ---------------------------------------------------------------------
-- LIGAR O RLS EM TODAS AS TABELAS
-- ---------------------------------------------------------------------
alter table tenants               enable row level security;
alter table usuarios              enable row level security;
alter table fontes                enable row level security;
alter table briefings             enable row level security;
alter table demandas              enable row level security;
alter table lugares               enable row level security;
alter table compromissos          enable row level security;
alter table atas                  enable row level security;
alter table desdobramentos        enable row level security;
alter table desdobramento_eventos enable row level security;
alter table auditoria             enable row level security;

-- Força o RLS inclusive para o dono das tabelas (defesa em profundidade)
alter table tenants               force row level security;
alter table usuarios              force row level security;
alter table fontes                force row level security;
alter table briefings             force row level security;
alter table demandas              force row level security;
alter table lugares               force row level security;
alter table compromissos          force row level security;
alter table atas                  force row level security;
alter table desdobramentos        force row level security;
alter table desdobramento_eventos force row level security;
alter table auditoria             force row level security;

-- ---------------------------------------------------------------------
-- 1. TENANTS — cada um enxerga apenas o próprio registro
-- ---------------------------------------------------------------------
drop policy if exists tenants_isolamento on tenants;
create policy tenants_isolamento on tenants
  for select using (id = evora_tenant_atual());

drop policy if exists tenants_sem_escrita_pelo_cliente on tenants;
create policy tenants_sem_escrita_pelo_cliente on tenants
  for update using (id = evora_tenant_atual() and false);
  -- criação e alteração de tenant são operação administrativa (service_role)

-- ---------------------------------------------------------------------
-- 2. USUARIOS — isolado por tenant
-- ---------------------------------------------------------------------
drop policy if exists usuarios_isolamento on usuarios;
create policy usuarios_isolamento on usuarios
  for all using (tenant_id = evora_tenant_atual())
          with check (tenant_id = evora_tenant_atual());

-- ---------------------------------------------------------------------
-- 3 a 10. CONTEÚDO — isolado por tenant E por mundo
--
-- Regra: a linha aparece se for do meu tenant E (for do meu mundo OU eu
-- for autoridade/auditor, que legitimamente veem os dois).
-- ---------------------------------------------------------------------

drop policy if exists fontes_isolamento on fontes;
create policy fontes_isolamento on fontes
  for all using (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  ) with check (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  );

drop policy if exists briefings_isolamento on briefings;
create policy briefings_isolamento on briefings
  for all using (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  ) with check (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  );

drop policy if exists demandas_isolamento on demandas;
create policy demandas_isolamento on demandas
  for all using (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  ) with check (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  );

-- lugares não tem mundo (endereço é endereço): isola só por tenant
drop policy if exists lugares_isolamento on lugares;
create policy lugares_isolamento on lugares
  for all using (tenant_id = evora_tenant_atual())
          with check (tenant_id = evora_tenant_atual());

drop policy if exists compromissos_isolamento on compromissos;
create policy compromissos_isolamento on compromissos
  for all using (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  ) with check (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  );

drop policy if exists atas_isolamento on atas;
create policy atas_isolamento on atas
  for all using (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  ) with check (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  );

drop policy if exists desdobramentos_isolamento on desdobramentos;
create policy desdobramentos_isolamento on desdobramentos
  for all using (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  ) with check (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  );

drop policy if exists desdob_eventos_isolamento on desdobramento_eventos;
create policy desdob_eventos_isolamento on desdobramento_eventos
  for all using (tenant_id = evora_tenant_atual())
          with check (tenant_id = evora_tenant_atual());

-- ---------------------------------------------------------------------
-- 11. AUDITORIA — leitura restrita, escrita só INSERT, nunca alteração
-- ---------------------------------------------------------------------
drop policy if exists auditoria_leitura on auditoria;
create policy auditoria_leitura on auditoria
  for select using (
    tenant_id = evora_tenant_atual() and evora_ve_os_dois_mundos()
  );  -- só autoridade e auditor leem a trilha

drop policy if exists auditoria_insercao on auditoria;
create policy auditoria_insercao on auditoria
  for insert with check (tenant_id = evora_tenant_atual());

-- Não existe policy de UPDATE nem de DELETE para auditoria: sem policy,
-- a operação é negada pelo RLS. Somado ao trigger do schema, são duas
-- camadas independentes garantindo a imutabilidade da trilha.

-- =====================================================================
-- TESTE DE ACEITE — a prova que vira argumento de venda
-- =====================================================================
-- Rode com dados fictícios e confirme:
--
--   1. Dois tenants, cada um com uma fonte. Autenticado como tenant A,
--      a fonte do tenant B NÃO aparece.               → isolamento entre clientes
--   2. Um tenant, duas fontes (uma 'gabinete', uma 'campanha').
--      Com mundo='campanha' no token, a fonte do gabinete NÃO aparece.
--                                                      → separação de mundos
--   3. Tentar UPDATE em `auditoria` → erro.            → trilha imutável
--   4. Requisição sem tenant_id no token → nada aparece. → falha fechada
--
-- Se os quatro passarem, o coração do multi-tenant está de pé.
-- =====================================================================
```

---

*Depois deste, falta só o BLOCO 3 (teste de aceite).*
*Évora Oversight · Confidencial — Eng. de Sistemas Luiz Gonzaga Filho*
