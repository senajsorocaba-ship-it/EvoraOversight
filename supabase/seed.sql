-- =====================================================================
-- ÉVORA OVERSIGHT — SEED LOCAL (Fase 2 do plano de testes)
-- =====================================================================
-- Roda automaticamente depois das migrations em `supabase start` /
-- `supabase db reset` (CLI procura por este arquivo pelo nome). NUNCA
-- rodar isto contra o Supabase de nuvem/produção — é só para o ambiente
-- local de desenvolvimento.
--
-- Dados fictícios inspirados no perfil real do tenant piloto
-- (motor/perfil_tatiane.json), mas SEM nenhum dado pessoal de cidadão —
-- mesmo em seed local, o gatilho LGPD do Manual (P8/P9, ainda sem
-- parecer) vale como princípio: as demandas abaixo não identificam
-- ninguém, de propósito.
--
-- IDs fixos (não gen_random_uuid()) de propósito: dá pra usar os mesmos
-- valores em testes manuais/scripts depois, sem precisar consultar o
-- banco toda vez para descobrir o id que acabou de ser gerado.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TENANT — onboarding completo (ciencia_travas true libera operacional)
-- ---------------------------------------------------------------------
insert into tenants (
  id, slug, nome_autoridade, cargo, partido, municipio_sede, uf,
  perfil, ciencia_travas, ciencia_data, operacional,
  demandas_parecer_juridico
) values (
  'a0000000-0000-0000-0000-00000000000a',
  'tatiane-costa-sorocaba',
  'Tatiane Costa',
  'Vereadora',
  'PL',
  'Sorocaba',
  'SP',
  jsonb_build_object(
    'temas_prioritarios', jsonb_build_array(
      'Cultura', 'Educação', 'Segurança Pública', 'Proteção à Mulher'
    )
  ),
  true,
  now(),
  true,
  -- true só aqui: tenant fictício de teste (ver cabeçalho deste arquivo,
  -- "SEM nenhum dado pessoal de cidadão"), liberado explicitamente pra
  -- não travar o próprio seed no trigger trg_demandas_trava_juridica
  -- (evora_rls_mvp_v1.sql). Todo tenant real nasce com default false —
  -- este script nunca roda fora do ambiente local (ver cabeçalho).
  true
);

-- ---------------------------------------------------------------------
-- 2. USUARIOS — a autoridade (vê os dois mundos, dá o freio humano) e
--    um assessor (só mundo gabinete, sem alçada de aprovação).
--    auth_user_id fica NULL de propósito: o vínculo é feito pelo BLOCO 5
--    quando a pessoa faz login de verdade (ver BLOCO_5_AUTENTICACAO.md).
-- ---------------------------------------------------------------------
insert into usuarios (id, tenant_id, nome, email, papel, mundo_permitido, alcada_aprovacao) values
  ('a0000000-0000-0000-0000-0000000000b1', 'a0000000-0000-0000-0000-00000000000a',
   'Tatiane Costa', 'tatiane.costa@exemplo-local.test', 'autoridade', null, true),
  ('a0000000-0000-0000-0000-0000000000b2', 'a0000000-0000-0000-0000-00000000000a',
   'Assessor Demo', 'assessor.demo@exemplo-local.test', 'assessor', 'gabinete', false);

-- ---------------------------------------------------------------------
-- 3. FONTES — veículos canônicos citados no perfil real (Anexo 16 §3)
-- ---------------------------------------------------------------------
insert into fontes (tenant_id, mundo, nome, url, nivel, esfera, cobertura, evidencia_cobertura, identificacao, procedencia, selo) values
  ('a0000000-0000-0000-0000-00000000000a', 'gabinete', 'Cruzeiro do Sul', 'https://www.cruzeirodosul.inf.br',
   'F2', 'municipal', 'Cobertura diária de Sorocaba, política e cidade', 'Arquivo de capturas de tela do site', 'verificada', 'declarado', 'verificado'),
  ('a0000000-0000-0000-0000-00000000000a', 'gabinete', 'Jornal Z Norte — Sorocabanices', 'https://www.jornalznorte.com.br',
   'F2', 'municipal', 'Coluna de bairro, zona norte de Sorocaba', 'Arquivo de capturas de tela da coluna', 'verificada', 'declarado', 'verificado'),
  ('a0000000-0000-0000-0000-00000000000a', 'gabinete', 'G1', 'https://g1.globo.com',
   'F1', 'nacional', 'Cobertura nacional e estadual, inclui SP', null, 'verificada', 'declarado', 'verificado');

-- ---------------------------------------------------------------------
-- 4. LUGARES — base para a agenda
-- ---------------------------------------------------------------------
insert into lugares (id, tenant_id, nome, endereco, municipio, uf) values
  ('a0000000-0000-0000-0000-0000000000c1', 'a0000000-0000-0000-0000-00000000000a',
   'Câmara Municipal de Sorocaba', 'Av. Engenheiro Carlos Reinaldo Mendes, 3041', 'Sorocaba', 'SP');

-- ---------------------------------------------------------------------
-- 5. COMPROMISSOS — agenda de exemplo (AAG-g)
-- ---------------------------------------------------------------------
insert into compromissos (tenant_id, mundo, titulo, descricao, lugar_id, inicio, fim, com_quem, pauta, quem_anotou, confirmado, confirmado_por) values
  ('a0000000-0000-0000-0000-00000000000a', 'gabinete', 'Sessão ordinária', 'Sessão plenária semanal',
   'a0000000-0000-0000-0000-0000000000c1', now() + interval '1 day' + interval '14 hours', now() + interval '1 day' + interval '18 hours',
   'Plenário', 'Pauta do dia a definir', 'a0000000-0000-0000-0000-0000000000b2', true, 'a0000000-0000-0000-0000-0000000000b1'),
  ('a0000000-0000-0000-0000-00000000000a', 'gabinete', 'Reunião com associação de bairro', 'Pauta: segurança pública na zona norte',
   'a0000000-0000-0000-0000-0000000000c1', now() + interval '3 days' + interval '9 hours', now() + interval '3 days' + interval '10 hours',
   'Associação de Moradores (zona norte)', 'Segurança pública', 'a0000000-0000-0000-0000-0000000000b2', false, null);

-- ---------------------------------------------------------------------
-- 6. DEMANDAS — SEM dado pessoal identificado (LGPD, ver cabeçalho)
-- ---------------------------------------------------------------------
insert into demandas (tenant_id, mundo, protocolo, titulo, descricao, tema, bairro, urgencia, status, registrada_por) values
  ('a0000000-0000-0000-0000-00000000000a', 'gabinete', 'DEM-2026-0001', 'Iluminação pública precária',
   'Trecho com postes apagados há semanas, relatos recorrentes de moradores.', 'Segurança Pública', 'Zona Norte', 2,
   'registrada', 'a0000000-0000-0000-0000-0000000000b2'),
  ('a0000000-0000-0000-0000-00000000000a', 'gabinete', 'DEM-2026-0002', 'Pedido de reforma de praça',
   'Praça com equipamentos de playground danificados.', 'Cultura', 'Centro', 4,
   'em_andamento', 'a0000000-0000-0000-0000-0000000000b2');

-- ---------------------------------------------------------------------
-- 7. DESDOBRAMENTOS — o que nasceu de uma demanda
-- ---------------------------------------------------------------------
insert into desdobramentos (tenant_id, mundo, origem_tipo, titulo, descricao, responsavel_id, status) values
  ('a0000000-0000-0000-0000-00000000000a', 'gabinete', 'demanda',
   'Ofício à Secretaria de Obras sobre iluminação', 'Cobrar prazo de reparo dos postes na zona norte',
   'a0000000-0000-0000-0000-0000000000b2', 'aberto');

-- briefings fica vazio de propósito — é gerado pela Fase 3 (motor de
-- execução chamando evora_gerar_briefing_diario), não por seed estático.
