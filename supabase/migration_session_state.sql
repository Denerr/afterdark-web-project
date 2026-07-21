-- Afterdark — migração: estado da sessão de jogo (relógios, NPCs, pistas, cena)
-- persistido POR MESA no Supabase, em vez de ficar só na memória do navegador.
-- Corrige: mesas diferentes "herdando" os mesmos relógios/NPCs entre si, e
-- permite recarregar o estado certo ao reabrir uma mesa (F5 do Mestre).
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.

alter table public.tables add column if not exists session_state jsonb not null default '{}'::jsonb;

-- Funcao segura pro Jogador (que nao e dono da mesa) ler o estado da sessao.
create or replace function public.get_table_session_state(p_id uuid)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select session_state from public.tables where id = p_id;
$$;

grant execute on function public.get_table_session_state(uuid) to anon, authenticated;
