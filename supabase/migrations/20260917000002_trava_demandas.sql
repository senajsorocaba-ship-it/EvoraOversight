-- Espelho INCREMENTAL de:
--   ao-SUPABASE-BLOCO1/AO SUPABASE BLOCO1.md.txt (coluna tenants.demandas_parecer_juridico)
--   ao-SUPABASE-BLOCO1/evora rls mvp v1.sql (seção 19 — TRAVA DO MÓDULO DEMANDAS)
-- NAO EDITAR AQUI. Editar os arquivos canonicos acima e copiar de novo.
--
-- "Caderno do Programador" (acompanha o Manual Supremo v11.0, 16/09/2026):
-- o módulo Demandas fica desligado até haver parecer jurídico, porque
-- trata dado pessoal de cidadão (nome, contato, geolocalização) sem esse
-- parecer concluído. A coluna guarda a decisão por tenant; a trigger é o
-- que a torna real — bloqueia insert/update em demandas enquanto
-- demandas_parecer_juridico for false. Não trava SELECT: dado fictício de
-- teste que já exista continua legível.

alter table tenants add column if not exists demandas_parecer_juridico boolean not null default false;
comment on column tenants.demandas_parecer_juridico is 'Caderno do Programador v11.0: módulo Demandas fica travado (nenhum insert/update em demandas) até isto virar true — decisão humana registrada, nunca automática.';

create or replace function evora_travar_demandas_sem_parecer()
returns trigger language plpgsql as $$
declare
  v_liberado boolean;
begin
  select t.demandas_parecer_juridico into v_liberado
  from tenants t
  where t.id = new.tenant_id;

  if not coalesce(v_liberado, false) then
    raise exception 'Módulo Demandas aguarda parecer jurídico (Caderno do Programador v11.0) — habilite tenants.demandas_parecer_juridico para liberar a escrita neste gabinete.';
  end if;

  return new;
end $$;

comment on function evora_travar_demandas_sem_parecer is
  'Bloqueia insert/update em demandas enquanto tenants.demandas_parecer_juridico for false. Módulo desligado até parecer jurídico (Caderno do Programador v11.0).';

drop trigger if exists trg_demandas_trava_juridica on demandas;
create trigger trg_demandas_trava_juridica
  before insert or update on demandas
  for each row execute function evora_travar_demandas_sem_parecer();
