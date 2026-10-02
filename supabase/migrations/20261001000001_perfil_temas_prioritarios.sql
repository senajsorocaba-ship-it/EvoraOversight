-- Espelho INCREMENTAL de:
--   ao-SUPABASE-BLOCO1/evora rls mvp v1.sql (seção 24 — Perfil do
--     Gabinete / autoatendimento)
-- NAO EDITAR AQUI. Editar o arquivo canonico acima e copiar de novo.
--
-- Tela de Configurações (web/src/components/assuntos-interesse.tsx):
-- deixa o próprio gabinete definir perfil.temas_prioritarios, usado por
-- evora_motor_execucao.py:montar_prompt_sistema no briefing diário. Única
-- brecha deliberada em tenants_sem_escrita_pelo_cliente (seção 1) — a
-- função só toca a chave temas_prioritarios dentro de perfil, nunca abre
-- escrita geral na tabela tenants.

create or replace function evora_atualizar_temas_prioritarios(p_temas text[])
returns text[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant  uuid := public.evora_tenant_atual();
  v_limpos  text[];
begin
  if v_tenant is null then
    raise exception 'Sem gabinete identificado — faça login novamente.';
  end if;

  select coalesce(array_agg(t order by ord), '{}')
    into v_limpos
    from (
      select t, ord
        from (
          select trim(x) as t, ordinality as ord
            from unnest(coalesce(p_temas, '{}'::text[])) with ordinality as u(x, ordinality)
        ) bruto
       where t <> '' and length(t) <= 80
       order by ord
       limit 25
    ) final;

  update public.tenants
     set perfil = jsonb_set(coalesce(perfil, '{}'::jsonb), '{temas_prioritarios}', to_jsonb(v_limpos))
   where id = v_tenant;

  return v_limpos;
end;
$$;

comment on function evora_atualizar_temas_prioritarios is
  'Autoatendimento do gabinete: grava perfil.temas_prioritarios (lido por evora_motor_execucao.py no briefing diário). Única escrita permitida em tenants pelo cliente — tudo mais continua bloqueado por tenants_sem_escrita_pelo_cliente (seção 1).';

revoke execute on function evora_atualizar_temas_prioritarios(text[]) from public, anon;
grant execute on function evora_atualizar_temas_prioritarios(text[]) to authenticated;
