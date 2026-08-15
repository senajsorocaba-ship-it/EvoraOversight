# CLAUDE.md — Motor do Briefing Évora Oversight

> Este arquivo dá a você (Claude Code) o contexto do projeto. Leia antes de agir.

## O que é este projeto

Este é o **motor do Briefing Matinal do Évora Oversight** — uma plataforma de inteligência política legislativa. O motor lê fontes públicas (Diário Oficial de Sorocaba, PNCP, jornais) e gera um **briefing diário em HTML** para a vereadora Tatiane Costa (Sorocaba/SP).

O dono do projeto é o Luiz (engenheiro, fundador). Trate-o com honestidade técnica direta, em português do Brasil. **Nunca invente resultados** — se uma fonte falhar, diga que falhou. Esse é um princípio do projeto (a "Cláusula de Caráter Travado").

## Objetivo desta sessão

Rodar o pipeline completo e produzir o **primeiro briefing real**. Ordem:
1. Confirmar que o Python 3.10+ está disponível (`python3 --version`).
2. Configurar a chave da API como variável de ambiente (o dono vai fornecer).
3. Rodar `python3 orquestrador_evora.py`.
4. Se der erro, ler o traceback e corrigir; explicar cada passo ao dono.
5. Abrir/mostrar o HTML gerado.

## Dependências

**Nenhuma instalação necessária.** O motor usa SOMENTE a biblioteca padrão do Python 3 (urllib, json, xml, subprocess, statistics, datetime). Não rode `pip install` — não é preciso. Só confirme que há Python 3.10 ou superior.

## A chave da API (essencial)

O passo 3 do pipeline (a "Bia" escrever o briefing) chama a API da Anthropic e **exige** a variável de ambiente `ANTHROPIC_API_KEY`.

- O dono vai fornecer a chave (`sk-ant-...`). Configure assim (macOS/Linux):
  ```
  export ANTHROPIC_API_KEY="sk-ant-...aqui..."
  ```
- **Nunca** grave a chave em nenhum arquivo do projeto, nem em logs, nem a repita de volta na conversa. Ela fica só na sessão de terminal.
- Os passos 1, 2 e 4 (coletores e render) **não** precisam da chave — só o passo 3.

## Os arquivos (o que cada um faz)

- `orquestrador_evora.py` — **rode este**. Executa o pipeline na ordem: coletor de imprensa → coletor PNCP → montador (Bia) → render. É tolerante a falha: se um coletor falha (rede/fonte fora), registra em `avisos_evora.log` e segue com o que tem (degrada avisando, nunca falha em silêncio).
- `imprensa_coletor_evora.py` — coleta notícias dos 5 jornais de Sorocaba (Cruzeiro do Sul, Z Norte/Sorocabanices, Jornal Ipanema, Giro Sorocaba, Portal Porque) via agregador. Gera `noticias.json`.
- `coletor_pncp_evora.py` — coleta contratos/licitações do PNCP. Gera `contratos_sorocaba.json`.
- `montador_briefing_evora.py` — a **Bia**: usa a API da Claude para escrever o briefing a partir do que foi coletado. Gera `briefing_AAAAMMDD.md`. (precisa da chave)
- `render_briefing_evora.py` — transforma o .md no `briefing_AAAAMMDD.html` final (é o que o dono abre no navegador).
- `aprendizado_evora.py` — camada que registra feedback para o sistema melhorar com o uso.
- `perfil_tatiane.json` — o perfil do tenant: temas reais da vereadora (cultura, educação, segurança, proteção à mulher, misoginia), variações do nome, os 5 jornais, limiar de fiscalização de 25%, Diário Oficial via COM. **Não invente dados aqui; use o que está no arquivo.**
- `perfil_tenant_modelo.json` — modelo em branco para novos tenants.
- `GUIA_Primeiro_Briefing.md` — o passo a passo humano (para o dono).
- `LEIA-ME_MOTOR.md` — visão geral do motor.

## Comando principal

```
python3 orquestrador_evora.py
```

Saída esperada: um arquivo `briefing_AAAAMMDD.html` na pasta. Abra-o para ver o briefing.

## Como lidar com erros (o que provavelmente aparece)

- **`ANTHROPIC_API_KEY` não definida / erro 401**: a chave não foi exportada ou tem espaço extra. Reexporte e rode de novo.
- **Erro de billing / 402**: falta crédito/cartão no console.anthropic.com (Settings → Billing). Avise o dono.
- **Coletor sem resultado (rede/site)**: NÃO é falha crítica. O motor registra em `avisos_evora.log` e segue. Alguns jornais podem vir parciais no primeiro run — isso é esperado; relate ao dono quais vieram e quais não.
- **Rede corporativa/proxy bloqueando**: se todas as coletas falharem, verifique conexão/proxy antes de mexer no código.

## Regras de conduta nesta sessão

- Honestidade acima de tudo: se algo não funcionou, diga claramente — não maquie o resultado.
- Não altere a lógica do pipeline sem explicar ao dono e pedir confirmação. Pode corrigir bugs óbvios (imports, typos), mas mudanças de comportamento precisam de OK.
- Explique cada passo em português, de forma direta e técnica.
- Ao terminar, mostre o caminho do HTML gerado e um resumo do que entrou (quais fontes responderam) e do que ficou pendente (o que está em `avisos_evora.log`).
