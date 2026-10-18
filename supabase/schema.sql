-- Study Quest accounts: run once in the Supabase SQL editor.
-- Login is username + password. Supabase Auth needs an email, so the app signs up
-- <username>@study-quest.app (never mailed; email confirmation is turned off).

-- one row per account
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  username text unique not null,
  display_name text,
  role text not null default 'her' check (role in ('her','him')),
  pair_code text unique,
  pair_code_at timestamptz,
  partner_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

-- her whole app state (same JSON as the studyQuest.v1 localStorage key)
create table if not exists public.app_state (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id)
);

-- rewards, notes and kisses between the two of them
create table if not exists public.messages (
  id bigint generated always as identity primary key,
  from_id uuid not null references public.profiles(id) on delete cascade,
  to_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null default 'note' check (kind in ('note','reward','kiss','hug','gift')),
  emoji text,
  body text check (char_length(body) <= 300),
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists messages_to_idx on public.messages (to_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.app_state enable row level security;
alter table public.messages enable row level security;

-- who am I paired with (null if nobody)
create or replace function public.my_partner() returns uuid
language sql stable security definer set search_path = public as $$
  select partner_id from public.profiles where id = auth.uid()
$$;

-- profiles: see yourself and your partner; edit only yourself (not the partner link)
drop policy if exists "profiles read" on public.profiles;
create policy "profiles read" on public.profiles for select to authenticated
  using (id = auth.uid() or id = public.my_partner());
drop policy if exists "profiles update self" on public.profiles;
create policy "profiles update self" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
revoke update on public.profiles from authenticated;
grant update (display_name, role) on public.profiles to authenticated;

-- app_state: you and your partner can read and write it (he edits her schedule)
drop policy if exists "state read" on public.app_state;
create policy "state read" on public.app_state for select to authenticated
  using (user_id = auth.uid() or user_id = public.my_partner());
drop policy if exists "state insert" on public.app_state;
create policy "state insert" on public.app_state for insert to authenticated
  with check (user_id = auth.uid() or user_id = public.my_partner());
drop policy if exists "state update" on public.app_state;
create policy "state update" on public.app_state for update to authenticated
  using (user_id = auth.uid() or user_id = public.my_partner())
  with check (user_id = auth.uid() or user_id = public.my_partner());

-- messages: send only to your partner; read your own; mark received ones as read
drop policy if exists "msg read" on public.messages;
create policy "msg read" on public.messages for select to authenticated
  using (from_id = auth.uid() or to_id = auth.uid());
drop policy if exists "msg send" on public.messages;
create policy "msg send" on public.messages for insert to authenticated
  with check (from_id = auth.uid() and to_id = public.my_partner());
drop policy if exists "msg mark read" on public.messages;
create policy "msg mark read" on public.messages for update to authenticated
  using (to_id = auth.uid()) with check (to_id = auth.uid());
revoke update on public.messages from authenticated;
grant update (read_at) on public.messages to authenticated;

-- new account -> profile row (username/role come from sign-up metadata)
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username, display_name, role)
  values (new.id,
          lower(coalesce(new.raw_user_meta_data->>'username', split_part(new.email,'@',1))),
          coalesce(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'username'),
          case when new.raw_user_meta_data->>'role' = 'him' then 'him' else 'her' end);
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- make a 6-digit pair code (valid 30 minutes)
create or replace function public.create_pair_code() returns text
language plpgsql security definer set search_path = public as $$
declare c text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  loop
    c := lpad((floor(random()*1000000))::int::text, 6, '0');
    exit when not exists (select 1 from public.profiles where pair_code = c);
  end loop;
  update public.profiles set pair_code = c, pair_code_at = now() where id = auth.uid();
  return c;
end $$;

-- enter the partner's code: links both accounts
create or replace function public.join_pair(code text) returns json
language plpgsql security definer set search_path = public as $$
declare other public.profiles;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into other from public.profiles
    where pair_code = trim(code) and pair_code_at > now() - interval '30 minutes' and id <> auth.uid();
  if other.id is null then raise exception 'bad code'; end if;
  update public.profiles set partner_id = auth.uid(), pair_code = null where id = other.id;
  update public.profiles set partner_id = other.id, pair_code = null where id = auth.uid();
  return json_build_object('partner_id', other.id, 'username', other.username, 'display_name', other.display_name, 'role', other.role);
end $$;

-- break the link on both sides
create or replace function public.unpair() returns void
language plpgsql security definer set search_path = public as $$
declare p uuid;
begin
  select partner_id into p from public.profiles where id = auth.uid();
  update public.profiles set partner_id = null where id = auth.uid();
  if p is not null then update public.profiles set partner_id = null where id = p and partner_id = auth.uid(); end if;
end $$;

revoke execute on function public.create_pair_code() from anon, public;
revoke execute on function public.join_pair(text) from anon, public;
revoke execute on function public.unpair() from anon, public;
revoke execute on function public.my_partner() from anon, public;
grant execute on function public.create_pair_code() to authenticated;
grant execute on function public.join_pair(text) to authenticated;
grant execute on function public.unpair() to authenticated;
grant execute on function public.my_partner() to authenticated;
