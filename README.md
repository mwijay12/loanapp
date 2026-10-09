# Loan & Inventory Management System

A Flutter mobile application for managing mobile phone loans, inventory, sales, and attendance across multiple branches (TZ). English + Kiswahili.

## Download the app (APK)

No need to build locally — GitHub builds the release automatically:

- **Latest release:** `https://github.com/godfrey125/loan-investment/releases/latest`
- Download **`app-arm64-v8a-release.apk`** (for real phones, ~15–25 MB).
- Every push to `main` also builds APKs under the **Actions** tab → latest run → Artifacts.
- New release: `git tag -a vX.Y.Z -m "..."` + `git push origin vX.Y.Z`.

## Frontend work done (`frontend/`)

### Screens & flows (`lib/features/`)

| Area | What was built |
|---|---|
| Onboarding | 3-slide intro (stock / IMEI / loans) → login |
| Auth | Phone + password login, branch/admin toggle → home or admin console |
| Home dashboard | Branch selector, role switcher, sync status |
| Stock | Searchable inventory, filters (phones / accessories / low stock / on-loan), product detail bottom-sheet |
| Loans | Loan list (all / overdue / current / locked), disburse-loan KYC sheet |
| Borrower details | 3-tab borrower view, M-Pesa record-payment modal, masked NIDA |
| Sell / Loan (POS) | SELL vs LOAN form, borrower + guarantor KYC, deposit / PIN / repayment schedule breakdown |
| Receive stock | Inbound verification, preset IMEIs/items, scan-IMEI dialog |
| Transfers | Inter-branch transfer (destination + qty), decrements inventory |
| Scanner | Animated laser viewfinder, manual IMEI entry, sample phones with cash/loan prices |
| IMEI inspector | IMEI lookup: model / serial / status / borrower / balance / warranty → loan details |
| Attendance | Live clock, GPS clock-in/out with **300–350 m branch geofence** (Super Admin exempt) |
| Reports | Today / Week / Month tabs + official **PDF preview** sheet |
| Daily closing | Z-report: drawer count vs expected, logs to activity feed |
| AI assistant | Mercury 2.5 chat, suggestion chips, history + animated mascot card on home |
| Admin console | HQ dashboard, weekly bar chart, branch list, staff + RBAC tabs, branch performance view |
| Notifications | Localized notification center, "mark all read" |
| Settings | Branch / biometrics / SMS / receipt toggles, M-Pesa + Tigo numbers, language switch |
| Account | Profile, English/Kiswahili selector |

### Platform / UX foundations (`lib/core/`)

- **Routing** (`core/routing/app_router.dart`) — GoRouter + `AppShell` bottom-nav shell: `/home /stock /loans /reports /account`, plus `/ai /scan /sell-loan /imei-inspector /receive /transfer /attendance /daily-closing /admin /branch-performance /notifications /settings /loan-details /onboarding /login`.
- **State** (`core/data/inventory_provider.dart`) — Riverpod: user role, active branch, inventory, loans, activities, attendance + derived totals.
- **Design system** (`core/theme/app_theme.dart`, `core/widgets/ui_kit.dart`) — brand tokens (blue `#1B6EF3` / `#0B4FCE`), `LimsCard`, stat tiles, gradient hero, status pills, bottom sheets, toasts, loading/empty/error states.
- **Two languages** — full `en`/`sw` localization (`core/theme/app_localizations.dart`), switchable in Settings/Account.
- **Role-based access** — Super Admin / Manager / Officer / Storekeeper / Cashier gates admin console, stock reception, NIDA unmasking.
- **Services** — geofenced attendance GPS (`location_service.dart`), A4 financial PDFs (`pdf_report_service.dart` via `pdf`/`printing`), call/WhatsApp/SMS collections with +255 sanitizing (`telecom_service.dart`), Mercury AI chat (`mercury_ai_service.dart`).
- **Data layer** — `MockLimsRepository` (quotes, loan schedules, POS) behind `LimsRepository`, ready to swap for Supabase (`api_service.dart` has the TODO).

## Project structure

```
loan-investment/
├── frontend/          # Flutter mobile application
│   ├── lib/
│   │   ├── features/  # 16 feature modules (screens)
│   │   ├── core/      # routing, theme, widgets, services, data
│   │   └── main.dart  # ProviderScope + MaterialApp.router (en/sw)
│   ├── android/       # Android platform files (AGP 9.x, Java 17)
│   ├── web/           # Web platform files
│   └── pubspec.yaml   # Flutter dependencies
├── backend/           # Supabase backend configuration
│   ├── supabase/      # Database schema (schema.sql)
│   ├── lib/          # Supabase client service
│   └── .env.example  # Environment variables template
├── .github/workflows/ # CI: builds release APK on push/tag
└── README.md          # This file
```

## Getting started

### Frontend (Flutter)

```bash
cd frontend
flutter pub get
flutter run
```

Release APK locally (small, split per ABI):

```bash
cd frontend
flutter build apk --release --split-per-abi
# install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### Backend (Supabase)

1. Create a project at [supabase.com](https://supabase.com)
2. Run `backend/supabase/schema.sql` in the SQL editor
3. Copy `backend/.env.example` to `backend/.env`
4. Update credentials in `backend/lib/supabase_client.dart`

## Demo credentials

- **Email:** john@branch.com
- **Password:** 123456

## Technology stack

- **Frontend:** Flutter 3 (stable) + Dart + Riverpod + GoRouter
- **Backend:** Supabase (PostgreSQL + Auth + Realtime)
- **On-device:** geolocator, pdf/printing, url_launcher, intl, http
- **CI:** GitHub Actions (Java 17 + Flutter stable → split-per-ABI release APKs)
