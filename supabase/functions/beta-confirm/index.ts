// Double opt-in, step 2: the link from the confirmation mail (GET ?t=<token>).
// Marks the sign-up confirmed, tells support@booksquad.de, then sends the
// visitor to the thank-you page. Deploy with verify_jwt = false (mail link).
import { createClient } from 'npm:@supabase/supabase-js@2.118.0';
import { MAILBOX, mailer } from '../_shared/mail.ts';

const DONE = 'https://booksquad.de/beta-bestaetigt.html';
const PLATFORM = { ios: 'iPhone', android: 'Android' } as Record<string, string>;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const redirect = (to: string) => new Response(null, { status: 303, headers: { Location: to } });

Deno.serve(async (req) => {
  if (req.method !== 'GET') return new Response('Method not allowed', { status: 405 });
  const token = new URL(req.url).searchParams.get('t') ?? '';
  if (!UUID.test(token)) return redirect(`${DONE}?ungueltig`);

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
  const { data: row, error } = await admin
    .from('beta_signups')
    .update({ confirmed_at: new Date().toISOString() })
    .eq('confirm_token', token)
    .is('confirmed_at', null)
    .select('first_name, email, platform, created_at')
    .maybeSingle();
  if (error) {
    console.error('beta-confirm: update failed', error);
    return redirect(`${DONE}?fehler`);
  }
  // Already confirmed (second click) or unknown token: same friendly page.
  if (!row) return redirect(DONE);

  const smtp = mailer();
  if (smtp) {
    const { count } = await admin
      .from('beta_signups')
      .select('id', { count: 'exact', head: true })
      .not('confirmed_at', 'is', null);
    try {
      await smtp.sendMail({
        from: `Booksquad <${MAILBOX}>`,
        to: MAILBOX,
        replyTo: row.email,
        subject: `Neue Beta-Anmeldung bestätigt (${count ?? '?'} gesamt)`,
        text: [
          'Bestätigte Anmeldung über booksquad.de',
          '',
          `Name:   ${row.first_name ?? '–'}`,
          `E-Mail: ${row.email}`,
          `Gerät:  ${PLATFORM[row.platform] ?? row.platform}`,
          `Zeit:   ${new Date(row.created_at).toLocaleString('de-DE', { timeZone: 'Europe/Berlin' })}`,
          '',
          'Liste: Supabase → Table Editor → beta_signups (confirmed_at gesetzt oder needs_confirmation = false) → Export CSV',
        ].join('\n'),
      });
    } catch (e) {
      // The sign-up is confirmed either way; the notice is a convenience.
      console.error('beta-confirm: notice failed', e);
    } finally {
      smtp.close();
    }
  }
  return redirect(DONE);
});
