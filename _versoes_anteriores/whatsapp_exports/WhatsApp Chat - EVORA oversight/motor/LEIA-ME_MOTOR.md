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
