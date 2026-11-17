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
| **Schema + RLS** (BLOCOs 1–3) | ✅ 40 tabelas (base + Fases 6–13 + Demandas/Histórico), políticas de isolamento por tenant, teste de aceite da RLS passando (4/4 cenários) + Demandas (10/10 cenários) |
| **Motor do briefing** (BLOCO 4) | ✅ Funções `evora_montar_blocos_briefing` / `evora_gerar_briefing_diario` — agregam os 7 blocos canônicos |
| **Autenticação** (BLOCO 5) | ✅ local (auto-vínculo `auth.users` → `usuarios`, `tenant_id`/`mundo` no JWT via Custom Access Token Hook). ⚠️ **Nunca rodado na nuvem** — exige um passo manual no dashboard (habilitar o hook) |
| **Coletores** (Fases 6–9) | ✅ Ingestão PNCP/imprensa, Atlas Municipal, coletor de menções por nome, vigia de vereadores — testados contra APIs reais. **161 testes unitários** (`ao-SUPABASE-BLOCO1/tests/`) cobrindo a lógica pura de todos os 8 scripts |
| **FARUS F1** (Fase 10) | ✅ Ingestão real do acervo por território (`evora_coletor_farus.py`), leitura no bloco 6 do briefing e na Bia. Testado com Sorocaba-SP (57 itens). **F2–F5 não construídos** (curadoria humana, radar autônomo) |
| **Aegis A0** (Fase 11) | ✅ Cofre de dado sensível — schema e teste de aceite (10/10) |
| **Bia por voz** | ✅ local — ativação por palavra-chave ("Bia…"), navegação, perguntas respondidas com dado do próprio tenant, resposta em streaming, fila de fala. Sem invenção (Cláusula de Caráter Travado) |
| **Painel web** | ⚠️ 16 telas com layout pronto, mas **só `/briefing` está ligada a dado real** — o resto é maquete estática (portada do PDF de demonstração) |
| **Reconhecimento facial** (modo descanso) | 🟡 STAND-BY — implementado, **não testado** |
| **Manual Supremo v11.0** (16/09/2026) | 🟡 Parcial — hook renomeado (`evora_token_hook`), módulo Demandas travado no banco até parecer jurídico, 2 coletores "confirmado" novos (PNCP + Agenda Legislativa, ambos aguardando uma `farus_fontes` liberada por humano pra rodar de verdade). **Veritas** (acervo legal — normas, o que *vale* e não o que *aconteceu*) ✅ schema construído (`veritas_normas`/`veritas_dispositivos`/`veritas_carga`, sem policy de acesso, só via `veritas_consultar`/`veritas_vigente_em`) + extrator de carga curada (`extrator_veritas.py`) |
| **Manual Supremo v11.1** (20/09/2026) | ✅ Schema construído — **Inteligência Legislativa** (matéria com tramitação, 8 tabelas, compartilhado por território), **Resposta/Minutas** (freio humano para tudo que o gabinete manda pra fora — Évora nunca envia, só registra), **Parecer como Evento** (habilitação é da pessoa, nunca vira papel novo). Testes de aceite entregues (12/12, 12/12, 11/11) copiados pro repo. **Nada disto rodado contra banco real ainda** (Docker local desligado nesta sessão) |
| **Manual Supremo v11.3** (20/09/2026) | 🟡 Sem mudança de schema — v11.2/v11.3 foram sobretudo editoriais (nomes reais trocados por função em todo o projeto, manual reorganizado em 4 volumes) + **Anexo 26/`Evora_Catalogo_Fontes.md`: catálogo real de fontes do FARUS/Veritas**, com estado de verificação por fonte. É o que falta pra **liberar de verdade** os coletores PNCP/Agenda Legislativa (hoje dormentes por falta de `farus_fontes` configurada) — **ainda não aplicado no banco**, fica pra quando alguém liberar as fontes ✅ do catálogo. Corrigido: Diário Oficial de Sorocaba já era fonte confirmada (só falta o conector, não a fonte). **Fila aberta (`FILA_v11_4.md`)**: nada exige construção agora — só decisões do fundador (preço Aegis Personal, fórmula do Sigma One, fluxo do requerimento) e verificações técnicas |
| **Aegis A1/A2 + Sigma One** (`Evora_Aegis_Sigma_One_v3.pdf`) | 📋 Spec em maturação, **não construído** — cofre com duas caixas (Mandato/Pessoal) e protocolo de guardiões com quórum. Cheio de `[DECISÃO]` em aberto (quantos guardiões, preço, perguntas jurídicas 38–40). Fora do escopo até essas decisões fecharem |
| **Base das Demandas + Histórico** (Tarefa 3, Briefing Técnico Guiron 13/11/2026) | ✅ `demandas` alinhada ao vocabulário pedido (`assunto`/`solicitante_*`/`origem`/`encerrado_em`), `demandas_historico` append-only gravado por trigger. Trava jurídica (parecer P8/P9) e exigência de consentimento continuam intactas. **Testado 10/10 cenários contra Postgres real** (`ao-SUPABASE-BLOCO1/evora demandas teste aceite.sql`) — corrigiu de passagem um bug de produção (`trg_demandas_atualizado` nunca funcionou nesta tabela, coluna com nome errado desde a criação) |

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
│ Next.js 16         │────▶│ 40 tabelas + RLS      │
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
| `supabase/migrations/` | Migrations do Postgres (schema, RLS, motor, auth, atlas, FARUS, Aegis, Veritas, Inteligência Legislativa/Resposta/Parecer) |
| `ao-SUPABASE-BLOCO1/` | SQL de referência (BLOCOs 1–5) + motor e coletores em Python + `CLAUDE.md` com o histórico de decisões por fase |
| `.github/workflows/` | `briefing-diario.yml` — cron do briefing |
| `motor/` | Pipeline original pré-Supabase (coletores + montador), mantido como referência |
| `Evora_Manual_v11_3.md` | Manual do produto — fonte da verdade sobre escopo, fases e princípios (substitui a v11.1, arquivada) |
| `FILA_v11_4.md` | Fila aberta — o que entrou depois da emissão da v11.3, aguardando decisão/verificação, nada pra construir ainda |
| `Evora_Catalogo_Fontes.md` | Catálogo real de fontes do FARUS/Veritas (extrato do Anexo 26), com estado de verificação por fonte — usar pra liberar `farus_fontes` de verdade |
| `Evora_Caderno_Programador.pdf` | Companheiro do Manual v11.0 — o quê e em que ordem (não o porquê) |
| `Evora_Checklist_Lancamento.pdf` | Checklist de negócio pro lançamento — 3 "portões" (operar com dado real / cobrar / oferecer ao mercado), a maior parte fora do escopo técnico deste repo |
| `Evora_Aegis_Sigma_One_v3.pdf` | Spec do cofre com quórum de guardiões (Aegis A1/A2) — design em maturação, não construído |
| `DEPLOY_RUNBOOK.md` | Roteiro de deploy passo a passo — Supabase, Vercel, GitHub Actions, com verificação em cada etapa |
| `_versoes_anteriores/` | Arquivo morto (manuais antigos, protótipos, exports, pacotes entregues já adaptados) |

---

## Rodar localmente

**Backend (Supabase local):**
```bash
supabase start                 # sobe Postgres + Auth + PostgREST via Docker
supabase db reset              # aplica todas as migrations + seed
```
Depois, no dashboard local (`http://127.0.0.1:54323`): Authentication → Hooks →
habilitar **Custom Access Token** → `evora_token_hook`.

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

**Testes unitários (coletores + motor, sem tocar rede/banco de verdade):**
```bash
cd ao-SUPABASE-BLOCO1
pip install -r requirements.txt -r requirements-dev.txt
pytest                              # 161 testes
```

---

## O que falta para o lançamento (deploy)

> Roteiro detalhado, passo a passo com comandos exatos e verificação em cada
> etapa: **[`DEPLOY_RUNBOOK.md`](DEPLOY_RUNBOOK.md)**. O resumo abaixo é só o
> checklist rápido.

1. **Commit + push** de todo o trabalho pendente (feito — falta só o `push`).
2. **`supabase db push`** — aplicar as 19 migrations no projeto Supabase da nuvem.
3. **Dashboard do Supabase (nuvem)**, passos que nenhum SQL faz:
   - Auth → Hooks → habilitar Custom Access Token → `evora_token_hook`
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
