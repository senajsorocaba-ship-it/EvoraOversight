-- Espelho INCREMENTAL de: ao-SUPABASE-BLOCO1/evora auth mvp v1.sql
-- (renomeia o hook de token).
-- NAO EDITAR AQUI. Editar o arquivo canonico acima e copiar de novo.
-- Depende de 20260818000004_auth.sql e 20260823000001_fix_grants_padrao.sql
-- já aplicadas.
--
-- Alinha o nome ao "Caderno do Programador" (acompanha o Manual Supremo
-- v11.0, 16/09/2026), que documenta a função como `evora_token_hook` — o
-- nome que este projeto tinha dado a ela (`custom_access_token_hook`) era
-- só uma convenção comum de exemplos do Supabase, não um requisito. Um
-- ALTER FUNCTION RENAME preserva corpo, comentário e grants — não precisa
-- recriar nada disso.
--
-- PASSO MANUAL PENDENTE, fora deste arquivo: se o hook já estiver
-- ativado no painel (Authentication > Hooks) de algum projeto Supabase,
-- é preciso reapontar a seleção para `public.evora_token_hook` depois
-- deste rename — senão o Auth continua chamando um nome que não existe
-- mais e todo login para de funcionar (falha fechada: nega tudo, não dá
-- erro visível óbvio). Neste projeto, até a data desta migration, o hook
-- nunca foi ativado em nenhum projeto na nuvem — só testado localmente,
-- onde a seleção é refeita a cada `supabase db reset` de qualquer forma.

-- IDEMPOTENTE de propósito: um `alter function ... rename` cru quebra se
-- este arquivo for replayado contra um banco onde o rename já teve efeito
-- antes por outro caminho (ex.: Supabase Preview Branches clonando um
-- projeto onde as migrations foram coladas manualmente no SQL Editor, sem
-- o histórico de `supabase db push` — então o replay do zero tropeça aqui
-- mesmo o banco de origem já estando com o nome novo). Guarda por
-- `to_regprocedure` em vez de confiar que a troca nunca rodou antes.
do $$
begin
  if to_regprocedure('public.evora_token_hook(jsonb)') is not null then
    raise notice 'evora_token_hook(jsonb) já existe — rename pulado (idempotente).';
  elsif to_regprocedure('public.custom_access_token_hook(jsonb)') is not null then
    execute 'alter function custom_access_token_hook(jsonb) rename to evora_token_hook';
  else
    raise notice 'Nem custom_access_token_hook nem evora_token_hook existem neste banco — nada a renomear aqui.';
  end if;

  if to_regprocedure('public.evora_token_hook(jsonb)') is not null then
    execute $c$comment on function evora_token_hook is
      'Hook de Auth do Supabase (ativar em Authentication > Hooks no painel — ver BLOCO_5_AUTENTICACAO.md). Injeta tenant_id/mundo no app_metadata do JWT a partir de usuarios, a cada emissão de token.'$c$;
  end if;
end $$;
