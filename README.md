# VD Pictures – gestionale

App in un unico file: `index.html` (clienti, fornitori, produzioni video/foto/grafica, to-do list, budget, time plan in PDF).

- Dati e login: Supabase (tabelle `docs` e `profiles`). Struttura in `supabase/supabase-setup.sql`.
- Pubblicazione: Cloudflare Workers (static assets, vedi `wrangler.jsonc`), collegato a questo repository.
- Backup: pulsante "Esporta tutto (JSON)" in fondo all'app.
