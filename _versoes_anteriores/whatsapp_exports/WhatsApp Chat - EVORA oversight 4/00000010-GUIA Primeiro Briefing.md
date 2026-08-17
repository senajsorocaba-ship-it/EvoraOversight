# Guia — Primeiro Briefing Real do Évora (atualizado v9.9)

Este guia leva você do zero ao primeiro briefing real da Tatiane. Siga na ordem.

## Parte 1 — Conseguir a chave da API (uma vez só)

1. Acesse **console.anthropic.com** e faça login (é a conta de desenvolvedor, separada do app Claude).
2. Verifique o telefone por SMS (pode liberar ~US$5 de crédito de teste).
3. **Settings → Billing:** adicione um cartão, ponha um crédito pequeno (US$5) e um limite mensal (ex.: US$10). *Sem billing, a chave existe mas as chamadas falham.*
4. **API Keys → Create Key:** dê o nome **Evora-Briefing** e crie.
5. **Copie a chave imediatamente** (aparece uma vez só; começa com `sk-ant-`). Guarde em lugar seguro.

## Parte 2 — Preparar a máquina (uma vez só)

```bash
# ter Python 3.10+ instalado
cd caminho/para/motor
pip install -r requirements.txt
```

## Parte 3 — Rodar o briefing

```bash
# 1) colar a chave (troque pela sua)
export ANTHROPIC_API_KEY="sk-ant-XXXXXXXX"

# 2) rodar o orquestrador (coleta + Bia escreve + renderiza)
python3 orquestrador_evora.py

# 3) o briefing sai em HTML na pasta de saída (abra no navegador)
```

## O que este motor já traz (atualizado)

- **Perfil da Tatiane:** temas reais (cultura, educação, segurança, proteção à mulher, misoginia), variações do nome.
- **5 jornais de Sorocaba:** Cruzeiro do Sul, Z Norte (Sorocabanices), Jornal Ipanema, Giro Sorocaba, Portal Porque.
- **Diário Oficial** via COM (noticias.sorocaba.sp.gov.br/jornal).
- **Fiscalização** com limiar de 25% (ajustável).
- **Blocos do briefing:** Resumo · Radar de Nomeações · Fiscalização · Pulso da Câmara/DO · Demandas · Imprensa · Movimento sugerido (72h).
- **Caráter travado:** sem invenção, fonte declarada (CVI), "não sei" é válido, freio humano.

## Se der erro

- **401 (não autorizado):** chave errada ou com espaço extra ao colar. Refaça o export.
- **402 / billing:** falta cartão/crédito no console. Volte à Parte 1, passo 3.
- **Sem resultado de alguma fonte:** o motor degrada avisando e segue com as demais (não trava).

## Ordem honesta de expectativa

No primeiro briefing, a coleta de alguns jornais pode vir parcial (sites variam). O Diário Oficial e a imprensa via agregador vêm de primeira. Isso é o esperado — a qualidade por fonte melhora na fase COM (conector direto por veículo).
