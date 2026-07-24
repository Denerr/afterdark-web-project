-- Afterdark — migração: arquivar mesa antes de excluir de vez
-- Adiciona uma coluna separada em vez de reaproveitar "status", assim
-- restaurar uma mesa arquivada devolve o status exato que ela tinha antes
-- (Pausada, Encerrada, etc), sem precisar adivinhar.
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.

alter table public.tables add column if not exists archived boolean not null default false;
