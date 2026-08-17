# Anexo — Segurança Operacional, Backup e Recuperação (MVP)

> **Para o Manual Supremo (série v10).** Rascunho a validar com o fundador antes de integrar.
> Escrito em linguagem direta, para consulta rápida em incidente. Amarra-se ao **VRX Runbook de
> Manutenção** (procedimento passo a passo) e à **Classificação de Dados N1–N5** (Anexo 4).
> Legenda de estado: 🟢 vale hoje · 🟠 liga quando o sistema sobe a servidor (Supabase/Vercel).
>
> Versão 1 · 15/07/2026.

---

> **Em resumo:** A regra é **segurança proporcional ao risco** — forte onde o dado é sensível, leve
> onde não é —, de modo que a proteção **nunca trave o negócio no dia a dia**. Três garantias sustentam
> tudo: **nada se perde** (backup automático), **tudo tem ponto de retorno** (dá para voltar no tempo),
> e **nada é apagado em incidente** (a trilha é prova). O travamento total (Modo Emergência) é **exceção,
> nunca rotina**.

---

## 1. A camada de segurança aceitável no MVP

O que **liga agora**, para operar com segurança sem complexidade que atrapalhe. O resto espera a fase certa.

| Proteção | O que é | Estado |
|---|---|---|
| Isolamento por RLS | Cada cliente e cada mundo (gabinete/campanha) só enxerga o que é seu. É o coração da separação. | 🟢 modelado |
| Autenticação | Login por senha (2FA opcional) do Supabase. Papel define alçada — papel não é pessoa. | 🟠 ao subir |
| Dados no Brasil | Banco na região **São Paulo** (LGPD). | 🟠 ao criar o projeto |
| Segredos fora do código | Chaves de API em variável de ambiente; **nunca** em arquivo ou repositório. | 🟢 regra vigente |
| Trilha de auditoria | Tabela `auditoria`, só INSERT (imutável). Materializa o **Aegis** no MVP. | 🟢 modelado |
| Backup automático | Cópia diária + retorno no tempo (ver seção 2). | 🟠 com Supabase Pro |

**O que NÃO se liga agora** (evita travamento e custo prematuro): biometria (exige DPIA — pendência jurídica J9), Sigma One criptográfico (secret sharing 3‑de‑5), Modo Emergência automático e os sub‑agentes do SISEC. Tudo isso é **V1.5/V2**. Ligar cedo demais adiciona pontos de falha sem necessidade.

---

## 2. Backup — os dois cofres

São **duas** coisas distintas a proteger, com ferramentas distintas:

| O que proteger | Ferramenta | Como se recupera |
|---|---|---|
| **O negócio** (código, Manual, configs, motor) | **Git / GitHub** | Volta ao último commit são; todo histórico versionado. |
| **Os dados do gabinete** (briefings, demandas, atas, cadastros) | **Supabase Pro — backup diário + PITR** | *Point‑in‑time recovery*: volta a **qualquer minuto dos últimos 7 dias**. |

> **Ponto de retorno** = o instante são para onde você volta. Para código, é um commit do Git. Para dados,
> é um ponto no tempo do PITR. Ter os dois é o que permite dizer, em qualquer erro: *"sem pânico, a gente volta."*

**Trava LGPD:** enquanto o parecer da Dra. Íria (perguntas J8/J9 — base legal e termo de consentimento) não sair, **nenhum dado real de cidadão** entra no banco. Backup e testes usam **dados fictícios**.

---

## 3. Protocolo de incidente (o que fazer quando trava, corrompe ou dá erro)

Este anexo **não substitui** o VRX Runbook — aponta para ele. O VRX já traz o mapa de severidade
(**S1 crítico → S4 baixo**) e o passo a passo por sintoma. A espinha, para memorizar:

**A regra de ouro, em 4 passos:**
1. **Não apague nada.** A trilha e os logs são prova — mesmo (e principalmente) num vazamento.
2. **Leia o erro.** A última linha do traceback e o `evora.log` resolvem a maioria dos casos.
3. **Restaure do ponto de retorno.** Código quebrado → volta no Git. Dado corrompido → PITR do Supabase.
4. **Só então investigue a causa** — com o sistema já de pé de novo.

**Severidade que mais importa (do VRX):**

| Nível | Exemplo | Resposta |
|---|---|---|
| **S1 — Crítico** | Suspeita de vazamento de dado pessoal; chave de API exposta | Imediato: conter, preservar, acionar responsável e (com a Íria) avaliar dever de comunicar à ANPD. |
| **S2 — Alto** | Briefing não saiu; app fora do ar | No mesmo dia: rodar manual, ler o erro, restaurar. |
| **S3 — Médio** | Uma fonte/jornal falhando | 24–48h: o sistema degrada avisando e segue; corrige depois. |
| **S4 — Baixo** | Ajuste de filtro, ruído | Backlog. |

> **Chave exposta (caso comum):** revogue em console.anthropic.com **na hora**, gere outra, atualize a
> variável de ambiente, registre na trilha. Nunca comitar chave em código.

---

## 4. Modo Emergência — travar sem paralisar o negócio

O travamento total existe, mas é **exceção**. Em ameaça grave, o **SISEC** (ou, enquanto manual, o
**ADM/VRX**) aciona o Modo Emergência com **teto de 24h** e preservação do **Mínimo Vital** (as funções
essenciais seguem no ar). O encerramento é do **ADM/VRX**; a autoridade recebe ciência. Segurança que
derruba o negócio a toda hora é segurança **mal calibrada** — o desenho aqui é o oposto: conter o risco
sem parar o que é essencial.

---

## 5. O que promover de 🟠 para 🟢 (lista de ação)

Para esta camada sair do papel, na ordem:
1. Subir o banco no **Supabase (São Paulo)** e ativar o plano **Pro** → liga backup diário + PITR.
2. Versionar tudo em **Git/GitHub** (código, motor, Manual) → ponto de retorno do negócio.
3. Confirmar **segredos** só em variável de ambiente (auditar que nada vazou em arquivo).
4. Ligar **auth + papéis** no app (alçada por papel).
5. Fechar o parecer **J8/J9** com a Dra. Íria → destrava dado real de cidadão.

---

## 6. Onde isto se conecta no Manual

- **VRX Runbook de Manutenção** — o procedimento operacional completo (severidades, runbook por sintoma, restaurar backup, reiniciar motor). Este anexo é o resumo de governança; o VRX é o manual de campo.
- **Anexo 4 — Classificação de Dados (N1–N5)** — define o que é sensível e, portanto, o que exige proteção máxima.
- **SISEC** — a camada de cibersegurança que, na V2, automatiza detecção e resposta.
- **Aegis** — o cofre soberano; a tabela `auditoria` é seu primeiro tijolo.
- **Matriz de Alçada (Anexo 5)** — quem autoriza cada mudança de segurança.
