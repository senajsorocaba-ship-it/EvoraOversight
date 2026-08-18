# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is not an application codebase — it's the SQL schema + RLS (Row Level Security) design for **Évora Oversight**, a multi-tenant Supabase/PostgreSQL backend serving political/legislative "gabinete" (office) clients. There is no build tooling, package manager, or test runner here; the "code" is raw SQL meant to be pasted into the Supabase SQL Editor and run in a fixed order.

Files:
- `AO SUPABASE BLOCO1.md.txt` — BLOCO 1: the core schema (`evora_schema_mvp_v1.sql` content), defines all 13 tables (11 original + `achados_fiscalizacao`/`mencoes_imprensa` from Fase 6), enum types, constraints, indexes, and triggers.
- `evora rls mvp v1.sql` — BLOCO 2 raw SQL: RLS functions and policies (isolation/security layer).
- `BLOCO_2_RLS.md` — same BLOCO 2 SQL wrapped with copy/paste instructions and a manual acceptance checklist (`pg_policies` count) for a human operator running it in Supabase's SQL Editor.
- `evora rls teste aceite v1.sql` — BLOCO 3 raw SQL: an automated, self-contained acceptance test for the RLS layer. Creates fictitious fixtures, switches to the `authenticated` role, simulates different JWT claims, and asserts (via `RAISE EXCEPTION`) the isolation/separation/immutability/fail-closed guarantees — then rolls back so nothing persists.
- `BLOCO_3_TESTE_ACEITE.md` — same BLOCO 3 SQL wrapped with copy/paste instructions and expected `NOTICE` output.
- `evora briefing motor mvp v1.sql` — BLOCO 4 raw SQL: the morning-briefing data aggregator. Two `security definer` functions (`evora_montar_blocos_briefing`, `evora_gerar_briefing_diario`) that assemble the 7 canonical `briefings.blocos` (definition lives outside this repo, in the same Évora project — see below), scoped by explicit `tenant_id`/`mundo` parameters rather than JWT claims, execute-granted to `service_role` only. Status: BLOCO 3 (RLS acceptance test) has been run and passed — do not redo it or alter the RLS layer when working on the briefing engine.
- `evora_motor_execucao.py` — the execution layer (Python, stdlib + the official `anthropic` SDK): calls `evora_gerar_briefing_diario` via PostgREST using the `service_role` key (server-side only), sends the resulting `blocos` jsonb to the Claude API to draft the markdown, renders HTML, and `UPDATE`s the same `briefings` row (`markdown`/`html`/`modelo_ia`/`custo_estimado`). Never sets `ciencia_por`/`ciencia_em`/`entregue_em` — the human gate stays outside this script. See its module docstring for full details.
- `.env.example` / `requirements.txt` — env vars the execution layer needs (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `ANTHROPIC_API_KEY`) and its one dependency (`anthropic`).
- `evora auth mvp v1.sql` — BLOCO 5 raw SQL: closes the loop the RLS layer (BLOCO 2) always assumed but never implemented — links `usuarios.auth_user_id` to `auth.users` by email (trigger on `auth.users` insert) and injects `tenant_id`/`mundo` into every JWT via a Supabase Auth **Custom Access Token Hook** (`custom_access_token_hook`), read live from `usuarios` on every login/refresh. Both are `security definer` / `set search_path = ''`, since they must work before the caller has any tenant context — that's exactly what they're computing.
- `BLOCO_5_AUTENTICACAO.md` — same BLOCO 5 SQL wrapped with copy/paste instructions, **plus a mandatory manual dashboard step** (Authentication → Hooks → enable Custom Access Token → select `custom_access_token_hook`) that no SQL script can do for you, plus a manual end-to-end acceptance test (provision a fixture user, sign up/log in for real, decode the returned JWT, confirm `app_metadata.tenant_id` is populated). Status: **validated against a real local Supabase stack** (`supabase start` via the CLI, see `../supabase/`) — signup → auto-link → login → JWT claims → PostgREST isolation, all confirmed working end to end. Not yet run against a cloud project (still needs the manual dashboard hook step there).
- `evora_ingestao_coletores.py` — Fase 6: reads the JSON files `D:\motor\coletor_pncp_evora.py` and `imprensa_coletor_evora.py` already produce and upserts them into `achados_fiscalizacao`/`mencoes_imprensa` via PostgREST (`service_role` key, stdlib only — no new dependency). Doesn't touch the `motor/` scripts themselves; just bridges their JSON output into Postgres. Validated end to end against the real PNCP/Google News APIs and the local Supabase stack: 500 contracts and 59 headlines ingested, `evora_gerar_briefing_diario` blocks 3 (`fiscalizacao`) and 6 (`imprensa`) now come back `preenchido` with real data instead of `pendente_integracao_externa`. Blocks 2 (`radar_de_nomeacoes`) and 4 (`pulso_da_camara_do`) are still pending — no collector exists for Diário Oficial/Câmara yet, so no table was added for them (would be dead schema).

Despite the `.md.txt` extension, `AO SUPABASE BLOCO1.md.txt` is pure SQL (no markdown fencing) — read/edit it as SQL.

## Execution order (do not reorder)

1. Run the schema file first (`AO SUPABASE BLOCO1.md.txt` content) — creates types, the 13 tables, constraints, indexes, `atualizado_em` triggers, and the immutable-audit trigger.
2. Then run the RLS file (`evora rls mvp v1.sql` / `BLOCO_2_RLS.md`) — creates the JWT-claim helper functions and the 13 RLS policies.
3. Then run the acceptance test (`evora rls teste aceite v1.sql` / `BLOCO_3_TESTE_ACEITE.md`) to prove the RLS layer actually behaves as designed, not just that it compiled.
4. Then run the briefing engine (`evora briefing motor mvp v1.sql`) to get the two aggregator functions in place.
5. BLOCO 5 (`evora auth mvp v1.sql` / `BLOCO_5_AUTENTICACAO.md`) only needs steps 1-2 done first — it's independent of 3 and 4, and can run any time after the RLS layer exists. It also requires a manual dashboard step (enabling the Custom Access Token hook) that no SQL script can perform.

Without step 2, the database has **no isolation between tenants** — this is explicitly called out in the schema file's closing comment. Never treat BLOCO 2 or BLOCO 3 as optional.

After running BLOCO 2, the expected manual acceptance check is:
```sql
select count(*) as politicas from pg_policies where schemaname='public';
```
This must return **13**.

BLOCO 3 automates the four acceptance scenarios plus one bonus check, ending in a `NOTICE: TESTE DE ACEITE: PASSOU — 4 de 4 cenários oficiais OK (+ bônus: ...)`. If a scenario fails, the script raises `CENARIO N FALHOU: ...` and the transaction is left open/aborted — run a bare `rollback;` before retrying. The whole script always ends in `ROLLBACK`, so its fixtures (two fictitious tenants, fontes, one auditoria row) never persist even on success.

## Briefing engine (BLOCO 4)

- The **7 canonical blocks** referenced by `briefings.blocos` (schema file, table 4) are *not* defined anywhere in this repo — they're defined in sibling project material on disk: `D:\motor\GUIA_Primeiro_Briefing.md` and Anexo 12 of `D:\Evora Manual v10_4.md`. In canonical order: `resumo_do_dia`, `radar_de_nomeacoes`, `fiscalizacao`, `pulso_da_camara_do`, `demandas`, `imprensa`, `movimento_sugerido_72h`. Don't redefine or reorder these without re-checking that source material.
- Of the 7 blocks, 5 now have real data: `resumo_do_dia` (insumos), `fiscalizacao` (from `achados_fiscalizacao`, Fase 6), `demandas`, `imprensa` (`fontes` declared list *plus* real headlines from `mencoes_imprensa`, each item tagged `tipo`), and `movimento_sugerido_72h`. Only `radar_de_nomeacoes` and `pulso_da_camara_do` remain `status: 'pendente_integracao_externa'` — they depend on a Diário Oficial/Câmara collector that doesn't exist as code yet (see `D:\motor\coletor_pncp_evora.py` and `imprensa_coletor_evora.py` for the two that *do* exist). Don't add a table or fabricate data for the remaining two blocks until a real collector exists to feed it — an empty ingestion table is dead schema, not progress.
- Both BLOCO 4 functions take `tenant_id`/`mundo` as explicit parameters (not from JWT claims) and are `security definer` with `execute` revoked from `public` and granted only to `service_role` — they are meant to be called by the same kind of trusted server-side job described in BLOCO 2's `service_role` comment (the "motor do briefing"), never by `authenticated`/`anon`.
- Redacting the actual markdown/html (an AI-writing step, analogous to `D:\motor\montador_briefing_evora.py`'s call to the Claude API) and enforcing the human gate (`briefings.ciencia_por`) both happen in a layer *outside* this SQL file — BLOCO 4 only assembles and persists the structured `blocos` jsonb.

## Execution layer (`evora_motor_execucao.py`)

- This is the "motor do briefing" / trusted server-side job that BLOCO 2's `service_role` comment and BLOCO 4 both refer to. It is meant to run from a server, a cron job, or a scheduled cloud function — **never** from a browser, mobile app, or anything a tenant user can reach, because it holds the `service_role` key.
- It calls Claude via the official `anthropic` Python SDK (per this project's `claude-api` conventions), not raw HTTP — that's a deliberate deviation from the zero-dependency style of the sibling `D:\motor\*.py` scripts, which predate the current SDK guidance.
- Persona and formatting rules are adapted from `D:\motor\montador_briefing_evora.py`, generalized to read the authority's name/cargo/partido/temas from `tenants` instead of being hardcoded to one tenant. Markdown→HTML rendering is adapted from `D:\motor\render_briefing_evora.py`.
- Required env vars: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `ANTHROPIC_API_KEY` (optional: `ANTHROPIC_MODEL_BRIEFING`, default `claude-opus-5`). None of these are ever printed, logged, or written to disk by the script.
- It does not touch `briefings.ciencia_por`/`ciencia_em`/`entregue_em` — giving ciência and delivering a briefing are still manual, application-side actions by a user with `alcada_aprovacao`. Don't add auto-ciência to this script without an explicit owner decision; it would break the freio humano principle. Even if it tried, `evora_valida_ciencia_briefing()` (BLOCO 2) would reject it: `ciencia_por` must match the currently authenticated JWT subject, and `service_role` requests carry no such claim.

## Domain architecture

### The 13 core tables
`tenants`, `usuarios`, `fontes`, `briefings`, `demandas`, `lugares`, `compromissos`, `atas`, `desdobramentos`, `desdobramento_eventos`, `auditoria` — the original 11 (ratified in "Anexo 14 da v10.6"). Plus `achados_fiscalizacao` and `mencoes_imprensa`, added in Fase 6 of the test plan (an explicit owner decision, per this file's own rule below) to give the PNCP and press collectors (`D:\motor\coletor_pncp_evora.py`, `imprensa_coletor_evora.py`) a real ingestion target instead of JSON-only output. Don't add/remove tables without an explicit decision from the project owner.

### Non-negotiable principles baked into the schema (do not weaken without an explicit owner decision)

1. **Multi-tenant by row** — every content table carries `tenant_id` referencing `tenants(id)`. All access must be scoped by it.
2. **Separation of "mundos" (worlds)** — content tables carry a `mundo` column (`gabinete` | `campanha`, enum `evora_mundo`). This is "Princípio Inviolável nº 4": office business and campaign business must never cross. `lugares` and `desdobramento_eventos` are the exceptions (no `mundo` column — see inline comments explaining why). The only sanctioned crossing point is the "Ponte Bia↔Nil", which happens at the application layer and must be logged to `auditoria`.
3. **Two separation levels** — `tenants.nivel_separacao` is `logico` (shared schema, MVP default) or `fisico` (premium, dedicated separation). One schema serves both; this is pending legal/architecture sign-off ("parecer P25").
4. **LGPD-readiness in `demandas`** — citizen-request rows carry consent (`consentimento`, `consentimento_data`), legal basis (`base_legal`), sensitive-data flag (`dado_sensivel`), and retention date (`retencao_ate`). A check constraint (`demandas_dado_pessoal_exige_consentimento`) blocks storing an identified citizen name without recorded consent. **Do not use real citizen data before the P8/P9 legal review lands — use fictitious data for testing.**
5. **Nothing is deleted** — soft delete via `ativo`/`ativa` boolean columns everywhere instead of `DELETE`. `auditoria` is the one exception in the other direction: it is insert-only and immutable (enforced by both a trigger and RLS — see below), never soft-deleted or edited.
6. **Provenance fields travel with external data** — anything sourced externally (`fontes`, etc.) carries fields like `fonte`, `url`, `selo` (CVI seal), `consultado_em`. Don't drop provenance columns when touching these tables.

### RLS design (BLOCO 2)

- Supabase issues a JWT per authenticated request; the app is responsible for writing `tenant_id` and `mundo` into the JWT's `app_metadata`.
- `evora_claims()` reads `request.jwt.claims` defensively — missing, empty, or malformed settings all resolve to `NULL`.
- `evora_tenant_atual()` / `evora_mundo_atual()` extract `tenant_id`/`mundo` from claims (checking `app_metadata` first, falling back to top-level claim).
- `evora_ve_os_dois_mundos()` returns true only for active users with `papel in ('autoridade', 'auditor')` and `mundo_permitido is null` — these are the only roles legitimately allowed to see both worlds.
- **Fail closed is the deliberate default**: a missing/invalid JWT means these functions return `NULL`, and every policy comparison against `NULL` denies access rather than allowing it. Preserve this property in any policy changes.
- RLS is both `enable`d and `force`d on every table (defense in depth — forcing means even the table owner role is subject to RLS).
- Content tables use a `for all using (tenant_id = evora_tenant_atual() and (mundo = evora_mundo_atual() or evora_ve_os_dois_mundos()))` pattern with matching `with check`. `usuarios`, `lugares`, and `desdobramento_eventos` isolate by `tenant_id` only (no `mundo` column). `tenants` only allows `select` of one's own row and blocks client-side `update` entirely (tenant admin is a `service_role`-only operation). `auditoria` allows `select` only to the two-world roles and allows `insert` only — there is intentionally no `update`/`delete` policy, so RLS denies those outright in addition to the immutability trigger.
- The `service_role` key bypasses RLS entirely by Supabase design. It is meant only for trusted server-side jobs (e.g., the briefing engine) and must never be exposed to a browser, mobile app, or committed to the repo.
- **Freio humano (v10.8)**: `briefings.ciencia_por`/`ciencia_em` (renamed from `aprovado_por`/`aprovado_em` — the v10.6 name implied approval-before-reading, which the v10.8 Manual corrected: reading needs no prior approval, ciência is required only before any act with external effect). The `briefings_isolamento` RLS policy alone would let any tenant+mundo user set `ciencia_por` to anyone's id; `evora_valida_ciencia_briefing()` (a `before update` trigger, not a policy — RLS `with check` can't compare against arbitrary other tables' columns the way a trigger can) closes that gap: `ciencia_por` must equal a `usuarios.id` in the same tenant with `alcada_aprovacao` and `ativo`, whose `auth_user_id` matches the *currently authenticated* JWT `sub` — so a user can only give ciência as themselves, never on someone else's behalf, and `ciencia_em` is always server-stamped (`now()`), never client-supplied. `service_role` requests carry no `sub` claim, so this also blocks the motor de execução from ever setting it, even by accident.

## Working conventions for this schema

- SQL, comments, and documentation are written in Brazilian Portuguese; keep new additions consistent with that (mirror existing terminology like `mundo`, `tenant`, `fonte`, `desdobramento` rather than translating).
- Every new content table should follow the existing shape: `tenant_id uuid not null references tenants(id)`, a `mundo` column if it is world-scoped content, an `ativo`/`ativa` soft-delete boolean, and a matching RLS policy added to BLOCO 2 in the same style as the others.
- When adding a table, update the schema file, the RLS file, and the acceptance-test expected policy count (currently 13) in `BLOCO_2_RLS.md`. If the new table is tenant+mundo scoped, add matching fixtures/assertions to BLOCO 3 (`evora rls teste aceite v1.sql` / `BLOCO_3_TESTE_ACEITE.md`) so the isolation and mundo-separation scenarios cover it too.
- `auditoria` must remain insert-only from every angle (trigger + RLS). Do not add an `update`/`delete` policy to it under any circumstance short of an explicit owner decision.
