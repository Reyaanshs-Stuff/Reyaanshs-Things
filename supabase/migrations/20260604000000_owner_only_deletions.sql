drop policy if exists "Users create private channels" on public.channels;
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

drop policy if exists "Channel owners update their channels" on public.channels;
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

drop policy if exists "Authors delete attachments"
  on public.message_attachments;
create policy "Authors delete attachments"
  on public.message_attachments for delete to authenticated
  using (sender_id = auth.uid());
grant delete on public.message_attachments to authenticated;

drop policy if exists "Private channel owners delete attachments"
  on storage.objects;
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
    alter publication supabase_realtime add table public.message_attachments;
  exception when duplicate_object then null;
  end;
end;
$$;
