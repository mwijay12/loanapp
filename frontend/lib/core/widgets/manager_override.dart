import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../data/inventory_provider.dart';
import '../data/mock_lims_data.dart';
import '../data/supabase_source.dart';

/// Manager approval at the counter, and the log behind it.
///
/// What used to stand here was a bottom sheet that printed a PIN on the screen —
/// `8 8 2 1` — above a list containing one invented request ("Galaxy A15 ·
/// TZS 30,000 Discount · Requested by Zawadi") whose Approve button ended in the
/// message "OTP PIN dispatched to Till #2". Nothing was sent anywhere. A PIN shown
/// on the shop's own screen is not an approval control, and a request list with
/// fabricated rows is worse than an empty one, because the manager approves a
/// customer who was never standing there.
///
/// Both halves here are real:
///  * [promptManagerOverride] asks a Branch Manager for their PIN and hands back
///    the single-use token `request_manager_override` issued. The PIN is compared
///    by Postgres against `profiles.manager_pin_hash`; this file never sees it,
///    stores it, or decides whether it was right.
///  * [showManagerOverridePanel] sets the manager's own PIN and reads
///    `override_audit`, a table no client can insert into, update or delete.
///
/// The wording distinguishes the states the database actually returns, because at
/// a counter they ask for different behaviour: a wrong PIN may be retried, five of
/// them in fifteen minutes must not be.

/// Asks a manager to authorise one action and returns what the server said.
///
/// Returns [ManagerOverride.isGranted] only with a token that has not been spent.
/// The sheet stays open on a wrong PIN so the manager can try again, and it
/// disables itself while a request is in flight: every wrong attempt is audited and
/// counts toward the lockout, so a double tap is not a harmless UI accident.
Future<ManagerOverride> promptManagerOverride(
  BuildContext context, {
  String action = 'sale',
  String detail = '',
}) async {
  final result = await showModalBottomSheet<ManagerOverride>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ManagerPinSheet(action: action, detail: detail),
  );
  return result ??
      const ManagerOverride(
        ManagerOverrideStatus.failed,
        error: 'No manager approval was given, so the sale was not made.',
      );
}

/// Opens the manager's own override screen: set a PIN, read the log.
Future<void> showManagerOverridePanel(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _OverridePanel(),
  );
}

class _ManagerPinSheet extends StatefulWidget {
  const _ManagerPinSheet({required this.action, required this.detail});

  final String action;
  final String detail;

  @override
  State<_ManagerPinSheet> createState() => _ManagerPinSheetState();
}

class _ManagerPinSheetState extends State<_ManagerPinSheet> {
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await SupabaseSource.requestManagerOverride(
      pin: _pin.text.trim(),
      action: widget.action,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.isGranted) {
      Navigator.pop(context, result);
      return;
    }
    // Wrong PIN and locked both stay open: the person reading the message is the
    // one who has to act on it, and closing the sheet would bury the reason.
    setState(() => _error = result.message);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_open_rounded, size: 20, color: Color(0xFFE5484D)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Branch Manager approval',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.detail.isEmpty
                  ? 'A Storekeeper may take cash for a sale only while a Branch '
                      'Manager is present with their own PIN.'
                  : widget.detail,
              style: const TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pin,
              obscureText: true,
              autofocus: true,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: const [],
              decoration: const InputDecoration(
                labelText: 'Manager PIN (6 digits)',
                counterText: '',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFE5484D), height: 1.35),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_pin.text.trim().length == 6 && !_busy) ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5484D),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 46),
                ),
                child: Text(_busy ? 'Checking…' : 'Approve'),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// The manager's own view: set a PIN, read the audit trail.
class _OverridePanel extends ConsumerStatefulWidget {
  const _OverridePanel();

  @override
  ConsumerState<_OverridePanel> createState() => _OverridePanelState();
}

class _OverridePanelState extends ConsumerState<_OverridePanel> {
  final _newPin = TextEditingController();
  final _confirmPin = TextEditingController();
  String? _notice;
  bool _noticeIsError = false;
  bool _saving = false;
  List<Map<String, dynamic>>? _log;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newPin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await SupabaseSource.fetchOverrideAudit();
    if (!mounted) return;
    setState(() => _log = rows);
  }

  Future<void> _savePin() async {
    final pin = _newPin.text.trim();
    if (pin != _confirmPin.text.trim()) {
      setState(() {
        _noticeIsError = true;
        _notice = 'The two PINs do not match.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _notice = null;
    });
    final result = await SupabaseSource.setManagerPin(pin: pin);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _noticeIsError = !result.isGranted;
      _notice = result.isGranted
          ? 'Your PIN is set. Only you and a Super Admin can change it again.'
          : result.message;
      if (result.isGranted) {
        _newPin.clear();
        _confirmPin.clear();
      }
    });
    _load();
  }

  String _nameOf(String? profileId, List<StaffMember> staff) {
    if (profileId == null || profileId.isEmpty) return '—';
    for (final s in staff) {
      if (s.id == profileId) return s.name;
    }
    // The uuid's tail is printed rather than nothing: an unresolvable person in an
    // audit line still has to be distinguishable from another unresolvable person.
    return 'staff ${profileId.substring(profileId.length > 4 ? profileId.length - 4 : 0)}';
  }

  String _labelOf(String action) => switch (action) {
        'pin_set' => 'PIN set',
        'pin_failed' => 'Wrong PIN entered',
        'override_granted' => 'Approval granted',
        'sale_recorded' => 'Sale recorded under approval',
        'payment_recorded' => 'Payment recorded under approval',
        _ => action,
      };

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffProvider);
    final role = ref.watch(userRoleProvider);
    final maySetPin = role == UserRoles.branchManager || role == UserRoles.superAdmin;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Override PIN & log',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                if (!maySetPin)
                  const Text(
                    'Your role can read this log but cannot set a PIN. Only a Branch '
                    'Manager or Super Admin has a PIN of their own.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                  )
                else ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Nobody sees this PIN but you. It is checked by the server, and '
                    'every use is written in the log below.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPin,
                    obscureText: true,
                    enabled: !_saving,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'New PIN (6 digits)',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _confirmPin,
                    obscureText: true,
                    enabled: !_saving,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Repeat PIN',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_notice != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _notice!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: _noticeIsError ? const Color(0xFFE5484D) : const Color(0xFF12B76A),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_newPin.text.length == 6 && !_saving) ? _savePin : null,
                      child: Text(_saving ? 'Saving…' : 'Save PIN'),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Override log',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (_log != null)
                      Text('${_log!.length} entries',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      onPressed: _load,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_log == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (_log!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Nothing has been overridden yet. This list fills itself: a PIN '
                      'set, a wrong PIN, an approval, and the sale it paid for.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                    ),
                  )
                else
                  for (final row in _log!)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            row['action'] == 'pin_failed'
                                ? Icons.error_outline_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 15,
                            color: row['action'] == 'pin_failed'
                                ? const Color(0xFFE5484D)
                                : const Color(0xFF12B76A),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_labelOf((row['action'] ?? '').toString())} · '
                              '${_nameOf((row['manager_profile'] ?? row['actor_profile'])?.toString(), staff)}'
                              '${row['branch_name'] == null ? '' : ' · ${row['branch_name']}'}',
                              style: const TextStyle(fontSize: 12.5, height: 1.3),
                            ),
                          ),
                          Text(
                            _ago(row['at']?.toString()),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A short, honest relative time. The raw `time_label` strings elsewhere in the
/// app are stored text from the seed data; this table has real timestamps.
String _ago(String? iso) {
  final at = DateTime.tryParse(iso ?? '')?.toLocal();
  if (at == null) return '';
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 8) return '${d.inDays}d ago';
  return '${at.day}/${at.month}';
}
