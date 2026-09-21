# CATÁLOGO DE FONTES — FARUS E VERITAS

**Extrato do Anexo 26 do Manual Supremo v11.3** · 20 de setembro de 2026
Évora Oversight · Confidencial — Eng. de Sistemas Luiz Gonzaga Filho

> **Este documento é extrato.** A versão que vale é a do Manual. Se houver diferença, prevalece o
> Manual.

> **Em resumo:** todas as fontes que alimentam o acervo de fatos (FARUS) e o acervo de normas (Veritas), com o estado de verificação de cada uma. Fonte não verificada não sustenta afirmação.

### §1 — O critério que separa os dois acervos

| | **FARUS** | **Veritas** |
| --- | --- | --- |
| Guarda | o que **aconteceu** | o que **vale** |
| Exemplos | ato publicado, contrato, despesa, sessão | lei, regimento, resolução, súmula |
| Envelhece | não — vira histórico | **sim — norma revogada engana** |
| Origem | coleta automática | **carga curada, com pessoa** |

**Uma mesma instituição pode alimentar os dois.** A ANA, por exemplo, publica **normas de referência** para o saneamento (Veritas) e **dados** sobre ele (FARUS). O que decide o destino é a natureza do conteúdo, não quem o publicou.

### §2 — Os três estados de uma fonte

| Estado | Significado | Pode sustentar afirmação? |
| --- | --- | --- |
| ✅ **Verificada** | Endereço, formato e acesso confirmados nesta construção | **sim**, após liberação humana (D6) |
| ☐ **A verificar** | Instituição conhecida; ponto de coleta ainda não confirmado | **não** |
| ⛔ **Descontinuada** | Existiu, parou de ser atualizada | **não — produz conclusão sobre dado congelado** |

> **"A verificar" não é defeito — é honestidade.** Listar a instituição registra que ela interessa. Afirmar que o ponto de coleta existe, sem ter conferido, seria exatamente o que a Cláusula de Caráter proíbe.

---

### §3 — MUNICÍPIO DE SOROCABA

| Fonte | Endereço | Acervo | Estado |
| --- | --- | --- | --- |
| **Câmara Sem Papel — legislação** | `sorocaba.camarasempapel.com.br/legislacao/` | **Veritas** | ✅ |
| **Câmara Sem Papel — sessões e pautas** | `sorocaba.camarasempapel.com.br/spl/sessoes.aspx` | **FARUS** | ✅ |
| **Diário Oficial do Município** | `noticias.sorocaba.sp.gov.br/jornal` · PDF, edições numeradas | **FARUS** | ✅ |
| Portal da Câmara | `camarasorocaba.sp.gov.br` | FARUS | ☐ |
| Portal da Transparência da Prefeitura | — | FARUS | ☐ |

**Conteúdo obrigatório do Veritas para o tenant zero:** Regimento Interno (**Resolução nº 322, de 18/09/2007**) · Lei Orgânica do Município · resoluções e decretos legislativos vigentes.

> #### ⚠️ Correção registrada nesta versão
>
> O Diário Oficial de Sorocaba **já constava como fonte confirmada** em versão anterior deste Manual. Documentos posteriores o listaram, por erro, como pendência — *"descobrir a plataforma do Diário Oficial"*. **Não era pendência.** A fonte está confirmada; o que falta é **construir o conector**.

---

### §4 — CONTROLE EXTERNO

#### Tribunal de Contas do Estado de São Paulo — fonte de maior valor para fiscalização

**O TCE-SP audita as 644 prefeituras paulistas, exceto a Capital.** Para fiscalizar o Executivo de Sorocaba, pode valer mais que o PNCP: é o órgão que audita a Prefeitura, com toda a despesa, toda semana.

| Fonte | Endereço | Conteúdo | Acervo | Estado |
| --- | --- | --- | --- | --- |
| **Portal da Transparência Municipal** | `transparencia.tce.sp.gov.br` | Receita, despesa, fornecedores por município | FARUS | ✅ |
| **Conjunto de dados — Despesas** | `transparencia.tce.sp.gov.br/conjunto-de-dados` | **CSV, atualização semanal, desde 2008** | FARUS | ✅ |
| **APIs** | mesmo portal | acesso legível por máquina | FARUS | ✅ existe · ☐ contrato de uso |
| Análises Audesp | mesmo portal | LRF, ensino, saúde, pessoal — mensal | FARUS | ✅ |
| **Relatórios de alerta** | mesmo portal | situações desfavoráveis ou irregulares na gestão | FARUS | ✅ |
| **Painel de transferências especiais** | `tce.sp.gov.br/paineis-tcesp` | **"emendas pix"** da União e do Estado | FARUS | ✅ |
| Observatório Fiscal | mesmo | receitas e despesas por área e programa | FARUS | ✅ |
| Painel de Obras · Saneamento · Dívida Ativa | mesmo | painéis temáticos | FARUS | ✅ existe · ☐ formato |
| Súmulas, deliberações, jurisprudência | `tce.sp.gov.br` | entendimento da Corte | **Veritas** | ☐ |

> **Três destaques para o produto:**
>
> **Os relatórios de alerta** são o próprio tribunal apontando problema na gestão. Para o bloco de Fiscalização do Executivo, é fonte oficial de indício — não é o Évora afirmando.
>
> **O painel de emendas pix** mostra recurso transferido ao município. É matéria de fiscalização direta do mandato.
>
> **A busca por fornecedor** permite cruzar quem contratou com a Prefeitura — o mesmo cruzamento que produziu o indício das três dispensas.

| Outras instâncias | Relevância | Acervo | Estado |
| --- | --- | --- | --- |
| Tribunal de Contas da União | recurso federal repassado ao município | FARUS | ☐ |
| Controladoria-Geral da União | Portal da Transparência federal, transferências | FARUS | ☐ |
| Ministério Público de São Paulo | ações e inquéritos envolvendo o município | FARUS | ☐ |

---

### §5 — COMPRAS PÚBLICAS E PREÇOS

| Fonte | Endereço | Uso | Acervo | Estado |
| --- | --- | --- | --- | --- |
| **PNCP** | `pncp.gov.br` | contratações de todos os entes | FARUS | ✅ **conector funcionando** |
| **Pesquisa de Preços Lite** | `pesquisaprecos.compras.gov.br` | compras federais homologadas, 12 meses | FARUS | ✅ |
| Dados abertos Compras.gov.br | `dadosabertos.compras.gov.br` | preços por material e serviço | FARUS | ✅ |
| **SINAPI** — Caixa e IBGE | — | custo de referência da construção civil | FARUS | ✅ |
| **SICRO** — DNIT | — | custo de referência de obras rodoviárias | FARUS | ✅ |
| **Painel de Preços** | `paineldeprecos.planejamento.gov.br` | — | — | ⛔ **parado em 04/07/2025** |

**Base legal do SINAPI:** art. 23 da Lei nº 14.133/2021 — custos unitários de obras iguais ou inferiores à mediana do SINAPI.

**Limite de dispensa vigente:** R$ 65.492,11 para outros serviços e compras, **por órgão, por exercício e por objeto** — Decreto nº 12.807/2025.

---

### §6 — AGÊNCIAS REGULADORAS FEDERAIS

**Critério de inclusão:** competência que toca serviço prestado ou fiscalizado no município. O vereador não regula esses setores — mas **fiscaliza como o município os presta ou concede**, e cobra quando o cidadão é prejudicado.

| Agência | Setor | Por que interessa ao gabinete municipal | Acervo | Estado |
| --- | --- | --- | --- | --- |
| **ANA** | Águas e saneamento | **Edita normas de referência para o saneamento**, que orientam a regulação local | **Veritas** + FARUS | ☐ |
| **ANEEL** | Energia elétrica | Iluminação pública é serviço municipal; qualidade do fornecimento | Veritas + FARUS | ☐ |
| **ANATEL** | Telecomunicações | Instalação de antenas (uso do solo é municipal); cobertura | Veritas + FARUS | ☐ |
| **ANVISA** | Vigilância sanitária | A vigilância sanitária municipal atua sob normas federais | **Veritas** | ☐ |
| **ANS** | Saúde suplementar | Reclamações de munícipes contra planos de saúde | FARUS | ☐ |
| **ANTT** | Transporte terrestre | Transporte intermunicipal e interestadual que atende a cidade | FARUS | ☐ |
| **ANAC** | Aviação civil | Aeroporto local, quando houver | FARUS | ☐ |
| **ANP** | Petróleo e combustíveis | Preço e qualidade de combustível; frota pública | FARUS | ☐ |
| **ANM** | Mineração | Atividade minerária no território; impacto ambiental | FARUS | ☐ |
| **ANPD** | Proteção de dados | **Rege o próprio Évora**; tratamento de dados pela Prefeitura | **Veritas** | ☐ |
| ANTAQ | Transporte aquaviário | baixa, salvo município com hidrovia | — | ☐ |
| ANCINE | Audiovisual | baixa | — | ☐ |

> **A ANPD é caso à parte.** Além de fonte para fiscalizar a Prefeitura, **suas normas regem o próprio Évora** — tratamento de dados de gabinete, de munícipes e de campanha. É leitura obrigatória para o jurídico do projeto, não só para os agentes.

---

### §7 — AGÊNCIAS E ÓRGÃOS DO ESTADO DE SÃO PAULO

| Órgão | Por que interessa | Acervo | Estado |
| --- | --- | --- | --- |
| **ARSESP** — agência reguladora de saneamento e energia | Regula saneamento e gás em municípios conveniados | Veritas + FARUS | ☐ |
| **ARTESP** — agência de transportes | Rodovias concedidas e transporte intermunicipal na região | FARUS | ☐ |
| **ALESP** — Assembleia Legislativa | Legislação estadual que afeta o município | **Veritas** | ☐ |
| **CETESB** — companhia ambiental | Licenciamento e áreas contaminadas no território | FARUS | ☐ |
| Diário Oficial do Estado | Atos estaduais que afetam o município | FARUS | ☐ |

---

### §8 — LEGISLAÇÃO FEDERAL

| Fonte | Conteúdo | Acervo | Estado |
| --- | --- | --- | --- |
| **Planalto** — legislação | Constituição, leis, decretos federais | **Veritas** | ☐ |
| LexML | Portal integrado de legislação e jurisprudência | **Veritas** | ☐ |
| Diário Oficial da União | Atos federais — **prazo registrado: antes de fev/2027** | FARUS | ☐ |
| Câmara dos Deputados — dados abertos | Proposições federais — **mesmo prazo** | FARUS | ☐ |
| Senado Federal — dados abertos | Proposições federais | FARUS | ☐ |

**Normas de uso diário do gabinete, a carregar no Veritas:** Lei nº 14.133/2021 (licitações) · Lei nº 12.527/2011 (acesso à informação) · Lei nº 13.709/2018 (proteção de dados) · Lei Complementar nº 101/2000 (responsabilidade fiscal) · Lei nº 14.026/2020 (marco do saneamento).

---

### §9 — DADOS E ESTATÍSTICA

| Fonte | Uso | Acervo | Estado |
| --- | --- | --- | --- |
| **IBGE** | População, censo, indicadores municipais | FARUS | ☐ |
| **Tesouro Nacional — SICONFI** | Finanças municipais declaradas | FARUS | ☐ |
| DATASUS | Saúde por município | FARUS | ☐ |
| INEP | Educação — IDEB, censo escolar | FARUS | ☐ |
| FNDE | Repasses para educação | FARUS | ☐ |
| Fundação Seade | Projeções e indicadores paulistas | FARUS | ✅ usada na definição do beta |

---

### §10 — IMPRENSA

**Levantados em campo, com o gabinete zero.** Classificação F1 ou F2 alterável a qualquer tempo, com registro.

| Veículo | Natureza | Estado |
| --- | --- | --- |
| **Cruzeiro do Sul** | impresso · `cruzeirodosul.inf.br` | ☐ verificar edição digital |
| **ZNorte** | impresso | ☐ verificar edição digital |
| **Jornal Olá** | impresso | ☐ verificar edição digital |
| **Jovem Pan** | rádio | ☐ verificar formato |
| Instagram e postagens | redes sociais | ☐ regra própria do Manual |

> **O coletor atual usa RSS do Google Notícias** — funciona para demonstrar, mas é intermediário, não a fonte. **Precisa ser refeito** para ler cada veículo diretamente.

---

### §11 — ELEITORAL

| Fonte | Uso | Estado |
| --- | --- | --- |
| Tribunal Superior Eleitoral | Normas eleitorais — Modo Vigilância Eleitoral do Veritas | ☐ |
| TSE — dados abertos | Resultados por seção e zona — mapa de calor | ☐ **Mundo Campanha desligado no beta** |

---

### §12 — PRIORIDADE DE CONSTRUÇÃO

| # | Conector | Por quê |
| --- | --- | --- |
| 1 | **Agenda Legislativa** | Fonte verificada · 4 dias de antecedência · substitui trabalho manual |
| 2 | **TCE-SP — despesas e alertas** | **Dado oficial semanal, com alerta do próprio tribunal** |
| 3 | **Diário Oficial de Sorocaba** | Fonte confirmada · nomeações e decretos só saem lá |
| 4 | Carga do Veritas | Regimento e Lei Orgânica, com o extrator já testado |
| 5 | Imprensa por veículo | Substitui o intermediário atual |

> **O TCE-SP entra em segundo lugar por uma razão concreta:** o alerta do tribunal é indício com fonte oficial de controle externo. O Évora não precisa inferir nada — o próprio órgão de controle já apontou. É o indício mais defensável que o produto pode oferecer.

### §13 — Regra de manutenção deste anexo

**Toda fonte nova entra aqui antes de entrar no banco.** Com endereço, acervo de destino e estado de verificação. **Fonte que sai de uso é marcada ⛔ e permanece listada** — o que ela sustentou no passado continua valendo com o selo da data da coleta.

---

*Catálogo de Fontes · extrato do Anexo 26 do Manual Supremo v11.3*
*Évora Oversight · Confidencial — Eng. de Sistemas Luiz Gonzaga Filho*
*Protegido pelas Leis nº 9.610/98 e nº 9.609/98*
