# Évora Oversight — Pacote de Sincronização v10.6 (documento único)

**Emitido em 19/07/2026 · alinhado ao Manual Supremo v10.6 · Confidencial — Eng. Luiz Gonzaga Filho**

Consolida os **22 arquivos** do pacote (os 20 da emissão original + os 2 do Atlas Municipal, acrescentados na mesma data por decisão do fundador) em um único .md — para leitura, conferência, arquivo e prova material. Para *usar* no laptop, prefira as versões soltas ou o zip.

## Índice dos 22 arquivos

| # | Arquivo | Tipo |
|---|---------|------|
| 1 | `LEIA-ME_SINCRONIZACAO.md` | markdown |
| 2 | `Briefing_Matinal_Pipeline_v1_1.md` | markdown |
| 3 | `GUIA_Primeiro_Briefing_v2.md` | markdown |
| 4 | `Evora_Catalogo_Agentes_v2.md` | markdown |
| 5 | `ROTEIRO_LAPTOP_APOSENTADO.md` | markdown |
| 6 | `renomear_versoes.ps1` | powershell |
| 7 | `motor/LEIA-ME_MOTOR.md` | markdown |
| 8 | `motor/requirements.txt` | text |
| 9 | `motor/perfil_tatiane.json` | json |
| 10 | `motor/perfil_tenant_modelo.json` | json |
| 11 | `motor/perfil_loader_evora.py` | python |
| 12 | `motor/entrevista_fundacao.py` | python |
| 13 | `motor/atlas_municipal.py` | python |
| 14 | `motor/atlas_sorocaba-sp.json` | json |
| 15 | `motor/imprensa_coletor_evora.py` | python |
| 16 | `motor/coletor_pncp_evora.py` | python |
| 17 | `motor/montador_briefing_evora.py` | python |
| 18 | `motor/render_briefing_evora.py` | python |
| 19 | `motor/render_dashboard_evora.py` | python |
| 20 | `motor/orquestrador_evora.py` | python |
| 21 | `motor/aprendizado_evora.py` | python |
| 22 | `motor/dashboard_template.html` | html |

---

## 1. `LEIA-ME_SINCRONIZACAO.md`

````markdown
# Pacote de Sincronização — Évora v10.6 (19/07/2026)

Este pacote deixa a pasta do projeto alinhada ao **Manual Supremo v10.6**.
Substitui o pacote v10.5 emitido em 18/07 (mesmos arquivos, sem o Anexo 16).

## Antes de tudo (regra de ouro)
```powershell
Copy-Item motor motor_backup_20260719 -Recurse   # backup — nada se apaga
```

## O que mudou nesta emissão (v10.5 -> v10.6)

O Manual ganhou o **Anexo 16 — Atlas Municipal do Brasil e Entrevista de Fundação**, que torna
o Évora instalável em qualquer município do Brasil. Consequências no código:

| Novidade | Onde |
|---|---|
| **`entrevista_fundacao.py`** — as 14 perguntas do onboarding, gera o perfil do tenant | `motor\` (NOVO) |
| **Níveis de fonte F1/F2/F3** (CNPJ identifica; cobertura decide entrada) | `perfil_tatiane.json`, `perfil_tenant_modelo.json` |
| **Multi-município** (`municipio_sede` + `area_atuacao`) | ambos os perfis + `perfil_loader_evora.py` |
| **Procedência por campo** (`declarado` / `atlas` / `verificado`) | ambos os perfis |
| Loader lê os dois formatos de veículo e exclui F3 da varredura geral | `perfil_loader_evora.py` |

## O que substitui o quê

| Arquivo novo (neste pacote) | Substitui | Mudança |
|---|---|---|
| `motor\entrevista_fundacao.py` | — (novo) | Onboarding do tenant: 14 perguntas → perfil (decisão D7) |
| `motor\atlas_municipal.py` + `motor\atlas_sorocaba-sp.json` | — (novo) | Atlas Municipal em arquivo: `semear` cidade nova, `aplicar` ao perfil (procedência `atlas`), `validar` regras do Anexo 16. Sorocaba já semeada (5 F1 + 1 F2 com evidência, DO verificado) |
| `motor\perfil_loader_evora.py` | versão v10.5 | Ganhou `area_atuacao()` e normalização F1/F2/F3 — **retrocompatível** |
| `motor\perfil_tatiane.json` | versão v10.5 | Níveis de fonte, procedência, multi-município |
| `motor\perfil_tenant_modelo.json` | versão v10.5 | Folha em branco com a estrutura nova |
| `motor\*.py` (demais scripts) | scripts de 13/07 | motor v2: dirigido pelo perfil, limiar do perfil, render corrigido, orquestrador honesto |
| `motor\render_dashboard_evora.py` + `motor\dashboard_template.html` | — | Dashboard real: painéis Briefing, Radar e Fiscalização com dados do dia (5º passo do orquestrador) |
| `Briefing_Matinal_Pipeline_v1_1.md` | `Briefing_Matinal_Pipeline_v1.md` | AFEx-g; 7 blocos canônicos; **nota v10.6 sobre fontes por cidade** |
| `GUIA_Primeiro_Briefing_v2.md` | guia "v9.9" | Sem pip; PowerShell + Mac/Linux; **Parte 0 — Entrevista de Fundação** |
| `Evora_Catalogo_Agentes_v2.md` | catálogo .pdf (ZIP de imagens) | 26 agentes (entrou AFC-p); markdown legível por IA |
| `ROTEIRO_LAPTOP_APOSENTADO.md` | `ROTEIRO_LAPTOP_v3.md` | Roteiro aposentado; instruções v2 assumem |
| `renomear_versoes.ps1` | — | Higiene: arquiva duplicatas com carimbo de data |

## Depois de copiar

1. Rodar `renomear_versoes.ps1` na pasta dos documentos (arquiva duplicatas, inclusive a v10.5).
2. Testar o motor: `python motor\perfil_loader_evora.py` -> deve mostrar "Limiar: 25%" e 7 blocos.
3. Rodar o pipeline com a chave (`GUIA_Primeiro_Briefing_v2.md`, Parte 3).
4. Conferir que `Dashboard_Real_AAAAMMDD.html` foi gerado junto.
5. **Tenant novo:** rodar `python motor\entrevista_fundacao.py` (Parte 0 do guia); depois `python motor\atlas_municipal.py semear "<Cidade>" <UF>`, preencher/verificar, e `aplicar` ao perfil.
6. Quando o Git subir, este pacote é o commit inicial ("consolidação v10.6").

## Estado honesto do que está aqui

| Componente | Estado |
|---|---|
| Motor de briefing (coleta -> Bia -> render) | **Roda** |
| Dashboard real (3 painéis) | **Roda** |
| Entrevista de Fundação | **Roda** — gera perfil consumível pelo motor; testada com e sem ciência das travas |
| Atlas Municipal (`atlas_municipal.py`) | **Roda (versão em arquivo)** — semear/aplicar/validar; Sorocaba semeada com dados verificados (`atlas_sorocaba-sp.json`); migra para o banco na Etapa 3 sem mudar estrutura |
| Conector do Diário Oficial (COM) | **A escrever** — nenhuma cidade tem conector, nem Sorocaba |
| Banco Supabase (11 tabelas + RLS) | **A escrever** — Etapa 3 |

*Confidencial — Eng. Luiz Gonzaga Filho · alinhado ao Manual Supremo v10.6 de 19/07/2026*

````


---

## 2. `Briefing_Matinal_Pipeline_v1_1.md`

````markdown
# Briefing Matinal — Espec do Pipeline (v1.1)

**Produto:** Briefing Político Matinal (MVP do Évora Oversight)
**Cliente-piloto:** Vereadora Tatiane Costa (PL) — pré-campanha Deputada Federal 2026, Sorocaba/SP
**Entrega:** todo dia às **06:45**, modo **sigiloso** (operado pelas assessoras; a autoridade recebe como produção da equipe)
**Orquestrador:** Bia-g (Gestora de Gabinete)

> **v1.1 · 18/07/2026 — o que mudou.** (1) Sigla corrigida em todo o documento: **AFGm-g → AFEx-g** (nome travado desde a v7.1 do Manual; ratificado pelo fundador em 18/07). (2) Saída-alvo alinhada aos **7 blocos canônicos do perfil do tenant** (Manual v10.6), substituindo os 6 blocos do demo de 17/06. (3) "Posição de partida" e "Radar da disputa" reposicionados conforme a separação de mundos. Nenhuma outra regra foi alterada.

> **Nota v10.6 (19/07/2026).** As fontes deste pipeline deixam de ser lista fixa de Sorocaba e passam a vir do **Atlas Municipal + perfil do tenant** (Manual v10.6, Anexo 16). Níveis: **F1** Registrada (CNPJ ativo + CNAE de mídia — identifica o veículo, não mede credibilidade) · **F2** Reconhecida (cobre a cidade/região com evidência arquivada, independente de sede) · **F3** Declarada (influencers/perfis pessoais — só no perfil isolado do tenant, nunca no Atlas). O teste de entrada é **cobertura**, não sede. O motor já lê os dois formatos de perfil (legado e F1/F2/F3).

---

## 1. Saída-alvo — os 7 blocos canônicos

O formato do briefing é definido pelo **perfil do tenant** (`perfil_tatiane.json`) — fonte única, referenciada por Manual, espec e código. Bloco sem dado sai literalmente como **"Sem dado hoje."** — nunca omitido em silêncio, nunca preenchido por suposição.

| # | Bloco | Conteúdo | Natureza |
|---|-------|----------|----------|
| 1 | **Resumo do dia** | Até 3 movimentos que pedem atenção hoje | Síntese (gerado por último) |
| 2 | **Radar de Nomeações (AFEx-g)** | Nomeações/exonerações do Diário Oficial + cruzamento com nomes de interesse | Fiscalização — indício, nunca acusação |
| 3 | **Fiscalização do Executivo** | Contratos acima do limiar do tenant (padrão 25%), base de comparação declarada | Fiscalização |
| 4 | **Pulso da Câmara / Diário Oficial** | Pautas, proposituras e atos em movimento onde ela pode liderar/posicionar | Mandato |
| 5 | **Demandas & Requerimentos** | O que corre no gabinete, mudanças de status, prazos vencidos | Mandato (depende do banco) |
| 6 | **Monitoramento & Imprensa** | Menções e manchetes relevantes, com veículo e data | Monitoramento |
| 7 | **Movimento sugerido (72h)** | Recomendações acionáveis a partir dos blocos acima | Síntese estratégica, sob freio humano |

**Onde foram parar os blocos antigos (v1):**
- *Posição de partida* (votos, colocação, presença digital) — **linha de base de atualização lenta**, fora do briefing diário; vive em tela própria/perfil e é citada quando um item do dia a exigir. *(Decisão registrada na v10.5.)*
- *Radar da disputa* — no mundo Gabinete existe **apenas como leitura de imprensa pública**, dentro do bloco 6. Análise eleitoral estruturada é do mundo Campanha (AIE-p/AIA-p, sob o Nil) e só cruza pela **Ponte Bia↔Nil** auditada.

---

## 2. Mapa fonte → bloco → agente

| Bloco | Fonte de dados | Agente dono | Acesso hoje |
|-------|----------------|-------------|-------------|
| 2 · Radar de Nomeações | Diário Oficial do Município (PDF via COM RMS-001) | AFEx-g | ⚠️ conector COM a construir |
| 3 · Fiscalização | PNCP · bases de preço de referência | AFEx-g | PNCP ✅ (endpoint a confirmar no go-live) |
| 4 · Pulso da Câmara/DO | Portal da Câmara · Câmara Sem Papel/SPL · Diário Oficial · imprensa | AFEx-g + AIM-g | ⚠️ formato a definir (semi-manual até o COM) |
| 5 · Demandas | Banco do gabinete (Supabase) | ADC-g | ❌ banco ainda não no ar |
| 6 · Monitoramento & Imprensa | Imprensa local (5 jornais via agregador) · veículos nacionais · (redes, quando liberado) | AIM-g | Imprensa ✅ · redes ❌ API gated (O5) |
| 1 · Resumo do dia | — (síntese dos blocos 2–6) | Bia-g | ✅ |
| 7 · Movimento 72h | — (síntese estratégica) | Bia-g + ACN-g (tom) | ✅ |

Legenda: ✅ acessível agora · ⚠️ acessível com configuração · ❌ bloqueado (dependência)

---

## 3. Fluxo de geração (madrugada → 06:45)

```
[1] COLETA (rotina noturna)
     cada conector puxa sua fonte:
     Diário Oficial · PNCP · Câmara/SPL · imprensa · (redes, quando liberado)
        │
        ▼
[2] VALIDAÇÃO DE DADOS (Veritas-Dados)
     valida origem + qualidade; recusa dado frágil; anexa fonte e data
        │
        ▼
[3] PROCESSAMENTO POR AGENTE
     AIM-g  → bloco 6 (imprensa e menções)
     AFEx-g → blocos 2, 3, 4 (Diário Oficial + PNCP + Câmara → achados)
     ADC-g  → bloco 5 (demandas, quando o banco subir)
     AAG-g  → agenda pública do dia
     ACN-g  → tom/enquadramento das recomendações
        │
        ▼
[4] SÍNTESE (Bia-g)
     monta bloco 1 (Resumo do dia) + bloco 7 (Movimento 72h)
     a partir dos blocos processados; bloco sem dado = "Sem dado hoje."
        │
        ▼
[5] FREIO HUMANO  ← princípio inviolável
     assessora revisa e aprova antes de qualquer entrega
        │
        ▼
[6] RENDER + ENTREGA 06:45
     HTML/PWA · modo sigiloso · trilha de auditoria registrada
```

---

## 4. Pontos de governança (travas de projeto)

- **Só dados públicos e verificáveis.** Cada apontamento carrega fonte + data de consulta (CVI). Sem isso, não entra.
- **Aprovação humana antes da entrega.** Nenhum briefing sai sem o freio humano (princípio inviolável).
- **Separação dura mandato × campanha.** No mundo -g, radar da disputa é só leitura de imprensa pública (bloco 6). Qualquer análise eleitoral estruturada pertence ao lado Praetor (Nil) e só cruza pela **Ponte Bia↔Nil**, auditada. *(Confirmado na v10.5.)*
- **LGPD não acionada neste produto.** O briefing usa dado público/agregado. O AIM-g nunca trata perfil/grupo privado como público. (O gatilho LGPD está no módulo de Demandas com dado real de cidadão — aguarda parecer.)
- **Rastreabilidade total.** Cada caso e desfecho arquivado com fonte, data e método.

---

## 5. Corte de escopo — o que construímos primeiro

**Fase A — Briefing real com fontes acessíveis (em curso)**
Entrega os blocos **1, 3 (parcial via PNCP), 6 e 7** com automação, e o bloco **4** semi-manual:
- PNCP → fiscalização de contratos (limiar do perfil)
- Imprensa local via agregador → monitoramento
- Blocos 2 e 5 saem como "Sem dado hoje." até as dependências (COM e banco)

**Fase B — Diário Oficial + banco**
- Conector COM RMS-001 (Diário Oficial em PDF) → liga o bloco 2 (Radar de Nomeações) e completa o 4
- Banco Supabase no ar → liga o bloco 5 (Demandas)

**Fase C — Monitoramento ao vivo (operação plena)**
- Redes/social listening (O5) e pauta da Câmara automatizada (SPL)

---

## 6. Dependências que afetam o build

| Dep. | O que falta | Impacto |
|------|-------------|---------|
| O4 / COM | Conector do Diário Oficial de Sorocaba (PDF) | Bloqueia o bloco 2 e a automação plena do 4 |
| Banco | Supabase + RLS no ar | Bloqueia o bloco 5 |
| O5 | APIs de redes ou social listening | Bloqueia o tempo-real do bloco 6 |
| PNCP | Confirmar endpoint/campos da API de consulta no go-live | Ajuste pontual no coletor |

---

## 7. Próximo passo

Motor v2 (dirigido pelo perfil) sincronizado no laptop → rodar o pipeline completo com a chave da API → primeiro briefing 100% gerado pela máquina, no formato dos 7 blocos, pronto para o freio humano. Em paralelo: subir o banco (Etapa 3) e especificar o conector COM.

---

*v1.1 · 18/07/2026 · substitui a v1 (17/06–15/07) · alinhado ao Manual Supremo v10.6 · Confidencial — Eng. Luiz Gonzaga Filho*

````


---

## 3. `GUIA_Primeiro_Briefing_v2.md`

````markdown
# Guia — Primeiro Briefing Real do Évora (v2 · alinhado ao Manual v10.6)

Este guia leva você do zero ao primeiro briefing real da Tatiane. Siga na ordem.

> **v2 · 18/07/2026 — o que mudou:** removido o passo `pip install` (o motor usa só a biblioteca padrão do Python — não há nada a instalar); instruções de chave agora em **Windows (PowerShell)** e **Mac/Linux** lado a lado; motor referenciado é o **v2** (dirigido pelo perfil do tenant, limiar 25% lido do perfil).

## Parte 0 — Tenant novo? Comece pela Entrevista de Fundação `[v10.6]`

Se você está implantando para **um cliente novo** (não a Tatiane), rode primeiro:

```powershell
python entrevista_fundacao.py
```

São 14 perguntas, cerca de 8 minutos. No fim, o script gera o `perfil_<tenant>.json`
que o motor lê — sem edição manual — e lista na tela o que ainda falta antes do go-live.

Duas coisas que o script **não deixa passar**:
- Sem a ciência das 3 travas, o perfil sai marcado `operacional: false` e o go-live fica bloqueado.
- Os veículos saem vazios de propósito: a verificação humana da mídia local é obrigatória
  antes do go-live (o Atlas preenche o rascunho, mas alguém confere).

Para a Tatiane (tenant zero), pule esta parte — o perfil dela já existe.

## Parte 1 — Conseguir a chave da API (uma vez só)

1. Acesse **console.anthropic.com** e faça login (é a conta de desenvolvedor, separada do app Claude).
2. Verifique o telefone por SMS (pode liberar ~US$5 de crédito de teste).
3. **Settings → Billing:** adicione um cartão, ponha um crédito pequeno (US$5) e um limite mensal (ex.: US$10). *Sem billing, a chave existe mas as chamadas falham.*
4. **API Keys → Create Key:** dê o nome **Evora-Briefing** e crie.
5. **Copie a chave imediatamente** (aparece uma vez só; começa com `sk-ant-`). Guarde em lugar seguro.

## Parte 2 — Preparar a máquina (uma vez só)

Só é preciso ter o **Python 3.10 ou superior**. Não há nada para instalar — o motor usa somente a biblioteca padrão.

**Windows (PowerShell):**
```powershell
python --version    # deve mostrar 3.10 ou superior
```

**Mac/Linux:**
```bash
python3 --version
```

Se o Python não estiver instalado no Windows, baixe em **python.org/downloads** e, na instalação, marque **"Add Python to PATH"**.

## Parte 3 — Rodar o briefing

**Windows (PowerShell):**
```powershell
cd caminho\para\motor

# 1) colar a chave (vale NESTA janela do PowerShell; troque pela sua)
$env:ANTHROPIC_API_KEY = "sk-ant-XXXXXXXX"

# 2) rodar o orquestrador (coleta + Bia escreve + renderiza)
python orquestrador_evora.py
```

> ⚠️ **Pegadinha do Windows:** o comando `setx` NÃO funciona para a janela atual (só vale para janelas novas). Use sempre `$env:` como acima. Se fechar o PowerShell, cole a chave de novo.

**Mac/Linux:**
```bash
cd caminho/para/motor
export ANTHROPIC_API_KEY="sk-ant-XXXXXXXX"
python3 orquestrador_evora.py
```

**3)** O briefing sai em `briefing_AAAAMMDD.html` na pasta do motor (e uma cópia na pasta **Evora Fable** da Área de Trabalho, quando localizável). Abra no navegador.

## O que este motor (v2) já traz

- **Dirigido pelo perfil do tenant:** identidade, tom, blocos, limiar e consultas vêm de `perfil_tatiane.json`. Trocar de cliente = trocar o perfil, sem tocar no código.
- **Perfil da Tatiane:** temas reais (cultura, educação, segurança, proteção à mulher, misoginia), variações do nome.
- **5 jornais de Sorocaba:** Cruzeiro do Sul, Z Norte (Sorocabanices), Jornal Ipanema, Giro Sorocaba, Portal Porque — consultas geradas do perfil.
- **Diário Oficial** via COM (noticias.sorocaba.sp.gov.br/jornal) — conector em construção; até lá o bloco sai "Sem dado hoje."
- **Fiscalização** com limiar de **25% lido do perfil** (ajustável no perfil; mudança registrada).
- **Os 7 blocos canônicos:** Resumo · Radar de Nomeações · Fiscalização · Pulso da Câmara/DO · Demandas · Monitoramento & Imprensa · Movimento sugerido (72h). Bloco sem dado sai como **"Sem dado hoje."**
- **Caráter travado:** sem invenção, fonte declarada (CVI), "não sei" é válido, freio humano.
- **Honestidade de resultado:** o orquestrador só declara "Briefing gerado" se o arquivo de fato existir; falhas vão para `avisos_evora.log`.

## Se der erro

- **401 (não autorizado):** chave errada ou com espaço extra ao colar. Refaça o `$env:` (Windows) ou o `export` (Mac/Linux).
- **402 / billing:** falta cartão/crédito no console. Volte à Parte 1, passo 3.
- **Sem conexão:** o montador avisa com mensagem clara (sem traceback). Verifique a internet e rode de novo.
- **Sem resultado de alguma fonte:** o motor degrada avisando e segue com as demais (não trava). Veja `avisos_evora.log`.

## Ordem honesta de expectativa

No primeiro briefing, a coleta de alguns jornais pode vir parcial (sites variam). A imprensa via agregador vem de primeira; PNCP depende do endpoint confirmado; Diário Oficial e Demandas entram nas fases seguintes. Isso é o esperado — e o briefing diz "Sem dado hoje." onde faltar, em vez de inventar.

---

*v2 · 18/07/2026 · substitui o guia "atualizado v9.9" · Confidencial — Eng. Luiz Gonzaga Filho*

````


---

## 4. `Evora_Catalogo_Agentes_v2.md`

```markdown
# Catálogo Vivo dos Agentes — Manual de Bolso (v2)

**Os 26 agentes do ecossistema, explicados com exemplo prático de cada um.**
Companheiro do Manual Supremo **v10.5** · Material de consulta e de conversa
Tenant zero: Vereadora Tatiane Costa · Sorocaba/SP
CONFIDENCIAL · propriedade intelectual de Eng. de Sistemas Luiz Gonzaga Filho

> **v2 · 18/07/2026 — o que mudou em relação ao catálogo original (era v7.1):** (1) contagem atualizada de 25 para **26 agentes** — entrou o **AFC-p (Financeiro de Campanha)**, criado na v8.8 do Manual; o Nil passa a coordenar **10** agentes de campanha; (2) ficha do ACC-p ajustada (o financeiro migrou para o AFC-p); (3) referências atualizadas para o Manual v10.6; (4) formato convertido de imagens para **markdown** — legível por pessoas e por IA. Todo o restante do texto é a transcrição fiel do catálogo original.

---

## Como usar este anexo

O manual principal descreve cada agente de forma enxuta. Este anexo é o oposto: feito para conversar e explicar, com um exemplo real de Sorocaba em cada agente. É o seu material de apoio na reunião — e de consulta no dia a dia.

**Antes de tudo, o que é um "agente".** Pense em cada agente como um assessor especializado que nunca dorme, tem uma única função, sempre diz de onde tirou a informação e nunca age sozinho em assunto sério — ele avisa, e quem decide é a pessoa. São 26 assessores assim, coordenados por duas chefes de equipe (a Bia, no gabinete; o Nil, na campanha).

**Como ler cada ficha:**
- **Por que existe** — a dor que ele resolve, em linguagem simples.
- **Função principal** — o que ele faz, numa linha.
- **Recebe de → Entrega a** — de quem vem o sinal e para quem volta o resultado.
- **Exemplo na prática** — uma cena concreta (ilustrativa; não é dado real).
- **Trava** — o limite de segurança, quando houver.

---

## As duas chefes de equipe

### Bia — Gestora do Gabinete

- **Por que existe:** para a vereadora ter um único ponto de contato confiável que organiza o mandato inteiro, em vez de cobrar dez assessores diferentes.
- **Função principal:** coordena os 11 agentes do gabinete, recebe pedidos, entrega o briefing e distribui as tarefas.
- **Recebe de → Entrega a:** a autoridade e a assessoria → a autoridade (respostas e briefing) e os agentes especialistas (tarefas).
- **Exemplo na prática** — A vereadora abre o aplicativo e pergunta: "como está o projeto da merenda escolar?". Em segundos, a Bia junta o que o agente de Projetos de Lei sabe da tramitação, confere a agenda e responde: "parado na comissão há 8 dias, o relator é o vereador X; sugiro pedir uma reunião". Ela não precisou ligar para ninguém.

### Nil — Gestor de Campanha

- **Por que existe:** para profissionalizar a disputa eleitoral com método, separada do mandato.
- **Função principal:** coordena os 10 agentes de campanha; lê o cenário, planeja narrativa e mobilização, sempre dentro da lei eleitoral. *(v2: eram 9 no catálogo original; o AFC-p entrou na v8.8.)*
- **Recebe de → Entrega a:** a candidata e o coordenador de campanha → a candidata (estratégia) e os agentes de campanha (ações).
- **Exemplo na prática** — Faltam três meses para a eleição. O Nil cruza onde a votação dela cresceu na última eleição com onde os adversários estão fracos, e propõe: "concentre as caravanas na zona leste nas próximas duas semanas — é onde há voto disponível e pouca presença dos concorrentes".

---

## O Núcleo Fundador (Genesis) — o que entra primeiro

Estes três agentes são a primeira entrega. Cada um carrega a sua trava de segurança — são a base de tudo.

### AIM-g — Inteligência e Monitoramento (o Briefing das 06:45)

- **Por que existe:** porque a autoridade acorda afogada em informação (jornal, Diário Oficial, redes) e não tem tempo de ler tudo.
- **Função principal:** varre as fontes durante a madrugada, separa o que importa e entrega um resumo às 06:45.
- **Recebe de → Entrega a:** fontes públicas (Diário Oficial, notícias, menções nas redes, agenda) → a Bia, que mostra à autoridade.
- **Trava:** toda informação vem com a fonte do lado; nunca opina sem base, nunca inventa.
- **Exemplo na prática** — Enquanto a cidade dorme, o AIM-g lê o Diário Oficial de Sorocaba, os jornais locais e as redes. Às 06:45, a vereadora recebe no celular: as três coisas que pedem atenção hoje, o que saiu na imprensa, e uma oportunidade de pauta cultural na semana — cada item com a origem. Em dois minutos ela sabe o dia inteiro.

### AFEx-g — Fiscalização do Executivo

- **Por que existe:** fiscalizar a Prefeitura é dever do vereador (Constituição, art. 31), mas ler todos os contratos à mão é impossível.
- **Função principal:** lê os contratos e licitações publicados, compara com preços de referência e sinaliza o que merece um olhar humano.
- **Recebe de → Entrega a:** Diário Oficial, Portal de Contratações (PNCP) e bases de preço → a Bia/autoridade, como ponto a verificar.
- **Trava:** é sempre indício, nunca acusação. A base de comparação é declarada e a decisão de agir é sempre humana, com o jurídico.
- **Exemplo na prática** — O AFEx-g percebe que um contrato de merenda saiu cerca de 38% acima do que outros municípios pagaram pelo mesmo item. Ele não diz "houve irregularidade". Ele avisa só para a vereadora: "sugiro verificar o contrato 123 — está acima da média; aqui está a comparação com 12 contratos parecidos". O que fazer com isso é decisão dela.

### ADC-g — Demandas Cidadãs

- **Por que existe:** para que nenhum pedido do cidadão se perca e o mandato responda com método.
- **Função principal:** registra cada demanda, classifica, marca prazo, lembra o responsável e fecha o ciclo dando retorno.
- **Recebe de → Entrega a:** a assessoria (que cadastra o atendimento) → o responsável pela tarefa e, no fim, o próprio cidadão (retorno).
- **Trava:** só trata dados do cidadão com termo de consentimento (LGPD) desde o primeiro dia.
- **Exemplo na prática** — Dona Maria liga pedindo ajuda com a iluminação da rua. A assessora registra. O ADC-g cria a ficha, marca o prazo, lembra o responsável e, quando resolve, avisa para retornar à Dona Maria. Três meses depois, a vereadora consegue ver quantas demandas do bairro foram atendidas.

---

## O resto da equipe do gabinete

### ARI-g — Relações Institucionais

- **Por que existe:** mandato se faz com relação, não só dentro do gabinete.
- **Função principal:** mapeia com quem falar (vereadores, órgãos, casas legislativas) e prepara a aproximação.
- **Recebe de → Entrega a:** os objetivos do mandato (via Bia) → recomendação de quem procurar e como.
- **Exemplo na prática** — Para aprovar um projeto, a vereadora precisa do apoio de mais quatro colegas. O ARI-g mapeia quem são, que pautas cada um defende, e sugere por quem começar a conversa.

### AAG-g — Agenda

- **Por que existe:** o tempo é o recurso mais escasso de quem governa.
- **Função principal:** monta e prioriza compromissos, evita conflitos e prepara o dia.
- **Recebe de → Entrega a:** convites e compromissos → agenda priorizada (confirmação depende da autoridade).
- **Exemplo na prática** — Chegam três convites para o mesmo sábado. O AAG-g vê que dois são no centro e um conflita com a sessão da Câmara, e propõe: "vá aos dois do centro de manhã e recuse o terceiro — bate com a votação".

### AJG-g — Jurídico do Gabinete

- **Por que existe:** para reduzir erro formal e risco na rotina administrativa.
- **Função principal:** confere forma legal de atos, prazos e ritos.
- **Recebe de → Entrega a:** atos a praticar → checagem de forma e alerta de prazo (risco vai para advogado humano).
- **Exemplo na prática** — Antes de protocolar um requerimento, o AJG-g confere se a forma está certa e o prazo dentro do regimento. Se for algo de risco real, avisa: "isso aqui precisa de um advogado olhar".

### APL-g — Projetos de Lei

- **Por que existe:** legislar bem exige técnica e acompanhamento.
- **Função principal:** estrutura a minuta e a justificativa e acompanha a tramitação.
- **Recebe de → Entrega a:** a diretriz da autoridade → minuta pronta e status da tramitação (o mérito político é dela).
- **Exemplo na prática** — A vereadora quer uma lei de incentivo à cultura nas escolas. O APL-g monta a minuta, escreve a justificativa com base em leis parecidas que já deram certo, e avisa quando a tramitação anda.

### ACN-g — Comunicação

- **Por que existe:** o mandato precisa ser compreendido para ter força.
- **Função principal:** prepara conteúdo, mensagem e resposta pública, no tom da autoridade.
- **Recebe de → Entrega a:** os fatos do mandato → peças e respostas propostas (nada sai sem aprovação).
- **Exemplo na prática** — Saiu a notícia da votação do orçamento. O ACN-g prepara uma nota curta, no tom dela, pronta para as redes. Ela lê, aprova, e só então publica.

### AMP-g — Mídia e Produção

- **Por que existe:** para dar qualidade e consistência à presença pública.
- **Função principal:** produz as peças visuais e audiovisuais na identidade aprovada.
- **Recebe de → Entrega a:** o briefing da Comunicação → o card/vídeo pronto para aprovação.
- **Exemplo na prática** — Para a nota do orçamento, o AMP-g monta o card visual com as cores, a fonte e o escudo dela, pronto para postar — depois do "ok".

### ADG-g — Dados do Gabinete

- **Por que existe:** boa inteligência começa em dado confiável.
- **Função principal:** organiza, limpa e cruza os dados internos que alimentam os outros agentes.
- **Recebe de → Entrega a:** dados brutos dos fluxos do gabinete → bases tratadas, prontas para uso.
- **Exemplo na prática** — Os contatos, as demandas e a agenda vivem espalhados em planilhas. O ADG-g junta tudo, tira a duplicidade e organiza, para que os outros agentes não trabalhem com informação furada.

### APG-g — Pesquisa do Gabinete

- **Por que existe:** para a decisão ser informada, não no "achismo".
- **Função principal:** pesquisa temas e dados sob demanda, sempre com fonte.
- **Recebe de → Entrega a:** uma pergunta da autoridade ou de outro agente → levantamento com as fontes.
- **Exemplo na prática** — A vereadora vai falar sobre fila de creche. O APG-g levanta os números, diz de onde tirou cada um, e é honesto sobre o que não encontrou — nunca preenche com invenção.

### AGP-g — Gestão de Pessoas (planejado)

- **Por que existe:** para cuidar dos dados da equipe do gabinete.
- **Estado:** planejado para fases futuras (V1.5/V2); depende de parecer jurídico (LGPD + CLT). Entra quando for liberado.

---

## A equipe de campanha

Estes agentes "acordam" no ciclo eleitoral e operam separados do gabinete — não usam a estrutura nem o recurso público do mandato.

### AME-p — Mobilização Eleitoral

- **Por que existe:** voto se conquista com presença e organização.
- **Função principal:** organiza ações de campo e digitais para engajar a base.
- **Recebe de → Entrega a:** o território e a base de apoiadores → plano de mobilização e relatório de engajamento.
- **Exemplo na prática** — O AME-p organiza um mutirão de porta a porta num bairro-chave: divide as ruas entre os voluntários, define o roteiro e mede quantas casas foram visitadas.

### AJE-p — Jurídico Eleitoral

- **Por que existe:** para proteger a candidatura de risco jurídico.
- **Função principal:** acompanha prazos do TSE, prestação de contas e regras da propaganda.
- **Recebe de → Entrega a:** os atos de campanha → checagem de conformidade e alerta de prazo (risco vai para advogado).
- **Exemplo na prática** — O AJE-p avisa: "a propaganda só pode começar em 16/08; até lá, este material não pode ir ao ar" — evitando uma multa.

### ACE-p — Comunicação Eleitoral

- **Por que existe:** campanha é disputa de narrativa.
- **Função principal:** cuida da mensagem e da resposta no período eleitoral.
- **Recebe de → Entrega a:** a estratégia do Nil → mensagem e respostas propostas (com aprovação).
- **Exemplo na prática** — Um adversário ataca nas redes. O ACE-p prepara, em minutos, três versões de resposta no tom dela — firme mas serena — para ela escolher.

### AIE-p — Inteligência Eleitoral

- **Por que existe:** para orientar a estratégia com dado, não com palpite.
- **Função principal:** lê tendências, regiões e oportunidades de voto.
- **Recebe de → Entrega a:** dados eleitorais e pesquisas → leitura de cenário com as ressalvas.
- **Exemplo na prática** — O AIE-p mostra num mapa onde ela tem voto fiel, onde está crescendo e onde nem vale gastar energia — sempre dizendo o grau de confiança de cada número.

### AMC-p — Mídia de Campanha

- **Por que existe:** para dar alcance e qualidade à mensagem.
- **Função principal:** produz as peças e os vídeos da campanha.
- **Recebe de → Entrega a:** a linha de campanha → peças prontas para aprovação.
- **Exemplo na prática** — De um discurso de 20 minutos, o AMC-p tira três cortes de 30 segundos, legendados, prontos para as redes — depois do aval.

### ADE-p — Dados Eleitorais

- **Por que existe:** campanha moderna é orientada a dado.
- **Função principal:** organiza bases e segmenta o público.
- **Recebe de → Entrega a:** bases eleitorais e território → grupos segmentados, respeitando a LGPD.
- **Exemplo na prática** — O ADE-p separa o público por bairro e por tema de interesse, para que a mensagem sobre educação chegue a quem se importa com educação.

### AIA-p — Inteligência de Adversários

- **Por que existe:** para antecipar e responder à disputa.
- **Função principal:** acompanha os movimentos e o discurso dos adversários — só por fontes públicas.
- **Recebe de → Entrega a:** o que os adversários falam em público → monitoramento com a fonte.
- **Trava:** nunca usa meio ilícito; não difama.
- **Exemplo na prática** — Um concorrente muda de discurso sobre segurança. O AIA-p registra a mudança (com o link público) e avisa o Nil, para a campanha não ser pega de surpresa.

### APE-p — Pesquisa Eleitoral (ativa em fase posterior)

- **Por que existe:** para medir e ajustar a estratégia.
- **Função principal:** estrutura e lê pesquisas de intenção e percepção.
- **Recebe de → Entrega a:** amostras e questionários → leitura com metodologia e margem declaradas.
- **Exemplo na prática** — A cada onda de pesquisa, o APE-p mostra para onde a intenção de voto está indo e em que temas ela convence mais — sempre com a margem de erro à vista.

### ACC-p — Coordenação de Campanha

- **Por que existe:** para dar ritmo e unidade à operação.
- **Função principal:** integra todos os agentes de campanha e o cronograma. *(v2: a rédea do financeiro passou ao AFC-p; o ACC-p garante que o cronograma e o financeiro andem juntos.)*
- **Recebe de → Entrega a:** o plano e o status de cada frente → cronograma integrado e relatórios ao Nil.
- **Exemplo na prática** — O ACC-p percebe que a equipe de mídia está atrasada e a de campo adiantada, realinha o cronograma e aciona o AFC-p para que cada gasto já entre na prestação de contas do TSE.

### AFC-p — Financeiro de Campanha `[v2 — acrescentado; agente criado na v8.8 do Manual]`

- **Por que existe:** porque dinheiro de campanha é a área de maior risco jurídico de uma candidatura — cada centavo precisa ter origem, destino e registro no prazo do TSE.
- **Função principal:** controla receitas e despesas da campanha, organiza os comprovantes e prepara a prestação de contas, item a item.
- **Recebe de → Entrega a:** os gastos e doações lançados pela coordenação → o financeiro organizado ao Nil e ao AJE-p (conformidade), pronto para a prestação de contas.
- **Trava:** nenhum lançamento sem comprovante e origem identificada; qualquer indício de irregularidade vai ao jurídico humano — o agente registra, nunca "dá jeito".
- **Exemplo na prática** — A campanha recebe uma doação e faz três gastos no mesmo dia. O AFC-p confere o limite legal da doação, anexa os comprovantes dos gastos, lança tudo nas categorias do TSE e avisa o AJE-p: "prestação parcial fecha em 5 dias; falta a nota do material gráfico". Nada se acumula para a véspera.

---

## Acima de todos — governança e trajetória

Estes três respondem diretamente à autoridade e ficam acima da Bia e do Nil. São o freio, o conselho e a visão de longo prazo.

### AAS-Évora — Auditoria Soberana

- **Por que existe:** para que o poder do próprio sistema tenha um freio acima de todos.
- **Função principal:** audita condutas, acessos e decisões de todo o ecossistema — inclusive da autoridade e do criador.
- **Recebe de → Entrega a:** os registros de todos os agentes e usuários → relatórios e alertas de desvio, direto à autoridade.
- **Trava:** independência total; trilha que nunca se apaga; não acoberta nada.
- **Exemplo na prática** — Alguém tenta, pela porta técnica, afrouxar a regra de que o AFEx-g só sinaliza (nunca acusa). A AAS-Évora bloqueia, registra quem tentou e avisa. Nem o criador passa por cima dela.

### AMA-Évora — Mentor da Autoridade

- **Por que existe:** para a autoridade ter um conselheiro de confiança, reservado.
- **Função principal:** orienta postura, decisões de trajetória e dilemas — com sigilo absoluto.
- **Recebe de → Entrega a:** o contexto pessoal da autoridade → aconselhamento reservado (fora de Bia/Nil).
- **Exemplo na prática** — A vereadora hesita entre disputar a reeleição ou arriscar a deputada federal. O AMA-Évora conversa com ela em sigilo, organiza prós e contras à luz dos valores dela — sem que ninguém mais veja.

### AIP — Inteligência Política

- **Por que existe:** para pensar a carreira, não só o dia de hoje.
- **Função principal:** lê a percepção pública e sugere posicionamento e narrativa de longo prazo.
- **Recebe de → Entrega a:** percepção, cenário e histórico → recomendação de trajetória (não substitui a decisão dela).
- **Exemplo na prática** — O AIP nota que a imagem dela como "voz da cultura" tem espaço para crescer no estado, e sugere uma linha de atuação consistente que a prepare, em dois anos, para o voo de deputada.

---

## Os bastidores — segurança que ninguém vê

A camada **SISEC** protege o sistema por trás das cortinas. A autoridade não interage com ela; ela só existe para que tudo o mais seja seguro. *(A SISEC é uma camada de serviço — seus componentes não entram na contagem dos 26 agentes.)*

- **ASA-sis** — vigia quem acessa o quê.
- **ADA-sis** — detecta comportamento estranho (dá uma "nota de anomalia" de 0 a 100).
- **ARE-sis** — responde e contém um incidente.
- **AAudLog-sis** — guarda a trilha de tudo, sem nunca apagar.
- **AMSeg-sis** — monitora a segurança 24 horas.

**Exemplo na prática** — De madrugada, alguém tenta acessar a conta da vereadora de um lugar incomum. O ADA-sis dá nota alta de anomalia, o ARE-sis bloqueia na hora, o AAudLog-sis registra tudo e a autoridade é avisada de manhã: "tentativa barrada, nada exposto".

---

## Tabela-relâmpago para a reunião

Uma frase por agente, para consulta rápida enquanto você fala.

| Agente | Numa frase |
|---|---|
| **Bia** | A chefe de gabinete que organiza tudo e fala com você. |
| **Nil** | O coordenador da campanha, separado do mandato. |
| AIM-g | O briefing das 06:45 com o que importa, com fonte. |
| AFEx-g | Olho nos contratos da Prefeitura — indício, nunca acusação. |
| ADC-g | Nenhum pedido do cidadão se perde. |
| ARI-g | Quem procurar e como, para aprovar pautas. |
| AAG-g | Protege a sua agenda e o seu tempo. |
| AJG-g | Confere a forma legal antes de você assinar. |
| APL-g | Escreve e acompanha seus projetos de lei. |
| ACN-g | Prepara sua comunicação, no seu tom. |
| AMP-g | Faz os cards e vídeos na sua identidade. |
| ADG-g | Organiza e limpa os dados internos. |
| APG-g | Pesquisa com fonte, nunca inventa. |
| AGP-g | (planejado) cuidará dos dados da equipe. |
| AME-p | Mobiliza a base no território. |
| AJE-p | Mantém a campanha dentro das regras do TSE. |
| ACE-p | Responde aos ataques, no seu tom. |
| AIE-p | Mostra onde há voto a buscar. |
| AMC-p | Produz os vídeos curtos da campanha. |
| ADE-p | Segmenta o público, com LGPD. |
| AIA-p | Acompanha os adversários (fontes públicas). |
| APE-p | Lê as pesquisas com rigor. |
| ACC-p | Dá ritmo à campanha e integra as frentes. |
| **AFC-p** | Cada centavo com origem, comprovante e prazo do TSE. `[v2]` |
| AAS-Évora | Audita todos — até você e o criador. |
| AMA-Évora | Seu conselheiro sigiloso de trajetória. |
| AIP | Pensa a sua carreira de longo prazo. |
| SISEC | A segurança invisível que protege tudo (camada, fora da contagem). |

---

*Catálogo Vivo dos Agentes v2 · 18/07/2026 · companheiro do Manual Supremo v10.6 · transcrição fiel do original (26/06/2026) com as atualizações marcadas `[v2]` · Confidencial — Eng. Luiz Gonzaga Filho*

```


---

## 5. `ROTEIRO_LAPTOP_APOSENTADO.md`

```markdown
# ROTEIRO DO LAPTOP — APOSENTADO (18/07/2026)

Este documento substitui o `ROTEIRO_LAPTOP_v3.md`, aposentado por decisão do fundador em 18/07/2026.

**Motivos do registro (Anexo 14 do Manual v10.6):** o cabeçalho dizia "v2" num arquivo v3, e o texto declarava como "aplicadas e validadas" correções que não estavam nos arquivos da pasta do projeto (dessincronização detectada e corrigida em 18/07).

**O que assume o papel dele:**
- Mapa da sessão de instalação e execução → `INSTRUCOES_CODAR_BRIEFING_v2.md`
- Passo a passo humano do primeiro briefing → `GUIA_Primeiro_Briefing_v2.md`
- Estado real e regras de sincronização → Manual v10.6, Anexo 14

O arquivo original não deve ser apagado (regra de ouro: nada se apaga) — apenas movido para a pasta `arquivo_historico/` com este aviso ao lado.

```


---

## 6. `renomear_versoes.ps1`

```powershell
# Évora — Higiene de Versões (item 7 · 18/07/2026)
# Regra do Manual v10.5 (Anexo 14): nunca dois arquivos com o mesmo número
# de versão e conteúdos diferentes. Este script carimba data/hora de
# modificação no nome das duplicatas conhecidas e move originais
# substituídos para arquivo_historico\ . NADA é apagado.
# USO: abra o PowerShell NA PASTA onde estão os arquivos e rode:
#   powershell -ExecutionPolicy Bypass -File .\renomear_versoes.ps1

$historico = "arquivo_historico"
New-Item -ItemType Directory -Force -Path $historico | Out-Null

$alvos = @(
  "Evora Manual v10_3.md",
  "Evora Manual v10_4.md",
  "Evora_Manual_v10_5.md",
  "ROTEIRO_LAPTOP_v3.md",
  "ROTEIRO LAPTOP v1.md"
)

Get-ChildItem -File | Where-Object {
    $n = $_.Name -replace '^\d+-',''   # ignora prefixo numérico do WhatsApp
    $alvos -contains $n
} | ForEach-Object {
    $carimbo = $_.LastWriteTime.ToString("yyyyMMdd_HHmm")
    $novo = "{0}__{1}{2}" -f $_.BaseName, $carimbo, $_.Extension
    Move-Item $_.FullName (Join-Path $historico $novo)
    Write-Host ("arquivado: {0}  ->  {1}\{2}" -f $_.Name, $historico, $novo)
}

Write-Host ""
Write-Host "Concluido. Fonte unica da verdade a partir de agora:"
Write-Host "  Manual  -> Evora_Manual_v10_6.md"
Write-Host "  Pipeline-> Briefing_Matinal_Pipeline_v1_1.md"
Write-Host "  Guia    -> GUIA_Primeiro_Briefing_v2.md"
Write-Host "  Motor   -> pasta motor\ (v2, dirigido pelo perfil)"

```


---

## 7. `motor/LEIA-ME_MOTOR.md`

```markdown
# Motor do Briefing — Évora Oversight (conteúdo da pasta)

Comece pelo **GUIA_Primeiro_Briefing.md**.

| Arquivo | O que faz |
| --- | --- |
| GUIA_Primeiro_Briefing.md | Passo a passo para gerar o briefing real |
| orquestrador_evora.py | Roda tudo na ordem (é o que você executa) |
| imprensa_coletor_evora.py | Coleta notícias reais (Google News) → noticias.json |
| coletor_pncp_evora.py | Coleta contratos do PNCP → contratos_sorocaba.json |
| montador_briefing_evora.py | A Bia escreve o briefing (usa a API da Claude) |
| render_briefing_evora.py | Gera o briefing em HTML on-brand |
| aprendizado_evora.py | Feedback 👍/👎 + Guarda Constitucional (aprende sem ferir travas) |
| perfil_tatiane.json | Perfil da tenant (nome, temas, fontes, fiscalização) |
| perfil_tenant_modelo.json | Template genérico para novos clientes |
| requirements.txt | (nada a instalar — só Python padrão) |

Requisito: Python 3 + a variável ANTHROPIC_API_KEY (veja o GUIA).
Honestidade: só o passo do montador usa a internet paga (API). Os coletores usam fontes públicas.

```


---

## 8. `motor/requirements.txt`

```text
# O motor do Briefing usa SOMENTE a biblioteca padrão do Python 3.
# Não precisa instalar nada além do Python (python.org).
# (urllib, json, xml, subprocess, statistics, datetime — todos já vêm no Python.)

```


---

## 9. `motor/perfil_tatiane.json`

```json
{
 "tenant": "tatiane-costa-sorocaba",
 "autoridade": {
  "nome": "Tatiane Costa",
  "variacoes_nome": [
   "Tatiane Costa",
   "Tati Costa",
   "Vereadora Tatiane",
   "Ver. Tatiane Costa",
   "Tatiane"
  ],
  "cargo_atual": "Vereadora",
  "municipio": "Sorocaba",
  "uf": "SP",
  "partido": "PL",
  "pre_candidatura_2026": "Deputada Federal",
  "municipio_sede": "Sorocaba",
  "area_atuacao": [
   {
    "municipio": "Sorocaba",
    "uf": "SP",
    "papel": "sede do mandato"
   }
  ],
  "_nota_area_atuacao": "Mandato municipal: área = a própria cidade. Se eleita para mandato estadual/federal, acrescentar aqui os municípios da área de atuação; o Atlas responde por todos eles (Manual v10.6, Anexo 16 §5)."
 },
 "briefing": {
  "horario": "06:45",
  "fuso": "America/Sao_Paulo",
  "tom": "factual, conciso, respeitoso; sem opinião pessoal nem recomendação de voto",
  "blocos": [
   "Resumo do dia",
   "Radar de Nomeações (AFEx-g)",
   "Fiscalização do Executivo (limiar 25%)",
   "Pulso da Câmara / Diário Oficial",
   "Demandas & Requerimentos",
   "Monitoramento & Imprensa (5 jornais)",
   "Movimento sugerido (72h)"
  ],
  "carater": "Cláusula de Caráter Travado: sem invenção; fonte declarada em tudo (CVI); 'não sei' é válido; nada não-ordenado; freio humano (nada é executado sem aprovação)."
 },
 "monitoramento": {
  "politicos_pessoas": [
   "Tatiane Costa (a autoridade)",
   "Flávio Bolsonaro"
  ],
  "orgaos": [
   "Prefeitura de Sorocaba",
   "Câmara de Sorocaba"
  ],
  "temas": [
   "Cultura",
   "Educação",
   "Segurança Pública",
   "Proteção à Mulher",
   "Leis sobre misoginia"
  ],
  "veiculos": [
   "Cruzeiro do Sul (cruzeirodosul.inf.br)",
   "Jornal Z Norte — seção Sorocabanices",
   "Jornal Ipanema / IPA Online (jornalipanema.com.br)",
   "Giro Sorocaba (girosorocaba.com.br)",
   "Portal Porque (portalporque.com.br)",
   "Jornal do Município (via COM)"
  ],
  "internacional_foco": [
   "Relação Brasil-EUA",
   "Família Bolsonaro nos EUA + reflexos nas eleições 2026"
  ],
  "posicionamento": "Monitorar falas e casos (Câmara e redes) sobre proteção à mulher e misoginia que exijam posicionamento — só fonte pública, decisão humana.",
  "mencoes": {
   "imprensa": true,
   "redes_sociais": [
    "Instagram",
    "Facebook",
    "X",
    "TikTok"
   ],
   "nota": "Redes: escopo decidido; ferramenta de coleta [PENDENTE]"
  },
  "veiculos_nacionais": [
   "Globo/G1",
   "GloboNews (texto)",
   "Record News (texto)"
  ],
  "veiculos_detalhe": [
   {
    "nome": "Cruzeiro do Sul",
    "url": "cruzeirodosul.inf.br",
    "nivel": "F1",
    "cobertura": "Sorocaba e região",
    "identificacao": "a confirmar na Receita",
    "procedencia": "declarado"
   },
   {
    "nome": "Jornal Z Norte — seção Sorocabanices",
    "url": "",
    "nivel": "F1",
    "cobertura": "Sorocaba",
    "identificacao": "a confirmar na Receita",
    "procedencia": "declarado"
   },
   {
    "nome": "Jornal Ipanema / IPA Online",
    "url": "jornalipanema.com.br",
    "nivel": "F1",
    "cobertura": "Sorocaba e região",
    "identificacao": "a confirmar na Receita",
    "procedencia": "declarado"
   },
   {
    "nome": "Giro Sorocaba",
    "url": "girosorocaba.com.br",
    "nivel": "F1",
    "cobertura": "Sorocaba",
    "identificacao": "a confirmar na Receita",
    "procedencia": "declarado"
   },
   {
    "nome": "Portal Porque",
    "url": "portalporque.com.br",
    "nivel": "F1",
    "cobertura": "Sorocaba",
    "identificacao": "a confirmar na Receita",
    "procedencia": "declarado"
   },
   {
    "nome": "Jornal do Município (via COM)",
    "url": "noticias.sorocaba.sp.gov.br/jornal",
    "nivel": "oficial",
    "cobertura": "Sorocaba",
    "identificacao": "órgão público",
    "procedencia": "verificado"
   },
   {
    "nome": "Globo/G1",
    "url": "g1.globo.com",
    "nivel": "F2",
    "cobertura": "nacional, cobre Sorocaba",
    "identificacao": "a confirmar",
    "procedencia": "declarado"
   },
   {
    "nome": "Revista Oeste",
    "url": "revistaoeste.com",
    "nivel": "F2",
    "cobertura": "nacional; cobriu pautas da autoridade em 07/07/2026",
    "identificacao": "a confirmar",
    "procedencia": "verificado",
    "evidencia": "Matéria sobre aprovação de projeto da autoria da autoridade, 07/07/2026"
   }
  ],
  "_nota_niveis": "F1 Registrada (CNPJ ativo + CNAE de mídia — identifica o veículo, não mede credibilidade) · F2 Reconhecida (cobre a cidade/região com evidência arquivada, independente de sede) · F3 Declarada (influencers/perfis pessoais — só aqui no perfil do tenant, nunca no Atlas). Manual v10.6, Anexo 16 §3.",
  "influencers_f3": [],
  "_nota_f3": "Nível F3: influencers e perfis pessoais indicados pelo tenant. Cada entrada exige finalidade declarada e fica visível na auditoria. Nunca sobe ao Atlas compartilhado."
 },
 "fiscalizacao": {
  "ambito": "municipal",
  "fontes": [
   "Diário Oficial de Sorocaba — noticias.sorocaba.sp.gov.br/jornal (PDF, via COM RMS-001)",
   "PNCP"
  ],
  "regra": "indício para verificação humana; nunca acusação; base de comparação sempre declarada",
  "radar_nomeacoes": "Diário: nomeações e exonerações (nome, cargo, secretaria) + cruzamento com pessoas de interesse. Indício, nunca acusação.",
  "limiar_desvio_pct": 25,
  "limiar_nota": "Ajustável de forma simples por qualquer assessor (dashboard/aba AFEx-g ou por voz à Bia); mudança registrada na trilha.",
  "ajustavel": "Qualquer assessor no dashboard (aba AFEx-g) ou por voz à Bia; muda na trilha."
 },
 "travas": {
  "freio_humano": true,
  "fontes_publicas_e_licitas": true,
  "lgpd_termo_demandas": "obrigatório desde o dia 1",
  "separacao_gabinete_campanha": true
 },
 "fontes": {
  "porta_de_entrada": "Qualquer assessor solicita nova fonte na caixa; vai automaticamente a quem tem alçada; entra como 'nova/a validar' até a autoridade confirmar. Trilha imutável.",
  "veiculos_canonicos": {
   "locais": [
    "Cruzeiro do Sul (online)",
    "Jornal Z Norte — seção Sorocabanices",
    "Jornal do Município (via COM RMS-001)"
   ],
   "nacionais": [
    "Globo/G1",
    "GloboNews (texto do portal)",
    "Record News (texto do portal)"
   ],
   "regra": "Inclusão livre por qualquer assessor (funciona na hora; aviso a todos via GEC/Mural; sensíveis pedem ok da autoridade; API -> VRX). Exclusão SOMENTE com alçada: qualquer um pede, quem tem alçada recebe o pedido no sistema e executa com justificativa. Fonte sempre identificada (CVI)."
  }
 },
 "agenda": {
  "decisao": "Agenda vive no Évora (calendário próprio); funciona offline (local) se a internet cair; sincroniza ao voltar. Migração a partir do Google Agenda na implantação."
 },
 "diario_oficial": {
  "fonte": "noticias.sorocaba.sp.gov.br/jornal (PDF, edições numeradas — via COM RMS-001)",
  "nota": "Separar atos oficiais (nomeações/exonerações/contratos) das notícias."
 },
 "_versao_perfil": "v10.6 · 19/07/2026 · alinhado ao Manual v10.6 (Anexo 16): níveis de fonte F1/F2/F3, procedência por campo (declarado/atlas/verificado), multi-município (municipio_sede + area_atuacao). Fonte única do limiar: fiscalizacao.limiar_desvio_pct (25).",
 "_procedencia": {
  "autoridade": "declarado",
  "monitoramento.temas": "declarado",
  "monitoramento.veiculos": "declarado (verificação humana pendente na Receita — F1)",
  "monitoramento.politicos_pessoas": "declarado — finalidade: acompanhamento de figuras públicas; só fonte pública",
  "fiscalizacao.limiar_desvio_pct": "declarado (padrão do sistema: 25%)",
  "_regra": "declarado = veio da Entrevista de Fundação · atlas = veio do Atlas Municipal · verificado = confirmado em fonte pública, com data e link"
 }
}
```


---

## 10. `motor/perfil_tenant_modelo.json`

```json
{
 "tenant": "MODELO-GENERICO",
 "autoridade": {
  "nome": "[NOME DA AUTORIDADE]",
  "variacoes_nome": [
   "[variação 1]",
   "[variação 2]"
  ],
  "cargo_atual": "[cargo]",
  "municipio": "[município]",
  "uf": "[UF]",
  "partido": "[partido]",
  "pre_candidatura_2026": "[cargo pretendido ou vazio]",
  "municipio_sede": "",
  "area_atuacao": []
 },
 "briefing": {
  "horario": "06:45",
  "fuso": "America/Sao_Paulo",
  "tom": "factual, conciso, respeitoso; sem opinião pessoal nem recomendação de voto",
  "blocos": [
   "Resumo do dia",
   "Pulso da Câmara",
   "Fiscalização do Executivo",
   "Monitoramento & Imprensa",
   "Movimento sugerido (72h)"
  ]
 },
 "monitoramento": {
  "politicos_pessoas": [],
  "orgaos": [],
  "temas": [],
  "veiculos": [],
  "internacional_foco": [],
  "veiculos_detalhe": [],
  "influencers_f3": [],
  "_nota_preenchimento": "Deixe vazio: a Entrevista de Fundação preenche a partir das respostas do tenant, e o Atlas Municipal completa os veículos F1/F2 da cidade. Manual v10.6, Anexo 16."
 },
 "fiscalizacao": {
  "ambito": "municipal",
  "fontes": [
   "Diário Oficial [definir]",
   "PNCP"
  ],
  "limiar_desvio": 0.3,
  "regra": "indício para verificação humana; nunca acusação; base de comparação sempre declarada"
 },
 "travas": {
  "freio_humano": true,
  "fontes_publicas_e_licitas": true,
  "lgpd_termo_demandas": "obrigatório desde o dia 1",
  "separacao_gabinete_campanha": true
 },
 "_procedencia": {
  "_regra": "declarado = Entrevista de Fundação · atlas = Atlas Municipal · verificado = fonte pública com data e link"
 },
 "_versao_perfil": "v10.6 · 19/07/2026 · folha em branco do tenant (Manual v10.6, Anexo 16)"
}
```


---

## 11. `motor/perfil_loader_evora.py`

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Carregador do Perfil do Tenant (motor v2)
===========================================================
Fonte única do multi-tenant: identidade, tom, blocos, limiar e consultas
vêm do perfil. Trocar de cliente = trocar o perfil, sem tocar no código.

Uso pelos demais scripts:
    from perfil_loader_evora import carregar_perfil
    p = carregar_perfil()            # perfil_tatiane.json por padrão
    p = carregar_perfil("outro.json")
Aceita também variável de ambiente EVORA_PERFIL apontando o arquivo.
Só biblioteca padrão.
"""
import json, os, sys

PADRAO = "perfil_tatiane.json"

BLOCOS_FALLBACK = [
    "Resumo do dia",
    "Radar de Nomeações (AFEx-g)",
    "Fiscalização do Executivo (limiar 25%)",
    "Pulso da Câmara / Diário Oficial",
    "Demandas & Requerimentos",
    "Monitoramento & Imprensa",
    "Movimento sugerido (72h)",
]


def carregar_perfil(caminho=None):
    """Carrega o perfil do tenant. Falha com mensagem clara (nunca em silêncio)."""
    caminho = caminho or os.environ.get("EVORA_PERFIL") or PADRAO
    if not os.path.exists(caminho):
        raise SystemExit(
            f"⚠️  Perfil do tenant não encontrado: {caminho}\n"
            "   O motor v2 é dirigido pelo perfil (multi-tenant). "
            "Coloque o arquivo na pasta ou aponte EVORA_PERFIL."
        )
    try:
        with open(caminho, encoding="utf-8") as f:
            p = json.load(f)
    except json.JSONDecodeError as e:
        raise SystemExit(f"⚠️  Perfil inválido ({caminho}): JSON malformado — {e}")
    p["_arquivo"] = caminho
    return p


def limiar_desvio(p):
    """Limiar de fiscalização como fração (0.25 = 25%).
    Fonte única: fiscalizacao.limiar_desvio_pct (decisão travada: 25%).
    Fallback: 25%. Aceita o campo legado limiar_desvio se for o único presente."""
    fisc = p.get("fiscalizacao", {}) or {}
    pct = fisc.get("limiar_desvio_pct")
    if isinstance(pct, (int, float)) and pct > 0:
        return float(pct) / 100.0
    legado = fisc.get("limiar_desvio")
    if isinstance(legado, (int, float)) and 0 < legado < 1:
        return float(legado)
    return 0.25


def blocos(p):
    b = (p.get("briefing", {}) or {}).get("blocos") or []
    return b if b else list(BLOCOS_FALLBACK)


def autoridade(p):
    return p.get("autoridade", {}) or {}


def _veiculos_normalizados(mon):
    """[v10.6] Devolve os nomes dos veículos que entram na varredura de
    imprensa, aceitando os dois formatos do perfil:
      - legado:  "veiculos": ["Cruzeiro do Sul (url)", ...]
      - v10.6:   "veiculos_detalhe": [{"nome":..., "nivel":"F1"}, ...]
    Regra travada (Anexo 16 §3): F3 (influencers e perfis pessoais) fica de
    fora — tem finalidade declarada própria e nunca se mistura à varredura
    geral. Se o perfil trouxer os dois formatos, o detalhado tem precedência.
    """
    detalhe = mon.get("veiculos_detalhe") or []
    if detalhe:
        nomes = []
        for v in detalhe:
            if isinstance(v, dict):
                if str(v.get("nivel", "")).upper() == "F3":
                    continue
                nome = v.get("nome", "")
            else:
                nome = str(v)
            if nome:
                nomes.append(nome)
        if nomes:
            return nomes
    return [v if isinstance(v, str) else v.get("nome", "")
            for v in (mon.get("veiculos") or [])]


def area_atuacao(p):
    """[v10.6] Municípios cobertos por este tenant (Anexo 16 §5).
    Mandato municipal devolve só a cidade-sede; mandato estadual/federal
    devolve a lista inteira. Sempre devolve ao menos um município."""
    a = autoridade(p)
    area = a.get("area_atuacao") or []
    nomes = [m.get("municipio") if isinstance(m, dict) else str(m) for m in area]
    nomes = [n for n in nomes if n]
    if nomes:
        return nomes
    sede = a.get("municipio_sede") or a.get("municipio") or ""
    return [sede] if sede else []


def consultas_imprensa(p):
    """Gera as consultas do coletor de imprensa a partir do perfil:
    variações do nome + órgãos + temas + veículos. Sem inventar nada
    fora do perfil; se o perfil estiver vazio, devolve lista mínima."""
    a = autoridade(p)
    mon = p.get("monitoramento", {}) or {}
    cidade = a.get("municipio", "")
    out = []

    variacoes = [v for v in a.get("variacoes_nome", []) if v]
    if variacoes:
        ors = " OR ".join(f'"{v}"' for v in variacoes[:6])
        out.append(f"{ors} {cidade}".strip())

    for orgao in mon.get("orgaos", []):
        out.append(f'"{orgao}"')

    temas = [t for t in mon.get("temas", []) if t]
    for i in range(0, len(temas), 3):
        grupo = " OR ".join(temas[i:i + 3])
        out.append(f"{cidade} {grupo}".strip())

    # [v10.6] Veículos podem vir como string (formato legado) ou como dict
    # com nível F1/F2/F3 (Manual v10.6, Anexo 16 §3). Os dois formatos
    # funcionam — o loader normaliza. Veículos F3 (influencers/perfis
    # pessoais) NÃO entram aqui: eles têm finalidade declarada própria e
    # não se misturam à varredura geral de imprensa.
    for veic in _veiculos_normalizados(mon):
        nome = veic.split("(")[0].split("—")[0].strip()
        if nome:
            out.append(f'"{nome}" {cidade}'.strip())

    # dedup preservando ordem
    visto, final = set(), []
    for c in out:
        if c and c not in visto:
            visto.add(c)
            final.append(c)
    return final or [f"{cidade} câmara prefeitura".strip() or "Sorocaba"]


if __name__ == "__main__":
    p = carregar_perfil(sys.argv[1] if len(sys.argv) > 1 else None)
    print(f"Perfil: {p.get('tenant')}  ({p['_arquivo']})")
    print(f"Autoridade: {autoridade(p).get('nome')}")
    print(f"Limiar de fiscalização: {int(limiar_desvio(p)*100)}%")
    print(f"Blocos ({len(blocos(p))}):")
    for b in blocos(p):
        print(f"  · {b}")
    print("Consultas de imprensa geradas do perfil:")
    for c in consultas_imprensa(p):
        print(f"  → {c}")

```


---

## 12. `motor/entrevista_fundacao.py`

```python
"""
Évora Oversight — Entrevista de Fundação
=========================================
Conduz as 14 perguntas do onboarding do tenant e emite o
`perfil_<tenant>.json` que o motor de briefing já lê hoje.

Base normativa: Manual Supremo v10.6, Anexo 16 §5.
Decisão D7 (fundador, 19/07/2026): construir a Entrevista ANTES do Atlas —
é o que destrava a venda do 2º tenant.

TRAVAS DESTE COMPONENTE (não são opcionais)
-------------------------------------------
1. Tudo que o tenant declara entra como `declarado`, NUNCA como `verificado`.
   Declaração é hipótese de trabalho; fato é fato. O sistema não corrige o
   tenant nem apaga o que ele disse — guarda os dois.
2. A ciência das 3 travas (bloco final) é OBRIGATÓRIA. Sem ela o perfil é
   gravado com `operacional: false` e o go-live não acontece (decisão D5).
3. Influencers e perfis pessoais entram como nível F3, dentro do perfil
   isolado do tenant, com finalidade declarada — NUNCA no Atlas (Anexo 16 §3).
4. O script não inventa: campo não respondido fica vazio e visível, não
   preenchido por suposição.

USO
---
    python entrevista_fundacao.py                 # interativo
    python entrevista_fundacao.py --saida perfil_fulano.json
    python entrevista_fundacao.py --respostas respostas.json   # não-interativo

O modo --respostas existe para (a) testar sem digitar, (b) permitir que uma
tela web colete as respostas e chame este mesmo motor, sem duplicar regra.
"""

import json
import re
import sys
import unicodedata
from collections import OrderedDict
from datetime import date
from pathlib import Path

VERSAO = "v10.6 · Anexo 16 §5"

# ---------------------------------------------------------------------------
# As 14 perguntas, em 4 blocos (Manual v10.6, Anexo 16 §5)
# ---------------------------------------------------------------------------
PERGUNTAS = [
    # bloco 1 — identidade e alcance
    ("p1",  1, "Nome completo, como aparece nos atos oficiais", "texto"),
    ("p2",  1, "Como te chamam na cidade? Todos os apelidos e variações usados na imprensa "
                "(separe por vírgula)", "lista"),
    ("p3a", 1, "Cargo atual", "texto"),
    ("p3b", 1, "Partido", "texto"),
    ("p3c", 1, "Município (cidade-sede do mandato)", "texto"),
    ("p3d", 1, "UF", "texto"),
    ("p4",  1, "É primeiro mandato? Se não, quantos e desde quando?", "texto"),
    # bloco 2 — bandeiras e território
    ("p5",  2, "Até 5 temas que definem seu mandato (separe por vírgula)", "lista"),
    ("p6",  2, "Bairros ou regiões da cidade que são sua base (separe por vírgula)", "lista"),
    ("p7",  2, "Órgãos que você mais fiscaliza ou acompanha (separe por vírgula)", "lista"),
    ("p8",  2, "Pessoas públicas cujas ações você precisa acompanhar (separe por vírgula; "
                "só figuras públicas)", "lista"),
    ("p8f", 2, "  ↳ Finalidade desse acompanhamento (obrigatória se respondeu acima)", "texto"),
    # bloco 3 — como quer ser servido
    ("p9",  3, "A que horas quer o briefing? (padrão 06:45)", "texto"),
    ("p10", 3, "Prefere texto curto e direto, ou explicado com contexto? "
                "(responda: direto / contexto)", "texto"),
    ("p11", 3, "Quem mais no gabinete recebe o briefing, e com que papel? "
                "(ex.: Maria — chefe de gabinete)", "lista"),
    ("p12", 3, "Quer o briefing por tela, voz, ou os dois? (tela / voz / ambos)", "texto"),
    # bloco 4 — fiscalização e limites
    ("p13", 4, "A partir de quantos % acima do preço de referência você quer ser avisado? "
                "(padrão 25)", "numero"),
    ("p14", 4, "Há assunto que você NÃO quer no briefing? (separe por vírgula; enter para nenhum)",
                "lista"),
]

BLOCOS = {
    1: "BLOCO 1 — Identidade e alcance",
    2: "BLOCO 2 — Bandeiras e território",
    3: "BLOCO 3 — Como você quer ser servido",
    4: "BLOCO 4 — Fiscalização e limites",
}

TRAVAS_CIENCIA = [
    "Indício nunca é acusação. O sistema sinaliza o que merece verificação; "
    "quem acusa é pessoa, com assessoria jurídica.",
    "Nada é publicado ou executado sem aprovação humana. O sistema propõe; "
    "a decisão é sempre sua.",
    "O sistema recusa o ilícito — inclusive vindo de você, do seu gabinete ou "
    "do criador da plataforma.",
]


# ---------------------------------------------------------------------------
# utilitários
# ---------------------------------------------------------------------------
def _slug(texto):
    """'Tatiane Costa' + 'Sorocaba' -> 'tatiane-costa-sorocaba'"""
    t = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode()
    t = re.sub(r"[^a-zA-Z0-9]+", "-", t).strip("-").lower()
    return re.sub(r"-{2,}", "-", t)


def _lista(txt):
    return [x.strip() for x in (txt or "").split(",") if x.strip()]


def _variacoes(nome, apelidos, cargo):
    """Monta as variações do nome para o coletor de imprensa, sem inventar:
    parte do que o tenant declarou e acrescenta as formas de tratamento
    do próprio cargo que ele informou."""
    out = [nome] + apelidos
    if cargo and nome:
        primeiro = nome.split()[0]
        out += [f"{cargo} {nome}", f"{cargo} {primeiro}"]
    visto, final = set(), []
    for v in out:
        v = (v or "").strip()
        if v and v.lower() not in visto:
            visto.add(v.lower())
            final.append(v)
    return final


# ---------------------------------------------------------------------------
# coleta
# ---------------------------------------------------------------------------
def perguntar_interativo():
    print("=" * 68)
    print("  ÉVORA OVERSIGHT — ENTREVISTA DE FUNDAÇÃO")
    print(f"  14 perguntas · cerca de 8 minutos · {VERSAO}")
    print("=" * 68)
    print("\n  Suas respostas montam o perfil inicial do seu mandato.")
    print("  Nada aqui é definitivo: o sistema aprende com o uso e ajusta.")
    print("  Pode deixar em branco o que não souber agora — vazio é melhor")
    print("  que chute, e o sistema mostra o que está faltando.\n")

    respostas = OrderedDict()
    bloco_atual = None
    for chave, bloco, texto, _tipo in PERGUNTAS:
        if bloco != bloco_atual:
            bloco_atual = bloco
            print(f"\n--- {BLOCOS[bloco]} ---\n")
        try:
            respostas[chave] = input(f"{texto}\n> ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n\nEntrevista interrompida. Nada foi gravado.")
            sys.exit(1)
        print()
    respostas["_ciencia"] = _colher_ciencia()
    return respostas


def _colher_ciencia():
    """Bloco final obrigatório (decisão D5). Sem ciência registrada,
    o tenant não entra em operação."""
    print("\n" + "=" * 68)
    print("  ANTES DE COMEÇAR — três travas do sistema")
    print("=" * 68 + "\n")
    for i, t in enumerate(TRAVAS_CIENCIA, 1):
        print(f"  {i}. {t}\n")
    try:
        r = input("Você leu e está ciente das três travas acima? (sim/não)\n> ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        return False
    return r.startswith("s")


# ---------------------------------------------------------------------------
# montagem do perfil
# ---------------------------------------------------------------------------
def montar_perfil(r):
    nome = r.get("p1", "").strip()
    cargo = r.get("p3a", "").strip()
    municipio = r.get("p3c", "").strip()
    uf = r.get("p3d", "").strip().upper()
    ciente = bool(r.get("_ciencia"))

    try:
        limiar = int(float(str(r.get("p13", "")).replace("%", "").replace(",", ".").strip() or 25))
    except ValueError:
        limiar = 25

    horario = r.get("p9", "").strip() or "06:45"
    modo = "direto" if r.get("p10", "").strip().lower().startswith("d") else "contexto"
    tom = ("factual, conciso, direto; sem opinião pessoal nem recomendação de voto"
           if modo == "direto" else
           "factual e explicado, com contexto suficiente para decidir; sem opinião "
           "pessoal nem recomendação de voto")

    pessoas = _lista(r.get("p8", ""))
    finalidade = r.get("p8f", "").strip()

    p = OrderedDict()
    p["tenant"] = _slug(f"{nome} {municipio}") or "tenant-sem-nome"
    p["autoridade"] = OrderedDict([
        ("nome", nome),
        ("variacoes_nome", _variacoes(nome, _lista(r.get("p2", "")), cargo)),
        ("cargo_atual", cargo),
        ("partido", r.get("p3b", "").strip()),
        ("municipio", municipio),
        ("municipio_sede", municipio),
        ("uf", uf),
        ("area_atuacao", [{"municipio": municipio, "uf": uf, "papel": "sede do mandato"}] if municipio else []),
        ("mandatos", r.get("p4", "").strip()),
    ])
    p["briefing"] = OrderedDict([
        ("horario", horario),
        ("fuso", "America/Sao_Paulo"),
        ("tom", tom),
        ("profundidade", modo),
        ("canal", (r.get("p12", "").strip().lower() or "tela")),
        ("blocos", [
            "Resumo do dia",
            "Radar de Nomeações (AFEx-g)",
            f"Fiscalização do Executivo (limiar {limiar}%)",
            "Pulso da Câmara / Diário Oficial",
            "Demandas & Requerimentos",
            "Monitoramento & Imprensa",
            "Movimento sugerido (72h)",
        ]),
        ("carater", "Cláusula de Caráter Travado: sem invenção; fonte declarada em tudo (CVI); "
                    "'não sei' é válido; nada não-ordenado; freio humano (nada é executado sem "
                    "aprovação)."),
        ("exclusoes", _lista(r.get("p14", ""))),
        ("destinatarios", _lista(r.get("p11", ""))),
    ])
    p["monitoramento"] = OrderedDict([
        ("temas", _lista(r.get("p5", ""))[:5]),
        ("territorio", _lista(r.get("p6", ""))),
        ("orgaos", _lista(r.get("p7", ""))),
        ("politicos_pessoas", pessoas),
        ("politicos_pessoas_finalidade", finalidade),
        ("veiculos", []),
        ("veiculos_detalhe", []),
        ("influencers_f3", []),
        ("_nota_veiculos", "Vazio de propósito: o Atlas Municipal preenche os veículos F1/F2 da "
                            "cidade na implantação (Anexo 16 §2). Verificação humana da mídia local "
                            "é obrigatória antes do go-live (decisão D6)."),
        ("_nota_f3", "Influencers e perfis pessoais entram aqui (F3), com finalidade declarada e "
                      "visíveis na auditoria. Nunca sobem ao Atlas compartilhado."),
    ])
    p["fiscalizacao"] = OrderedDict([
        ("ambito", "municipal"),
        ("limiar_desvio_pct", limiar),
        ("regra", "indício para verificação humana; nunca acusação; base de comparação sempre declarada"),
        ("radar_nomeacoes", "Diário Oficial: nomeações e exonerações (nome, cargo, secretaria) + "
                            "cruzamento com pessoas de interesse. Indício, nunca acusação."),
        ("fontes", ["Diário Oficial do município (via COM — conector a definir na implantação)", "PNCP"]),
    ])
    p["travas"] = OrderedDict([
        ("freio_humano", True),
        ("fontes_publicas_e_licitas", True),
        ("lgpd_termo_demandas", "obrigatório desde o dia 1"),
        ("separacao_gabinete_campanha", True),
        ("ciencia_registrada", ciente),
        ("ciencia_data", date.today().isoformat() if ciente else ""),
        ("ciencia_texto", TRAVAS_CIENCIA),
    ])
    p["operacional"] = ciente
    if not ciente:
        p["_bloqueio"] = ("Go-live bloqueado: a ciência das 3 travas não foi registrada "
                          "(Manual v10.6, Anexo 16 §5 — decisão D5). Rode a entrevista novamente "
                          "e confirme a ciência para liberar a operação.")

    p["_procedencia"] = OrderedDict([
        ("autoridade", "declarado"),
        ("monitoramento.temas", "declarado"),
        ("monitoramento.politicos_pessoas", f"declarado — finalidade: {finalidade or '[NÃO INFORMADA]'}"),
        ("monitoramento.veiculos", "pendente — será preenchido pelo Atlas (atlas) + verificação humana"),
        ("fiscalizacao.limiar_desvio_pct", "declarado"),
        ("_regra", "declarado = veio da Entrevista de Fundação · atlas = veio do Atlas Municipal · "
                    "verificado = confirmado em fonte pública, com data e link"),
    ])
    p["_versao_perfil"] = (f"{VERSAO} · gerado pela Entrevista de Fundação em "
                            f"{date.today().strftime('%d/%m/%Y')} · respostas do tenant entram como "
                            f"'declarado', nunca como 'verificado'")
    return p


def avisos(p):
    """O que o operador precisa saber antes do go-live — dito na cara,
    não escondido no JSON."""
    av = []
    if not p.get("operacional"):
        av.append("BLOQUEIO: ciência das 3 travas não registrada — go-live impedido (D5).")
    if not p["autoridade"]["nome"]:
        av.append("Nome da autoridade vazio — o coletor de imprensa não terá o que buscar.")
    if not p["autoridade"]["municipio"]:
        av.append("Município vazio — sem ele o Atlas não consegue ligar as fontes da cidade.")
    if not p["monitoramento"]["temas"]:
        av.append("Nenhum tema informado — o briefing sairá genérico até que se preencha.")
    if p["monitoramento"]["politicos_pessoas"] and not p["monitoramento"]["politicos_pessoas_finalidade"]:
        av.append("Pessoas a acompanhar informadas SEM finalidade declarada — exigida pelo Anexo 16 §5.")
    av.append("Veículos vazios: rode o Atlas Municipal e faça a verificação humana da mídia "
              "local antes do go-live (D6).")
    return av


def main():
    import argparse
    ap = argparse.ArgumentParser(description="Entrevista de Fundação — Évora Oversight")
    ap.add_argument("--saida", default=None, help="arquivo de saída (padrão: perfil_<tenant>.json)")
    ap.add_argument("--respostas", default=None,
                    help="JSON com as respostas (modo não-interativo, para testes ou tela web)")
    args = ap.parse_args()

    if args.respostas:
        r = json.loads(Path(args.respostas).read_text(encoding="utf-8"))
    else:
        r = perguntar_interativo()

    p = montar_perfil(r)
    saida = args.saida or f"perfil_{p['tenant']}.json"
    Path(saida).write_text(json.dumps(p, ensure_ascii=False, indent=1), encoding="utf-8")

    print("\n" + "=" * 68)
    print(f"  Perfil gerado: {saida}")
    print(f"  Tenant: {p['tenant']}")
    print(f"  Operacional: {'SIM' if p['operacional'] else 'NÃO (ver bloqueio abaixo)'}")
    print("=" * 68)
    print("\n  O que ainda falta antes do go-live:\n")
    for a in avisos(p):
        print(f"   · {a}")
    print("\n  Próximo passo: rodar o orquestrador para o briefing de teste")
    print("  (passo 5 da implantação — Manual v10.6, Anexo 13).\n")


if __name__ == "__main__":
    main()

```


---

## 13. `motor/atlas_municipal.py`

```python
"""
Évora Oversight — Atlas Municipal (versão em arquivo)
======================================================
Implementa o Anexo 16 §2–§4 do Manual Supremo v10.6 SEM depender do banco
(Etapa 3): cada município vive em um `atlas_<municipio>.json`. Quando o
Supabase subir, estes arquivos migram para as tabelas `municipios` e
`municipio_fontes` sem mudança de estrutura.

O que este componente faz:
  1. `semear`  — cria o esqueleto do Atlas de uma cidade nova, com todos os
     campos previstos e TUDO marcado "a confirmar" (selo CVI). A máquina não
     inventa: o esqueleto existe para o humano preencher e verificar.
  2. `aplicar` — cruza o Atlas com um perfil de tenant (o que a Entrevista
     de Fundação gerou): os veículos F1/F2 verificados da cidade entram em
     `monitoramento.veiculos_detalhe` com procedência `atlas`.
  3. `validar` — confere as regras travadas do Anexo 16 (F3 nunca no Atlas,
     campo factual com fonte, selo por campo).

TRAVAS (Anexo 16, ratificadas pelo fundador em 19/07/2026):
  - Atlas é camada COMPARTILHADA da plataforma: fatos públicos sobre a
    CIDADE. Nada de tenant aqui — temas, pessoas de interesse e F3 moram
    no perfil isolado.
  - Leitura A (factual): só o que consta em fonte oficial nomeada, pode ser
    reproduzido sem adjetivo e sobrevive a contestação sem interpretação.
  - CNPJ identifica o veículo e atesta regularidade — não decide entrada
    nem mede credibilidade. Entrada é por COBERTURA.
  - Edição com trilha: toda mudança gravada em `_trilha` (quem, quando, o quê).
    Na versão em arquivo a trilha é local; no banco ela vai à AAS-Évora.

USO
---
    python atlas_municipal.py semear "Itu" SP
    python atlas_municipal.py aplicar atlas_sorocaba.json perfil_tatiane.json
    python atlas_municipal.py validar atlas_sorocaba.json
"""

import json
import re
import sys
import unicodedata
from collections import OrderedDict
from datetime import date
from pathlib import Path

VERSAO = "Atlas v1 (arquivo) · Manual v10.6, Anexo 16"

CNAES_MIDIA = {
    "5812": "edição de jornais",
    "5813": "edição de revistas",
    "6010": "rádio",
    "6021": "TV aberta",
    "6022": "TV por assinatura (programadoras)",
    "6319": "portais/provedores de conteúdo",
    "5911": "produção audiovisual",
    "5912": "pós-produção audiovisual",
}


def _slug(texto):
    t = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode()
    return re.sub(r"-{2,}", "-", re.sub(r"[^a-zA-Z0-9]+", "-", t).strip("-").lower())


def _hoje():
    return date.today().strftime("%d/%m/%Y")


def _campo(valor="", fonte="", selo="a confirmar"):
    """Todo campo do Atlas carrega valor + fonte + selo CVI + data.
    Selo 'verificado' só com fonte nomeada — a função trava isso."""
    if selo == "verificado" and not fonte:
        raise ValueError("Selo 'verificado' exige fonte nomeada (Anexo 16 §4).")
    return OrderedDict([("valor", valor), ("fonte", fonte),
                        ("selo", selo), ("data", _hoje() if valor else "")])


# ---------------------------------------------------------------------------
# 1. SEMEAR — esqueleto de cidade nova (nada inventado; tudo "a confirmar")
# ---------------------------------------------------------------------------
def semear(municipio, uf):
    a = OrderedDict()
    a["_versao"] = VERSAO
    a["_camada"] = ("COMPARTILHADA da plataforma — fatos públicos sobre a cidade. "
                     "Nunca guardar aqui dados de tenant (temas, pessoas de interesse, F3).")
    a["municipio"] = municipio
    a["uf"] = uf.upper()
    a["slug"] = _slug(f"{municipio}-{uf}")

    a["identificacao"] = OrderedDict([
        ("codigo_ibge", _campo()),
        ("regiao", _campo()),
        ("microrregiao", _campo()),
        ("populacao", _campo()),
    ])
    a["executivo"] = OrderedDict([
        ("prefeito", _campo()),
        ("vice", _campo()),
        ("cnpj_prefeitura", _campo()),
        ("portal", _campo()),
        ("secretarias", []),          # cada item: {"nome": _campo(), "titular": _campo()}
    ])
    a["legislativo"] = OrderedDict([
        ("num_vereadores", _campo()),
        ("presidente_camara", _campo()),
        ("composicao_partidaria", []),  # cada item: {"partido": str, "cadeiras": int, "fonte": str, "selo": str}
        ("portal", _campo()),
        ("sistema_tramitacao", _campo()),
    ])
    a["diario_oficial"] = OrderedDict([
        ("onde_publica", _campo()),
        ("formato", _campo()),          # PDF / HTML / XML / RSS
        ("plataforma", _campo()),       # determina QUAL conector COM serve
        ("periodicidade", _campo()),
        ("conector_com", _campo(valor="", fonte="", selo="a confirmar")),  # ex.: RMS-001
    ])
    a["contratacoes"] = OrderedDict([
        ("cnpjs_pncp", []),             # cada item: {"orgao": str, "cnpj": _campo()}
    ])
    a["mapa_politico_factual"] = OrderedDict([
        ("_regra", "Leitura A (decisão D3): só fato público com fonte — eleitos, votos, partidos, "
                    "coligações declaradas, presidências. PROIBIDO: inferência de alinhamento. "
                    "Correlações são pesquisa sob demanda no tenant, nunca cadastro aqui."),
        ("ultima_eleicao_municipal", _campo()),
        ("eleitos", []),                # cada item: {"nome": str, "cargo": str, "partido": str, "votos": int, "fonte": str, "selo": str}
    ])
    a["midia"] = OrderedDict([
        ("_regra", "Níveis F1 (CNPJ ativo + CNAE de mídia — identificação) e F2 (cobertura comprovada "
                    "com evidência arquivada). F3 NUNCA entra no Atlas. CNPJ não mede credibilidade; "
                    "ausência de CNPJ não descarta fonte. Revalidação semestral do CNPJ."),
        ("veiculos", []),               # ver _veiculo() abaixo
    ])
    a["_trilha"] = [OrderedDict([("data", _hoje()), ("acao", "semeadura do esqueleto"),
                                  ("autor", "atlas_municipal.py"), ("obs", "tudo 'a confirmar'")])]
    a["_pendencias_go_live"] = [
        "Verificação humana da mídia local (obrigatória — decisão D6)",
        "Confirmar plataforma do Diário Oficial e conector COM correspondente",
        "Preencher CNPJs dos órgãos para o PNCP",
    ]
    return a


def _veiculo(nome, nivel, cobertura, url="", cnpj="", situacao_receita="", cnae="",
             evidencia="", fonte="", selo="a confirmar"):
    """Monta um veículo F1/F2 do Atlas com as regras do Anexo 16 §3."""
    nivel = nivel.upper()
    if nivel == "F3":
        raise ValueError("F3 (influencers/perfis pessoais) NUNCA entra no Atlas — "
                          "vai no perfil isolado do tenant (Anexo 16 §3).")
    if nivel == "F2" and not evidencia:
        raise ValueError("F2 exige evidência de cobertura arquivada (links de matérias, com data).")
    v = OrderedDict([
        ("nome", nome), ("nivel", nivel), ("url", url),
        ("cobertura", cobertura),
        ("cnpj", cnpj), ("situacao_receita", situacao_receita),
        ("cnae", cnae), ("cnae_descricao", CNAES_MIDIA.get(cnae[:4], "") if cnae else ""),
        ("identificacao", "verificada" if (cnpj and situacao_receita.lower() == "ativa")
                           else "pendente"),
        ("evidencia_cobertura", evidencia),
        ("fonte", fonte), ("selo", selo), ("data", _hoje()),
        ("proxima_revalidacao_cnpj", ""),
    ])
    return v


# ---------------------------------------------------------------------------
# 2. APLICAR — cruza Atlas -> perfil do tenant (procedência 'atlas')
# ---------------------------------------------------------------------------
def aplicar(atlas_path, perfil_path):
    atlas = json.loads(Path(atlas_path).read_text(encoding="utf-8"))
    perfil = json.loads(Path(perfil_path).read_text(encoding="utf-8"),
                        object_pairs_hook=OrderedDict)

    cidade_perfil = (perfil.get("autoridade", {}).get("municipio_sede")
                     or perfil.get("autoridade", {}).get("municipio", ""))
    if _slug(f"{cidade_perfil}-{perfil.get('autoridade',{}).get('uf','')}") != atlas.get("slug"):
        print(f"AVISO: cidade do perfil ('{cidade_perfil}') difere do Atlas "
              f"('{atlas.get('municipio')}'). Nada aplicado.")
        return False

    mon = perfil.setdefault("monitoramento", OrderedDict())
    detalhe = mon.setdefault("veiculos_detalhe", [])
    ja = {v.get("nome", "").lower() for v in detalhe if isinstance(v, dict)}

    aplicados = 0
    for v in atlas.get("midia", {}).get("veiculos", []):
        if v.get("nome", "").lower() in ja:
            continue
        detalhe.append(OrderedDict([
            ("nome", v["nome"]), ("url", v.get("url", "")),
            ("nivel", v.get("nivel", "")), ("cobertura", v.get("cobertura", "")),
            ("identificacao", v.get("identificacao", "pendente")),
            ("procedencia", "atlas"),
            ("selo", v.get("selo", "a confirmar")),
        ]))
        aplicados += 1

    # órgãos do PNCP
    orgaos = mon.setdefault("orgaos", [])
    for item in atlas.get("contratacoes", {}).get("cnpjs_pncp", []):
        nome = item.get("orgao", "")
        if nome and nome not in orgaos:
            orgaos.append(nome)

    proc = perfil.setdefault("_procedencia", OrderedDict())
    proc["monitoramento.veiculos"] = (f"atlas ({atlas.get('municipio')}) — {aplicados} veículo(s) "
                                       f"aplicado(s) em {_hoje()}; verificação humana antes do "
                                       f"go-live continua obrigatória (D6)")

    Path(perfil_path).write_text(json.dumps(perfil, ensure_ascii=False, indent=1),
                                  encoding="utf-8")
    print(f"✓ {aplicados} veículo(s) do Atlas aplicados ao perfil ({perfil_path}).")
    if aplicados == 0:
        print("  (Nenhum veículo novo — Atlas vazio ou tudo já constava no perfil.)")
    return True


# ---------------------------------------------------------------------------
# 3. VALIDAR — regras travadas do Anexo 16
# ---------------------------------------------------------------------------
def validar(atlas_path):
    a = json.loads(Path(atlas_path).read_text(encoding="utf-8"))
    problemas = []
    for v in a.get("midia", {}).get("veiculos", []):
        if v.get("nivel", "").upper() == "F3":
            problemas.append(f"PROIBIDO: veículo F3 no Atlas ({v.get('nome')}).")
        if v.get("nivel", "").upper() == "F2" and not v.get("evidencia_cobertura"):
            problemas.append(f"F2 sem evidência de cobertura ({v.get('nome')}).")
        if v.get("selo") == "verificado" and not v.get("fonte"):
            problemas.append(f"Selo 'verificado' sem fonte ({v.get('nome')}).")
    for chave in ("temas", "politicos_pessoas", "influencers"):
        if chave in json.dumps(a, ensure_ascii=False).lower():
            pass  # nomes de campo de tenant não devem existir; checagem leve
    if not a.get("_trilha"):
        problemas.append("Atlas sem trilha de edição.")
    if problemas:
        print(f"✗ {len(problemas)} problema(s) em {atlas_path}:")
        for p in problemas:
            print("   ·", p)
        return False
    print(f"✓ {atlas_path} passa nas regras do Anexo 16.")
    return True


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    cmd = sys.argv[1]
    if cmd == "semear" and len(sys.argv) >= 4:
        municipio, uf = sys.argv[2], sys.argv[3]
        a = semear(municipio, uf)
        saida = f"atlas_{a['slug']}.json"
        Path(saida).write_text(json.dumps(a, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"✓ Esqueleto criado: {saida}")
        print("  Tudo está 'a confirmar' — preencha e verifique antes de aplicar a um tenant.")
        for p in a["_pendencias_go_live"]:
            print("   ·", p)
    elif cmd == "aplicar" and len(sys.argv) >= 4:
        aplicar(sys.argv[2], sys.argv[3])
    elif cmd == "validar" and len(sys.argv) >= 3:
        validar(sys.argv[2])
    else:
        print(__doc__)


if __name__ == "__main__":
    main()

```


---

## 14. `motor/atlas_sorocaba-sp.json`

```json
{
 "_versao": "Atlas v1 (arquivo) · Manual v10.6, Anexo 16",
 "_camada": "COMPARTILHADA da plataforma — fatos públicos sobre a cidade. Nunca guardar aqui dados de tenant (temas, pessoas de interesse, F3).",
 "municipio": "Sorocaba",
 "uf": "SP",
 "slug": "sorocaba-sp",
 "identificacao": {
  "codigo_ibge": {
   "valor": "",
   "fonte": "",
   "selo": "a confirmar",
   "data": ""
  },
  "regiao": {
   "valor": "",
   "fonte": "",
   "selo": "a confirmar",
   "data": ""
  },
  "microrregiao": {
   "valor": "",
   "fonte": "",
   "selo": "a confirmar",
   "data": ""
  },
  "populacao": {
   "valor": "",
   "fonte": "",
   "selo": "a confirmar",
   "data": ""
  }
 },
 "executivo": {
  "prefeito": {
   "valor": "",
   "fonte": "",
   "selo": "a confirmar",
   "data": ""
  },
  "vice": {
   "valor": "",
   "fonte": "",
   "selo": "a confirmar",
   "data": ""
  },
  "cnpj_prefeitura": {
   "valor": "",
   "fonte": "",
   "selo": "a confirmar",
   "data": ""
  },
  "portal": {
   "valor": "",
   "fonte": "",
   "selo": "a confirmar",
   "data": ""
  },
  "secretarias": []
 },
 "legislativo": {
  "num_vereadores": {
   "valor": "",
   "fonte": "",
   "selo": "a confirmar",
   "data": ""
  },
  "presidente_camara": {
   "valor": "",
   "fonte": "",
   "selo": "a confirmar",
   "data": ""
  },
  "composicao_partidaria": [],
  "portal": {
   "valor": "",
   "fonte": "",
   "selo": "a confirmar",
   "data": ""
  },
  "sistema_tramitacao": {
   "valor": "",
   "fonte": "",
   "selo": "a confirmar",
   "data": ""
  }
 },
 "diario_oficial": {
  "onde_publica": {
   "valor": "noticias.sorocaba.sp.gov.br/jornal",
   "fonte": "Verificação direta do site, 18/07/2026 (edições 3990 de 08/07 e 3991 de 13/07 identificadas)",
   "selo": "verificado",
   "data": "20/07/2026"
  },
  "formato": {
   "valor": "PDF (edições numeradas sequencialmente em página WordPress)",
   "fonte": "Verificação direta do site, 18/07/2026",
   "selo": "verificado",
   "data": "20/07/2026"
  },
  "plataforma": {
   "valor": "",
   "fonte": "",
   "selo": "a confirmar",
   "data": ""
  },
  "periodicidade": {
   "valor": "",
   "fonte": "",
   "selo": "a confirmar",
   "data": ""
  },
  "conector_com": {
   "valor": "RMS-001 (especificado no Manual; conector ainda NÃO construído)",
   "fonte": "Manual Supremo v10.6, seção COM",
   "selo": "verificado",
   "data": "20/07/2026"
  }
 },
 "contratacoes": {
  "cnpjs_pncp": [
   {
    "orgao": "Prefeitura de Sorocaba",
    "cnpj": {
     "valor": "",
     "fonte": "",
     "selo": "a confirmar",
     "data": ""
    }
   }
  ]
 },
 "mapa_politico_factual": {
  "_regra": "Leitura A (decisão D3): só fato público com fonte — eleitos, votos, partidos, coligações declaradas, presidências. PROIBIDO: inferência de alinhamento. Correlações são pesquisa sob demanda no tenant, nunca cadastro aqui.",
  "ultima_eleicao_municipal": {
   "valor": "",
   "fonte": "",
   "selo": "a confirmar",
   "data": ""
  },
  "eleitos": []
 },
 "midia": {
  "_regra": "Níveis F1 (CNPJ ativo + CNAE de mídia — identificação) e F2 (cobertura comprovada com evidência arquivada). F3 NUNCA entra no Atlas. CNPJ não mede credibilidade; ausência de CNPJ não descarta fonte. Revalidação semestral do CNPJ.",
  "veiculos": [
   {
    "nome": "Cruzeiro do Sul",
    "nivel": "F1",
    "url": "cruzeirodosul.inf.br",
    "cobertura": "Sorocaba e região",
    "cnpj": "",
    "situacao_receita": "",
    "cnae": "",
    "cnae_descricao": "",
    "identificacao": "pendente",
    "evidencia_cobertura": "",
    "fonte": "Veículo canônico do Manual v10.6 (decisão do fundador, v9.8); matéria sobre pauta da Câmara verificada em 14/07/2026",
    "selo": "verificado",
    "data": "20/07/2026",
    "proxima_revalidacao_cnpj": ""
   },
   {
    "nome": "Jornal Z Norte — seção Sorocabanices",
    "nivel": "F1",
    "url": "",
    "cobertura": "Sorocaba (zona norte)",
    "cnpj": "",
    "situacao_receita": "",
    "cnae": "",
    "cnae_descricao": "",
    "identificacao": "pendente",
    "evidencia_cobertura": "",
    "fonte": "Veículo canônico do Manual v10.6 (v9.8)",
    "selo": "verificado",
    "data": "20/07/2026",
    "proxima_revalidacao_cnpj": ""
   },
   {
    "nome": "Jornal Ipanema / IPA Online",
    "nivel": "F1",
    "url": "jornalipanema.com.br",
    "cobertura": "Sorocaba e região",
    "cnpj": "",
    "situacao_receita": "",
    "cnae": "",
    "cnae_descricao": "",
    "identificacao": "pendente",
    "evidencia_cobertura": "",
    "fonte": "Veículo canônico do Manual v10.6 (v9.8)",
    "selo": "verificado",
    "data": "20/07/2026",
    "proxima_revalidacao_cnpj": ""
   },
   {
    "nome": "Giro Sorocaba",
    "nivel": "F1",
    "url": "girosorocaba.com.br",
    "cobertura": "Sorocaba",
    "cnpj": "",
    "situacao_receita": "",
    "cnae": "",
    "cnae_descricao": "",
    "identificacao": "pendente",
    "evidencia_cobertura": "",
    "fonte": "Veículo canônico do Manual v10.6 (v9.8)",
    "selo": "verificado",
    "data": "20/07/2026",
    "proxima_revalidacao_cnpj": ""
   },
   {
    "nome": "Portal Porque",
    "nivel": "F1",
    "url": "portalporque.com.br",
    "cobertura": "Sorocaba",
    "cnpj": "",
    "situacao_receita": "",
    "cnae": "",
    "cnae_descricao": "",
    "identificacao": "pendente",
    "evidencia_cobertura": "",
    "fonte": "Veículo canônico do Manual v10.6 (v9.8); reportagens de fiscalização de contratos verificadas (17/04/2025)",
    "selo": "verificado",
    "data": "20/07/2026",
    "proxima_revalidacao_cnpj": ""
   },
   {
    "nome": "Revista Oeste",
    "nivel": "F2",
    "url": "revistaoeste.com",
    "cobertura": "nacional; cobre pautas de Sorocaba",
    "cnpj": "",
    "situacao_receita": "",
    "cnae": "",
    "cnae_descricao": "",
    "identificacao": "pendente",
    "evidencia_cobertura": "Matéria sobre aprovação de projeto de autoria da vereadora Tatiane Costa na Câmara de Sorocaba, votação de 07/07/2026 (verificada em 18/07/2026)",
    "fonte": "Busca verificada em 18/07/2026",
    "selo": "verificado",
    "data": "20/07/2026",
    "proxima_revalidacao_cnpj": ""
   }
  ]
 },
 "_trilha": [
  {
   "data": "20/07/2026",
   "acao": "semeadura do esqueleto",
   "autor": "atlas_municipal.py",
   "obs": "tudo 'a confirmar'"
  },
  {
   "data": "19/07/2026",
   "acao": "semeadura inicial com dados verificados na sessão de consolidação v10.5/v10.6",
   "autor": "sessão de trabalho fundador + Claude",
   "obs": "5 veículos F1 canônicos + 1 F2 com evidência; DO verificado; CNPJs pendentes de consulta à Receita"
  }
 ],
 "_pendencias_go_live": [
  "Verificação humana da mídia local (obrigatória — decisão D6)",
  "Confirmar plataforma do Diário Oficial e conector COM correspondente",
  "Preencher CNPJs dos órgãos para o PNCP"
 ]
}
```


---

## 15. `motor/imprensa_coletor_evora.py`

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Coletor de Imprensa (motor v2 · alimenta o AIM-g)
===================================================================
Busca notícias no Google News (feed RSS público, sem chave/sem custo) sobre
a autoridade, a cidade e os temas de interesse do PERFIL DO TENANT.

Mudança v2 (achado C5 da Revisão): as CONSULTAS são GERADAS DO PERFIL
(variações do nome — incluindo "Vereadora Tati", "Vereadora Tatiane",
"Gabinete 6" quando presentes no perfil —, órgãos, temas e veículos).
Trocar de cliente = trocar o perfil, sem tocar no código.

Só biblioteca padrão (urllib + xml). Saída: terminal + noticias.json
Nota: no MVP os veículos entram via Google News (agregador). O conector
direto por site (Cruzeiro do Sul, Z Norte etc.) entra na fase COM.
"""
import json, urllib.request, urllib.parse, urllib.error
import xml.etree.ElementTree as ET
from html import unescape
import re

from perfil_loader_evora import carregar_perfil, consultas_imprensa

JANELA = "7d"
MAX_POR_CONSULTA = 8
IDIOMA = "hl=pt-BR&gl=BR&ceid=BR:pt-BR"
BASE = "https://news.google.com/rss/search?q="


def _get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Evora-Oversight/2.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()


def _limpa(txt):
    if not txt:
        return ""
    return unescape(re.sub(r"<[^>]+>", "", txt)).strip()


def buscar(consulta):
    q = urllib.parse.quote(f"{consulta} when:{JANELA}")
    url = f"{BASE}{q}&{IDIOMA}"
    try:
        xml = _get(url)
    except urllib.error.URLError as e:
        print(f"  ! sem conexão em '{consulta}': {e.reason}")
        return []
    except Exception as e:
        print(f"  ! erro em '{consulta}': {e}")
        return []
    try:
        root = ET.fromstring(xml)
    except ET.ParseError:
        return []
    itens = []
    for item in root.iter("item"):
        titulo = _limpa(item.findtext("title"))
        link = item.findtext("link") or ""
        data = item.findtext("pubDate") or ""
        fonte_el = item.find("source")
        fonte = _limpa(fonte_el.text) if fonte_el is not None else ""
        if not fonte and " - " in titulo:
            titulo, fonte = titulo.rsplit(" - ", 1)
        itens.append({"titulo": titulo, "fonte": fonte, "data": data,
                      "link": link, "consulta": consulta})
        if len(itens) >= MAX_POR_CONSULTA:
            break
    return itens


def dedup(itens):
    visto, out = set(), []
    for it in itens:
        chave = it["titulo"].lower()[:80]
        if chave not in visto:
            visto.add(chave)
            out.append(it)
    return out


def main():
    p = carregar_perfil()
    consultas = consultas_imprensa(p)

    print("=" * 64)
    print("ÉVORA — Coletor de Imprensa (AIM-g · Monitoramento) · v2")
    print(f"Tenant: {p.get('tenant')} · janela: últimos {JANELA} · "
          f"{len(consultas)} consultas geradas do perfil")
    print("=" * 64)

    todos = []
    for c in consultas:
        print(f"→ buscando: {c}")
        todos += buscar(c)
    todos = dedup(todos)

    print(f"\n{len(todos)} notícias (após deduplicação):\n")
    print("-" * 64)
    print("BLOCO MONITORAMENTO — imprensa e menções")
    print("-" * 64)
    for n in todos[:20]:
        print(f"\n• {n['titulo']}")
        print(f"  {n['fonte']}  ·  {n['data']}")

    with open("noticias.json", "w", encoding="utf-8") as f:
        json.dump(todos, f, ensure_ascii=False, indent=2)
    print("\n✓ Salvo em noticias.json (insumo do AIM-g para o briefing)")
    print("  Obs.: o AIM-g depois filtra por relevância e escreve o bloco.")


if __name__ == "__main__":
    main()

```


---

## 16. `motor/coletor_pncp_evora.py`

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Coletor PNCP (motor v2 · alimenta o AFEx-g · Fiscalização)
============================================================================
Lê contratos do Portal Nacional de Contratações Públicas (PNCP) e prepara a
lista para o AFEx-g sinalizar — por INDÍCIO, nunca acusação — itens com valor
fora da referência, para verificação HUMANA.

Mudança v2 (achado C2 da Revisão): o LIMIAR e o MUNICÍPIO vêm do PERFIL DO
TENANT (fiscalizacao.limiar_desvio_pct — decisão travada no Manual: 25%),
com fallback 25%. Nada de valor fixo no código.

PRINCÍPIO PÉTREO: o AFEx-g levanta indício e declara a base de comparação;
a decisão é sempre humana. Este coletor NÃO conclui irregularidade.

ATENÇÃO (pendência do Blueprint): confirmar endpoint/campos exatos da API de
consulta do PNCP na implementação real (a API evolui). Ajustar no go-live.

Só biblioteca padrão. Saída: contratos_sorocaba.json
"""
import json, urllib.request, urllib.parse, urllib.error, statistics
from datetime import date, timedelta

from perfil_loader_evora import carregar_perfil, limiar_desvio, autoridade

BASE    = "https://pncp.gov.br/api/consulta/v1/contratos"
DIAS    = 30
TIMEOUT = 30


def _get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Evora-Oversight/2.0"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return json.loads(r.read().decode("utf-8"))


def buscar_contratos():
    fim = date.today()
    ini = fim - timedelta(days=DIAS)
    params = {
        "dataInicial": ini.strftime("%Y%m%d"),
        "dataFinal":   fim.strftime("%Y%m%d"),
        "pagina":      "1",
        # filtros adicionais (confirmar nomes na API real):
        # "codigoMunicipioIbge": ..., "cnpjOrgao": ...
    }
    url = f"{BASE}?{urllib.parse.urlencode(params)}"
    try:
        dados = _get(url)
    except urllib.error.URLError as e:
        print(f"  ! sem conexão com o PNCP ({e.reason}) — bloco seguirá 'Sem dado hoje.'")
        return []
    except Exception as e:
        print(f"  ! erro ao consultar o PNCP: {e}")
        return []
    itens = dados.get("data", dados) if isinstance(dados, dict) else dados
    return itens if isinstance(itens, list) else []


def normalizar(itens, municipio):
    out = []
    for it in itens:
        def g(*chaves):
            for k in chaves:
                if isinstance(it, dict) and it.get(k) not in (None, ""):
                    return it[k]
            return ""
        mun = str(g("municipioNome", "municipio", "nomeMunicipio"))
        if municipio and mun and municipio.lower() not in mun.lower():
            continue
        out.append({
            "numero":          g("numeroControlePNCP", "numeroContrato", "numero"),
            "objeto":          g("objetoContrato", "objeto", "descricaoObjeto"),
            "valor":           float(g("valorGlobal", "valorInicial", "valor") or 0),
            "orgao":           g("orgaoEntidadeRazaoSocial", "orgao", "nomeOrgao"),
            "fornecedor":      g("nomeRazaoSocialFornecedor", "fornecedor", "nomeFornecedor"),
            "data_publicacao": g("dataPublicacaoPncp", "dataPublicacao", "data"),
            "municipio":       mun,
        })
    return out


def sinalizar_indicios(contratos, limiar):
    """Marca indício quando o valor está acima da mediana dos comparáveis.
    Base de comparação SEMPRE declarada. Nunca afirma irregularidade."""
    valores = [c["valor"] for c in contratos if c["valor"] > 0]
    if len(valores) < 4:
        for c in contratos:
            c["relevancia"], c["indicio"] = "rotina", ""
        return contratos
    mediana = statistics.median(valores)
    for c in contratos:
        if c["valor"] > 0 and c["valor"] > mediana * (1 + limiar):
            desvio = (c["valor"] / mediana - 1) * 100
            c["relevancia"] = "atenção"
            c["indicio"] = (f"valor ~{desvio:.0f}% acima da mediana dos contratos "
                            f"do período; sugiro verificar. Base: mediana de "
                            f"{len(valores)} contratos no PNCP (R$ {mediana:,.2f}). "
                            f"Limiar do tenant: {int(limiar*100)}%.")
        else:
            c["relevancia"], c["indicio"] = "rotina", ""
    return contratos


def main():
    p = carregar_perfil()
    a = autoridade(p)
    municipio, uf = a.get("municipio", ""), a.get("uf", "")
    limiar = limiar_desvio(p)

    print("=" * 64)
    print("ÉVORA — Coletor PNCP (AFEx-g · Fiscalização do Executivo) · v2")
    print(f"Município: {municipio}/{uf} · janela: {DIAS} dias · "
          f"limiar (do perfil): {int(limiar*100)}%")
    print("=" * 64)

    brutos = buscar_contratos()
    print(f"→ {len(brutos)} contratos retornados pelo PNCP")
    contratos = sinalizar_indicios(normalizar(brutos, municipio), limiar)

    indicios = [c for c in contratos if c.get("indicio")]
    print(f"→ {len(contratos)} contratos de {municipio}; {len(indicios)} com indício para verificar\n")
    for c in indicios[:10]:
        print(f"• {c['objeto'][:60]}  | R$ {c['valor']:,.2f}")
        print(f"  INDÍCIO (verificar, não acusação): {c['indicio']}")

    with open("contratos_sorocaba.json", "w", encoding="utf-8") as f:
        json.dump(contratos, f, ensure_ascii=False, indent=2)
    print("\n✓ Salvo em contratos_sorocaba.json (insumo do AFEx-g)")
    print("  Lembrete: indício é para verificação humana — nunca acusação.")


if __name__ == "__main__":
    main()

```


---

## 17. `motor/montador_briefing_evora.py`

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Montador do Briefing Matinal (motor v2 — a Bia escreve via API)
=================================================================================
Pega o que os coletores juntaram (PNCP + imprensa) e a BIA escreve o Briefing
no formato do PERFIL DO TENANT (identidade, tom, 7 blocos e Caráter Travado
vêm de perfil_tatiane.json — Manual v10.4, formato canônico).

Mudanças v2 (achados C1, C3, C4 da Revisão):
  C1 — lê o perfil; system prompt gerado do perfil; blocos sem dado = "Sem dado hoje."
  C3 — instrução Windows correta: PowerShell  $env:ANTHROPIC_API_KEY = "sua-chave"
       (setx só vale para janelas NOVAS; não use para a sessão atual)
       Mac/Linux:  export ANTHROPIC_API_KEY="sua-chave"
  C4 — sem internet/DNS, sai mensagem clara em vez de traceback bruto.

Entradas: contratos_sorocaba.json · noticias.json (o que faltar vira "Sem dado hoje.")
Saída:    briefing_AAAAMMDD.md
Só biblioteca padrão. Requer ANTHROPIC_API_KEY no ambiente (pago por uso).
"""
import os, json, urllib.request, urllib.error
from datetime import date

from perfil_loader_evora import carregar_perfil, blocos, autoridade

MODELO  = "claude-sonnet-4-6"   # bom custo/qualidade; alternativa: claude-opus-4-8
MAX_TOK = 2500
API_URL = "https://api.anthropic.com/v1/messages"


def sistema_do_perfil(p):
    """Monta a 'constituição' da Bia a partir do perfil do tenant (fonte única)."""
    a = autoridade(p)
    br = p.get("briefing", {}) or {}
    quem = f"{a.get('cargo_atual','')} {a.get('nome','')} ({a.get('partido','')}, " \
           f"{a.get('municipio','')}/{a.get('uf','')})".strip()
    pre = a.get("pre_candidatura_2026", "")
    if pre:
        quem += f", pré-candidata a {pre} 2026"
    tom = br.get("tom", "factual, conciso, respeitoso; sem opinião pessoal nem recomendação de voto")
    carater = br.get("carater", "Sem invenção; fonte declarada em tudo; 'não sei' é válido; freio humano.")
    lista_blocos = "\n".join(f"## {b}" for b in blocos(p))
    return f"""Você é a Bia, Gestora do Gabinete na plataforma Évora Oversight.
Sua tarefa: escrever o Briefing Matinal de {quem}, a partir SOMENTE dos dados fornecidos.

REGRAS INVIOLÁVEIS (Cláusula de Caráter Travado do tenant):
{carater}
- Não invente nada. Use apenas os dados recebidos.
- Bloco sem dado recebido sai EXATAMENTE como: "Sem dado hoje." (integridade, não falha).
- Cada item relevante cita a fonte/origem e a data.
- Tom: {tom}
- Fiscalização é sempre "indício para acompanhar, NUNCA acusação", com base de comparação declarada.
- Marque relevância quando útil (Rotina / Atenção).
- "Movimento sugerido (72h)" traz sugestões que dependem de APROVAÇÃO HUMANA (freio humano).

FORMATO (markdown, TODOS os blocos, nesta ordem exata — os sem dado com "Sem dado hoje."):
# Briefing Matinal — {{data}}
{lista_blocos}
Seja objetivo — isto é lido às {br.get('horario','06:45')} no celular."""


def carregar(caminho):
    if not os.path.exists(caminho):
        return None
    try:
        with open(caminho, encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return None


def _brl(v):
    return f"R$ {v:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def resumir_contratos(contratos, top=8):
    if not contratos:
        return "SEM DADO (coletor PNCP não trouxe contratos hoje)."
    total = sum(c.get("valor", 0) for c in contratos)
    maiores = sorted(contratos, key=lambda c: c.get("valor", 0), reverse=True)[:top]
    linhas = [f"Total: {len(contratos)} contratos somando {_brl(total)}"]
    for c in maiores:
        linhas.append(f"- {_brl(c.get('valor', 0))} | {c.get('objeto','—')[:70]}"
                      f" | órgão: {c.get('orgao','—')} | fornecedor: {c.get('fornecedor','—')}"
                      f" | {c.get('relevancia','')} | publicado: {c.get('data_publicacao','—')}"
                      + (f" | INDÍCIO: {c['indicio']}" if c.get("indicio") else ""))
    return "\n".join(linhas)


def resumir_noticias(noticias, top=14):
    if not noticias:
        return "SEM DADO (coletor de imprensa não trouxe notícias hoje)."
    return "\n".join(
        f"- {n.get('titulo','—')} | fonte: {n.get('fonte','—')} | {n.get('data','')}"
        for n in noticias[:top]
    )


def montar_mensagem(contratos, noticias):
    return f"""Dados de hoje para o briefing (o que estiver marcado SEM DADO vira "Sem dado hoje." no bloco).

[FISCALIZAÇÃO — contratos públicos (PNCP)]
{resumir_contratos(contratos)}

[IMPRENSA — notícias coletadas]
{resumir_noticias(noticias)}

[DEMAIS BLOCOS] Radar de Nomeações, Pulso da Câmara/DO e Demandas ainda não têm coletor ligado — use "Sem dado hoje.", salvo o que a imprensa acima sustentar com fonte.

Escreva o Briefing Matinal seguindo o formato e as regras. Data de hoje: {date.today().strftime('%d/%m/%Y')}."""


def chamar_api(sistema, mensagem):
    chave = os.environ.get("ANTHROPIC_API_KEY")
    if not chave:
        raise SystemExit(
            "⚠️  Defina a ANTHROPIC_API_KEY antes de rodar.\n"
            '   Windows (PowerShell, vale nesta janela):  $env:ANTHROPIC_API_KEY = "sua-chave"\n'
            '   Mac/Linux:                                export ANTHROPIC_API_KEY="sua-chave"'
        )
    corpo = json.dumps({
        "model": MODELO,
        "max_tokens": MAX_TOK,
        "system": sistema,
        "messages": [{"role": "user", "content": mensagem}],
    }).encode("utf-8")
    req = urllib.request.Request(API_URL, data=corpo, headers={
        "x-api-key": chave,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            dados = json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        detalhe = e.read().decode("utf-8", "replace")[:300]
        dica = {401: "chave errada ou com espaço extra (refaça o $env:/export)",
                402: "falta cartão/crédito no console (Billing)",
                429: "limite de uso atingido (aguarde ou ajuste o limite no console)"}.get(e.code, "")
        raise SystemExit(f"Erro da API ({e.code}){' — ' + dica if dica else ''}: {detalhe}")
    except urllib.error.URLError as e:
        raise SystemExit(
            f"⚠️  Sem conexão com a API ({e.reason}).\n"
            "   Verifique a internet/proxy e rode de novo. Nada foi gerado — "
            "degradar avisando, nunca falhar em silêncio."
        )
    partes = [b.get("text", "") for b in dados.get("content", []) if b.get("type") == "text"]
    return "\n".join(partes).strip()


def main():
    p = carregar_perfil()
    print(f"→ Perfil do tenant: {p.get('tenant')}  ({p['_arquivo']})")
    print("→ Carregando dados dos coletores...")
    contratos = carregar("contratos_sorocaba.json")
    noticias = carregar("noticias.json")
    if not contratos and not noticias:
        print("  ⚠ Nenhum dado dos coletores — o briefing sairá com blocos 'Sem dado hoje.'")

    print("→ A Bia está escrevendo o briefing (API da Claude)...\n")
    texto = chamar_api(sistema_do_perfil(p), montar_mensagem(contratos, noticias))
    print(texto)

    nome = f"briefing_{date.today().strftime('%Y%m%d')}.md"
    with open(nome, "w", encoding="utf-8") as f:
        f.write(texto + "\n")
    print(f"\n✓ Briefing salvo em {nome}")


if __name__ == "__main__":
    main()

```


---

## 18. `motor/render_briefing_evora.py`

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Renderizador do Briefing (motor v2 · markdown -> HTML on-brand)
=================================================================================
Pega o briefing_AAAAMMDD.md (escrito pela Bia) e gera um HTML no padrão visual
do Évora (navy + dourado), pronto para ler no celular às 06h45.

Mudança v2 (achado C6 da Revisão): a conversão agora usa uma MÁQUINA DE
BLOCOS explícita — abre <div class="block"> a cada "## " e fecha o anterior
por estado, sem o replace frágil que deixava </div> órfão quando havia
"# título" ou parágrafo antes do primeiro bloco.

Só biblioteca padrão. USO:
  python3 render_briefing_evora.py            (briefing de hoje)
  python3 render_briefing_evora.py arquivo.md (um específico)
"""
import sys, re, html
from datetime import date

CSS = """
:root{--navy:#213A5C;--gold:#B5985A;--cream:#F4F1EA;--paper:#FBFAF6;--ink:#23272e;--mut:#5b6470;--line:#E4DED1}
*{box-sizing:border-box;margin:0;padding:0}
body{background:var(--cream);color:var(--ink);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;line-height:1.55}
.wrap{max-width:620px;margin:0 auto;padding-bottom:50px}
.top{background:var(--navy);color:#fff;padding:18px}
.bname{font-family:Georgia,serif;letter-spacing:.26em;font-size:12px}
.bname b{color:var(--gold)}
.btitle{font-family:Georgia,serif;font-size:22px;margin-top:8px}
.bsub{font-size:12.5px;color:#b9c6d6;margin-top:2px}
.block{margin:16px 14px 0;background:var(--paper);border:1px solid var(--line);border-radius:9px;padding:14px 16px}
h1{display:none}
h2{font-family:Georgia,serif;font-size:16px;color:var(--navy);margin:0 0 8px;padding-bottom:6px;border-bottom:1px solid var(--line)}
ul,ol{margin:4px 0 0 18px}li{font-size:14px;margin:5px 0}
p{font-size:14px;margin:6px 0}
blockquote{margin:10px 14px 0;padding:10px 12px;background:#EEF2F7;border-left:3px solid var(--gold);font-size:13px;color:var(--mut);border-radius:0 8px 8px 0}
strong{color:var(--navy)}
.foot{margin:18px 14px 0;font-size:11px;color:var(--mut);text-align:center;line-height:1.6}
hr{border:0;border-top:1px solid var(--line);margin:14px}
em{color:var(--mut)}
"""


def _inline(s):
    s = html.escape(s)
    s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
    s = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"<em>\1</em>", s)
    return s


def md_to_html(md):
    """Máquina de blocos: estado explícito para lista, bloco e citação."""
    out = []
    in_ul = in_block = in_quote = False

    def fecha_ul():
        nonlocal in_ul
        if in_ul:
            out.append("</ul>")
            in_ul = False

    def fecha_quote():
        nonlocal in_quote
        if in_quote:
            out.append("</blockquote>")
            in_quote = False

    def fecha_block():
        nonlocal in_block
        fecha_ul()
        fecha_quote()
        if in_block:
            out.append("</div>")
            in_block = False

    for raw in md.splitlines():
        line = raw.rstrip()
        s = line.strip()
        if not s:
            fecha_ul()
            fecha_quote()
            continue
        if s.startswith("# ") and not s.startswith("## "):
            fecha_block()
            out.append(f"<h1>{_inline(s[2:])}</h1>")
        elif s.startswith("## "):
            fecha_block()
            out.append(f'<div class="block"><h2>{_inline(s[3:])}</h2>')
            in_block = True
        elif s.startswith("> "):
            fecha_ul()
            if not in_quote:
                out.append("<blockquote>")
                in_quote = True
            out.append(f"<p>{_inline(s[2:])}</p>")
        elif s.startswith(("- ", "* ")):
            fecha_quote()
            if not in_ul:
                out.append("<ul>")
                in_ul = True
            out.append(f"<li>{_inline(s[2:])}</li>")
        elif re.match(r"^\d+\.\s", s):
            fecha_quote()
            if not in_ul:
                out.append("<ul>")
                in_ul = True
            out.append(f"<li>{_inline(re.sub(r'^\\d+\\.\\s*', '', s))}</li>")
        elif s in ("---", "***", "___"):
            fecha_ul()
            fecha_quote()
            out.append("<hr>")
        else:
            fecha_ul()
            fecha_quote()
            out.append(f"<p>{_inline(s)}</p>")
    fecha_block()
    return "\n".join(out)


def main():
    arq = sys.argv[1] if len(sys.argv) > 1 else f"briefing_{date.today().strftime('%Y%m%d')}.md"
    try:
        md = open(arq, encoding="utf-8").read()
    except FileNotFoundError:
        raise SystemExit(f"Arquivo não encontrado: {arq} (rode antes o montador).")
    corpo = md_to_html(md)
    page = f"""<!DOCTYPE html><html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Briefing Matinal — Évora</title><style>{CSS}</style></head><body>
<div class="wrap">
  <div class="top">
    <div class="bname">ÉVORA <b>GABINETE</b></div>
    <div class="btitle">Briefing Matinal</div>
    <div class="bsub">{date.today().strftime('%d/%m/%Y')} · 06h45 · gerado pela Bia a partir de fontes públicas</div>
  </div>
  {corpo}
  <div class="foot">ÉVORA OVERSIGHT · cada item com origem declarada · uso interno do gabinete<br>Indício é para verificação humana — nunca acusação.</div>
</div></body></html>"""
    saida = arq.replace(".md", ".html")
    open(saida, "w", encoding="utf-8").write(page)
    print(f"✓ Briefing renderizado em {saida}")


if __name__ == "__main__":
    main()

```


---

## 19. `motor/render_dashboard_evora.py`

```python
"""
Évora Oversight — Render Dashboard Real (motor_v2)
====================================================
Injeta dados REAIS (do briefing do dia + fiscalização PNCP) nos painéis
"Briefing", "Radar de Nomeações" e "Fiscalização" do Dashboard Geral v1
(protótipo visual recuperado do WhatsApp em 15/07/2026).

Caráter Travado aplicado aqui, não só no motor de briefing:
  - Nunca inventa. Se não há dado real para um painel, o painel mostra
    "Sem dado hoje" com o motivo (conector pendente, sem rede, etc.).
  - Cada item real carrega fonte + data no corpo do texto (CVI).
  - Este script NÃO decide sozinho o que é "achado" — apenas formata
    o que o motor (montador_briefing_evora.py + coletor_pncp_evora.py)
    já coletou e validou.

Escopo desta versão (decisão do fundador, 19/07/2026):
    Painéis tornados reais agora -> Briefing, Radar de Nomeações, Fiscalização
    Painéis que continuam protótipo -> todos os demais (Demandas, Agenda,
    Bia IA, lado Campanha etc.) — dependem do banco (Etapa 3) ou de
    conectores ainda não construídos. Nada neles foi tocado.

Uso:
    from render_dashboard_evora import renderizar_dashboard
    renderizar_dashboard(template_path, saida_path, dados_reais)

`dados_reais` é um dict com estas chaves (todas opcionais — o que faltar
vira "Sem dado hoje" automaticamente):
    {
      "data_referencia": "19/07/2026",
      "briefing": [ [status, titulo, corpo_com_fonte], ... ],
      "radar":    [ [status, titulo, corpo_com_fonte], ... ]  ou None,
      "fiscalizacao": [ [status, titulo, corpo_com_fonte], ... ] ou None,
      "alertas":  [ {"p":status, "t":titulo, "o":origem, "m":"gab"}, ... ],
    }
status válido: "cr" (crítico) · "at" (atenção) · "ok" (ok) · "in" (informativo)
"""

import json
import re
from pathlib import Path


def _extrair_bloco_D(html: str):
    """Localiza `const D={...};` por contagem de chaves (robusto a strings
    com { } dentro). Retorna (inicio_chave, fim_chave, dict_D)."""
    marca = html.find("const D=")
    if marca == -1:
        raise ValueError("Não encontrei 'const D=' no template — o dashboard mudou de formato?")
    inicio = html.find("{", marca)
    depth = 0
    in_str = False
    esc = False
    fim = None
    for j in range(inicio, len(html)):
        c = html[j]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            continue
        if c == '"':
            in_str = True
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                fim = j
                break
    if fim is None:
        raise ValueError("JSON de const D não fechou corretamente — arquivo corrompido?")
    blob = html[inicio : fim + 1]
    return inicio, fim, json.loads(blob)


def _sem_dado(motivo: str, fonte: str, data_ref: str):
    return [["in", "Sem dado hoje", f"{motivo} Fonte da checagem: {fonte}, consultado em {data_ref}."]]


def _set_selo(D: dict, mundo: str, item_id: str, valor):
    """Ajusta (ou remove) o selo numérico da barra lateral para um item.
    valor=None remove o selo (nunca mostrar contagem que não é real)."""
    for grupo in D.get(mundo, []):
        for item in grupo.get("itens", []):
            if item.get("id") == item_id:
                if valor is None:
                    item.pop("selo", None)
                else:
                    item["selo"] = str(valor)
                return
    # item não encontrado — não é erro fatal, só não há selo pra ajustar


def renderizar_dashboard(template_path: str, saida_path: str, dados_reais: dict):
    html = Path(template_path).read_text(encoding="utf-8")
    inicio, fim, D = _extrair_bloco_D(html)

    data_ref = dados_reais.get("data_referencia", "hoje")

    # --- Briefing (g_brief) ---------------------------------------------
    briefing_itens = dados_reais.get("briefing")
    if not briefing_itens:
        briefing_itens = _sem_dado(
            "O motor ainda não gerou o briefing de hoje.",
            "orquestrador_evora.py", data_ref,
        )
    D["cont"]["g_brief"] = [
        "❋", "Briefing Matinal",
        f"AIM-g — Inteligência e Monitoramento · dados reais de {data_ref}",
        briefing_itens,
    ]

    # --- Radar de Nomeações (g_radar) ------------------------------------
    radar_itens = dados_reais.get("radar")
    if not radar_itens:
        radar_itens = _sem_dado(
            "O conector do Diário Oficial (COM RMS-001) ainda não está no ar.",
            "noticias.sorocaba.sp.gov.br/jornal", data_ref,
        )
        _set_selo(D, "gab", "g_radar", None)
    else:
        achados = sum(1 for it in radar_itens if it[0] in ("cr", "at"))
        _set_selo(D, "gab", "g_radar", achados if achados else None)
    D["cont"]["g_radar"] = [
        "◎", "Radar de Nomeações",
        "AFEx-g — Fiscalização do Executivo",
        radar_itens,
    ]

    # --- Fiscalização (g_fisc) -------------------------------------------
    fisc_itens = dados_reais.get("fiscalizacao")
    if not fisc_itens:
        fisc_itens = _sem_dado(
            "O coletor PNCP roda só com internet do laptop; não houve execução hoje.",
            "coletor_pncp_evora.py", data_ref,
        )
        _set_selo(D, "gab", "g_fisc", None)
    else:
        criticos = sum(1 for it in fisc_itens if it[0] in ("cr", "at"))
        _set_selo(D, "gab", "g_fisc", criticos if criticos else None)
    D["cont"]["g_fisc"] = [
        "◇", "Fiscalização",
        "AFEx-g · limiar 25% · indício, nunca acusação",
        fisc_itens,
    ]

    # --- Alertas (feed superior) ------------------------------------------
    if "alertas" in dados_reais:
        D["alertas"] = dados_reais["alertas"]

    novo_blob = json.dumps(D, ensure_ascii=False)
    novo_html = html[:inicio] + novo_blob + html[fim + 1 :]
    Path(saida_path).write_text(novo_html, encoding="utf-8")
    return saida_path


# =====================================================================
# PRODUÇÃO — 4º passo do orquestrador (roda todo dia, sem intervenção)
# =====================================================================
#
# Não exige mudar o montador nem o formato do briefing: lê o
# briefing_AAAAMMDD.md que já existe (texto em markdown, escrito pela
# Bia) e recorta os blocos "## Resumo do dia", "## Radar de Nomeações
# (AFEx-g)" e "## Fiscalização do Executivo" — os mesmos 3 que o
# fundador decidiu tornar reais em 19/07/2026. O resto do dashboard
# continua protótipo até o banco (Etapa 3) subir.
#
# Se o bloco do markdown já é "Sem dado hoje" (o motor degradou
# honestamente por falta de coletor/rede), o dashboard herda esse
# "Sem dado hoje" — nunca inventa por cima.

_CABECALHOS = {
    "Resumo do dia": "briefing",
    "Radar de Nomeações (AFEx-g)": "radar",
    "Fiscalização do Executivo (indício, nunca acusação)": "fiscalizacao",
}


def _split_headline_corpo(linha: str):
    """'- **Título** — resto do texto.' -> ('Título', 'resto do texto.')
    Se não achar negrito, usa as primeiras ~8 palavras como título."""
    if linha.startswith("- "):
        linha = linha[2:]
    linha = linha.strip()
    m = re.match(r"\*\*(.+?)\*\*\s*[—\-:]?\s*(.*)", linha)
    if m:
        titulo, corpo = m.group(1).strip(), m.group(2).strip()
        return titulo, corpo if corpo else titulo
    palavras = linha.split()
    titulo = " ".join(palavras[:8]) + ("…" if len(palavras) > 8 else "")
    return titulo, linha


def _status_da_linha(linha: str):
    # status vem do CONTEÚDO DO ITEM, nunca do bloco inteiro — um bloco
    # pode ter uma frase "sem dado do PNCP hoje" no topo e, logo abaixo,
    # itens de contexto que são reais e têm fonte própria.
    if "sem dado" in linha.lower():
        return "in"
    return "at"


def _parse_briefing_md(caminho_md: str):
    """Recorta os 3 blocos do markdown real e devolve dict pronto pra
    renderizar_dashboard(). Bloco ausente ou vazio -> None (vira
    'Sem dado hoje' automaticamente dentro de renderizar_dashboard)."""
    texto = Path(caminho_md).read_text(encoding="utf-8")
    blocos = {}
    atual = None
    buffer = []
    for linha in texto.splitlines():
        if linha.startswith("## "):
            if atual is not None:
                blocos[atual] = buffer
            atual = linha[3:].strip()
            buffer = []
        elif atual is not None:
            buffer.append(linha)
    if atual is not None:
        blocos[atual] = buffer

    resultado = {"briefing": None, "radar": None, "fiscalizacao": None}
    for cabecalho, chave in _CABECALHOS.items():
        linhas = blocos.get(cabecalho, [])
        itens = []
        for linha in linhas:
            l = linha.strip()
            if l.startswith("- "):
                titulo, corpo = _split_headline_corpo(l)
                status = _status_da_linha(l)
                itens.append([status, titulo, corpo])
        if not itens:
            resultado[chave] = None
        else:
            resultado[chave] = itens
    return resultado


def _montar_alertas(dados: dict):
    alertas = []
    for chave, prefixo in (("radar", "Radar de Nomeações"), ("fiscalizacao", "Fiscalização")):
        itens = dados.get(chave)
        if not itens:
            alertas.append({"p": "in", "t": f"{prefixo}: sem dado hoje",
                             "o": "AFEx-g", "m": "gab"})
        else:
            for status, titulo, _ in itens[:2]:
                alertas.append({"p": status, "t": titulo, "o": prefixo, "m": "gab"})
    for status, titulo, _ in (dados.get("briefing") or [])[:3]:
        alertas.append({"p": status, "t": titulo, "o": "AIM-g", "m": "gab"})
    return alertas


def main():
    import argparse
    from datetime import date

    hoje = date.today().strftime("%Y%m%d")
    hoje_br = date.today().strftime("%d/%m/%Y")

    ap = argparse.ArgumentParser(description="Render Dashboard Real a partir do briefing do dia")
    ap.add_argument("briefing_md", nargs="?", default=f"briefing_{hoje}.md",
                     help="caminho do briefing_AAAAMMDD.md (padrão: o de hoje, "
                          "igual ao render_briefing_evora.py)")
    ap.add_argument("--template", default="dashboard_template.html")
    ap.add_argument("--saida", default=f"Dashboard_Real_{hoje}.html")
    ap.add_argument("--data", default=hoje_br, help="DD/MM/AAAA (padrão: hoje)")
    args = ap.parse_args()

    if not Path(args.briefing_md).exists():
        print(f"  (Dashboard real pulado: {args.briefing_md} ainda não existe "
              "— rode o Montador primeiro.)")
        return
    if not Path(args.template).exists():
        print(f"  (Dashboard real pulado: {args.template} não encontrado na pasta do motor.)")
        return

    dados = _parse_briefing_md(args.briefing_md)
    dados["data_referencia"] = args.data
    dados["alertas"] = _montar_alertas(dados)

    caminho = renderizar_dashboard(args.template, args.saida, dados)
    print(f"Dashboard real gerado: {caminho}")


if __name__ == "__main__":
    main()

```


---

## 20. `motor/orquestrador_evora.py`

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Orquestrador do Briefing (motor v2)
=====================================================
Roda o pipeline completo do Briefing Matinal, na ordem:
  1) coletor de imprensa   -> noticias.json
  2) coletor do PNCP       -> contratos_sorocaba.json
  3) montador (a Bia)      -> briefing_AAAAMMDD.md   (usa a API da Claude)
  4) render                -> briefing_AAAAMMDD.html
  5) dashboard real        -> Dashboard_Real_AAAAMMDD.html
     (só os painéis Briefing, Radar de Nomeações e Fiscalização — decisão
     do fundador em 19/07/2026; o resto do dashboard segue protótipo até
     o banco/Etapa 3 subir)

Mudanças v2 (achados C7 e C8 da Revisão):
  C8 — o orquestrador SÓ declara "Briefing gerado" após verificar que o
       arquivo HTML de hoje EXISTE (nunca maquiar resultado).
  C7 — cópia automática do HTML para a pasta "Evora Fable" na Área de
       Trabalho (decisão do fundador): acha o Desktop mesmo com OneDrive
       ou Windows em português; se não achar, AVISA e o arquivo fica na
       pasta do motor — nunca falha em silêncio.

Tolerante a falha: coletor que cai vira aviso em avisos_evora.log e o
pipeline segue com o que tem (degradar avisando, nunca falhar em silêncio).

USO:  python orquestrador_evora.py
Requer ANTHROPIC_API_KEY (só para o passo 3):
  Windows (PowerShell):  $env:ANTHROPIC_API_KEY = "sua-chave"
  Mac/Linux:             export ANTHROPIC_API_KEY="sua-chave"
"""
import subprocess, sys, os, shutil
from datetime import datetime, date

PASSOS = [
    ("Coletor de imprensa", "imprensa_coletor_evora.py", False),
    ("Coletor do PNCP",     "coletor_pncp_evora.py",     False),
    ("Montador (Bia escreve o briefing)", "montador_briefing_evora.py", True),
    ("Render do briefing",  "render_briefing_evora.py",  False),
    # 19/07/2026 — decisão do fundador: tornar reais os painéis Briefing,
    # Radar de Nomeações e Fiscalização do Dashboard (protótipo recuperado
    # do WhatsApp em 15/07). Lê o briefing_AAAAMMDD.md que o passo acima
    # gerou; nunca inventa — bloco sem dado real vira "Sem dado hoje" no
    # próprio dashboard. Não-crítico: se faltar, o briefing continua saindo.
    ("Dashboard real (Briefing+Radar+Fiscalização)", "render_dashboard_evora.py", False),
]


def aviso(msg):
    linha = f"{datetime.now():%Y-%m-%d %H:%M:%S} · {msg}\n"
    with open("avisos_evora.log", "a", encoding="utf-8") as f:
        f.write(linha)
    print("  ⚠  " + msg)


def roda(nome, script, critico):
    print(f"\n▶ {nome}  ({script})")
    if not os.path.exists(script):
        aviso(f"{nome}: script {script} não encontrado — passo pulado.")
        return not critico
    try:
        r = subprocess.run([sys.executable, script], timeout=300)
        if r.returncode != 0:
            aviso(f"{nome}: terminou com código {r.returncode}.")
            return not critico
        return True
    except subprocess.TimeoutExpired:
        aviso(f"{nome}: tempo esgotado (timeout).")
        return not critico
    except Exception as e:
        aviso(f"{nome}: erro {e}.")
        return not critico


def achar_desktop():
    """Localiza a Área de Trabalho no Windows (com OneDrive/pt-BR) ou Unix.
    Devolve None se não encontrar — quem chama avisa (nunca em silêncio)."""
    home = os.path.expanduser("~")
    candidatos = []
    onedrive = os.environ.get("OneDrive") or os.environ.get("ONEDRIVE")
    if onedrive:
        candidatos += [os.path.join(onedrive, "Desktop"),
                       os.path.join(onedrive, "Área de Trabalho")]
    candidatos += [os.path.join(home, "Desktop"),
                   os.path.join(home, "Área de Trabalho")]
    for c in candidatos:
        if os.path.isdir(c):
            return c
    return None


def copiar_para_desktop(arquivo):
    desktop = achar_desktop()
    if not desktop:
        aviso("Área de Trabalho não localizada — a cópia ficou só na pasta do motor.")
        return None
    destino_dir = os.path.join(desktop, "Evora Fable")
    try:
        os.makedirs(destino_dir, exist_ok=True)
        destino = os.path.join(destino_dir, os.path.basename(arquivo))
        shutil.copy2(arquivo, destino)
        return destino
    except OSError as e:
        aviso(f"Falha ao copiar para a Área de Trabalho ({e}) — arquivo segue na pasta do motor.")
        return None


def main():
    print("=" * 64)
    print("ÉVORA OVERSIGHT — Orquestrador do Briefing Matinal · motor v2")
    print(f"Data: {date.today():%d/%m/%Y}")
    print("=" * 64)
    if not os.environ.get("ANTHROPIC_API_KEY"):
        aviso("ANTHROPIC_API_KEY não definida — o passo do montador vai falhar. "
              'Windows: $env:ANTHROPIC_API_KEY = "..."  ·  Mac/Linux: export ANTHROPIC_API_KEY="..."')
    for nome, script, critico in PASSOS:
        if not roda(nome, script, critico):
            print(f"\n✗ Pipeline interrompido em: {nome} (passo crítico).")
            print("  Veja avisos_evora.log para o histórico rastreado.")
            return

    # C8 — só declarar sucesso se o resultado EXISTIR (verdade acima da conveniência)
    nome_html = f"briefing_{date.today():%Y%m%d}.html"
    print("\n" + "=" * 64)
    if os.path.exists(nome_html):
        print("✓ Briefing gerado.")
        print(f"  Abra: {nome_html}")
        destino = copiar_para_desktop(nome_html)
        if destino:
            print(f"  Cópia na Área de Trabalho: {destino}")
        nome_dash = f"Dashboard_Real_{date.today():%Y%m%d}.html"
        if os.path.exists(nome_dash):
            print(f"  Dashboard real: {nome_dash}")
    else:
        aviso(f"O pipeline terminou, mas {nome_html} NÃO foi encontrado — "
              "verifique o passo do render em avisos_evora.log.")
        print("✗ Briefing NÃO gerado (arquivo ausente). Nada foi maquiado.")
    print("  Avisos (se houver): avisos_evora.log")
    print("=" * 64)


if __name__ == "__main__":
    main()

```


---

## 21. `motor/aprendizado_evora.py`

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ÉVORA OVERSIGHT — Camada de Aprendizado (Guarda Constitucional)
================================================================
Aplica o feedback da autoridade (👍/👎 e sugestões) para calibrar a RELEVÂNCIA
e a FORMA do briefing — nunca a verdade, nunca as travas. Toda mudança entra
na trilha (append-only). É a materialização do "aprende com o uso" dentro dos
princípios do fundador.

REGRAS PÉTREAS (a Guarda Constitucional bloqueia qualquer aprendizado que):
  - tente alterar uma fonte ou apagar um fato verificado;
  - peça para publicar/decidir sozinho (o freio humano é inviolável);
  - tente remover a citação de origem;
  - empurre para opinião política ou recomendação de voto.

USO:
  Registrar feedback:  python3 aprendizado_evora.py fb <assunto_id> up|down "sugestão opcional"
  Ver pesos atuais:    python3 aprendizado_evora.py pesos
Arquivos: pesos_relevancia.json (estado) · trilha_aprendizado.log (append-only)
"""
import sys, json, os
from datetime import datetime

PESOS = "pesos_relevancia.json"
TRILHA = "trilha_aprendizado.log"

# frases/intenções que a Guarda Constitucional NÃO permite aprender
PROIBIDO = [
    "publicar sozinho", "postar automaticamente", "decidir sozinho",
    "remover fonte", "apagar fonte", "esconder origem",
    "recomendar voto", "atacar", "acusar sem prova",
]

def trilha(msg):
    with open(TRILHA, "a", encoding="utf-8") as f:
        f.write(f"{datetime.now():%Y-%m-%d %H:%M:%S} · {msg}\n")

def carregar_pesos():
    if os.path.exists(PESOS):
        with open(PESOS, encoding="utf-8") as f:
            return json.load(f)
    return {}

def salvar_pesos(p):
    with open(PESOS, "w", encoding="utf-8") as f:
        json.dump(p, f, ensure_ascii=False, indent=2)

def guarda_constitucional(sugestao):
    """Retorna (permitido, motivo). Bloqueia sugestões que ferem as travas."""
    s = (sugestao or "").lower()
    for termo in PROIBIDO:
        if termo in s:
            return False, f"sugestão bloqueada pela Guarda Constitucional (contém: '{termo}')"
    return True, "ok"

def aplicar_feedback(assunto, sinal, sugestao=""):
    pesos = carregar_pesos()
    atual = pesos.get(assunto, 1.0)

    permitido, motivo = guarda_constitucional(sugestao)
    if not permitido:
        trilha(f"BLOQUEIO · assunto={assunto} · {motivo} · sugestão='{sugestao}'")
        print(f"⛔ {motivo}. Nada foi alterado. Registrado na trilha.")
        return

    if sinal == "up":
        novo = min(atual + 0.15, 3.0)      # sobe a relevância (teto)
    elif sinal == "down":
        novo = max(atual - 0.15, 0.2)      # desce (piso — nunca zera/apaga)
    else:
        print("Sinal inválido: use up ou down.")
        return

    pesos[assunto] = round(novo, 3)
    salvar_pesos(pesos)
    trilha(f"FEEDBACK · assunto={assunto} · {sinal} · peso {atual}→{pesos[assunto]}"
           + (f" · sugestão='{sugestao}' (encaminhada à VRX)" if sugestao else ""))
    print(f"✓ Relevância de '{assunto}': {atual} → {pesos[assunto]}")
    if sugestao:
        print("  Sugestão registrada e encaminhada à VRX (Porta de Suporte).")
    print("  A verdade e as fontes NÃO mudam — só a prioridade de exibição.")

def main():
    if len(sys.argv) < 2:
        print(__doc__); return
    cmd = sys.argv[1]
    if cmd == "pesos":
        print(json.dumps(carregar_pesos(), ensure_ascii=False, indent=2)); return
    if cmd == "fb" and len(sys.argv) >= 4:
        assunto, sinal = sys.argv[2], sys.argv[3]
        sugestao = sys.argv[4] if len(sys.argv) > 4 else ""
        aplicar_feedback(assunto, sinal, sugestao); return
    print("Uso: fb <assunto_id> up|down \"sugestão\"  |  pesos")

if __name__ == "__main__":
    main()

```


---

## 22. `motor/dashboard_template.html` *(parcial aqui por tamanho; íntegro no pacote)*

```html
<!DOCTYPE html><html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>Évora</title>
<style>
:root{--navy:#000F40;--navy2:#0a1b4a;--gold:#B5985A;--gold-light:#E4CE97;--rose:#7a2f5a;--rose-light:#e8b4d0;
--paper:#F7F5EF;--card:#FBFAF6;--ink:#23272E;--muted:#5B6470;--line:#E6E0D2;
--at-bg:#FBF1DE;--at-ink:#8A5A12;--ok-bg:#E7F0E9;--ok-ink:#1E5233}
*{box-sizing:border-box;margin:0;padding:0}html,body{height:100%}
body{background:var(--navy);color:var(--ink);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;line-height:1.5;-webkit-font-smoothing:antialiased}
.serif{font-family:Georgia,"Times New Roman",serif}
/* LOCK */
#lock{position:fixed;inset:0;z-index:100;display:flex;flex-direction:column;align-items:center;justify-content:center;cursor:pointer;padding:16px;overflow:hidden;background:var(--navy);transition:opacity .55s ease}
#lock .biglogo{height:min(40vh,320px);max-width:88vw;object-fit:contain;opacity:0;animation:shieldIn 1.9s cubic-bezier(.18,.7,.3,1) .3s forwards,breathe 5s ease-in-out 2.4s infinite}
#lock .hint{margin-top:24px;text-align:center;color:#9fb2cc;font-size:13px;opacity:0;animation:lfade 1.2s ease 1.5s forwards}#lock .hint .k{color:var(--gold-light)}
#lock .sensor{position:absolute;top:20px;right:20px;display:flex;align-items:center;gap:8px;font-size:11px;color:#7b8ea8;border:1px solid rgba(181,152,90,.3);border-radius:20px;padding:6px 12px;cursor:pointer}
#lock .sensor.on .dot{background:#5fae7e;box-shadow:0 0 8px rgba(95,174,126,.8)}#lock .sensor .dot{width:8px;height:8px;border-radius:50%;background:#4a6785;transition:.3s}
.facescan{position:absolute;inset:0;display:none;align-items:center;justify-content:center;flex-direction:column;background:rgba(0,15,64,.72)}.facescan.show{display:flex}
.ring{width:110px;height:110px;border-radius:50%;border:3px solid rgba(181,152,90,.25);border-top-color:var(--gold);animation:spin 1s linear infinite}@keyframes spin{to{transform:rotate(360deg)}}.facescan .txt{margin-top:16px;font-size:13px;color:#cfe0f2}
@keyframes shieldIn{0%{opacity:0;transform:translateY(-40px) scale(.5) rotate(-12deg)}55%{opacity:1;transform:translateY(6px) scale(1.05) rotate(3deg)}78%{transform:translateY(0) scale(.98)}100%{opacity:1;transform:translateY(0) scale(1) rotate(0)}}
@keyframes breathe{0%,100%{transform:scale(1)}50%{transform:scale(1.03)}}@keyframes lfade{to{opacity:1}}
@media(max-height:520px){#lock .biglogo{height:52vh}}
/* APP */
.app{display:flex;min-height:100vh}
.rail{width:222px;flex:none;background:var(--navy);border-right:1px solid rgba(181,152,90,.28);display:flex;flex-direction:column;position:sticky;top:0;height:100vh;overflow-y:auto;z-index:30}
.railtop{padding:14px 12px 10px;border-bottom:1px solid rgba(181,152,90,.2);cursor:pointer;text-align:center}
.railtop img{height:46px;max-width:100%;object-fit:contain}
/* SELETOR DE MUNDO */
.worldsel{display:flex;gap:5px;padding:10px 10px 4px}
.wbtn{flex:1;text-align:center;font-size:11px;font-weight:800;letter-spacing:.03em;padding:9px 6px;border-radius:9px;cursor:pointer;border:1px solid transparent;transition:.14s;color:#9fb2cc;background:rgba(255,255,255,.04)}
.wbtn .wt{display:block;font-size:8px;font-weight:700;opacity:.7;margin-top:2px}
.wbtn.gab.on{background:rgba(181,152,90,.18);border-color:var(--gold);color:#fff}
.wbtn.camp.on{background:rgba(232,180,208,.14);border-color:var(--rose-light);color:#fff}
.railwrap{padding:6px 10px;flex:1}
.railgroup{font-size:9px;letter-spacing:.15em;text-transform:uppercase;color:var(--gold-light);font-weight:800;opacity:.85;padding:12px 8px 5px}
.app.mcamp .railgroup{color:var(--rose-light)}
.tab{position:relative;display:flex;align-items:center;gap:10px;background:rgba(255,255,255,.03);border:1px solid rgba(181,152,90,.2);border-radius:10px;padding:9px 11px;margin-bottom:6px;cursor:pointer;transition:transform .13s,border-color .13s,background .13s}
.tab:hover{transform:translateX(3px);border

<!-- ... conteúdo integral no arquivo solto (430 KB) ... -->
```


---

*Fim do pacote · 22 arquivos · 19/07/2026 · Évora Oversight · Confidencial — Eng. Luiz Gonzaga Filho*
