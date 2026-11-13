-- Security review (Nov 2026). Additive: no existing rows are changed or removed.

-- ---------------------------------------------------------------------
-- 1. Post images are private: readable only by people who may see the post.
--    image_url keeps the old public-URL form as identifier; the app turns it
--    into a short-lived signed URL. Old public links stop working.
-- ---------------------------------------------------------------------
update storage.buckets set public = false where id = 'post-images';

drop policy if exists "Readers see images of visible posts" on storage.objects;
create policy "Readers see images of visible posts" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'post-images'
    and exists (
      select 1 from public.posts p
      where right(p.image_url, char_length(name) + 1) = '/' || name
        -- Only the author's own folder: a post can't unlock someone else's image.
        and (storage.foldername(name))[1] = p.author_id::text
        and private.can_view_post(p.id)
    )
  );

-- Moderation removes images of deleted posts; remove() needs to see the object.
drop policy if exists "Admins read post images" on storage.objects;
create policy "Admins read post images" on storage.objects
  for select to authenticated
  using (bucket_id = 'post-images' and private.is_admin());

-- Only our own storage may be referenced (no tracking pixels on foreign hosts).
alter table public.posts drop constraint if exists posts_image_url_storage;
alter table public.posts add constraint posts_image_url_storage check (
  image_url is null
  or (
    image_url ~ '^https://[a-z0-9]+\.supabase\.co/storage/v1/object/public/post-images/[0-9a-f-]+/[A-Za-z0-9._-]+$'
    -- ...and only an image in the author's own folder.
    and image_url like '%/post-images/' || author_id::text || '/%'
  )
) not valid;

alter table public.profiles drop constraint if exists profiles_avatar_url_storage;
alter table public.profiles add constraint profiles_avatar_url_storage check (
  avatar_url is null
  or avatar_url ~ '^https://[a-z0-9]+\.supabase\.co/storage/v1/object/public/avatars/[0-9a-f-]+/'
) not valid;

-- ---------------------------------------------------------------------
-- 2. Beta sign-ups need a confirmation click (double opt-in).
--    Rows from before this migration already got their mail: they stay valid.
-- ---------------------------------------------------------------------
alter table public.beta_signups
  add column if not exists needs_confirmation boolean not null default false,
  add column if not exists confirm_token uuid not null default gen_random_uuid(),
  add column if not exists confirmed_at timestamptz;
alter table public.beta_signups alter column needs_confirmation set default true;
create unique index if not exists beta_signups_confirm_token_key on public.beta_signups (confirm_token);

-- ---------------------------------------------------------------------
-- 3. Auto-hide counts only established reporters: account older than 7 days
--    with a confirmed e-mail. Three throwaway accounts can no longer hide a post.
-- ---------------------------------------------------------------------
create or replace function private.auto_hide_reported()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  n integer;
begin
  if new.target_type not in ('post', 'comment') then
    return new;
  end if;
  select count(distinct r.reporter_id) into n
    from public.reports r
    join auth.users u on u.id = r.reporter_id
   where r.status = 'open'
     and r.target_type = new.target_type
     and (case when new.target_type = 'post' then r.post_id = new.post_id
               else r.comment_id = new.comment_id end)
     and u.created_at < now() - interval '7 days'
     and u.email_confirmed_at is not null;
  if n >= 3 then
    if new.target_type = 'post' and new.post_id is not null then
      update public.posts set hidden_at = now() where id = new.post_id and hidden_at is null;
    elsif new.comment_id is not null then
      update public.comments set hidden_at = now() where id = new.comment_id and hidden_at is null;
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.auto_hide_reported() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. Who follows whom stays private for private accounts. Counts stay public
--    (like on Instagram) through profile_counts().
-- ---------------------------------------------------------------------
drop policy if exists "Follows visible to signed-in users" on public.follows;
drop policy if exists "Follows visible by privacy" on public.follows;
create policy "Follows visible by privacy" on public.follows
  for select to authenticated using (
    follower_id = (select auth.uid())
    or following_id = (select auth.uid())
    or (private.can_see_content(follower_id) and private.can_see_content(following_id))
  );

create or replace function public.profile_counts(p_user uuid)
returns table (posts integer, followers integer, following integer)
language sql stable security definer set search_path = '' as $$
  select (select count(*)::integer from public.posts
           where author_id = p_user and group_id is null and hidden_at is null),
         (select count(*)::integer from public.follows where following_id = p_user),
         (select count(*)::integer from public.follows where follower_id = p_user);
$$;
revoke all on function public.profile_counts(uuid) from public, anon;
grant execute on function public.profile_counts(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 5. Spam brakes for likes, follows and follow requests.
-- ---------------------------------------------------------------------
alter table public.likes add column if not exists created_at timestamptz not null default now();

create or replace function private.enforce_rate_limit()
returns trigger
language plpgsql security definer set search_path to 'public' as $function$
declare
  n int;
begin
  if coalesce(current_setting('role', true), 'none') not in ('authenticated', 'anon') then
    return new;
  end if;
  new.created_at := now();
  perform pg_advisory_xact_lock(hashtext(tg_table_name || coalesce(auth.uid()::text, '')));
  if tg_table_name = 'posts' then
    select count(*) into n from public.posts
    where author_id = auth.uid() and created_at > now() - interval '10 minutes';
    if n >= 10 then raise exception 'rate_limit' using hint = 'posts'; end if;
  elsif tg_table_name = 'comments' then
    select count(*) into n from public.comments
    where author_id = auth.uid() and created_at > now() - interval '10 minutes';
    if n >= 30 then raise exception 'rate_limit' using hint = 'comments'; end if;
  elsif tg_table_name = 'reports' then
    select count(*) into n from public.reports
    where reporter_id = auth.uid() and created_at > now() - interval '1 day';
    if n >= 20 then raise exception 'rate_limit' using hint = 'reports'; end if;
  elsif tg_table_name = 'groups' then
    select count(*) into n from public.groups
    where creator_id = auth.uid() and created_at > now() - interval '1 day';
    if n >= 5 then raise exception 'rate_limit' using hint = 'groups'; end if;
  elsif tg_table_name = 'messages' then
    select count(*) into n from public.messages
    where sender_id = auth.uid() and created_at > now() - interval '10 minutes';
    if n >= 60 then raise exception 'rate_limit' using hint = 'messages'; end if;
  elsif tg_table_name = 'likes' then
    select count(*) into n from public.likes
    where user_id = auth.uid() and created_at > now() - interval '1 hour';
    if n >= 300 then raise exception 'rate_limit' using hint = 'likes'; end if;
  elsif tg_table_name = 'follows' then
    select count(*) into n from public.follows
    where follower_id = auth.uid() and created_at > now() - interval '1 hour';
    if n >= 100 then raise exception 'rate_limit' using hint = 'follows'; end if;
  elsif tg_table_name = 'follow_requests' then
    select count(*) into n from public.follow_requests
    where requester_id = auth.uid() and created_at > now() - interval '1 hour';
    if n >= 50 then raise exception 'rate_limit' using hint = 'follow_requests'; end if;
  end if;
  return new;
end;
$function$;

drop trigger if exists likes_rate_limit on public.likes;
create trigger likes_rate_limit before insert on public.likes
  for each row execute function private.enforce_rate_limit();
drop trigger if exists follows_rate_limit on public.follows;
create trigger follows_rate_limit before insert on public.follows
  for each row execute function private.enforce_rate_limit();
drop trigger if exists follow_requests_rate_limit on public.follow_requests;
create trigger follow_requests_rate_limit before insert on public.follow_requests
  for each row execute function private.enforce_rate_limit();

-- ---------------------------------------------------------------------
-- 6. A book added straight as "Gelesen" is an old read: it no longer counts
--    toward this year's goal, the statistics or the streak. Only finishing a
--    book that was on the shelf (status change) does.
-- ---------------------------------------------------------------------
create or replace function private.log_reading_day()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  delta integer := 0;
  finished boolean := tg_op = 'UPDATE' and new.status = 'read' and old.status is distinct from 'read';
begin
  if tg_op = 'UPDATE' then
    delta := greatest(coalesce(new.current_page, 0) - coalesce(old.current_page, 0), 0);
  end if;
  if finished then
    new.finished_at := coalesce(new.finished_at, now());
  elsif new.status is distinct from 'read' then
    new.finished_at := null;
  end if;
  if delta > 0 or finished then
    insert into public.reading_days (user_id, day, pages)
      values (new.user_id, private.berlin_today(), delta)
      on conflict (user_id, day) do update
        set pages = public.reading_days.pages + excluded.pages;
  end if;
  return new;
end;
$$;
revoke all on function private.log_reading_day() from public, anon, authenticated;

-- Unconfirmed beta sign-ups are removed after 30 days (privacy policy, section 9).
-- Only rows that asked for a confirmation; older sign-ups are never touched.
-- Runs daily where pg_cron is enabled (Dashboard → Integrations → Cron).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'beta-unconfirmed-cleanup';
    perform cron.schedule(
      'beta-unconfirmed-cleanup',
      '15 3 * * *',
      $job$delete from public.beta_signups
            where needs_confirmation and confirmed_at is null
              and created_at < now() - interval '30 days'$job$
    );
  end if;
end $$;
