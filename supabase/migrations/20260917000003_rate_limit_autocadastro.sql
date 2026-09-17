-- Espelho INCREMENTAL de:
--   ao-SUPABASE-BLOCO1/AO SUPABASE BLOCO1.md.txt (tabela evora_rate_limit)
--   ao-SUPABASE-BLOCO1/evora rls mvp v1.sql (enable/force RLS em evora_rate_limit)
--   ao-SUPABASE-BLOCO1/evora auth mvp v1.sql (evora_checar_rate_limite +
--     evora_verificar_vereador/evora_autocadastro_vereador chamando o freio)
-- NAO EDITAR AQUI. Editar os arquivos canonicos acima e copiar de novo.
--
-- Manual v11.0: freio de abuso pras 2 RPCs anônimas que recebem e-mail
-- (evora_verificar_vereador/evora_autocadastro_vereador) — sem isso, dava
-- pra martelar e-mails em sequência tentando enumerar o roster de
-- municipio_vereadores. Contador de curto prazo, sem policy de acesso
-- (ausência é a proteção, mesmo padrão de municipio_vereadores/aegis_cofre).

create table if not exists evora_rate_limit (
  chave         text primary key,
  tentativas    int not null default 1,
  janela_inicio timestamptz not null default now()
);
comment on table evora_rate_limit is 'Contador de tentativas por janela de tempo, pras RPCs anônimas de autocadastro. Sem policy de acesso — só evora_checar_rate_limite (security definer) toca aqui.';

alter table evora_rate_limit enable row level security;
alter table evora_rate_limit force row level security;

create or replace function evora_checar_rate_limite(p_chave text, p_limite int, p_janela interval)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tentativas    int;
  v_janela_inicio timestamptz;
begin
  select tentativas, janela_inicio into v_tentativas, v_janela_inicio
    from public.evora_rate_limit
   where chave = p_chave
     for update;

  if not found then
    insert into public.evora_rate_limit (chave) values (p_chave);
    return;
  end if;

  if now() - v_janela_inicio > p_janela then
    update public.evora_rate_limit
       set tentativas = 1, janela_inicio = now()
     where chave = p_chave;
    return;
  end if;

  if v_tentativas >= p_limite then
    raise exception 'Muitas tentativas em pouco tempo — aguarde um pouco antes de tentar de novo.';
  end if;

  update public.evora_rate_limit
     set tentativas = tentativas + 1
   where chave = p_chave;
end;
$$;

comment on function evora_checar_rate_limite is
  'Freio de abuso por janela de tempo — levanta exceção se p_chave já bateu p_limite tentativas dentro de p_janela. Usado por evora_verificar_vereador/evora_autocadastro_vereador contra martelamento das RPCs anônimas de autocadastro.';

revoke execute on function evora_checar_rate_limite(text, int, interval) from public, anon, authenticated;

create or replace function evora_verificar_vereador(p_municipio_id uuid, p_email text)
returns table(elegivel boolean, nome text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.evora_checar_rate_limite('vereador:' || lower(p_email), 10, interval '15 minutes');

  return query
  select true, v.nome
    from public.municipio_vereadores v
   where v.municipio_id = p_municipio_id
     and v.ativo
     and lower(v.email) = lower(p_email)
   limit 1;
end;
$$;

create or replace function evora_autocadastro_vereador(p_municipio_id uuid, p_email text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nome      text;
  v_uf        text;
  v_municipio text;
  v_slug      text;
  v_tenant_id uuid;
begin
  perform public.evora_checar_rate_limite('vereador:' || lower(p_email), 10, interval '15 minutes');

  select v.nome into v_nome
    from public.municipio_vereadores v
   where v.municipio_id = p_municipio_id
     and v.ativo
     and lower(v.email) = lower(p_email)
   limit 1;

  if v_nome is null then
    raise exception 'E-mail não consta na lista de vereadores verificados desta cidade.';
  end if;

  if exists (select 1 from public.usuarios where lower(email) = lower(p_email)) then
    raise exception 'Já existe cadastro com este e-mail.';
  end if;

  select nome, uf into v_municipio, v_uf
    from public.municipios
   where id = p_municipio_id;

  v_slug := lower(regexp_replace(v_nome || '-' || v_municipio, '[^a-zA-Z0-9]+', '-', 'g'))
            || '-' || substr(gen_random_uuid()::text, 1, 6);

  insert into public.tenants (slug, nome_autoridade, cargo, municipio_sede, uf)
  values (v_slug, v_nome, 'vereador(a)', v_municipio, v_uf)
  returning id into v_tenant_id;

  insert into public.usuarios (tenant_id, nome, email, papel, mundo_permitido, alcada_aprovacao)
  values (v_tenant_id, v_nome, p_email, 'autoridade', null, true);

  return v_tenant_id;
end;
$$;
