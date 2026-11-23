create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null check (char_length(btrim(username)) between 1 and 32),
  avatar_path text,
  created_at timestamptz not null default now()
);

create unique index profiles_username_lower_idx
  on public.profiles (lower(username));

create table public.channels (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 64),
  creator_id uuid not null references public.profiles (id) on delete cascade,
  avatar_path text,
  is_public boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.channel_members (
  channel_id uuid not null references public.channels (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (channel_id, user_id)
);

create table public.channel_invites (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels (id) on delete cascade,
  inviter_id uuid not null references public.profiles (id) on delete cascade,
  invitee_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (inviter_id <> invitee_id)
);

create unique index channel_invites_pending_idx
  on public.channel_invites (channel_id, invitee_id)
  where status = 'pending';

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  body text not null default '' check (char_length(body) <= 4000),
  created_at timestamptz not null default now()
);

create index messages_channel_created_idx
  on public.messages (channel_id, created_at desc);

create table public.message_attachments (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages (id) on delete cascade,
  channel_id uuid not null references public.channels (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  storage_path text not null unique,
  file_name text not null,
  mime_type text not null,
  size_bytes bigint not null check (size_bytes between 1 and 52428800),
  created_at timestamptz not null default now()
);

create table public.message_reactions (
  message_id uuid not null references public.messages (id) on delete cascade,
  channel_id uuid not null references public.channels (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  emoji text not null check (char_length(emoji) between 1 and 16),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id, emoji)
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  desired_username text;
begin
  desired_username := nullif(trim(new.raw_user_meta_data ->> 'username'), '');
  if desired_username is null then
    desired_username := split_part(coalesce(new.email, 'user'), '@', 1);
  end if;

  insert into public.profiles (id, username)
  values (new.id, desired_username);
  insert into public.channels (id, name, creator_id, is_public)
  values (
    '00000000-0000-0000-0000-000000000001'::uuid,
    'global',
    new.id,
    true
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.is_chat_member(check_channel uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.channel_members
    where channel_id = check_channel and user_id = auth.uid()
  );
$$;

create or replace function public.can_access_channel(check_channel uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.channels
    where id = check_channel
      and (is_public or public.is_chat_member(id))
  );
$$;

create or replace function public.respond_to_channel_invite(
  invite_id uuid,
  accept_invite boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_invite public.channel_invites;
begin
  select * into selected_invite
  from public.channel_invites
  where id = invite_id
    and invitee_id = auth.uid()
    and status = 'pending'
  for update;

  if not found then
    raise exception 'Invitation is unavailable.';
  end if;

  update public.channel_invites
  set status = case when accept_invite then 'accepted' else 'declined' end,
      responded_at = now()
  where id = invite_id;

  if accept_invite then
    insert into public.channel_members (channel_id, user_id)
    values (selected_invite.channel_id, auth.uid())
    on conflict (channel_id, user_id) do nothing;
  end if;
end;
$$;

create or replace function public.add_channel_creator_as_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.channel_members (channel_id, user_id, role)
  values (new.id, new.creator_id, 'owner');
  return new;
end;
$$;

create trigger on_channel_created
  after insert on public.channels
  for each row execute procedure public.add_channel_creator_as_owner();

alter table public.profiles enable row level security;
alter table public.channels enable row level security;
alter table public.channel_members enable row level security;
alter table public.channel_invites enable row level security;
alter table public.messages enable row level security;
alter table public.message_attachments enable row level security;
alter table public.message_reactions enable row level security;

create policy "Profiles are visible to signed-in users"
  on public.profiles for select to authenticated using (true);
create policy "Users update their own profile"
  on public.profiles for update to authenticated using (id = auth.uid())
  with check (
    id = auth.uid()
    and (
      avatar_path is null
      or (storage.foldername(avatar_path))[1] = auth.uid()::text
    )
  );

create policy "Accessible channels are visible"
  on public.channels for select to authenticated
  using (
    is_public
    or public.is_chat_member(id)
    or exists (
      select 1 from public.channel_invites
      where channel_id = channels.id
        and invitee_id = auth.uid()
        and status = 'pending'
    )
  );
create policy "Users create private channels"
  on public.channels for insert to authenticated
  with check (
    creator_id = auth.uid()
    and not is_public
    and (
      avatar_path is null
      or (storage.foldername(avatar_path))[1] = auth.uid()::text
    )
  );
create policy "Channel owners update their channels"
  on public.channels for update to authenticated
  using (creator_id = auth.uid())
  with check (
    creator_id = auth.uid()
    and not is_public
    and (
      avatar_path is null
      or (storage.foldername(avatar_path))[1] = auth.uid()::text
    )
  );
create policy "Channel owners delete their channels"
  on public.channels for delete to authenticated
  using (creator_id = auth.uid() and not is_public);

create policy "Members are visible to channel members"
  on public.channel_members for select to authenticated
  using (public.can_access_channel(channel_id));

create policy "Channel participants can view invitations"
  on public.channel_invites for select to authenticated
  using (
    invitee_id = auth.uid()
    or (inviter_id = auth.uid() and public.is_chat_member(channel_id))
  );
create policy "Channel owners invite users"
  on public.channel_invites for insert to authenticated
  with check (
    inviter_id = auth.uid()
    and exists (
      select 1
      from public.channel_members as member
      join public.channels as channel on channel.id = member.channel_id
      where member.channel_id = channel_invites.channel_id
        and member.user_id = auth.uid()
        and member.role = 'owner'
        and not channel.is_public
    )
  );

create policy "Channel participants read messages"
  on public.messages for select to authenticated
  using (public.can_access_channel(channel_id));
create policy "Channel participants send messages"
  on public.messages for insert to authenticated
  with check (sender_id = auth.uid() and public.can_access_channel(channel_id));
create policy "Authors delete their messages"
  on public.messages for delete to authenticated using (sender_id = auth.uid());

create policy "Channel participants read attachments"
  on public.message_attachments for select to authenticated
  using (public.can_access_channel(channel_id));
create policy "Channel participants add attachments"
  on public.message_attachments for insert to authenticated
  with check (
    sender_id = auth.uid()
    and public.can_access_channel(channel_id)
    and exists (
      select 1 from public.messages
      where id = message_attachments.message_id
        and channel_id = message_attachments.channel_id
        and sender_id = auth.uid()
    )
    and (storage.foldername(storage_path))[1] = channel_id::text
    and (storage.foldername(storage_path))[2] = auth.uid()::text
  );
create policy "Authors delete attachments"
  on public.message_attachments for delete to authenticated
  using (sender_id = auth.uid());

create policy "Channel participants read reactions"
  on public.message_reactions for select to authenticated
  using (
    exists (
      select 1 from public.messages
      where id = message_reactions.message_id
        and channel_id = message_reactions.channel_id
        and public.can_access_channel(channel_id)
    )
  );
create policy "Users add their own reactions"
  on public.message_reactions for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.messages
      where id = message_reactions.message_id
        and channel_id = message_reactions.channel_id
        and public.can_access_channel(channel_id)
    )
  );
create policy "Users remove their own reactions"
  on public.message_reactions for delete to authenticated
  using (user_id = auth.uid());

grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.channels to authenticated;
grant select on public.channel_members to authenticated;
grant select, insert on public.channel_invites to authenticated;
grant select, insert, delete on public.messages to authenticated;
grant select, insert, delete on public.message_attachments to authenticated;
grant select, insert, delete on public.message_reactions to authenticated;

grant execute on function public.is_chat_member(uuid) to authenticated;
grant execute on function public.can_access_channel(uuid) to authenticated;
grant execute on function public.respond_to_channel_invite(uuid, boolean)
  to authenticated;
revoke all on function public.respond_to_channel_invite(uuid, boolean)
  from public, anon;
revoke all on function public.is_chat_member(uuid) from public, anon;
revoke all on function public.can_access_channel(uuid) from public, anon;

insert into public.channels (id, name, creator_id, is_public)
select
  '00000000-0000-0000-0000-000000000001'::uuid,
  'global',
  id,
  true
from auth.users
order by created_at
limit 1
on conflict (id) do nothing;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values
  (
    'profile-avatars',
    'profile-avatars',
    true,
    5242880,
    array['image/jpeg', 'image/png', 'image/webp']
  ),
  (
    'channel-avatars',
    'channel-avatars',
    true,
    5242880,
    array['image/jpeg', 'image/png', 'image/webp']
  ),
  ('chat-attachments', 'chat-attachments', false, 52428800, null)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "Avatar objects are publicly readable"
  on storage.objects for select to public
  using (bucket_id in ('profile-avatars', 'channel-avatars'));
create policy "Users upload their own profile avatars"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'profile-avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "Users update their own profile avatars"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'profile-avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "Users delete their own profile avatars"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'profile-avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "Users upload channel avatars"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'channel-avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "Users manage their channel avatars"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'channel-avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "Channel members read attachments"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'chat-attachments'
    and public.can_access_channel(((storage.foldername(name))[1])::uuid)
  );
create policy "Channel members upload attachments"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'chat-attachments'
    and (storage.foldername(name))[2] = auth.uid()::text
    and public.can_access_channel(((storage.foldername(name))[1])::uuid)
  );
create policy "Users delete their uploaded attachments"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'chat-attachments'
    and (storage.foldername(name))[2] = auth.uid()::text
  );
create policy "Private channel owners delete attachments"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'chat-attachments'
    and exists (
      select 1
      from public.channels
      where id = ((storage.foldername(name))[1])::uuid
        and creator_id = auth.uid()
        and not is_public
    )
  );

do $$
begin
  begin
    alter publication supabase_realtime add table public.messages;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.message_reactions;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.message_attachments;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.channel_invites;
  exception when duplicate_object then null;
  end;
end;
$$;
