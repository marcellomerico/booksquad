# Website auf Cloudflare Pages umziehen

Ziel: booksquad.de über Cloudflare Pages statt Netlify. Kostenlos, unbegrenzte Deploys ohne Build-Credits, HTTPS automatisch. Die Seite ist statisch (`site/`), es gibt keinen Build-Schritt. Sicherheits-Header stehen in `site/_headers` (gleicher Inhalt wie `netlify.toml`).

## 1. Projekt anlegen (du, ca. 10 Min.)

1. Kostenloses Konto auf [dash.cloudflare.com](https://dash.cloudflare.com/sign-up) anlegen, Zwei-Faktor-Anmeldung einschalten.
2. **Workers & Pages → Create → Pages → Connect to Git** → GitHub verbinden → Repository `marcellomerico/booksquad` auswählen (Zugriff nur auf dieses Repo genügt).
3. Einstellungen:
   - Production branch: `main`
   - Framework preset: **None**
   - Build command: leer lassen
   - Build output directory: `site`
4. **Save and Deploy**. Danach ist die Seite unter `booksquad.pages.dev` (oder ähnlich) erreichbar → dort kurz ansehen.
5. Optional, gegen unnötige Builds: **Settings → Builds → Build watch paths** → Include: `site/*`.

## 2. Domain verbinden (zusammen mit Claude)

1. Im Pages-Projekt **Custom domains → Set up a custom domain** → `booksquad.de`, danach `www.booksquad.de`.
2. Cloudflare zeigt die nötigen DNS-Einträge. Da die Domain bei IONOS bleibt, bei IONOS (Domains → booksquad.de → DNS):
   - `www`: CNAME auf `<projekt>.pages.dev` (statt `mybooksquad.netlify.app`)
   - `@` (Hauptdomain): Cloudflare Pages unterstützt eine Hauptdomain nur, wenn die DNS bei Cloudflare liegt. Zwei Wege:
     - **Empfohlen:** Nameserver der Domain bei IONOS auf die beiden Cloudflare-Nameserver umstellen (Cloudflare → Add site → Free). Vorher die MX- und TXT-Einträge von IONOS für die E-Mail (support@booksquad.de) in Cloudflare übernehmen, sonst kommt keine Mail mehr an. Claude prüft die Liste mit dir.
     - Alternativ: `@` bei IONOS per Weiterleitung auf `https://www.booksquad.de` zeigen lassen.
3. Warten, bis Cloudflare „Active“ und ein Zertifikat zeigt (meist wenige Minuten).

## 3. Aufräumen

- Datenschutzerklärung Abschnitt 8: „Netlify (Netlify Inc., USA)“ durch „Cloudflare Pages (Cloudflare, Inc., USA)“ ersetzen (Text in `docs/legal/PRIVACY.md`, dann `python3 tool/build_site.py .`). Cloudflare stellt den Auftragsverarbeitungsvertrag mit Standardvertragsklauseln automatisch bereit (Dashboard → Manage Account → Configurations → DPA).
- Netlify-Projekt danach löschen, `netlify.toml` entfernen.
