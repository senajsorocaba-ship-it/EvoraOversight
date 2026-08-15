-- ============================================================
-- ÉVORA OVERSIGHT — Segurança de Isolamento (RLS) · Núcleo MVP · v1
-- ------------------------------------------------------------
-- ESTE É O CORAÇÃO DA SEPARAÇÃO (Nível 1 — lógico).
-- Row-Level Security (RLS) faz o banco RECUSAR, na raiz, qualquer
-- tentativa de ler/gravar dado de outro tenant ou de outro mundo.
-- É a "trava das gavetas": mesmo que o código erre, o banco barra.
--
-- Como funciona: cada requisição autenticada carrega o tenant e o
-- mundo ativos (via claims do JWT do Supabase). As políticas abaixo
-- só deixam ver/mexer linhas do MESMO tenant e do MESMO mundo.
--
-- No Nível 2 (físico), como cada cliente roda em instância separada,
-- este mesmo RLS continua valendo — reforço, não substituição.
-- ============================================================

-- Funções auxiliares: leem tenant e mundo ativos do token da sessão
create or replace function evora_tenant_id() returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'tenant_id','')::uuid
$$;

create or replace function evora_mundo() returns text
language sql stable as $$
  select coalesce(current_setting('request.jwt.claims', true)::jsonb ->> 'mundo','gabinete')
$$;

-- ------------------------------------------------------------
-- Ativar RLS em todas as tabelas com dado de tenant
-- ------------------------------------------------------------
alter table tenants           enable row level security;
alter table usuarios          enable row level security;
alter table fontes            enable row level security;
alter table briefings         enable row level security;
alter table demandas          enable row level security;
alter table lugares           enable row level security;
alter table compromissos      enable row level security;
alter table atas              enable row level security;
alter table desdobramentos    enable row level security;
alter table desdobramento_eventos enable row level security;
alter table auditoria         enable row level security;

-- ------------------------------------------------------------
-- POLÍTICA-BASE: mesma para tabelas com tenant_id + mundo
--   -> só enxerga linhas do seu tenant E do seu mundo
-- ------------------------------------------------------------

-- FONTES
create policy fontes_isola on fontes
  using (tenant_id = evora_tenant_id() and mundo::text = evora_mundo())
  with check (tenant_id = evora_tenant_id() and mundo::text = evora_mundo());

-- BRIEFINGS
create policy briefings_isola on briefings
  using (tenant_id = evora_tenant_id() and mundo::text = evora_mundo())
  with check (tenant_id = evora_tenant_id() and mundo::text = evora_mundo());

-- DEMANDAS
create policy demandas_isola on demandas
  using (tenant_id = evora_tenant_id() and mundo::text = evora_mundo())
  with check (tenant_id = evora_tenant_id() and mundo::text = evora_mundo());

-- COMPROMISSOS
create policy compromissos_isola on compromissos
  using (tenant_id = evora_tenant_id() and mundo::text = evora_mundo())
  with check (tenant_id = evora_tenant_id() and mundo::text = evora_mundo());

-- ATAS
create policy atas_isola on atas
  using (tenant_id = evora_tenant_id() and mundo::text = evora_mundo())
  with check (tenant_id = evora_tenant_id() and mundo::text = evora_mundo());

-- DESDOBRAMENTOS
create policy desdobros_isola on desdobramentos
  using (tenant_id = evora_tenant_id() and mundo::text = evora_mundo())
  with check (tenant_id = evora_tenant_id() and mundo::text = evora_mundo());

-- ------------------------------------------------------------
-- Tabelas com tenant mas SEM mundo (valem para o tenant todo)
-- ------------------------------------------------------------

-- USUÁRIOS (o usuário pertence ao tenant; mundo é controlado pelo papel/acesso)
create policy usuarios_isola on usuarios
  using (tenant_id = evora_tenant_id())
  with check (tenant_id = evora_tenant_id());

-- LUGARES (endereços do gabinete, valem para o tenant)
create policy lugares_isola on lugares
  using (tenant_id = evora_tenant_id())
  with check (tenant_id = evora_tenant_id());

-- TENANTS (cada um só vê a si mesmo)
create policy tenants_isola on tenants
  using (id = evora_tenant_id());

-- ------------------------------------------------------------
-- AUDITORIA — regra especial: SÓ INSERT, nunca ler cruzado, nunca alterar
--   (a trilha é imutável; leitura é restrita e sempre do próprio tenant)
-- ------------------------------------------------------------
create policy auditoria_insert on auditoria
  for insert with check (tenant_id = evora_tenant_id());

create policy auditoria_leitura on auditoria
  for select using (tenant_id = evora_tenant_id());
-- Obs.: NÃO criamos policy de UPDATE nem DELETE -> ficam proibidos por padrão.
--       A trilha nunca é alterada nem apagada. É a prova de integridade.

-- linha do tempo dos desdobramentos: herda o tenant pelo desdobramento
create policy desdobro_eventos_isola on desdobramento_eventos
  using (exists (select 1 from desdobramentos d
                 where d.id = desdobramento_id and d.tenant_id = evora_tenant_id()))
  with check (exists (select 1 from desdobramentos d
                 where d.id = desdobramento_id and d.tenant_id = evora_tenant_id()));

-- ============================================================
-- RESULTADO: com este RLS ativo, é IMPOSSÍVEL (pela regra do banco)
-- que uma sessão do mundo Campanha leia um dado do mundo Gabinete,
-- ou que um tenant veja o dado de outro. Essa é a prova do Nível 1.
-- O "teste ao vivo" da venda demonstra exatamente isto.
-- ============================================================
