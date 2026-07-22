-- Afterdark — migração: permite o jogador sair da propria mesa
-- Hoje so o dono da mesa (Mestre) pode deletar linhas de table_members;
-- o jogador nao consegue remover a propria participacao (funcionalidade
-- "sair da mesa"). Mesmo criterio ja usado no UPDATE: dono da mesa, o
-- proprio jogador logado, ou linha de jogador sem conta (user_id nulo).
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.

drop policy if exists "members_delete_master" on public.table_members;
drop policy if exists "members_delete_own_or_master" on public.table_members;
create policy "members_delete_own_or_master" on public.table_members
  for delete using (
    auth.uid() = user_id
    or user_id is null
    or exists(select 1 from public.tables where id = table_members.table_id and owner_id = auth.uid())
  );
