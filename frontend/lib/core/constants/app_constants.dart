class AppConstants {
  static const String appName = 'Loan & Inventory';
  static const String currency = 'TZS';

  // NOTE: employeeName / employeeRole used to live here as hardcoded values
  // ("John" / "Branch Manager"). They were removed because the account screen
  // displayed them instead of the real signed-in identity, which meant every
  // user saw the same name and a role they may not hold. Read the live session
  // instead: userRoleProvider for the role, activeStaffMemberProvider for the
  // staff profile.
  static const String branchName = 'Mbagala Branch';

  /// First branch to go live. Single-branch launch; multi-branch stays possible
  /// because every operational table carries `branch_id` and RLS derives the
  /// branch from the session.
  static const String launchBranch = 'Mbagala Branch';

  /// Branch master list.
  ///
  /// TODO(P2): read these from `public.branches` in Supabase. They live here for
  /// now only so the admin panel dropdown and the location-service geofences
  /// stop disagreeing with each other. Note Mbagala was missing from every
  /// hardcoded copy, including location_service.dart.
  static const List<String> branches = <String>[
    'Mbagala Branch',
    'Kariakoo Main Branch',
    'Mbezi Hub Branch',
    'Mwanza Branch',
    'Arusha Branch',
  ];

  // ---------------------------------------------------------------------
  // Showcase / demo build.
  //
  // FALSE unless the build passes --dart-define=DEMO_MODE=true. When true the
  // app never talks to Supabase: it runs on the bundled mock data, and the
  // login screen accepts the demo accounts below instead of calling Supabase
  // Auth. That keeps a publicly shared demo link from exposing a database.
  //
  // A production build MUST NOT set this flag. The branch is compiled out when
  // it is false, so a release APK cannot be talked into demo mode at runtime.
  // ---------------------------------------------------------------------
  static const bool demoMode =
      bool.fromEnvironment('DEMO_MODE', defaultValue: false);

  static const String demoPassword = 'Demo@2026';

  /// Demo identities. Deliberately hardcoded and deliberately obvious: these
  /// are throwaway accounts for a showcase, never real staff.
  static const Map<String, Map<String, String>> demoAccounts =
      <String, Map<String, String>>{
    'demo.admin@example.com': {
      'name': 'Demo Super Admin',
      'role': UserRoles.superAdmin,
    },
    'demo.manager@example.com': {
      'name': 'Demo Branch Manager',
      'role': UserRoles.branchManager,
    },
    'demo.loan@example.com': {
      'name': 'Demo Loan Officer',
      'role': UserRoles.loanOfficer,
    },
    'demo.store@example.com': {
      'name': 'Demo Storekeeper',
      'role': UserRoles.storekeeper,
    },
    'demo.cashier@example.com': {
      'name': 'Demo Counter Cashier',
      'role': UserRoles.counterCashier,
    },
    'demo.audit@example.com': {
      'name': 'Demo Auditor',
      'role': UserRoles.auditor,
    },
  };

  // ---------------------------------------------------------------------
  // Company identity used on printed documents.
  //
  // These were previously typed out inside the PDF service, so the receipt,
  // the customer statement and the loan agreement each carried their own copy
  // and could disagree. There is now exactly one place to change them.
  //
  // TODO(David): these fiscal values are PLACEHOLDERS copied from the old
  // hardcoded strings in pdf_report_service.dart — they were never confirmed
  // against a TRA certificate. Send the real business name, TIN, VRN, EFD
  // serial and address, and only this block needs editing.
  // ---------------------------------------------------------------------
  static const String companyName = 'LIMS Tanzania';
  static const String companyTin = '142-998-314';
  static const String companyVrn = '40-028912-K';
  static const String companyAddress = 'Mbagala, Dar es Salaam, Tanzania';
  static const String companyPhone = '';
  static const String companyEmail = '';
  static const String companyWebsite = '';

  /// Printed only when a real value exists, so a blank field degrades into an
  /// absent line rather than an empty 'TIN: ' on an official document.
  static String fiscalLine() {
    final parts = <String>[
      if (companyTin.isNotEmpty) 'TIN: $companyTin',
      if (companyVrn.isNotEmpty) 'VRN: $companyVrn',
    ];
    return parts.join('  |  ');
  }


  static const String offline = 'Offline';
  static const String syncing = 'Syncing...';
  static const String allSynced = 'All transactions synced';

  // Status labels
  static const String statusAvailable = 'AVAILABLE';
  static const String statusSold = 'SOLD';
  static const String statusTransferred = 'TRANSFERRED';
  static const String statusDamaged = 'DAMAGED';
  static const String statusReturned = 'RETURNED';
  static const String statusPending = 'PENDING';
  static const String statusInTransit = 'IN TRANSIT';
  static const String statusReceived = 'RECEIVED';
  static const String statusMatched = 'STOCK MATCHED';
  static const String statusNotMatched = 'STOCK MISMATCH';
  static const String statusComplete = 'Complete';
  static const String statusIncomplete = 'Incomplete';
}

/// Canonical LIMS roles — the single source of truth for the frontend.
///
/// These strings MUST match `public.role_permissions.role` and the
/// `profiles.role` CHECK constraint in Supabase. The DB is authoritative:
/// the frontend only ever *projects* the role it is given, it never invents
/// one. Keep this list in sync with the seed migration.
class UserRoles {
  UserRoles._();

  static const String superAdmin = 'Super Admin';
  static const String branchManager = 'Branch Manager';
  static const String loanOfficer = 'Loan Officer';
  static const String storekeeper = 'Storekeeper';
  static const String counterCashier = 'Counter Cashier';
  static const String auditor = 'Auditor';

  /// Pre-invitation state: the row exists but the person has no access yet.
  static const String pending = 'Pending';

  /// Sentinel for "no authenticated session". Most restrictive value.
  static const String noSession = 'noSession';

  /// Roles that can be assigned through the admin panel, in seniority order.
  static const List<String> assignable = <String>[
    superAdmin,
    branchManager,
    loanOfficer,
    storekeeper,
    counterCashier,
    auditor,
  ];

  /// Every role the app recognises, including non-assignable states.
  static const Set<String> all = <String>{
    superAdmin,
    branchManager,
    loanOfficer,
    storekeeper,
    counterCashier,
    auditor,
    pending,
    noSession,
  };

  /// Retired role strings that may still exist on old rows.
  ///
  /// 'Inventory Officer' was renamed to Storekeeper and 'Staff' was a
  /// catch-all that actually behaved like Counter Cashier. Mapping them here
  /// means an un-migrated row still resolves instead of dropping the user to
  /// `noSession`.
  static const Map<String, String> legacyAliases = <String, String>{
    'Inventory Officer': storekeeper,
    'Staff': counterCashier,
  };

  /// Returns the canonical role, or null when the value is unknown/empty.
  ///
  /// Never falls back upward: an unrecognised string resolves to null so the
  /// caller can apply the most restrictive behaviour.
  static String? normalize(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    final mapped = legacyAliases[value] ?? value;
    return all.contains(mapped) ? mapped : null;
  }

  static bool isKnown(String? raw) => normalize(raw) != null;

  /// True only for a real, canonical, assignable role.
  static bool isAssignable(String? raw) {
    final value = normalize(raw);
    return value != null && assignable.contains(value);
  }

  /// Human label including the Swahili gloss used in the admin panel.
  static String label(String role) {
    switch (role) {
      case superAdmin:
        return 'Super Admin (Mamlaka Kamili)';
      case branchManager:
        return 'Branch Manager (Meneja wa Tawi)';
      case loanOfficer:
        return 'Loan Officer (Afisa Mkopo)';
      case storekeeper:
        return 'Storekeeper (Afisa Stoo)';
      case counterCashier:
        return 'Counter Cashier (Mweka Hazina)';
      case auditor:
        return 'Auditor (Mkaguzi — Kusoma Tu)';
      case pending:
        return 'Pending (Anasubiri Mwaliko)';
      default:
        return role;
    }
  }

  // ---------------------------------------------------------------------
  // Capability sets.
  //
  // These mirror `public.role_permissions` in Supabase. The DB is the real
  // enforcement point; these exist so the UI stops hardcoding role strings in
  // a dozen different places and drifting from the seed data. Keep in sync.
  // ---------------------------------------------------------------------

  /// Roles that can see customer PII unmasked (NIDA, guarantor contacts).
  static const Set<String> piiViewers = <String>{
    superAdmin,
    branchManager,
    loanOfficer,
  };

  /// Roles that can unmask customer PII. Everything else, including an unknown
  /// or signed-out session, gets masked data.
  static bool canViewPii(String? raw) => piiViewers.contains(normalize(raw));

  /// Roles that administer people: invite staff, change roles, suspend accounts.
  static const Set<String> staffAdmins = <String>{superAdmin, branchManager};

  static bool canAdministerStaff(String? raw) =>
      staffAdmins.contains(normalize(raw));

  /// Roles that may approve an override or a loan they did not create.
  /// Separation of duties: the creator can never be the approver.
  static const Set<String> approvers = <String>{superAdmin, branchManager};

  static bool canApprove(String? raw) => approvers.contains(normalize(raw));

  /// Roles that handle cash at a till.
  static bool canHandleCash(String? raw) =>
      normalize(raw) == counterCashier ||
      normalize(raw) == branchManager ||
      normalize(raw) == superAdmin;

  /// Roles that move stock.
  static bool canManageStock(String? raw) =>
      normalize(raw) == storekeeper ||
      normalize(raw) == branchManager ||
      normalize(raw) == superAdmin;

  /// True when the session is real and known (not signed out, not pending).
  static bool hasAccess(String? raw) => isAssignable(raw);

  /// The role to show in a header: the canonical label, or a safe placeholder.
  static String displayName(String? raw) => normalize(raw) ?? '—';
}
