# Backend - Supabase Configuration

## Setup

1. Create a new project at [supabase.com](https://supabase.com)
2. Run the SQL schema in `supabase/schema.sql` in the Supabase SQL editor
3. Copy `.env.example` to `.env` and fill in your credentials
4. Update `lib/supabase_client.dart` with your Supabase URL and anon key

## Database Tables

- `branches` - Branch locations
- `employees` - Staff accounts
- `phones` - Device inventory with IMEI
- `customers` - Customer information
- `sales` - Sales transactions
- `loans` - Loan records
- `loan_payments` - Loan payment history
- `stock_transfers` - Inter-branch transfers
- `attendance` - Staff check-in/out
- `daily_closing` - Daily stock closing
- `notifications` - System notifications
- `audit_logs` - Activity audit trail

## API Integration

The frontend can now connect to Supabase by:
1. Adding `supabase_flutter` to `frontend/pubspec.yaml`
2. Calling `SupabaseService.init()` at app startup
3. Using `SupabaseService` methods instead of mock data
