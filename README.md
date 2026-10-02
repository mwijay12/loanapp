# Loan & Inventory Management System

A modern Flutter mobile application for managing mobile phone loans, inventory, sales, and attendance across multiple branches.

## Project Structure

```
loan-investment/
├── frontend/          # Flutter mobile application
│   ├── lib/          # Dart source code
│   ├── android/      # Android platform files
│   ├── web/          # Web platform files
│   └── pubspec.yaml  # Flutter dependencies
│
├── backend/           # Supabase backend configuration
│   ├── supabase/     # Database schema
│   ├── lib/          # Supabase client service
│   └── .env.example  # Environment variables template
│
└── README.md         # This file
```

## Features

- **Inventory Management** - Track phones by IMEI, model, brand
- **Sales & Loans** - Process sales and loan transactions
- **Stock Transfers** - Move inventory between branches
- **Attendance** - Fingerprint-based staff check-in/out
- **Daily Closing** - End-of-day stock reconciliation
- **AI Assistant** - Intelligent help with typewriter animations
- **Multi-language** - English and Kiswahili support
- **Offline Support** - Local data with sync capability
- **Reports** - Daily activity, sales, and stock reports

## Getting Started

### Frontend (Flutter)

```bash
cd frontend
flutter pub get
flutter run
```

### Backend (Supabase)

1. Create a project at [supabase.com](https://supabase.com)
2. Run `backend/supabase/schema.sql` in the SQL editor
3. Copy `backend/.env.example` to `backend/.env`
4. Update credentials in `backend/lib/supabase_client.dart`

## Demo Credentials

- **Email:** john@branch.com
- **Password:** 123456

## Technology Stack

- **Frontend:** Flutter + Dart + Riverpod + GoRouter
- **Backend:** Supabase (PostgreSQL + Auth + Realtime)
- **Database:** PostgreSQL (via Supabase)
- **Authentication:** Supabase Auth
