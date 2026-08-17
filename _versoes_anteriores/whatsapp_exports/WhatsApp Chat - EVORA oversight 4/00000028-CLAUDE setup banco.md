# CLAUDE.md — Setup do Banco de Dados do Évora (núcleo do MVP)

> Contexto para o Claude Code. Leia antes de agir. Português do Brasil, honestidade técnica.

## O que é

Este é o **núcleo do banco de dados do Évora Oversight**, uma plataforma de inteligência política legislativa (SaaS multi-tenant). O objetivo desta sessão é **criar o banco no Supabase** a partir dos dois arquivos SQL desta pasta.

Dono: Luiz (fundador, aprendendo a codar). Trate com franqueza técnica, explique cada passo.

## Os arquivos

- `evora_schema_mvp_v1.sql` — cria as 12 tabelas do núcleo (tenants, usuarios, fontes, briefings, demandas, lugares, compromissos, atas, desdobramentos, desdobramento_eventos, auditoria) + tipos e índices.
- `evora_rls_mvp_v1.sql` — ativa a **segurança de isolamento (RLS)**: as travas que impedem um cliente/mundo de ver dados de outro. É o coração da separação de mundos.

**Ordem obrigatória:** rodar primeiro o schema, depois o RLS (o RLS depende das tabelas existirem).

## Princípios que este banco respeita (não quebrar)

1. **Multi-tenant:** toda linha pertence a um `tenant_id` (cliente).
2. **Separação de mundos:** tabelas de conteúdo têm `mundo` (gabinete/campanha). O RLS garante que um mundo nunca vê o outro.
3. **Dois níveis de separação:** `tenants.nivel_separacao` = `logico` (padrão/MVP) ou `fisico` (premium). O schema serve aos dois sem mudança.
4. **LGPD preparada:** a tabela `demandas` já tem campos de consentimento, base legal, dado sensível e retenção — a preencher conforme parecer jurídico (perguntas 8 e 9, ainda pendentes). NÃO usar dados reais de cidadãos até o parecer; testar com dados fictícios.
5. **Nada é apagado:** soft delete (campos `ativo`/`ativa`) em vez de DELETE. A tabela `auditoria` é imutável (só INSERT).

## Passo a passo para criar no Supabase

### 1. Criar o projeto no Supabase
- Acesse **supabase.com**, faça login, crie um **New Project**.
- **Region:** escolha **South America (São Paulo)** — os dados ficam no Brasil (LGPD). *(Se a advogada confirmar exigência de dados no Brasil, isto já atende; se não, ainda é a escolha segura.)*
- Guarde a senha do banco num lugar seguro.

### 2. Rodar o schema
- No painel do Supabase, vá em **SQL Editor → New query**.
- Cole todo o conteúdo de `evora_schema_mvp_v1.sql` e clique em **Run**.
- Verifique em **Table Editor** que as 12 tabelas apareceram.

### 3. Rodar o RLS
- Nova query no SQL Editor.
- Cole todo o conteúdo de `evora_rls_mvp_v1.sql` e **Run**.
- Verifique em **Authentication → Policies** que as políticas foram criadas.

### 4. Teste rápido (com dados fictícios)
- Insira um tenant de teste, um usuário, uma fonte no mundo 'gabinete' e outra no mundo 'campanha'.
- Confirme que, simulando uma sessão do mundo 'campanha', a fonte do 'gabinete' NÃO aparece. **Esse é o teste de separação** — a prova que vira argumento de venda.

## Se der erro

- **"type already exists"**: você já rodou o schema antes. Ou apague as tabelas/tipos e rode limpo, ou ignore se as tabelas já estão certas.
- **"permission denied" no RLS**: normal — o RLS está funcionando (bloqueando acesso sem o tenant/mundo no token). Para testar via SQL Editor como admin, o Supabase usa o papel `service_role` que ignora RLS; o isolamento vale para as requisições autenticadas da aplicação.
- **Erro de sintaxe**: os dois arquivos foram validados por um parser PostgreSQL real. Se houver erro, é provável cópia incompleta — cole o arquivo inteiro.

## O que NÃO fazer nesta fase

- Não conectar dados reais de cidadãos (aguarda parecer LGPD — perguntas 8 e 9).
- Não construir ainda o mundo campanha completo (financeiro AFC-p), documentos/OCR, CRM — são fase 2.
- Não alterar a lógica de separação sem entender o impacto nos dois níveis.

## Próximo passo depois do banco

Com o banco no ar, o próximo tijolo é ligar a **primeira tela real** (sugestão: Briefing ou Demandas) a estas tabelas, via a API do Supabase. Peça ao Luiz por onde começar.
