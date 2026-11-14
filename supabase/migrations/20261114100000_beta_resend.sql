-- Signing up again with an unconfirmed address sends the confirmation mail again
-- instead of locking the address for 30 days. At most 3 mails per address and
-- one per 10 minutes, so the form can't be used to flood a stranger's inbox.
-- Additive: existing rows keep their data.
alter table public.beta_signups add column if not exists mails_sent integer not null default 1;

create or replace function private.post_beta_notify(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  fn_url text := (select decrypted_secret from vault.decrypted_secrets where name = 'beta_notify_url');
  fn_key text := (select decrypted_secret from vault.decrypted_secrets where name = 'beta_notify_key');
begin
  if fn_url is not null and fn_key is not null then
    perform net.http_post(
      url := fn_url,
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || fn_key),
      body := jsonb_build_object('id', p_id)
    );
  end if;
end;
$$;
revoke all on function private.post_beta_notify(uuid) from public, anon, authenticated;

create or replace function private.notify_beta_signup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.post_beta_notify(new.id);
  return new;
end;
$$;
revoke all on function private.notify_beta_signup() from public, anon, authenticated;

-- Runs after beta_signups_rate_limit (triggers fire in name order).
create or replace function private.resend_beta_confirmation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid;
begin
  update public.beta_signups
     set notified_at = null, mails_sent = mails_sent + 1
   where lower(email) = lower(new.email)
     and needs_confirmation and confirmed_at is null
     and notified_at < now() - interval '10 minutes'
     and mails_sent < 3
  returning id into rid;
  if rid is null then
    return new; -- new address, or nothing to resend: the unique index answers
  end if;
  perform private.post_beta_notify(rid);
  return null; -- no second row; the website gets the same 201 as for a new sign-up
end;
$$;
revoke all on function private.resend_beta_confirmation() from public, anon, authenticated;

drop trigger if exists beta_signups_resend on public.beta_signups;
create trigger beta_signups_resend
  before insert on public.beta_signups
  for each row execute function private.resend_beta_confirmation();
