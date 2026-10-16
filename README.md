# LIMS — Loan & Inventory Management System (Tanzania)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?logo=supabase)](https://supabase.com)
[![Cloudinary](https://img.shields.io/badge/Cloudinary-Media%20CDN-3448C5?logo=cloudinary)](https://cloudinary.com)
[![License](https://img.shields.io/badge/Author-David%20Erick%20Mwijage-1B6EF3)](https://github.com/mwijay12)

Enterprise mobile phone retail loan, hire-purchase credit, dual-IMEI inventory ledger, and multi-branch attendance system tailored for Tanzanian smartphone dealerships (Kariakoo, Mbezi, Arusha, Mwanza, Dodoma). Full English + Kiswahili support.

---

## 🌟 Lead Architecture & Maintainer
* **Architect & Developer:** David Erick Mwijage ([@mwijay12](https://github.com/mwijay12))
* **Repository:** [https://github.com/mwijay12/loanapp](https://github.com/mwijay12/loanapp)
* **Target Environment:** Tanzania Mobile Phone Retail & Credit Financing

---

## 🚀 Key Architectural Capabilities

1. **Credit-First Loan Engine:**
   - 20-digit NIDA validation, biometric & ID scan verification, guarantor mapping.
   - Flexible repayment schedules (daily, weekly, monthly installments via M-Pesa Till/Paybill, Airtel Money, Tigo Pesa).
   - Dynamic interest & penalty calculations with automated overdue flagging.

2. **Serialized Dual-IMEI Inventory & Ledger:**
   - Primary & secondary IMEI tracking to eliminate anti-carrier bypass.
   - Barcode laser viewfinder scanner for instant stock-in, transfers, and sales.
   - High-resolution phone renders hosted on **Cloudinary CDN** (`fbwhgkbe`).

3. **Supabase Cloud Backend & Database:**
   - PostgreSQL tables: `profiles`, `products`, `loans`, `branches`, `activities`, `attendance`, `heartbeat_pings`.
   - Live Supabase authentication with role-based access control (Super Admin vs Branch Staff).

4. **Permanent Supabase Keep-Alive & Heartbeat Automation:**
   - Supabase free-tier automatically pauses projects after 7 days of inactivity.
   - **Automated Solution:** GitHub Action (`.github/workflows/supabase-heartbeat.yml`) runs every 2 days to ping and write an active heartbeat entry into `heartbeat_pings`.
   - **In-App Touch:** `ApiService().sendHeartbeatPing()` executes upon mobile app launch.
   - **Local Script:** `run_heartbeat.bat` & `scripts/supabase_heartbeat.ps1` for on-demand keep-alive triggers.

5. **Cloudinary Media Storage:**
   - Used for borrower KYC documents, identity cards, receipt photos, and device condition captures.
   - Uploads go through a signed preset configured in CI secrets (never commit secrets here).

6. **Tamper-Proof Geofenced Attendance:**
   - 300–350m branch geofence enforcement using device GPS + server timestamp.

---

## 📱 Mobile App Downloads (APK)

GitHub Actions builds release APKs automatically on every push:
* **Repository Releases:** [https://github.com/mwijay12/loanapp/releases](https://github.com/mwijay12/loanapp/releases)
* **Recommended APK:** `app-arm64-v8a-release.apk` (Optimized for modern Android devices).

---

## 🔑 Login & Demo Credentials

> P0: demo credentials were removed from this file and from the login screen.
> Contact your administrator for credentials. Never commit real passwords.
> Production builds contain no demo login path.

---

## 📂 Project Structure

```text
loanapp/
├── .github/workflows/
│   ├── android-apk.yml          # GitHub CI/CD: Builds release APK on push/tag
│   └── supabase-heartbeat.yml   # Keep-Alive: Cron job every 2 days to prevent pause
├── backend/
│   ├── supabase/
│   │   └── schema.sql           # Complete PostgreSQL DDL schema & indexes
│   ├── lib/
│   │   └── supabase_client.dart # Supabase service client
│   └── API_AND_SCHEMA_SPECIFICATION.md
├── frontend/
│   ├── lib/
│   │   ├── core/                # Theme, routing, services (Supabase, Cloudinary, Telecom, GPS)
│   │   ├── features/            # 16 Modules: Auth, Home, Stock, Loans, POS, Scanner, Reports, etc.
│   │   └── main.dart            # Flutter entrypoint (ProviderScope + Multi-lingual)
│   ├── android/                 # Android platform configuration (Camera, GPS, Storage permissions)
│   ├── assets/                  # High-res device images & icons
│   └── pubspec.yaml             # Flutter dependencies
├── scripts/
│   └── supabase_heartbeat.ps1   # PowerShell keep-alive script
├── run_heartbeat.bat            # Windows 1-click heartbeat runner
└── README.md
```

---

## 🛠️ Local Development

### 1. Run Flutter Mobile App
```bash
cd frontend
flutter pub get
flutter run
```

### 2. Manual Heartbeat Ping
```bash
# Windows 1-click
./run_heartbeat.bat

# Or PowerShell
powershell -ExecutionPolicy Bypass -File scripts/supabase_heartbeat.ps1
```

---

## ⚖️ License
Developed by **David Erick Mwijage** ([@mwijay12](https://github.com/mwijay12)). All Rights Reserved.
