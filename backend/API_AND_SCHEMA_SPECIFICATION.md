# LIMS Backend API, Database Schema & RBAC Specification
**Document ID:** LIMS-BACKEND-SPEC-2026-002  
**Platform:** Supabase (PostgreSQL 15+) · Flutter Front-End  
**Architects:** David Erick Mwijage (Architecture & Systems) · Godfrey Shora (Lead Developer)  
**Target Release:** LIMS Production v1.0 · Tanzania Phone Dealership Network  

---

## 1. Executive Architecture Summary

LIMS is a credit-first, multi-branch serialized phone inventory and loan management system. In the Tanzanian retail environment, hardware retail margins are thin (8–15%), while handset financing (hire-purchase credit at 20–35% APR) represents the primary profit center.

Consequently, the backend is architected around 4 non-negotiable principles:
1. **Serialized IMEI Integrity**: Handsets are tracked per unique 15-digit primary IMEI and secondary IMEI (anti-carrier bypass), not as generic bulk inventory items.
2. **Immutable Inventory Ledger (`inventory_movements`)**: Every state transition (intake, transfer_out, transfer_in, sale, loan_issue, repossession) is recorded as an immutable append-only ledger entry. No `UPDATE` or `DELETE` policies exist.
3. **Credit as the Primary Product**: Full borrower KYC (NIDA 20-digit ID, mobile money collection rails, residential geocoding) and guarantor mapping tied to automated weekly installment schedules.
4. **Tamper-Proof Attendance & Shift Custody**: Shift check-in timestamps are evaluated server-side using `NOW()`. Mobile device clocks are untrusted. Active staff hold legal custody of the branch cash drawer and safe.

---

## 2. PostgreSQL Relational Schema Extensions

```sql
-- ============================================================================
-- 1. ENUMS & EXTENSIONS
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE device_condition AS ENUM (
    'brand_new_sealed',
    'open_box',
    'refurbished_grade_a',
    'refurbished_grade_b'
);

CREATE TYPE movement_type AS ENUM (
    'intake',
    'transfer_out',
    'transfer_in',
    'cash_sale',
    'loan_issue',
    'loan_repossession',
    'write_off',
    'audit_adjustment'
);

CREATE TYPE loan_status AS ENUM (
    'active',
    'in_grace_period',
    'overdue_flagged',
    'knox_locked',
    'paid_off',
    'defaulted_written_off'
);

CREATE TYPE payment_channel AS ENUM (
    'cash_drawer',
    'mpesa_till',
    'mpesa_paybill',
    'airtel_money',
    'tigo_pesa',
    'crdb_card'
);

-- ============================================================================
-- 2. SERIALIZED PHONES & INVENTORY
-- ============================================================================
CREATE TABLE IF NOT EXISTS phones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID NOT NULL REFERENCES branches(id),
    brand VARCHAR(60) NOT NULL,
    model VARCHAR(100) NOT NULL,
    storage VARCHAR(30) NOT NULL,
    ram VARCHAR(30) NOT NULL,
    color VARCHAR(40) NOT NULL,
    condition device_condition DEFAULT 'brand_new_sealed',
    primary_imei VARCHAR(15) UNIQUE NOT NULL,
    secondary_imei VARCHAR(15),
    barcode VARCHAR(60),
    cost_price DECIMAL(12,2) NOT NULL,
    cash_retail_price DECIMAL(12,2) NOT NULL,
    loan_hire_price DECIMAL(12,2) NOT NULL,
    min_deposit_percent INTEGER DEFAULT 25,
    supplier_name VARCHAR(120) DEFAULT 'Dar Central Hub',
    status VARCHAR(30) DEFAULT 'in_stock', -- 'in_stock', 'sold', 'on_loan', 'in_transit'
    battery_health INTEGER DEFAULT 100,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_phones_imei ON phones(primary_imei);
CREATE INDEX idx_phones_branch ON phones(branch_id);
CREATE INDEX idx_phones_status ON phones(status);

-- ============================================================================
-- 3. IMMUTABLE INVENTORY LEDGER (Audit Requirement 05)
-- ============================================================================
CREATE TABLE IF NOT EXISTS inventory_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone_id UUID NOT NULL REFERENCES phones(id),
    primary_imei VARCHAR(15) NOT NULL,
    movement_type movement_type NOT NULL,
    from_branch_id UUID REFERENCES branches(id),
    to_branch_id UUID REFERENCES branches(id),
    reference_table VARCHAR(60),
    reference_id UUID,
    employee_id UUID NOT NULL REFERENCES employees(id),
    client_operation_id UUID UNIQUE NOT NULL, -- Idempotency key
    notes TEXT,
    occurred_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_movements_phone ON inventory_movements(phone_id);
CREATE INDEX idx_movements_client ON inventory_movements(client_operation_id);
CREATE INDEX idx_movements_time ON inventory_movements(occurred_at DESC);

-- ============================================================================
-- 4. BORROWERS, GUARANTORS & LOAN CONTRACTS
-- ============================================================================
CREATE TABLE IF NOT EXISTS borrowers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    full_name VARCHAR(120) NOT NULL,
    nida_number VARCHAR(25) UNIQUE NOT NULL,
    primary_phone VARCHAR(20) NOT NULL,
    secondary_phone VARCHAR(20),
    ward_residence VARCHAR(100) NOT NULL,
    occupation VARCHAR(100),
    credit_score INTEGER DEFAULT 650,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS guarantors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    borrower_id UUID NOT NULL REFERENCES borrowers(id) ON DELETE CASCADE,
    full_name VARCHAR(120) NOT NULL,
    relationship VARCHAR(60) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    nida_number VARCHAR(25),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS loans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    borrower_id UUID NOT NULL REFERENCES borrowers(id),
    phone_id UUID NOT NULL REFERENCES phones(id),
    branch_id UUID NOT NULL REFERENCES branches(id),
    issued_by_employee_id UUID NOT NULL REFERENCES employees(id),
    supervisor_approved_by UUID REFERENCES employees(id),
    total_loan_amount DECIMAL(12,2) NOT NULL,
    deposit_paid DECIMAL(12,2) NOT NULL,
    financed_balance DECIMAL(12,2) NOT NULL,
    installment_frequency VARCHAR(20) DEFAULT 'weekly',
    total_installments INTEGER DEFAULT 8,
    amount_per_installment DECIMAL(12,2) NOT NULL,
    status loan_status DEFAULT 'active',
    contract_signed BOOLEAN DEFAULT TRUE,
    device_lock_consented BOOLEAN DEFAULT TRUE,
    knox_device_id VARCHAR(100),
    first_due_date DATE NOT NULL,
    issued_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS loan_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loan_id UUID NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
    installment_no INTEGER NOT NULL,
    due_date DATE NOT NULL,
    amount_due DECIMAL(12,2) NOT NULL,
    amount_paid DECIMAL(12,2) DEFAULT 0,
    status VARCHAR(30) DEFAULT 'pending', -- 'pending', 'paid', 'overdue'
    payment_channel payment_channel,
    external_transaction_id VARCHAR(100), -- M-Pesa / Tigo Receipt
    paid_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(loan_id, installment_no)
);

CREATE INDEX idx_schedules_due ON loan_schedules(due_date) WHERE status = 'pending';

-- ============================================================================
-- 5. TAMPER-PROOF ATTENDANCE & SHIFT CUSTODY
-- ============================================================================
CREATE TABLE IF NOT EXISTS attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id),
    branch_id UUID NOT NULL REFERENCES branches(id),
    clock_in TIMESTAMP WITH TIME ZONE DEFAULT NOW(), -- Server authoritative!
    clock_out TIMESTAMP WITH TIME ZONE,
    is_drawer_custodian BOOLEAN DEFAULT TRUE,
    device_lat DOUBLE PRECISION,
    device_lng DOUBLE PRECISION,
    geofence_verified BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 6. OFFLINE SYNC IDEMPOTENCY QUEUE (Audit Requirement 13)
-- ============================================================================
CREATE TABLE IF NOT EXISTS sync_operations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_operation_id UUID UNIQUE NOT NULL, -- Client-generated UUID
    device_id VARCHAR(255) NOT NULL,
    employee_id UUID REFERENCES employees(id),
    branch_id UUID REFERENCES branches(id),
    operation_type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    status VARCHAR(30) DEFAULT 'applied',
    retry_count INTEGER DEFAULT 0,
    last_error TEXT,
    client_created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_sync_client_op ON sync_operations(client_operation_id);
```

---

## 3. Row-Level Security (RLS) Policy Architecture

All tables in production Supabase have RLS enabled: `ALTER TABLE {table_name} ENABLE ROW LEVEL SECURITY;`

| Table | Role: Staff (Branch Agent / Cashier) | Role: Admin (HQ / Regional Director) |
|---|---|---|
| `phones` | `SELECT, INSERT` (Branch Scoped via employee's branch) | `SELECT, INSERT, UPDATE, DELETE` (Network-wide) |
| `inventory_movements` | `INSERT, SELECT` (Branch Scoped, Append-Only) | `SELECT` (Network-wide, Immutable) |
| `loans` & `loan_schedules` | `SELECT, INSERT` (Own branch only) | `SELECT, UPDATE` (All branches, Approvals > 1M) |
| `borrowers` & `guarantors` | `SELECT, INSERT` | `SELECT, UPDATE, EXPORT` |
| `attendance` | `INSERT` (Self check-in, NOW()), `SELECT` (Own records) | `SELECT, UPDATE` (All staff shifts & rosters) |
| `sync_operations` | `INSERT, SELECT` (Own device ID only) | `SELECT` (System diagnostics) |

---

## 4. REST API Contract Endpoints

### 4.1 Handset Intake & IMEI Validation
- **POST** `/api/v1/inventory/intake`
- **Headers:** `Authorization: Bearer <token>`, `X-Branch-ID: <uuid>`
- **Payload:**
```json
{
  "client_operation_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "brand": "Samsung",
  "model": "Galaxy A15",
  "storage": "128GB",
  "ram": "6GB",
  "color": "Light Blue",
  "condition": "brand_new_sealed",
  "primary_imei": "358920112849102",
  "secondary_imei": "358920112849110",
  "cost_price": 290000.00,
  "cash_retail_price": 380000.00,
  "loan_hire_price": 460000.00,
  "supplier": "Dar Central Hub",
  "quantity": 5
}
```

### 4.2 Cash POS Sale Checkout
- **POST** `/api/v1/sales/checkout`
- **Payload:**
```json
{
  "client_operation_id": "a548e64c-b7f3-42e1-a083-d34e9e4f552a",
  "phone_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "primary_imei": "358920112849102",
  "payment_channel": "mpesa_till",
  "amount_paid": 380000.00,
  "customer_phone": "0754892314",
  "issue_efd_receipt": true
}
```

### 4.3 Phone Loan Issuance (Credit & KYC)
- **POST** `/api/v1/loans/issue`
- **Payload:**
```json
{
  "client_operation_id": "e30e7df5-7b56-4dc0-84c2-26f59b66bb18",
  "phone_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "borrower": {
    "full_name": "Bakari Juma Mwambungu",
    "nida_number": "19920415-14120-00002-18",
    "primary_phone": "0754892314",
    "secondary_phone": "0682110445",
    "ward_residence": "Kariakoo, Mtaa wa Swahili",
    "occupation": "Biashara ya Nguo"
  },
  "guarantor": {
    "full_name": "Hawa Rashidi Said",
    "relationship": "Dada Mzazi",
    "phone": "0713452980",
    "nida_number": "19890212-14120-00001-24"
  },
  "financials": {
    "total_loan_amount": 460000.00,
    "deposit_paid": 115000.00,
    "installment_weeks": 8,
    "amount_per_week": 43125.00,
    "payment_channel": "mpesa_paybill",
    "contract_signed": true,
    "device_lock_consented": true
  },
  "supervisor_pin": "8821" // Mandatory if total_loan_amount > 1,000,000
}
```

### 4.4 Remote Knox Device Locking Webhook / Command
- **POST** `/api/v1/loans/{loan_id}/lock-device`
- **Headers:** `Authorization: Bearer <admin_token>`
- **Response:**
```json
{
  "status": "success",
  "loan_id": "e30e7df5-7b56-4dc0-84c2-26f59b66bb18",
  "imei": "358920112849102",
  "knox_status": "LOCKED",
  "lock_timestamp": "2026-10-01T13:00:00Z",
  "screen_message": "Kifaa hiki kimefungwa na LIMS kwa sababu ya kuchelewesha marejesho ya mkopo. Lipa TZS 43,125 kupitia M-Pesa Lipa Namba 5421098 kufungua."
}
```
