-- =====================================================================================================
-- Torre de Controle de Produção — Menzoil · esquema do Supabase (Postgres)
-- Como usar: Supabase → SQL Editor → cole este arquivo inteiro → Run. É seguro rodar de novo (idempotente).
-- =====================================================================================================
-- Modelo:
--   perfis     uma linha por pessoa (liga em auth.users): nome, administrador?, ativo?, permissões, campos e travas de filtro.
--   registros  todos os dados da ferramenta (itens, pedidos, linhas do plano, paradas, refugos…), um registro por linha,
--              com VERSÃO (detecção de conflito) e SEQUÊNCIA global (sincronização incremental e tempo real).
-- Segurança:
--   • Só quem está autenticado E ativo lê os dados (RLS).
--   • NINGUÉM escreve direto na tabela de dados: toda gravação passa pela função aplicar_lote(), que confere permissão,
--     versão (conflito) e a trava de linha com produção apontada (só administrador altera a programação).
--   • Conta nova nasce INATIVA (aguardando liberação). A primeira conta criada vira administradora.
-- =====================================================================================================

-- ---------- tabelas ----------
create table if not exists public.perfis (
  id            uuid primary key references auth.users(id) on delete cascade,
  email         text not null,
  nome          text not null,
  admin         boolean not null default false,
  ativo         boolean not null default false,
  permissoes    jsonb not null default '{}'::jsonb,
  campos        jsonb not null default '{}'::jsonb,
  travas        jsonb not null default '{}'::jsonb,
  criado_em     timestamptz not null default now(),
  ultimo_acesso timestamptz
);

create sequence if not exists public.registros_seq;
create table if not exists public.registros (
  colecao             text not null,
  chave               text not null,
  dados               jsonb not null,
  versao              bigint not null default 1,
  seq                 bigint not null default nextval('public.registros_seq'),
  apagado             boolean not null default false,
  atualizado_por      uuid,
  atualizado_por_nome text,
  atualizado_em       timestamptz not null default now(),
  primary key (colecao, chave)
);
create index if not exists registros_seq_idx on public.registros (seq);

-- ---------- funções auxiliares (security definer: leem perfis sem depender da RLS) ----------
create or replace function public.esta_ativo() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select ativo from public.perfis where id = auth.uid()), false)
$$;

create or replace function public.eh_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select ativo and admin from public.perfis where id = auth.uid()), false)
$$;

-- pode gravar dados: administrador, ou quem tem "edição" em pelo menos uma tela
create or replace function public.pode_editar() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select ativo and (admin or exists (select 1 from jsonb_each_text(permissoes) e where e.value = 'edicao'))
                   from public.perfis where id = auth.uid()), false)
$$;

-- número seguro a partir de um campo JSON (texto não numérico vira 0)
create or replace function public.num_json(j jsonb, campo text) returns numeric
language sql immutable as $$
  select case when (j->>campo) ~ '^-?[0-9]+(\.[0-9]+)?$' then (j->>campo)::numeric else 0 end
$$;

-- mesma regra de "linha com produção apontada" usada na ferramenta
create or replace function public.linha_produzida(d jsonb) returns boolean
language sql immutable as $$
  select public.num_json(d,'actualQtyUnits') > 0 or public.num_json(d,'turno1') > 0 or public.num_json(d,'turno2') > 0 or public.num_json(d,'turno3') > 0
      or (coalesce(d->>'status','') <> '' and d->>'status' <> 'Planejado')
$$;

create or replace function public.unidades_produzidas(d jsonb) returns numeric
language sql immutable as $$
  select greatest(public.num_json(d,'actualQtyUnits'), public.num_json(d,'turno1') + public.num_json(d,'turno2') + public.num_json(d,'turno3'))
$$;

-- não-administrador, em linha COM produção: não pode mudar data nem recurso, nem aumentar a quantidade,
-- nem reduzi-la abaixo do que já foi produzido (reduzir até o produzido é o caminho "Reprogramar pendência")
create or replace function public.viola_trava(velho jsonb, novo jsonb) returns boolean
language sql immutable as $$
  select (velho->>'date') is distinct from (novo->>'date')
      or (velho->>'resource') is distinct from (novo->>'resource')
      or not (public.num_json(novo,'batchUnits') <= public.num_json(velho,'batchUnits')
          and public.num_json(novo,'batchUnits') >= public.unidades_produzidas(velho))
$$;

-- ---------- gravação em lote com controle de versão ----------
-- ops: [{colecao, chave, tipo:'upsert'|'delete', base_versao, dados}]
-- devolve, para cada op: {ok,versao,seq} | {conflito,atual:{dados,versao,apagado}} | {erro,atual}
create or replace function public.aplicar_lote(ops jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  op jsonb; r public.registros%rowtype; achou boolean;
  saida jsonb := '[]'::jsonb; res jsonb;
  uid uuid := auth.uid(); eh_adm boolean; meu_nome text;
  col text; ch text; tp text; base bigint; novos jsonb; atual jsonb; nova_seq bigint;
  colecoes text[] := array['items','recipes','resources','orders','plan','paradas','refugos','locaisGranel','motivosParada','prioridades','removidasComProducao','config'];
begin
  if not public.pode_editar() then raise exception 'sem_permissao' using errcode = '42501'; end if;
  if jsonb_typeof(ops) <> 'array' then raise exception 'ops_invalidas'; end if;
  if jsonb_array_length(ops) > 1000 then raise exception 'lote_grande'; end if;
  eh_adm := public.eh_admin();
  select nome into meu_nome from public.perfis where id = uid;

  for op in select * from jsonb_array_elements(ops) loop
    col := op->>'colecao'; ch := op->>'chave'; tp := op->>'tipo'; base := nullif(op->>'base_versao','')::bigint; novos := op->'dados';
    if col is null or ch is null or not (col = any(colecoes)) then
      saida := saida || jsonb_build_array(jsonb_build_object('erro','colecao_invalida')); continue;
    end if;
    select * into r from public.registros where colecao = col and chave = ch for update;
    achou := found;
    atual := case when achou then jsonb_build_object('dados', r.dados, 'versao', r.versao, 'apagado', r.apagado) else null end;
    res := null;

    if tp = 'upsert' then
      if novos is null or jsonb_typeof(novos) <> 'object' then res := jsonb_build_object('erro','dados_invalidos');
      elsif not achou then
        nova_seq := nextval('public.registros_seq');
        insert into public.registros (colecao, chave, dados, versao, seq, apagado, atualizado_por, atualizado_por_nome)
          values (col, ch, novos, 1, nova_seq, false, uid, meu_nome);
        res := jsonb_build_object('ok', true, 'versao', 1, 'seq', nova_seq);
      elsif r.apagado then
        if base is null then   -- recriação de um registro que tinha sido removido
          nova_seq := nextval('public.registros_seq');
          update public.registros set dados = novos, versao = r.versao + 1, seq = nova_seq, apagado = false, atualizado_por = uid, atualizado_por_nome = meu_nome, atualizado_em = now()
            where colecao = col and chave = ch;
          res := jsonb_build_object('ok', true, 'versao', r.versao + 1, 'seq', nova_seq);
        else res := jsonb_build_object('conflito', true, 'atual', atual);
        end if;
      elsif base is null or base <> r.versao then
        res := jsonb_build_object('conflito', true, 'atual', atual);
      elsif col = 'plan' and not eh_adm and public.linha_produzida(r.dados) and public.viola_trava(r.dados, novos) then
        res := jsonb_build_object('erro', 'linha_travada', 'atual', atual);
      else
        nova_seq := nextval('public.registros_seq');
        update public.registros set dados = novos, versao = r.versao + 1, seq = nova_seq, atualizado_por = uid, atualizado_por_nome = meu_nome, atualizado_em = now()
          where colecao = col and chave = ch;
        res := jsonb_build_object('ok', true, 'versao', r.versao + 1, 'seq', nova_seq);
      end if;

    elsif tp = 'delete' then
      if not achou or r.apagado then
        res := jsonb_build_object('ok', true, 'versao', case when achou then r.versao else 0 end, 'seq', case when achou then r.seq else 0 end);
      elsif col = 'plan' and not eh_adm and public.linha_produzida(r.dados) then
        res := jsonb_build_object('erro', 'linha_travada', 'atual', atual);
      else
        nova_seq := nextval('public.registros_seq');
        update public.registros set apagado = true, versao = r.versao + 1, seq = nova_seq, atualizado_por = uid, atualizado_por_nome = meu_nome, atualizado_em = now()
          where colecao = col and chave = ch;
        res := jsonb_build_object('ok', true, 'versao', r.versao + 1, 'seq', nova_seq);
      end if;
    else
      res := jsonb_build_object('erro', 'tipo_invalido');
    end if;
    saida := saida || jsonb_build_array(res);
  end loop;
  return saida;
end $$;

-- registra o acesso (último login) do próprio usuário
create or replace function public.registrar_acesso() returns void
language sql security definer set search_path = public as $$
  update public.perfis set ultimo_acesso = now() where id = auth.uid()
$$;

-- limpeza periódica de registros apagados há mais de N dias (só administrador)
create or replace function public.limpar_registros_apagados(dias int default 30) returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if not public.eh_admin() then raise exception 'sem_permissao' using errcode = '42501'; end if;
  delete from public.registros where apagado and atualizado_em < now() - make_interval(days => dias);
  get diagnostics n = row_count; return n;
end $$;

-- ---------- novas contas ----------
create or replace function public.criar_perfil_novo_usuario() returns trigger
language plpgsql security definer set search_path = public as $$
declare primeiro boolean;
begin
  select not exists (select 1 from public.perfis) into primeiro;   -- a primeira conta vira administradora e já nasce ativa
  insert into public.perfis (id, email, nome, admin, ativo)
    values (new.id, new.email, coalesce(nullif(new.raw_user_meta_data->>'nome',''), new.email), primeiro, primeiro)
    on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists ao_criar_usuario on auth.users;
create trigger ao_criar_usuario after insert on auth.users for each row execute function public.criar_perfil_novo_usuario();

-- nunca deixar o sistema sem administrador ativo
create or replace function public.proteger_ultimo_admin() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (tg_op = 'DELETE' and old.admin and old.ativo) or (tg_op = 'UPDATE' and old.admin and old.ativo and not (new.admin and new.ativo)) then
    if not exists (select 1 from public.perfis where admin and ativo and id <> old.id) then
      raise exception 'ultimo_admin' using hint = 'Deve existir pelo menos um administrador ativo.';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $$;
drop trigger if exists proteger_admin_upd on public.perfis;
create trigger proteger_admin_upd before update or delete on public.perfis for each row execute function public.proteger_ultimo_admin();

-- ---------- segurança por linha (RLS) ----------
alter table public.perfis enable row level security;
alter table public.registros enable row level security;

drop policy if exists perfis_leitura on public.perfis;
create policy perfis_leitura on public.perfis for select to authenticated using (id = auth.uid() or public.eh_admin());
drop policy if exists perfis_admin_atualiza on public.perfis;
create policy perfis_admin_atualiza on public.perfis for update to authenticated using (public.eh_admin()) with check (public.eh_admin());
drop policy if exists perfis_admin_exclui on public.perfis;
create policy perfis_admin_exclui on public.perfis for delete to authenticated using (public.eh_admin());
drop policy if exists registros_leitura on public.registros;
create policy registros_leitura on public.registros for select to authenticated using (public.esta_ativo());
-- (sem policies de insert/update/delete em registros: a escrita só acontece por aplicar_lote)

-- ---------- permissões (privilégios) ----------
revoke all on public.registros from anon, authenticated;
revoke all on public.perfis from anon, authenticated;
grant select on public.registros to authenticated;
grant select, delete on public.perfis to authenticated;
grant update (nome, admin, ativo, permissoes, campos, travas) on public.perfis to authenticated;
grant usage on schema public to anon, authenticated;
revoke execute on function public.aplicar_lote(jsonb) from public, anon;
revoke execute on function public.registrar_acesso() from public, anon;
revoke execute on function public.limpar_registros_apagados(int) from public, anon;
grant execute on function public.aplicar_lote(jsonb) to authenticated;
grant execute on function public.registrar_acesso() to authenticated;
grant execute on function public.limpar_registros_apagados(int) to authenticated;

-- ---------- tempo real ----------
do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin alter publication supabase_realtime add table public.registros; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.perfis; exception when duplicate_object then null; end;
  end if;
end $$;
