-- Afterdark — migração: ficha criada na entrada da mesa vira personagem da conta.
--
-- Antes, a ficha feita no assistente da mesa ficava só na participação (table_members);
-- quem tinha conta não a encontrava em "Personagens" e não podia reutilizá-la.
-- Agora, sempre que uma participação com conta (user_id) tem ficha, o personagem é criado
-- em characters para essa conta, uma única vez por participação:
--   * vale para fichas novas, para quem entrou como visitante e depois vinculou a conta,
--     e (passo 3) para as fichas que já existem;
--   * não duplica: se a conta já tem um personagem com o mesmo nome (ex.: escolheu um
--     personagem pronto do Perfil), nada é criado;
--   * se o jogador apagar o personagem do Perfil, ele não volta sozinho;
--   * a foto da ficha da mesa é copiada para o personagem enquanto ele não tiver foto.
-- Rodar no SQL Editor do Supabase (pode rodar mais de uma vez).

-- 1) Registro das participações já sincronizadas (garante "uma única vez")
create table if not exists public._ad_member_char_sync (
  member_id uuid primary key,
  character_id uuid,
  created_at timestamptz not null default now()
);
alter table public._ad_member_char_sync enable row level security;
revoke all on public._ad_member_char_sync from public, anon, authenticated;

-- 2) Sincronização de uma participação
create or replace function public._ad_member_to_character(p_member_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare m record; v_cid uuid; v_data jsonb; v_role text; v_sync record;
begin
  select tm.id, tm.user_id, tm.char_name, tm.char_data, tm.photo, t.name as table_name, t.owner_id
    into m
    from public.table_members tm join public.tables t on t.id = tm.table_id
   where tm.id = p_member_id;
  if not found or m.user_id is null or coalesce(trim(m.char_name), '') = ''
     or m.char_data is null or jsonb_typeof(m.char_data) <> 'object' or m.owner_id = m.user_id then
    return null;
  end if;

  select * into v_sync from public._ad_member_char_sync where member_id = m.id;
  if found then
    -- já sincronizada: só completa a foto, se o personagem ainda existir e estiver sem foto
    if v_sync.character_id is not null and m.photo is not null then
      update public.characters set data = data || jsonb_build_object('photo', m.photo)
       where id = v_sync.character_id and owner_id = m.user_id and coalesce(data->>'photo', '') = '';
    end if;
    return v_sync.character_id;
  end if;

  -- a conta já tem um personagem com esse nome: é o mesmo personagem, não duplica
  select id into v_cid from public.characters
   where owner_id = m.user_id and lower(trim(name)) = lower(trim(m.char_name))
   order by created_at limit 1;
  if v_cid is not null then
    insert into public._ad_member_char_sync(member_id, character_id) values (m.id, v_cid)
      on conflict (member_id) do nothing;
    return v_cid;
  end if;

  v_role := coalesce(nullif(trim(m.char_data->>'personality'), ''),
                     case when coalesce(m.char_data->>'sens', 'humano') = 'humano' then 'Humano Comum' else 'Sensitivo' end);
  v_data := m.char_data || jsonb_build_object(
    'name', left(m.char_name, 80), 'role', v_role, 'usedIn', m.table_name,
    'photo', m.photo, 'bio', coalesce(m.char_data->>'history', ''), 'fromMember', m.id);
  insert into public.characters(owner_id, name, data)
    values (m.user_id, left(m.char_name, 80), v_data)
    returning id into v_cid;
  insert into public._ad_member_char_sync(member_id, character_id) values (m.id, v_cid)
    on conflict (member_id) do nothing;
  return v_cid;
end $$;
revoke all on function public._ad_member_to_character(uuid) from public, anon, authenticated;

create or replace function public._ad_member_char_trg()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.user_id is not null and coalesce(trim(new.char_name), '') <> '' and new.char_data is not null then
    perform public._ad_member_to_character(new.id);
  end if;
  return new;
end $$;
revoke all on function public._ad_member_char_trg() from public, anon, authenticated;

drop trigger if exists members_to_character on public.table_members;
create trigger members_to_character
  after insert or update of user_id, char_name, char_data, photo on public.table_members
  for each row execute function public._ad_member_char_trg();

-- 3) Fichas que já existem (ex.: personagens criados ao entrar em mesas antes desta migração)
do $$
declare r record; n int := 0; c uuid;
begin
  for r in select id from public.table_members
            where user_id is not null and coalesce(trim(char_name), '') <> '' and char_data is not null
            order by joined_at loop
    c := public._ad_member_to_character(r.id);
    if c is not null then n := n + 1; end if;
  end loop;
  raise notice 'participações sincronizadas: %', n;
end $$;

-- Conferência: personagens criados a partir de fichas de mesa
select count(*) as personagens_vindos_de_mesas from public.characters where data ? 'fromMember';
