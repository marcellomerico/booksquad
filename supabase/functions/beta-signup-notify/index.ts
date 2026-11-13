// Double opt-in, step 1: mails the confirmation link to a new beta sign-up
// (called by a DB trigger with {id}). Nothing the visitor typed goes into the
// mail, so the form can't be used to send text to strangers.
// Each row is mailed at most once: notified_at is claimed before sending, released on failure.
import { createClient } from 'npm:@supabase/supabase-js@2.118.0';
import { MAILBOX, mailer } from '../_shared/mail.ts';

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });
  const { id } = await req.json().catch(() => ({}));
  if (typeof id !== 'string') return new Response('Bad request', { status: 400 });

  const smtp = mailer();
  if (!smtp) {
    console.error('beta-signup-notify: SMTP_PASSWORD secret missing');
    return new Response('Not configured', { status: 500 });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const admin = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data: row, error } = await admin
    .from('beta_signups')
    .update({ notified_at: new Date().toISOString() })
    .eq('id', id)
    .is('notified_at', null)
    .eq('needs_confirmation', true)
    .select('email, confirm_token')
    .maybeSingle();
  if (error) {
    console.error('beta-signup-notify: claim failed', error);
    return new Response('Error', { status: 500 });
  }
  if (!row) return new Response('Nothing to do');

  const link = `${supabaseUrl}/functions/v1/beta-confirm?t=${row.confirm_token}`;
  try {
    await smtp.sendMail({
      from: `Booksquad <${MAILBOX}>`,
      to: row.email,
      subject: 'Bitte bestätige deine Anmeldung zur Booksquad-Beta',
      text: [
        'Hallo,',
        '',
        'jemand hat diese Adresse für die Beta von Booksquad angemeldet, der App zum Lesen mit Freunden.',
        '',
        'Warst du das? Dann bestätige hier:',
        link,
        '',
        'Wenn nicht, ignoriere diese Mail einfach. Ohne Bestätigung speichern wir nichts dauerhaft und schreiben dir nicht wieder.',
        '',
        'Viele Grüße',
        'Booksquad',
        '',
        '—',
        'Booksquad · booksquad.de · Impressum: https://booksquad.de/imprint.html · Datenschutz: https://booksquad.de/privacy.html#beta',
      ].join('\n'),
    });
  } catch (e) {
    console.error('beta-signup-notify: send failed', e);
    await admin.from('beta_signups').update({ notified_at: null }).eq('id', id);
    return new Response('Send failed', { status: 502 });
  } finally {
    smtp.close();
  }
  return new Response('Sent');
});
