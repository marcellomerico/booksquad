// Beta sign-up behind Cloudflare Turnstile. The website posts here once a
// site key is set in site/landing.js; without the TURNSTILE_SECRET secret this
// function refuses. Deploy with verify_jwt = false (public form).
// When switching it on, also take the direct insert away from anon:
//   revoke insert on public.beta_signups from anon;
import { createClient } from 'npm:@supabase/supabase-js@2.118.0';

const cors = {
  'Access-Control-Allow-Origin': 'https://booksquad.de',
  'Access-Control-Allow-Headers': 'content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const reply = (status: number) => new Response(null, { status, headers: cors });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return reply(204);
  if (req.method !== 'POST') return reply(405);
  const secret = (Deno.env.get('TURNSTILE_SECRET') ?? '').trim();
  if (!secret) return reply(503);

  const body = await req.json().catch(() => null);
  if (!body || typeof body.token !== 'string' || typeof body.email !== 'string') return reply(400);

  const check = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
    method: 'POST',
    body: new URLSearchParams({ secret, response: body.token }),
  }).then((r) => r.json()).catch(() => null);
  if (!check?.success) return reply(403);

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
  // The table's own checks validate the fields; the triggers handle rate limit and resend.
  const { error } = await admin.from('beta_signups').insert({
    first_name: typeof body.first_name === 'string' && body.first_name.trim() ? body.first_name.trim() : null,
    email: body.email.trim(),
    platform: body.platform,
    consent: body.consent === true,
  });
  // Known address (23505): same answer as a new one, the form must not reveal who signed up.
  if (!error || error.code === '23505') return reply(201);
  if (error.code === '23514') return reply(400);
  console.error('beta-signup: insert failed', error);
  return reply(error.message.includes('rate_limit') ? 429 : 500);
});
