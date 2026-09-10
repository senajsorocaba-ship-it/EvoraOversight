# Évora Oversight

Plataforma multi-tenant de inteligência para gabinetes políticos brasileiros.
A primeira entrega — **Genesis / Núcleo Fundador (L1)** — gira em torno de um
entregável-herói: o **Briefing Matinal**, redigido por IA a partir de dado real
(Diário Oficial, PNCP, imprensa, demandas do gabinete) e entregue à autoridade
às 06:45, com **freio humano** obrigatório antes de qualquer ato de efeito
externo.

> **Princípios que o código não pode violar:** verdade acima da conveniência
> (nunca inventar — o que não é fato verificado é marcado como pendente ou
> "não verificado"); a autoridade humana decide; separação gabinete × campanha;
> LGPD e legislação eleitoral como condição; toda informação com fonte declarada
> (CVI — cada citação vem com veículo, data e link).

---

## Em que etapa estamos

**Faseamento do produto:** L1 (Núcleo Fundador). **Selo de maturidade: BETA —
ainda não lançado.** Nada roda em produção: não há Supabase na nuvem migrado,
nem deploy do front, nem agendador ativo. Tudo abaixo foi validado contra um
**Supabase local** (`supabase start`).

| Camada | Estado |
|---|---|
| **Schema + RLS** (BLOCOs 1–3) | ✅ 24 tabelas, políticas de isolamento por tenant, teste de aceite da RLS passando (4/4 cenários) |
| **Motor do briefing** (BLOCO 4) | ✅ Funções `evora_montar_blocos_briefing` / `evora_gerar_briefing_diario` — agregam os 7 blocos canônicos |
| **Autenticação** (BLOCO 5) | ✅ local (auto-vínculo `auth.users` → `usuarios`, `tenant_id`/`mundo` no JWT via Custom Access Token Hook). ⚠️ **Nunca rodado na nuvem** — exige um passo manual no dashboard (habilitar o hook) |
| **Coletores** (Fases 6–9) | ✅ Ingestão PNCP/imprensa, Atlas Municipal, coletor de menções por nome, vigia de vereadores — testados contra APIs reais |
| **FARUS F1** (Fase 10) | ✅ Ingestão real do acervo por território (`evora_coletor_farus.py`), leitura no bloco 6 do briefing e na Bia. Testado com Sorocaba-SP (57 itens). **F2–F5 não construídos** (curadoria humana, radar autônomo) |
| **Aegis A0** (Fase 11) | ✅ Cofre de dado sensível — schema e teste de aceite (10/10) |
| **Bia por voz** | ✅ local — ativação por palavra-chave ("Bia…"), navegação, perguntas respondidas com dado do próprio tenant, resposta em streaming, fila de fala. Sem invenção (Cláusula de Caráter Travado) |
| **Painel web** | ⚠️ 16 telas com layout pronto, mas **só `/briefing` está ligada a dado real** — o resto é maquete estática (portada do PDF de demonstração) |
| **Reconhecimento facial** (modo descanso) | 🟡 STAND-BY — implementado, **não testado** |

### Briefing — blocos com dado real

5 dos 7 blocos já vêm preenchidos: `resumo_do_dia`, `fiscalizacao` (PNCP),
`demandas`, `imprensa` (fontes declaradas + menções + acervo FARUS) e
`movimento_sugerido_72h`. Faltam `radar_de_nomeacoes` e `pulso_da_camara_do` —
dependem de um coletor de Diário Oficial / Câmara que ainda não existe como
código.

---

## Arquitetura

Três componentes, **um repositório só**:

```
┌─ web/ ─────────────┐     ┌─ Supabase (Postgres) ─┐
│ Next.js 16         │────▶│ 24 tabelas + RLS      │
│ Painel + Bia (voz) │◀────│ funções do briefing   │
└────────────────────┘     └───────────┬───────────┘
                                       │ service_role
┌─ .github/workflows/ ───────┐         ▼
│ briefing-diario.yml (cron) │──▶ ao-SUPABASE-BLOCO1/*.py
│ 05:30, todo dia            │    coletores + motor → Claude API → grava markdown/html
└────────────────────────────┘
```

- **`web/`** — Next.js 16 / React 19. Fala com o Supabase pela sessão do
  usuário (nunca a `service_role`); a RLS isola tenant/mundo. A rota
  `/api/bia` (server) é a única que chama a API da Claude no front.
- **`ao-SUPABASE-BLOCO1/`** — o "motor do briefing" e os coletores (Python
  stdlib + SDK oficial da Anthropic). Rodam server-side com a `service_role`
  key. Nunca tocam `ciencia_por` — o gate humano fica na aplicação.
- **`supabase/migrations/`** — o schema versionado (espelha os arquivos SQL de
  `ao-SUPABASE-BLOCO1/`, que são a fonte de referência legível).
- **`.github/workflows/briefing-diario.yml`** — agendador diário (GitHub
  Actions; não há servidor para este projeto). Roda os 2 coletores e depois o
  motor, todos em `--todos`.

---

## Estrutura do repositório

| Caminho | O que é |
|---|---|
| `web/` | Aplicação Next.js (painel do gabinete + Bia por voz) |
| `supabase/migrations/` | Migrations do Postgres (schema, RLS, motor, auth, atlas, FARUS, Aegis) |
| `ao-SUPABASE-BLOCO1/` | SQL de referência (BLOCOs 1–5) + motor e coletores em Python + `CLAUDE.md` com o histórico de decisões por fase |
| `.github/workflows/` | `briefing-diario.yml` — cron do briefing |
| `motor/` | Pipeline original pré-Supabase (coletores + montador), mantido como referência |
| `Evora Manual v10 9 1.md` | Manual do produto — fonte da verdade sobre escopo, fases e princípios |
| `_versoes_anteriores/` | Arquivo morto (manuais antigos, protótipos, exports) |

---

## Rodar localmente

**Backend (Supabase local):**
```bash
supabase start                 # sobe Postgres + Auth + PostgREST via Docker
supabase db reset              # aplica todas as migrations + seed
```
Depois, no dashboard local (`http://127.0.0.1:54323`): Authentication → Hooks →
habilitar **Custom Access Token** → `custom_access_token_hook`.

**Front:**
```bash
cd web
npm install
npm run dev                        # http://localhost:3000
```
Crie `web/.env.local` com `NEXT_PUBLIC_SUPABASE_URL`,
`NEXT_PUBLIC_SUPABASE_ANON_KEY` (apontando para o Supabase local ou de nuvem) e
`ANTHROPIC_API_KEY` (usada só na rota `/api/bia`, no servidor).

**Motor do briefing (sob demanda):**
```bash
cd ao-SUPABASE-BLOCO1
pip install -r requirements.txt
# .env com SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, ANTHROPIC_API_KEY
python evora_coletor_mencoes.py --tenant-id <uuid> --mundo gabinete
python evora_coletor_farus.py   --tenant-id <uuid>
python evora_motor_execucao.py  --tenant-id <uuid> --mundo gabinete
```

---

## O que falta para o lançamento (deploy)

1. **Commit + push** de todo o trabalho pendente (feito).
2. **`supabase db push`** — aplicar as 11 migrations no projeto Supabase da nuvem.
3. **Dashboard do Supabase (nuvem)**, passos que nenhum SQL faz:
   - Auth → Hooks → habilitar Custom Access Token → `custom_access_token_hook`
     (**bloqueador** — sem isso o JWT não carrega `tenant_id` e a RLS zera tudo)
   - Auth → URL Configuration → `site_url` e redirect URLs = domínio real
   - Decidir confirmação de e-mail (se ligar, configurar SMTP)
4. **Provisionar o primeiro gabinete real** (fluxo `/cadastro` ou inserção manual).
5. **Vercel** — importar o repo, **Root Directory = `web`**, definir
   `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`,
   `ANTHROPIC_API_KEY`.
6. **GitHub Actions** — cadastrar os 3 secrets e rodar o workflow manualmente
   uma vez para validar.

Fora de escopo do lançamento: entrega do briefing por e-mail, FARUS F2–F5,
coletor de Diário Oficial/Câmara, reconhecimento facial.
