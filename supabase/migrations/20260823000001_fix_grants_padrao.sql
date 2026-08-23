-- Correção de segurança (Fase 8/9, achada durante teste real de ponta a
-- ponta do cadastro no projeto NA NUVEM).
--
-- Achado: o projeto na nuvem tinha um privilégio padrão herdado
-- (ALTER DEFAULT PRIVILEGES, comportamento legado do Supabase — a versão
-- atual, usada localmente via config.toml, já não faz isso por padrão)
-- que concedia TODOS os privilégios — select/insert/update/delete em
-- toda tabela, execute em toda função — a `anon` e `authenticated` em
-- todo objeto novo criado por `postgres` no schema `public`,
-- silenciosamente, desde a Fase 1. Nenhuma migration deste projeto pediu
-- isso; foi descoberto testando acesso direto via REST com a chave anon.
--
-- Impacto real, confirmado:
--   · Tabelas: o RLS (enable+force em todas) estava segurando os dados —
--     testado de verdade (INSERT/DELETE via chave anon direto em
--     municipio_vereadores, ambos sem efeito) — mas a segunda camada de
--     defesa que todo o projeto documenta ("grant nenhum para
--     anon/authenticated" nas tabelas fechadas) não existia de fato.
--   · Funções: aqui o impacto era real, não só teórico —
--     evora_gerar_briefing_diario/evora_montar_blocos_briefing (BLOCO 4,
--     security definer, bypassam RLS de propósito, desenhadas para
--     service_role apenas) estavam executáveis por QUALQUER visitante
--     anônimo da internet, com qualquer tenant_id — uma exposição real
--     de dado entre tenants, já que RLS não se aplica dentro de uma
--     security definer chamada diretamente por quem não deveria poder
--     chamá-la.
--
-- Esta migration revoga tudo de anon/authenticated e reaplica exatamente
-- o desenho já documentado nos arquivos canônicos (BLOCO 2 pra tabelas,
-- BLOCO 5 e Fase 8 pras funções públicas), e corrige o privilégio padrão
-- pra objetos futuros não herdarem o mesmo problema.

-- ---------------------------------------------------------------------
-- TABELAS
-- ---------------------------------------------------------------------
revoke all privileges on all tables in schema public from anon, authenticated;

grant select, insert, update on usuarios, fontes, briefings, demandas,
  lugares, compromissos, atas, desdobramentos, desdobramento_eventos
  to authenticated;
grant select on tenants to authenticated;
grant select, insert on auditoria to authenticated;
grant select on achados_fiscalizacao, mencoes_imprensa to authenticated;
grant select on municipios, municipio_fontes to authenticated;
-- municipio_trilha, municipio_vereadores, municipio_vereadores_pendencias:
-- nenhum grant para authenticated/anon, de propósito — ver comentários
-- nos arquivos canônicos (evora rls mvp v1.sql, seções 14/15).

grant all privileges on all tables in schema public to service_role;

-- ---------------------------------------------------------------------
-- FUNÇÕES
-- ---------------------------------------------------------------------
revoke all privileges on all functions in schema public from anon, authenticated;

-- Fase 8 — autocadastro de vereador: as únicas 3 funções que um visitante
-- sem sessão precisa chamar.
grant execute on function evora_listar_municipios_uf(text) to anon, authenticated;
grant execute on function evora_verificar_vereador(uuid, text) to anon, authenticated;
grant execute on function evora_autocadastro_vereador(uuid, text) to anon, authenticated;

-- Helpers de RLS (BLOCO 2): authenticated precisa de execute nestas pra
-- qualquer policy que as chame dentro do USING conseguir avaliar. anon
-- não precisa — as únicas tabelas com policy using(true) (municipios/
-- municipio_fontes) não chamam nenhuma delas.
grant execute on function evora_claims() to authenticated;
grant execute on function evora_tenant_atual() to authenticated;
grant execute on function evora_mundo_atual() to authenticated;
grant execute on function evora_ve_os_dois_mundos() to authenticated;

-- Reafirma o que já era intencional (idempotente — já estava assim, sem
-- mudança real; mantido aqui por completude e clareza do estado final).
revoke execute on function custom_access_token_hook(jsonb) from public, anon, authenticated;
grant execute on function custom_access_token_hook(jsonb) to supabase_auth_admin;

-- Funções-gatilho (evora_toca_atualizado_em, evora_valida_ciencia_briefing,
-- evora_auditoria_imutavel, evora_vincular_auth_user) e
-- evora_gerar_briefing_diario/evora_montar_blocos_briefing (service_role
-- apenas) ficam SEM grant nenhum pra anon/authenticated — nem trigger nem
-- service_role-only precisam disso pra funcionar (gatilho não checa
-- privilégio de quem disparou o evento; service_role já tem acesso total
-- via grant próprio, intocado por este arquivo).

-- ---------------------------------------------------------------------
-- Evita que objetos FUTUROS herdem o mesmo problema automaticamente.
-- ---------------------------------------------------------------------
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on functions from anon, authenticated;
