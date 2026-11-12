-- VD Pictures – struttura database Supabase
-- Incolla tutto nell'SQL Editor del nuovo progetto Supabase e premi "Run".
-- Stessa impostazione di HB On Tour: una tabella "docs" con i dati in JSON,
-- più una tabella "profiles" che dice chi può entrare.

-- 1) Dati dell'app (clienti, produzioni, fornitori, to-do)
create table if not exists public.docs (
  col        text        not null,               -- 'clients' | 'productions' | 'suppliers' | 'tasks'
  id         text        not null,
  data       jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (col, id)
);

create index if not exists docs_col_idx on public.docs (col);

-- aggiorna updated_at a ogni modifica
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists docs_touch on public.docs;
create trigger docs_touch before update on public.docs
for each row execute function public.touch_updated_at();

-- 2) Chi può usare l'app
create table if not exists public.profiles (
  id    uuid primary key references auth.users (id) on delete cascade,
  name  text,
  role  text not null default 'member' check (role in ('admin', 'member', 'viewer'))
);

-- funzione di supporto: ruolo dell'utente collegato
create or replace function public.my_role()
returns text language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid()
$$;

-- 3) Sicurezza (Row Level Security)
alter table public.docs     enable row level security;
alter table public.profiles enable row level security;

-- leggere: chiunque abbia un profilo (admin, member, viewer)
drop policy if exists docs_read on public.docs;
create policy docs_read on public.docs
  for select to authenticated
  using (public.my_role() in ('admin', 'member', 'viewer'));

-- scrivere: solo admin e member (Matteo e Kia)
drop policy if exists docs_insert on public.docs;
create policy docs_insert on public.docs
  for insert to authenticated
  with check (public.my_role() in ('admin', 'member'));

drop policy if exists docs_update on public.docs;
create policy docs_update on public.docs
  for update to authenticated
  using (public.my_role() in ('admin', 'member'))
  with check (public.my_role() in ('admin', 'member'));

drop policy if exists docs_delete on public.docs;
create policy docs_delete on public.docs
  for delete to authenticated
  using (public.my_role() in ('admin', 'member'));

-- ognuno vede il proprio profilo; l'admin li vede tutti
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.my_role() = 'admin');

-- 4) Aggiornamenti in tempo reale (quando Kia salva, Matteo lo vede subito)
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'docs'
  ) then
    alter publication supabase_realtime add table public.docs;
  end if;
end $$;

-- 5) DOPO aver creato gli utenti in Authentication > Users,
--    togli i "--" dalle righe qui sotto, metti le email giuste e lancia di nuovo:
-- insert into public.profiles (id, name, role)
--   select id, 'Matteo', 'admin'  from auth.users where email = 'matteo@vdpictures.ch'
--   on conflict (id) do update set role = excluded.role, name = excluded.name;
-- insert into public.profiles (id, name, role)
--   select id, 'Kia', 'member'   from auth.users where email = 'EMAIL-DI-KIA'
--   on conflict (id) do update set role = excluded.role, name = excluded.name;
