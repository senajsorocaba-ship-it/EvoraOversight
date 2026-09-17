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
alter table achados_fiscalizacao  enable row level security;
alter table mencoes_imprensa      enable row level security;
alter table municipios            enable row level security;
alter table municipio_fontes      enable row level security;
alter table municipio_trilha      enable row level security;
alter table municipio_vereadores  enable row level security;
alter table municipio_vereadores_pendencias enable row level security;
alter table farus_territorios        enable row level security;
alter table farus_tenant_territorios enable row level security;
alter table farus_fontes             enable row level security;
alter table farus_itens              enable row level security;
alter table aegis_cofre              enable row level security;
alter table aegis_acessos            enable row level security;
-- evora_rate_limit (Manual v11.0): mesmo caso de municipio_vereadores — sem
-- grant e sem policy nenhuma, só a função security definer que a usa toca
-- nela (ver evora_checar_rate_limite, evora_auth_mvp_v1.sql).
alter table evora_rate_limit         enable row level security;

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
-- achados_fiscalizacao/mencoes_imprensa (Fase 6): estavam enabled mas não
-- forced — lacuna encontrada e corrigida na Fase 7 (Atlas Municipal),
-- ficando consistentes com todo o resto do arquivo.
alter table achados_fiscalizacao  force row level security;
alter table mencoes_imprensa      force row level security;
alter table municipios            force row level security;
alter table municipio_fontes      force row level security;
-- municipio_trilha NÃO é forçada aqui de propósito diferente: nem sequer
-- tem policy (ver seção 15) — sem grant e sem policy, RLS enabled já
-- nega tudo para authenticated/anon; force é redundante mas inofensivo,
-- então mantemos por consistência com as demais.
alter table municipio_trilha      force row level security;
-- municipio_vereadores (Fase 8): mesmo caso de municipio_trilha — sem
-- grant e sem policy, e-mail de vereador só é lido pelas funções security
-- definer (evora_auth_mvp_v1.sql), nunca via REST direto.
alter table municipio_vereadores  force row level security;
-- municipio_vereadores_pendencias (Fase 9): mesmo caso — fila operacional
-- interna do vigia, sem grant/policy para authenticated/anon, só
-- service_role (a CLI) lê e escreve.
alter table municipio_vereadores_pendencias force row level security;
-- FARUS/Aegis (Fases 10/11, Manual v10.9.1): mesma disciplina de sempre —
-- ver seções 16 e 17 mais abaixo para as policies (FARUS tem leitura
-- condicional por território+propriedade; Aegis não tem policy de select
-- nenhuma no cofre, de propósito).
alter table farus_territorios        force row level security;
alter table farus_tenant_territorios force row level security;
alter table farus_fontes             force row level security;
alter table farus_itens              force row level security;
alter table aegis_cofre              force row level security;
alter table aegis_acessos            force row level security;
alter table evora_rate_limit         force row level security;

-- ---------------------------------------------------------------------
-- GRANTS DE TABELA — obrigatório para a Data API (PostgREST) enxergar a
-- tabela, ANTES mesmo da RLS entrar em jogo.
--
-- Supabase parou de expor automaticamente tabelas novas do schema `public`
-- para as roles da Data API (anon/authenticated/service_role) sem GRANT
-- explícito — é o comportamento padrão atual, tanto local (CLI) quanto na
-- nuvem. Sem isto, toda chamada via PostgREST devolve "permission denied
-- for table X" (código 42501) mesmo com policy de RLS correta, porque o
-- Postgres nega no nível de privilégio da tabela antes de a RLS ser
-- avaliada. Detectado rodando este bloco contra o Supabase local de verdade
-- (supabase start) — não aparece testando só com `set role` no SQL Editor.
--
-- Princípio do menor privilégio na concessão de tabela (a RLS acima ainda
-- é quem decide QUAIS LINHAS, isto aqui só decide quais OPERAÇÕES a role
-- pode tentar): sem DELETE para `authenticated` em nenhuma tabela — o
-- Manual já estabelece "nada é deletado", soft delete via ativo/ativa.
-- `anon` não recebe nada — todo o produto exige login (Princípio de falha
-- fechada já documentado acima).
grant select, insert, update on usuarios, fontes, briefings, demandas,
  lugares, compromissos, atas, desdobramentos, desdobramento_eventos
  to authenticated;
grant select on tenants to authenticated;         -- só leitura do próprio; update é sempre 'false' na policy
grant select, insert on auditoria to authenticated;  -- imutável: sem update/delete de propósito (ver seção 11)
grant select on achados_fiscalizacao, mencoes_imprensa to authenticated;  -- só leitura: quem escreve é a ingestão (service_role), não o usuário

-- Atlas Municipal (Anexo 16, Fase 7): leitura aberta a QUALQUER tenant
-- autenticado — é o ponto todo do Atlas, dado de cidade não é isolado por
-- tenant (ver policies de select-using(true) na seção 15). Escrita
-- travada ao service_role só: sem insert/update/delete para authenticated
-- aqui, a trava anti-envenenamento começa neste grant, antes mesmo da RLS.
grant select on municipios, municipio_fontes to authenticated;
-- municipio_trilha: SEM grant para authenticated nesta fase — não existe
-- visualizador (nenhuma UI foi construída na Fase 7). service_role
-- continua com acesso total via a linha abaixo. Reabrir isto é uma linha,
-- se/quando um leitor de trilha for construído.

-- FARUS (Fase 10, Manual v10.9.1): leitura para authenticated — a policy
-- (seção 16) é quem decide QUAIS linhas (território do tenant + público-ou-
-- próprio). farus_tenant_territorios também recebe insert/delete porque é
-- o próprio tenant quem inclui/remove um território que acompanha — nunca
-- update (trocar de território é remover e incluir de novo, mais simples
-- de auditar). Escrita do acervo (farus_itens/farus_fontes) é só do motor
-- (service_role) — nenhum insert/update/delete para authenticated aqui.
grant select on farus_territorios, farus_fontes, farus_itens to authenticated;
grant select, insert, delete on farus_tenant_territorios to authenticated;

-- Aegis A0 (Fase 11): SEM grant nenhum em aegis_cofre para
-- authenticated/anon — a ausência é a proteção (não existe select direto
-- possível nem que a policy quisesse liberar). aegis_acessos (a trilha de
-- QUEM leu o cofre) tem select — a autoridade pode auditar os acessos do
-- próprio gabinete (policy na seção 17); insert só via aegis_ler
-- (security definer, já grava sozinha).
grant select on aegis_acessos to authenticated;

-- service_role ignora RLS por design (ver nota no topo deste arquivo) — o
-- motor do briefing e outros jobs de servidor precisam de acesso irrestrito
-- às 16 tabelas, então aqui a concessão é total, não por operação.
grant all privileges on all tables in schema public to service_role;

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

-- ---------------------------------------------------------------------
-- 12/13. ACHADOS_FISCALIZACAO / MENCOES_IMPRENSA (Fase 6) — só SELECT
-- para authenticated (grant já reflete isso); quem escreve é a ingestão
-- via service_role, que ignora RLS. Mesmo padrão tenant+mundo das demais
-- tabelas de conteúdo.
-- ---------------------------------------------------------------------
drop policy if exists achados_fiscalizacao_isolamento on achados_fiscalizacao;
create policy achados_fiscalizacao_isolamento on achados_fiscalizacao
  for select using (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  );

drop policy if exists mencoes_imprensa_isolamento on mencoes_imprensa;
create policy mencoes_imprensa_isolamento on mencoes_imprensa
  for select using (
        tenant_id = evora_tenant_atual()
    and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos())
  );

-- ---------------------------------------------------------------------
-- 14. MUNICIPIOS / MUNICIPIO_FONTES (Fase 7, Anexo 16) — leitura aberta
-- a qualquer tenant autenticado, propositalmente DIFERENTE do padrão
-- tenant_id=evora_tenant_atual() usado em toda tabela acima: o Atlas é
-- camada compartilhada da plataforma, não isolada por tenant — dois
-- gabinetes da mesma cidade devem enxergar a mesma linha. A trava
-- anti-envenenamento não é "quem lê", é "quem escreve": não existe
-- policy de insert/update/delete aqui (nem grant, ver seção de GRANTS
-- acima) — só service_role escreve, sempre por script/CLI, nunca por
-- um usuário comum autenticado.
-- ---------------------------------------------------------------------
drop policy if exists municipios_leitura_publica on municipios;
create policy municipios_leitura_publica on municipios
  for select using (true);

drop policy if exists municipio_fontes_leitura_publica on municipio_fontes;
create policy municipio_fontes_leitura_publica on municipio_fontes
  for select using (true);

-- municipio_trilha: nenhuma policy — sem grant para authenticated (acima)
-- e RLS enabled+forced já nega tudo por padrão. Só service_role lê/escreve.

-- municipio_vereadores (Fase 8): mesmo caso — nenhuma policy, nenhum grant
-- para authenticated/anon. O e-mail de vereador é dado sensível o
-- suficiente para nunca ser exposto via REST direto, nem em leitura; o
-- autocadastro consulta esta tabela só através de
-- evora_verificar_vereador/evora_autocadastro_vereador (evora_auth_mvp_v1.sql),
-- funções security definer que respondem 1 e-mail por vez.

-- ---------------------------------------------------------------------
-- 15. FREIO HUMANO (v10.8) — só quem tem alcada_aprovacao dá ciência,
-- só de si mesmo, timestamp sempre do servidor.
--
-- A policy briefings_isolamento (seção 3) já libera UPDATE em qualquer
-- coluna para qualquer usuário do tenant+mundo — inclusive ciencia_por.
-- Sozinha, ela deixaria um assessor sem alçada preencher ciencia_por com
-- o PRÓPRIO id (autoaprovação) ou pior, com o id de outra pessoa. Esta
-- trigger fecha essa lacuna: usa evora_claims() (definida acima nesta
-- mesma seção de contexto) para exigir que quem está autenticado agora
-- SEJA o usuário referenciado em ciencia_por, com alcada_aprovacao=true
-- e ativo no mesmo tenant. Fica em BLOCO 2 (não no schema, BLOCO 1)
-- porque depende de evora_claims(), que só existe a partir daqui.
-- ---------------------------------------------------------------------
create or replace function evora_valida_ciencia_briefing()
returns trigger language plpgsql as $$
declare
  v_ok boolean;
begin
  if new.ciencia_por is distinct from old.ciencia_por then
    if new.ciencia_por is null then
      new.ciencia_em := null;  -- "desfazer" ciência (ex.: clique errado) — a ação em si fica na auditoria da aplicação
    else
      select exists (
        select 1 from usuarios u
        where u.id = new.ciencia_por
          and u.tenant_id = new.tenant_id
          and u.alcada_aprovacao
          and u.ativo
          and u.auth_user_id = nullif(evora_claims() ->> 'sub', '')::uuid
      ) into v_ok;
      if not v_ok then
        raise exception 'ciencia_por precisa ser o proprio usuario autenticado, com alcada_aprovacao e ativo no tenant (freio humano, Manual v10.8).';
      end if;
      new.ciencia_em := now();
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_briefings_ciencia on briefings;
create trigger trg_briefings_ciencia
  before update on briefings
  for each row execute function evora_valida_ciencia_briefing();

-- ---------------------------------------------------------------------
-- 16. FARUS (Fase 10, Manual v10.9.1) — a exceção controlada. Compartilha
-- por MUNICÍPIO (como o Atlas, seção 14), mas — diferente do Atlas — um
-- item pode pertencer a um tenant específico (pesquisa privada). Adaptado
-- de `evora farus f1.sql`, já testado 10/10 (ver `evora farus teste
-- aceite.sql`); conteúdo idêntico ao entregue.
-- ---------------------------------------------------------------------

-- Territórios que o tenant da sessão acompanha.
create or replace function farus_territorios_do_tenant()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select tt.territorio_id
  from farus_tenant_territorios tt
  where tt.tenant_id = evora_tenant_atual();
$$;

drop policy if exists farus_territorios_leitura on farus_territorios;
create policy farus_territorios_leitura on farus_territorios
  for select to authenticated
  using (id in (select farus_territorios_do_tenant()));

drop policy if exists farus_tt_isolamento on farus_tenant_territorios;
create policy farus_tt_isolamento on farus_tenant_territorios
  for all to authenticated
  using (tenant_id = evora_tenant_atual())
  with check (tenant_id = evora_tenant_atual());

drop policy if exists farus_fontes_leitura on farus_fontes;
create policy farus_fontes_leitura on farus_fontes
  for select to authenticated
  using (territorio_id in (select farus_territorios_do_tenant()));

-- A política mais delicada do módulo: território do tenant E (item público
-- OU do próprio tenant) — a segunda condição é o que impede um cliente ver
-- a pesquisa privada que outro cliente da mesma cidade mandou fazer.
drop policy if exists farus_itens_leitura on farus_itens;
create policy farus_itens_leitura on farus_itens
  for select to authenticated
  using (
    territorio_id in (select farus_territorios_do_tenant())
    and (
      tenant_origem is null
      or tenant_origem = evora_tenant_atual()
    )
  );

comment on policy farus_itens_leitura on farus_itens is
  'Exceção controlada ao isolamento: compartilha por município, mas nunca o contexto de outro tenant.';

-- Escrita do acervo é do motor (service_role) — nenhuma policy de
-- insert/update/delete para authenticated em farus_fontes/farus_itens
-- (mesmo grant-level já reforça isso, seção de GRANTS acima).

-- ---------------------------------------------------------------------
-- 17. AEGIS A0 (Fase 11, Manual v10.9.1) — cofre de dado sensível. Adaptado
-- de `evora aegis a0.sql`, já testado 10/10 (ver `evora aegis teste
-- aceite.sql`). ÚNICA ADAPTAÇÃO REAL: o arquivo entregue usa `auth.uid()`
-- para achar o usuário autenticado; este projeto nunca usa esse helper —
-- usa `evora_claims() ->> 'sub'`, o mesmo idioma já auditado em
-- evora_valida_ciencia_briefing (seção 15 acima). A trava em si não muda:
-- só autoridade/chefe_gabinete abrem o cofre.
--
-- NENHUMA policy de SELECT em aegis_cofre para authenticated — a ausência
-- é a proteção, não esquecimento (mesmo espírito de municipio_vereadores,
-- seção 14). Ler só pela função aegis_ler.
-- ---------------------------------------------------------------------

create or replace function aegis_ler(
  p_usuario_id uuid,
  p_especie    aegis_especie,
  p_motivo     aegis_motivo_leitura,
  p_justificativa text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid := evora_tenant_atual();
  v_id     uuid;
  v_valor  text;
  v_papel  text;
begin
  if v_tenant is null then
    raise exception 'Sem identidade no token.';
  end if;

  select u.papel::text into v_papel
  from usuarios u
  where u.auth_user_id = nullif(evora_claims() ->> 'sub', '')::uuid
    and u.ativo;

  if v_papel is null or v_papel not in ('autoridade','chefe_gabinete') then
    raise exception 'Papel % não tem alçada para abrir o cofre.', coalesce(v_papel,'indefinido');
  end if;

  select c.id, c.valor into v_id, v_valor
  from aegis_cofre c
  where c.usuario_id = p_usuario_id
    and c.especie = p_especie
    and c.tenant_id = v_tenant;

  if v_id is null then
    raise exception 'Não há registro desta espécie para este usuário neste gabinete.';
  end if;

  -- Grava ANTES de devolver: leitura sem registro não existe.
  insert into aegis_acessos (cofre_id, tenant_id, quem, motivo, justificativa)
  values (v_id, v_tenant, coalesce(evora_claims() ->> 'sub', 'desconhecido'), p_motivo, p_justificativa);

  return v_valor;
end $$;

comment on function aegis_ler is
  'Única porta de leitura do cofre. Exige motivo declarado e grava o acesso antes de devolver o valor.';

-- Leitura da máscara — livre, porque não revela nada. Não abre o cofre e
-- não gera registro de acesso; é o que as telas consomem.
create or replace function aegis_mascara(p_usuario_id uuid, p_especie aegis_especie)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select c.mascara
  from aegis_cofre c
  where c.usuario_id = p_usuario_id
    and c.especie = p_especie
    and c.tenant_id = evora_tenant_atual();
$$;

comment on function aegis_mascara is
  'Devolve apenas a forma mascarada. É o que a tela consome — o cofre permanece fechado.';

-- A autoridade pode consultar QUEM leu o cofre do seu próprio gabinete.
drop policy if exists aegis_acessos_leitura on aegis_acessos;
create policy aegis_acessos_leitura on aegis_acessos
  for select to authenticated
  using (tenant_id = evora_tenant_atual());

grant execute on function aegis_ler(uuid, aegis_especie, aegis_motivo_leitura, text) to authenticated;
grant execute on function aegis_mascara(uuid, aegis_especie) to authenticated;
revoke execute on function aegis_ler(uuid, aegis_especie, aegis_motivo_leitura, text) from anon;
revoke execute on function aegis_mascara(uuid, aegis_especie) from anon;

-- ---------------------------------------------------------------------
-- 18. TRAVESSIA DE MUNDO (Ponte Bia↔Nil) — a única travessia sancionada
-- entre gabinete e campanha (Princípio Inviolável nº 4, "separação de
-- mundos") acontece na aplicação e fica registrada aqui, na trilha
-- imutável (seção 11 acima). Esta função NÃO altera o token — a policy
-- de cada tabela continua conferindo tenant_id/mundo do próprio JWT; ela
-- só autoriza e REGISTRA a travessia. A aplicação usa o valor de volta
-- pra decidir de qual mundo pedir dado na sessão. Só quem legitimamente
-- enxerga os dois mundos (evora_ve_os_dois_mundos, definida acima nesta
-- mesma seção de contexto) pode atravessar — mesmo idioma de
-- evora_valida_ciencia_briefing (seção 15): plpgsql comum, sem security
-- definer, porque tudo que a função faz (ler usuarios, inserir em
-- auditoria) o próprio chamador authenticated já pode fazer direto —
-- ela só acrescenta a validação e o registro em uma chamada só.
-- ---------------------------------------------------------------------
create or replace function evora_registrar_travessia(p_mundo evora_mundo)
returns evora_mundo language plpgsql as $$
declare
  v_tenant     uuid := evora_tenant_atual();
  v_usuario_id uuid;
  v_papel      text;
begin
  if v_tenant is null then
    raise exception 'Sem identidade no token. Refaça o login.';
  end if;

  select u.id, u.papel::text into v_usuario_id, v_papel
  from usuarios u
  where u.auth_user_id = nullif(evora_claims() ->> 'sub', '')::uuid
    and u.ativo;

  if v_usuario_id is null then
    raise exception 'Usuário sem cadastro ativo.';
  end if;

  -- Apenas quem legitimamente vê os dois mundos pode atravessar.
  if not evora_ve_os_dois_mundos() then
    raise exception 'Seu papel (%) não tem acesso aos dois mundos.', coalesce(v_papel, 'indefinido');
  end if;

  insert into auditoria (tenant_id, mundo, ator_id, acao, detalhe)
  values (
    v_tenant,
    p_mundo,
    v_usuario_id,
    'travessia_ponte',
    jsonb_build_object('para', p_mundo, 'papel', v_papel)
  );

  return p_mundo;
end $$;

comment on function evora_registrar_travessia(evora_mundo) is
  'Registra na trilha imutável a travessia entre gabinete e campanha (Ponte Bia↔Nil). Recusa quem não tem os dois mundos. Não altera o token — a aplicação usa o retorno para pedir dado do mundo escolhido na sessão.';

revoke execute on function evora_registrar_travessia(evora_mundo) from anon;
grant execute on function evora_registrar_travessia(evora_mundo) to authenticated;

-- ---------------------------------------------------------------------
-- 19. TRAVA DO MÓDULO DEMANDAS — "Caderno do Programador" (Manual Supremo
-- v11.0, 16/09/2026): o módulo fica desligado até haver parecer jurídico,
-- porque trata dado pessoal de cidadão (nome, contato, geolocalização)
-- sem esse parecer concluído. `tenants.demandas_parecer_juridico`
-- (schema, BLOCO 1) guarda a decisão; esta trigger é o que a torna real —
-- um trigger, não só a policy `demandas_isolamento` acima, porque
-- precisa ler OUTRA tabela (tenants) além da linha sendo escrita, e
-- porque uma mensagem de erro explícita ("aguarda parecer jurídico") é
-- mais honesta que um "new row violates row-level security policy"
-- genérico de uma RLS negada.
--
-- Roda em INSERT e em UPDATE — enquanto a chave estiver `false`, nada
-- muda nessa tabela pro tenant, nem um `status` de demanda já existente.
-- Não trava SELECT: dado fictício de teste que já exista continua
-- legível (é o que a Bia já consulta hoje), só a ESCRITA fica presa.
-- `service_role` (o motor do briefing, por exemplo) passa direto — só
-- `authenticated` escreve nesta tabela hoje de qualquer forma.
-- ---------------------------------------------------------------------
create or replace function evora_travar_demandas_sem_parecer()
returns trigger language plpgsql as $$
declare
  v_liberado boolean;
begin
  select t.demandas_parecer_juridico into v_liberado
  from tenants t
  where t.id = new.tenant_id;

  if not coalesce(v_liberado, false) then
    raise exception 'Módulo Demandas aguarda parecer jurídico (Caderno do Programador v11.0) — habilite tenants.demandas_parecer_juridico para liberar a escrita neste gabinete.';
  end if;

  return new;
end $$;

comment on function evora_travar_demandas_sem_parecer is
  'Bloqueia insert/update em demandas enquanto tenants.demandas_parecer_juridico for false. Módulo desligado até parecer jurídico (Caderno do Programador v11.0).';

drop trigger if exists trg_demandas_trava_juridica on demandas;
create trigger trg_demandas_trava_juridica
  before insert or update on demandas
  for each row execute function evora_travar_demandas_sem_parecer();

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
