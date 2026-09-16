-- Espelho INCREMENTAL de: ao-SUPABASE-BLOCO1/evora rls mvp v1.sql
-- (seção 18 — evora_registrar_travessia).
-- NAO EDITAR AQUI. Editar o arquivo canonico acima e copiar de novo.
-- Depende de 20260818000002_rls.sql já aplicada (evora_tenant_atual,
-- evora_claims, evora_ve_os_dois_mundos, tabela auditoria e sua policy
-- de insert).
--
-- TRAVESSIA DE MUNDO (Ponte Bia↔Nil) — a única travessia sancionada entre
-- gabinete e campanha (Princípio Inviolável nº 4, "separação de mundos")
-- acontece na aplicação e fica registrada aqui, na trilha imutável. Esta
-- função NÃO altera o token — a policy de cada tabela continua conferindo
-- tenant_id/mundo do próprio JWT; ela só autoriza e REGISTRA a travessia.
-- A aplicação usa o valor de volta pra decidir de qual mundo pedir dado
-- na sessão. Só quem legitimamente enxerga os dois mundos
-- (evora_ve_os_dois_mundos) pode atravessar — mesmo idioma de
-- evora_valida_ciencia_briefing: plpgsql comum, sem security definer,
-- porque tudo que a função faz (ler usuarios, inserir em auditoria) o
-- próprio chamador authenticated já pode fazer direto — ela só acrescenta
-- a validação e o registro em uma chamada só.

create or replace function evora_registrar_travessia(p_mundo evora_mundo)
returns evora_mundo language plpgsql as $$
declare
  v_tenant     uuid := evora_tenant_atual();
  v_usuario_id uuid;
  v_papel      text;
begin
  if v_tenant is null then
    raise exception 'Sem identidade no token. Refaça o login.';
  end if;

  select u.id, u.papel::text into v_usuario_id, v_papel
  from usuarios u
  where u.auth_user_id = nullif(evora_claims() ->> 'sub', '')::uuid
    and u.ativo;

  if v_usuario_id is null then
    raise exception 'Usuário sem cadastro ativo.';
  end if;

  -- Apenas quem legitimamente vê os dois mundos pode atravessar.
  if not evora_ve_os_dois_mundos() then
    raise exception 'Seu papel (%) não tem acesso aos dois mundos.', coalesce(v_papel, 'indefinido');
  end if;

  insert into auditoria (tenant_id, mundo, ator_id, acao, detalhe)
  values (
    v_tenant,
    p_mundo,
    v_usuario_id,
    'travessia_ponte',
    jsonb_build_object('para', p_mundo, 'papel', v_papel)
  );

  return p_mundo;
end $$;

comment on function evora_registrar_travessia(evora_mundo) is
  'Registra na trilha imutável a travessia entre gabinete e campanha (Ponte Bia↔Nil). Recusa quem não tem os dois mundos. Não altera o token — a aplicação usa o retorno para pedir dado do mundo escolhido na sessão.';

revoke execute on function evora_registrar_travessia(evora_mundo) from anon;
grant execute on function evora_registrar_travessia(evora_mundo) to authenticated;
