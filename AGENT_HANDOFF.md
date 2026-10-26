# LIMS (loanapp) — Agent Handoff

Read this file first. It is written for an agent with **no prior context** on
this conversation — everything needed to keep working safely is here or
linked from here. It was produced by scanning `frontend/`, `backend/`,
`.github/workflows/`, `docs/`, and the git history as of **2026-10-27**,
commit `7960b4c`.

Reply to the user in **Swahili** (mixed with English technical terms) unless
they switch language — that has been the working language throughout.

---

## 1. What this app is

**LIMS** — Loan & Inventory Management System for Tanzanian phone
dealerships (Kariakoo, Mbezi, Arusha, Mwanza, Dodoma). Multi-branch,
serialized dual-IMEI phone inventory + hire-purchase credit (loans) + cash
POS + attendance + petty cash, in English and Kiswahili.

- **Repo:** https://github.com/mwijay12/loanapp (branch `main`)
- **Stack:** Flutter (Dart) + Riverpod + go_router, Supabase (PostgreSQL +
  Auth), Cloudinary (images), Cloudflare Tunnel (web preview hosting).
- **Architect/owner:** David Erick Mwijage (@mwijay12). Lead dev credited in
  docs: Godfrey Shora.

## 2. Repo layout

```
project/
├── frontend/                  Flutter app (THIS is where almost all work happens)
│   ├── lib/core/              routing, services (Supabase/Cloudinary/GPS), theming, l10n, shared widgets
│   ├── lib/features/          ~20 feature modules (auth, home, stock, loans, sales, petty_cash, admin, ...)
│   └── pubspec.yaml           go_router ^13.0.1, flutter_riverpod, supabase_flutter, image_picker, pdf, ...
├── backend/
│   ├── supabase/schema.sql              12 core tables (branches, employees, phones, customers, sales,
│   │                                     loans, loan_payments, stock_transfers, transfer_items, attendance,
│   │                                     daily_closing, notifications, audit_logs)
│   ├── supabase/migrations/*.sql        23 incremental migrations (RLS, product_units/IMEI, petty_cash, ...)
│   ├── API_AND_SCHEMA_SPECIFICATION.md  aspirational/companion spec — NOT all of it is implemented, see §6
│   └── lib/supabase_client.dart
├── docs/                       two audit/strategy PDFs+DOCX, see §6 — read before proposing new features
├── .github/workflows/
│   ├── android-apk.yml         builds a release APK on push to main / tags v* (needs SUPABASE_URL/ANON_KEY secrets)
│   └── supabase-heartbeat.yml  pings Supabase every 2 days so the free tier doesn't pause
├── run_tunnel.py               starts `python3 -m http.server` on the built web/ + a cloudflared tunnel
├── cloudflared                 bundled binary used by run_tunnel.py
└── .tools/flutter/             a Flutter SDK was unpacked here in a previous session (see §5 — currently
                                 broken: package_config.json points at a stale /home/accio/... path)
```

## 3. How the user works (read before touching anything)

- The user communicates in **Swahili**, runs a real Tanzanian phone shop
  business, and is **non-technical** — they describe symptoms ("database
  inaonekana tupu", "app inafunga"), not root causes. Investigate the
  codebase yourself; do not ask them to debug.
- They are often in a hurry ("niondoke hapa" = "let me get going") — be
  decisive, fix forward, report concisely, do not over-ask.
- **Never invent demo data or claim a fix "should work" without reading the
  code path.** This user has explicitly and angrily called out fabricated
  claims before ("hiyo ni uongo mkubwa" — "that's a huge lie") when told data
  existed without actually reading from Supabase. Always verify against the
  actual table/column before describing data as present or connected.
- GitHub push requires a **Personal Access Token** pasted by the user into
  chat. There is no stored credential helper. The token lives only in
  `.git/config`'s remote URL (`git remote -v` to see it) — it has gone stale
  / been replaced multiple times already. If `git push` fails with
  `could not read Password`, the token is invalid/expired — ask the user for
  a fresh one, do not guess or reuse an old one from memory/history.
- Supabase PAT (management API token) has also been supplied in chat before,
  for inspecting the live database directly, separate from the anon
  key/dart-defines used by the app at runtime.

## 4. Current known-good state (as of commit `7960b4c`)

Done and pushed to `origin/main`:

1. **Live Supabase connection** — the app reads real data when built with
   `--dart-define=SUPABASE_URL=...` `SUPABASE_ANON_KEY=...` (see
   `frontend/lib/core/services/api_service.dart` `SupabaseConfig`). Without
   those defines it falls back to `demoMode` mock data
   (`frontend/lib/core/data/mock_lims_data.dart`).
2. **Dashboard KPI = Gross Sales** — "Leo" / "Today" figures read `total`
   (contract value), not `paid` (cash collected), from
   `frontend/lib/core/data/sales_provider.dart`. Day boundary is **East
   Africa Time (UTC+3)**, via `isEatToday()` / `eatDateOf()` in that same
   file — every "today" metric in the app must use this helper, never
   `DateTime.now()` directly, or a late-evening sale rolls into the wrong day.
3. **Petty Cash module** — `frontend/lib/features/petty_cash/`, table
   `public.petty_cash` (migration `2026_10_24_01_petty_cash.sql`: `amount`,
   `category`, `description`, `branch_id`, `staff_id`). Labels are "Petty
   Cash" / "Record New Expense" (English UI chrome) with a Swahili category
   option "Usafi" (cleaning) — **the user prefers Swahili labels for specific
   UI elements like category names**, keep that pattern when adding
   categories, but don't blanket-translate the whole module without asking.
   **RLS note:** current policies allow anonymous INSERT/SELECT ("demo/preview
   mode" per migration comment) — tighten this before a real production
   rollout (see §6, Gap register, which flags RLS/receipting generally).
4. **Back-button stability (`7960b4c`)** — `frontend/lib/core/widgets/back_guard.dart`
   (`BackGuard`) wraps all 14 top-level routes declared in
   `frontend/lib/core/routing/app_router.dart` via a `_standalone(...)`
   helper, plus `onException` → `/home` for dead routes. **Read this file
   before adding any new top-level `GoRoute`** — it must be wrapped with
   `_standalone(...)` or the same close-on-back bug returns. Routes already
   inside `ShellRoute` (`/home`, `/stock`, `/loans`, `/reports`, `/account`)
   are protected by `AppShell`'s own `PopScope` instead — do not double-wrap
   those.
5. **Login demo prefill** — `AppConstants.prefillDemoCredentials` (separate
   from `AppConstants.demoMode`, which stays `false` so the till reads real
   Supabase data) keeps `demo.admin@example.com` / `Demo@2026` pre-filled on
   the login screen for quick access. **Unverified:** whether that account
   actually exists in Supabase Auth with that password — if the user reports
   login failing with those prefilled values, that's the first thing to check
   (`profiles` table + Supabase Auth users, not just the Flutter constant).
6. **`run_tunnel.py`** resolves `cloudflared` and `frontend/build/web` from
   its own file location (`os.path.dirname(os.path.abspath(__file__))`), not
   a hardcoded absolute path — keep it that way if the workspace path changes
   again (it already has, twice, across sessions: `/home/accio/...` →
   `/root/.accio/...`).

## 5. Toolchain status — READ BEFORE BUILDING

- `.tools/flutter/` has a Flutter SDK, but **`frontend/.dart_tool/package_config.json`
  is stale**: it resolves `go_router`, `riverpod`, etc. to
  `/root/.pub-cache/hosted/pub.dev/...` paths that do **not exist** on this
  machine, and the `flutter` package itself to a `/home/accio/...` path that
  no longer exists either. Result: `flutter analyze` / `flutter build` /
  `flutter run` will NOT currently work until `cd frontend && flutter pub get`
  is re-run successfully (needs network access to pub.dev, which may or may
  not be available in this sandbox — check before assuming it'll work).
- **Offline syntax check that DOES work without pub deps:**
  `../.tools/flutter/bin/dart format --output=none <file>.dart` — parses
  without resolving imports, catches real syntax errors, doesn't rewrite the
  file. Use this after any Dart edit when `flutter pub get` isn't available.
- The already-deployed Cloudflare Tunnel web build is **stale relative to
  `main`** — it was built before the back-button fix in `7960b4c`. Rebuilding
  requires a working `flutter pub get` + `flutter build web
  --dart-define=...`. Do not claim the live link reflects the latest commit
  unless you rebuilt and redeployed it in this session.
- `git log --oneline -5` and `git status --short` before starting any
  session — there may be uncommitted work or the remote may have moved.

## 6. What's genuinely missing (don't rediscover this from scratch)

Two audit documents already exist in `docs/` —
`LIMS_Reality_Check_Gaps_and_Monetisation_Strategy_TZ_v1.0.{pdf,docx}` and
`LIMS_Technical_Audit_and_Implementation_Blueprint_v1.0.{pdf,docx}` — read
them (`read` tool handles PDF text/pages) before proposing new epics, so you
don't re-derive conclusions that are already written down. Headline finding:

> The spec/app models **a stock system**, but the actual Tanzanian phone-shop
> business runs on **credit** (hire-purchase financing). Margins on hardware
> are thin (8–15%); the real profit/risk centre is the loan.

Seven capability gaps identified there, ranked by commercial leverage:

1. **Device locking & recovery** — no mechanism to make an unpaid financed
   handset recoverable (e.g. remote lock). Flagged as the single largest
   lever on default loss.
2. **Automated mobile money repayment rails** — collections are currently
   manual/cash-counter, not integrated with M-Pesa/Tigo Pesa/Airtel Money
   APIs.
3. **Borrower identity / KYC / guarantor mapping** — present in the UI
   (`sell_loan_screen.dart` collects NIDA, guarantor, passport photo) but
   under-specified as a *system-level* risk model (no credit scoring, no
   cross-branch borrower history check).
4. **Agent & consignment inventory** — ledger only understands branches, not
   third-party sellers/consignment stock.
5. **Dual-IMEI trapping, trade-in & blacklist registry** — `phones` table has
   `primary_imei`/`secondary_imei` but no blacklist/bypass-prevention layer.
6. **Fiscal compliance & receipting** — `AppConstants.companyTin` /
   `companyVrn` in `app_constants.dart` are explicitly marked
   `TODO(David): PLACEHOLDERS ... never confirmed against a TRA certificate.`
   Get the real business TIN/VRN/EFD serial before any real receipt is
   printed for a customer.
7. **Credit decisioning & collections operations** — no arrears ladder, no
   reminder workflow, no restructuring state machine; `loans` table has a
   `status` enum but nothing drives transitions automatically.

Do **not** build all of this speculatively. Wait for the user to prioritize;
this section exists so you recognize these as *known, already-documented*
gaps rather than re-investigating them from zero each session.

## 7. Conventions to preserve

- **Comments-as-rationale style.** Much of this codebase uses long doc
  comments explaining *why* a design choice was made (not just what it does)
  — e.g. `sell_loan_screen.dart`'s `_borrowerPassportBytes` comment about a
  fabricated Unsplash photo that used to be shown as "the borrower's KYC
  portrait". Match this style in new code: explain the bug/incident a change
  prevents, not just the mechanism.
- **No fabricated data, ever.** Several existing comments document removing
  previously-fabricated mock content (fake photos, fake "today" numbers).
  Treat this as a hard project norm, not just this agent's own instruction.
- **Codes vs. labels.** Payment channels, categories etc. are stored as
  lowercase codes (`'cash'`, `'mpesa'`) and rendered through a
  locale-specific label function at display time — never persist a
  human-readable/translated string to the database (see
  `_paymentChannelLabel` in `sell_loan_screen.dart` for the pattern and the
  bug it fixed: a sale stored as "Fedha kaunta" in Swahili and "Cash at
  counter" in English, breaking reports that grouped by that column).
- **Role source of truth is the server.** `frontend/lib/core/constants/app_constants.dart`
  `UserRoles` strings must stay in sync with `profiles.role` CHECK constraint
  and `role_permissions.role` in Supabase — the client never invents a role,
  it only projects what the server returns.
- **Supervisor PIN** for loans above TZS 1,000,000 is injected via
  `--dart-define=SUPERVISOR_PIN=...` and is empty (fail-closed, blocks
  high-value loans) unless a build sets it — don't hardcode a PIN.
- Keep `AppConstants.demoMode = false` in anything resembling a production
  build; it compiles out the offline/mock fallback entirely when false.

## 8. Suggested next steps (not mandatory — confirm with user first)

- Rebuild & redeploy the Flutter web bundle once `flutter pub get` works, so
  the Cloudflare Tunnel link reflects commit `7960b4c`'s back-button fix.
- Verify `demo.admin@example.com` / `Demo@2026` actually authenticates against
  the live Supabase project (§4.5).
- Tighten `petty_cash` RLS policies before this leaves "demo/preview mode".
- Replace the placeholder TIN/VRN/company address in `app_constants.dart`
  with verified figures before printing a real customer receipt.
- Work through the Gap register in §6 in the priority order the user picks —
  don't self-select gap #1 (device locking) just because the audit doc ranks
  it highest; confirm with the user, it may not match their immediate
  commercial priority.
