# Spike — Sistema da Câmara de Sorocaba (Tarefa 2, Briefing Técnico Guiron 13/11/2026)

Investigação feita em 16–17/11/2026, buscando páginas reais do sistema
**Câmara Sem Papel** (`sorocaba.camarasempapel.com.br`). Nenhuma credencial do
gabinete (SAP) foi usada — só páginas públicas. Prova de leitura real anexa:
`spike_pauta_camara.py` + `pauta_20261117.json` (sessão Ordinária Nº 73,
17/11/2026, 1 matéria real extraída).

## Dado × onde está × formato × login × observação

| Dado | Onde está | Formato | Login? | Observação |
|---|---|---|---|---|
| Lista de sessões | [`/spl/sessoes.aspx`](https://sorocaba.camarasempapel.com.br/spl/sessoes.aspx) | HTML | Não | Mostra as 10 mais recentes por página; paginação é `__doPostBack` (JS), não seguível com fetch simples — não dá pra saber o total sem um browser real |
| Pauta de uma sessão (matérias) | [`/spl/sessao-leitura.aspx?id=<id>&tip=1`](https://sorocaba.camarasempapel.com.br/spl/sessao-leitura.aspx?id=1343&tip=1) | HTML | Não | Confirmado campo a campo: ordem, nº processo, autor, ementa, fase, ação. Partido do autor **não** aparece aqui |
| Texto/detalhe do processo | `/processo.aspx?id=<id>` | HTML | Não | Só o link foi usado nesta investigação, conteúdo não extraído |
| Filtro por autor | `/spl/consulta-producao.aspx?autor=<id>` | HTML | Não | Existe, confirmada a URL; não testada em profundidade |
| Lista de comissões | [`/spl/comissoes.aspx`](https://sorocaba.camarasempapel.com.br/spl/comissoes.aspx) | HTML (lista) | Não | ~22 Permanentes + ~23 Especiais, legislatura 2025–2028 |
| Composição de 1 comissão | [`/spl/comissao.aspx?id=179`](https://sorocaba.camarasempapel.com.br/spl/comissao.aspx?id=179) | HTML | Não | Nome, partido, cargo (Presidente/Membro), período, status — confirmado só na Comissão de Justiça (1 de ~45) |
| Histórico por ano (proposições) | [`/spl/consulta-cronologico.aspx`](https://sorocaba.camarasempapel.com.br/spl/consulta-cronologico.aspx) | HTML (índice) | Não | Lista anos 1999–2026 com lacunas (sem 2006, 2008). Teste em 1999 voltou **0** proposições — não confirma dado real nessa época |
| "Ordem do Dia Resumida/Atualizada" | Link direto no site | **PDF** | Não | Fora do escopo deste spike — extrair de PDF é outro problema técnico |
| robots.txt | [`/robots.txt`](https://sorocaba.camarasempapel.com.br/robots.txt) | texto | — | **Totalmente aberto**: `User-agent: *` / `Allow: /`, sem Disallow, sem crawl-delay |

## As 7 perguntas, direto

1. **API/portal de dados abertos?** Não é uma API formal — é um portal público (Câmara Sem Papel), sem autenticação nas páginas acima. [`sessoes.aspx`](https://sorocaba.camarasempapel.com.br/spl/sessoes.aspx)
2. **Pauta, proposições, tramitação, comissões, autoria?** Pauta/proposições/tramitação/autoria: confirmados em [`sessao-leitura.aspx`](https://sorocaba.camarasempapel.com.br/spl/sessao-leitura.aspx?id=1343&tip=1). Comissões: confirmadas em [`comissoes.aspx`](https://sorocaba.camarasempapel.com.br/spl/comissoes.aspx) + [`comissao.aspx?id=179`](https://sorocaba.camarasempapel.com.br/spl/comissao.aspx?id=179)
3. **Formato?** HTML em tudo, exceto a Ordem do Dia Resumida/Atualizada (PDF)
4. **Precisa de login?** Não, em nenhuma página verificada — nenhuma credencial do SAP foi usada
5. **robots.txt / termos / limite de requisição?** [`robots.txt`](https://sorocaba.camarasempapel.com.br/robots.txt) libera tudo (`Allow: /`). **Nenhuma página de termos de uso foi encontrada** (rodapé só tem aviso de copyright). Sem limite de requisição declarado em lugar nenhum
6. **Filtra por autor?** Sim — `autor` vem em cada matéria, e existe `consulta-producao.aspx?autor=<id>` dedicada
7. **Até que ano vai o histórico?** Não confirmado com certeza. O índice de proposições em [`consulta-cronologico.aspx`](https://sorocaba.camarasempapel.com.br/spl/consulta-cronologico.aspx) lista até 1999, mas o teste nesse ano voltou 0 resultados — pode não ter dado real tão antigo. Sessões (não propostas): só dá pra ver as mais recentes, a paginação em JS impede medir a profundidade real sem um navegador de verdade

## O que NÃO foi encontrado / não deu pra confirmar

- Página de termos de uso ou política de uso (não existe, ou não está visível)
- Limite real de requisições (rate limit) — não declarado
- Profundidade real do histórico de **sessões** (só de proposições há um índice por ano, com lacunas e sem confirmação de dado antigo)
- Composição das outras ~44 comissões (só 1 foi conferida, pelo padrão confirmado deve funcionar igual nas demais, mas não foi testado)
- Partido do autor na página da sessão (teria que cruzar com `parlamentar.aspx` ou `consulta-producao.aspx`)
