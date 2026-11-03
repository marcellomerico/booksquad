// SMTP via the IONOS mailbox support@booksquad.de (password in the SMTP_PASSWORD secret).
import nodemailer from 'npm:nodemailer@7.0.13';

export const MAILBOX = 'support@booksquad.de';

export function mailer() {
  // Trim: secrets pasted from a password manager often carry a trailing newline.
  const password = (Deno.env.get('SMTP_PASSWORD') ?? '').trim();
  if (!password) return null;
  return nodemailer.createTransport({
    host: 'smtp.ionos.de',
    port: 465,
    secure: true,
    auth: { user: MAILBOX, pass: password },
  });
}
