import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/data/branch_provider.dart';
import '../../../core/data/mock_lims_data.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/data/member_admin.dart';
import '../../../core/data/sales_provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/services/avatar_service.dart';
import '../../../core/services/live_data.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../home/presentation/dashboard_kit.dart';

/// Settings, built from the session instead of from a script.
///
/// The previous screen was a mock-up: a fixed \"David Julius / Store Manager\"
/// header, a hardcoded branch starting at Kariakoo, a six-item branch list that
/// belonged to nobody, and a dropdown that let any role move the terminal. A
/// Mbagala Branch Manager therefore opened Settings and read that they were
/// posted to Kariakoo, with permission to switch.
///
/// Everything below comes from the signed-in person: their own row, their own
/// branch, their own role, and the branches that exist in the database. The only
/// choice offered is one their role can actually make.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _savingPhoto = false;

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final me = ref.watch(activeStaffMemberProvider);
    final branch = ref.watch(activeBranchProvider);
    final canSwitch = UserRoles.canSwitchBranch(ref.watch(userRoleProvider));
    final live = ref.watch(dataSourceProvider);
    final salesLoaded = ref.watch(salesProvider).length;

    return Scaffold(
      backgroundColor: DashPalette.page,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: DashPalette.pageGradient,
            stops: DashPalette.pageStops,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              _header(locale),
              const SizedBox(height: 18),
              _profileCard(locale, me),
              const SizedBox(height: 22),
              _sectionTitle(tr(locale, 'set.branch')),
              const SizedBox(height: 10),
              _branchCard(locale, me, branch, canSwitch),
              const SizedBox(height: 22),
              _sectionTitle(tr(locale, 'set.language')),
              const SizedBox(height: 10),
              _languageCard(locale),
              const SizedBox(height: 22),
              _sectionTitle(tr(locale, 'set.dataTitle')),
              const SizedBox(height: 10),
              _dataCard(locale, live.kind, salesLoaded),
              const SizedBox(height: 22),
              _sectionTitle(tr(locale, 'set.sessionTitle')),
              const SizedBox(height: 10),
              _sessionCard(locale),
              const SizedBox(height: 20),
              _signOutCard(locale),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  tr(locale, 'set.version'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: DashPalette.faint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// The same back affordance the dashboards use: a white circle on the
  /// gradient, not a flat app bar. Settings is a page of the app, not a
  /// different app.
  Widget _header(Locale locale) {
    return DashPageHeader(
      title: tr(locale, 'set.title'),
      onBack: () => context.pop(),
    );
  }

  /// Sign out is an action, so it is a row you press — not a red outline that
  /// reads like a broken button.
  Widget _signOutCard(Locale locale) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFD9E0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F2F6BD6),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: _signOut,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDF1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: Color(0xFFE5484D),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr(locale, 'set.signOut'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                      color: Color(0xFFE5484D),
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: DashPalette.faint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _signOut() {
    ref.read(userRoleProvider.notifier).clearSession();
    ref.read(signedInNameProvider.notifier).state = null;
    ref.read(signedInBranchProvider.notifier).state = null;
    ref.read(signedInAvatarProvider.notifier).state = null;
    context.go('/login');
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          letterSpacing: -0.1,
          fontWeight: FontWeight.w800,
          color: DashPalette.ink,
        ),
      );

  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: DashPalette.hairline),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F2F6BD6),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );

  Widget _profileCard(Locale locale, StaffMember me) {
    final roleLabel =
        tr(locale, UserRoles.labelKey(ref.watch(userRoleProvider)));
    final branchLabel =
        me.branch.trim().isEmpty ? tr(locale, 'set.noBranch') : me.branch;
    final hasSession = ref.watch(userRoleProvider) != UserRoles.noSession;

    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    PersonAvatar(
                      name: me.name,
                      grad: me.grad,
                      asset: me.avatarAsset,
                      size: 58,
                    ),
                    if (hasSession)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.brand600,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 11, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        me.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        roleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${tr(locale, 'set.activeAt')} · $branchLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF12B76A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _savingPhoto || !hasSession
                    ? null
                    : () => _showPhotoSheet(locale, me),
                icon: _savingPhoto
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_camera_outlined, size: 16),
                label: Text(
                  tr(locale, 'set.changePhoto'),
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.brand600,
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  backgroundColor: const Color(0xFFF5F9FF),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _branchCard(
      Locale locale, StaffMember me, String branch, bool canSwitch) {
    final branches =
        ref.watch(branchesProvider).where((b) => b.active).toList();

    return _card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.brand100,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      size: 18, color: AppTheme.brand600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // The terminal is either the branch you are posted to,
                        // or one a Super Admin is inspecting. The wording says
                        // which, because those are different situations.
                        canSwitch
                            ? tr(locale, 'set.terminal')
                            : tr(locale, 'set.assignedBranch'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        branch,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.brand600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canSwitch)
                  TextButton(
                    onPressed: branches.isEmpty
                        ? null
                        : () => _showBranchPicker(locale, branch, branches),
                    child: Text(
                      tr(locale, 'set.change'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  canSwitch
                      ? Icons.swap_horiz_rounded
                      : Icons.lock_outline_rounded,
                  size: 13,
                  color: AppTheme.ink400,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    canSwitch
                        ? tr(locale, 'set.switchHintAdmin')
                        : tr(locale, 'set.switchHintLocked'),
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.35,
                      color: AppTheme.ink500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageCard(Locale locale) {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            for (final code in const ['en', 'sw'])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      final next = Locale(code);
                      ref.read(localeProvider.notifier).state = next;
                      LocaleStore.save(next);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: locale.languageCode == code
                            ? AppTheme.brand600
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        tr(locale, 'set.lang.$code'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: locale.languageCode == code
                              ? Colors.white
                              : AppTheme.ink700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dataCard(Locale locale, DataSourceKind kind, int salesLoaded) {
    final live = kind == DataSourceKind.live;
    return _card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: live ? const Color(0xFF12B76A) : const Color(0xFFF79009),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                live
                    ? trf(locale, 'set.dataLive', {'n': salesLoaded})
                    : tr(locale, 'set.dataDemo'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Who is signed in, from the account itself.
  ///
  /// This card used to read the `staff` roster, which has no email column, so it
  /// printed `—` under "Login email" and `—` under a "Staff number" the database
  /// has never had. The email is on the session; the branch and the role are
  /// already printed in the header above this card, so repeating them here would
  /// be two rows saying the same thing.
  Widget _sessionCard(Locale locale) {
    final me = ref.watch(activeStaffMemberProvider);
    final member = ref.watch(currentMemberProvider).valueOrNull;
    final sessionEmail = liveClient()?.auth.currentUser?.email ?? '';
    final email = (member?.email.isNotEmpty ?? false)
        ? member!.email
        : (sessionEmail.isNotEmpty ? sessionEmail : me.email);

    return _card(
      child: Column(
        children: [
          _row(locale, 'set.loginEmail', email.trim().isEmpty ? '—' : email),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _row(locale, 'set.rbacOwner', tr(locale, 'set.rbacOwnerValue')),
        ],
      ),
    );
  }

  Widget _row(Locale locale, String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr(locale, key),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.ink600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBranchPicker(
      Locale locale, String current, List<BranchRecord> branches) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              tr(locale, 'set.pickBranch'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink900,
              ),
            ),
            const SizedBox(height: 6),
            ...branches.map((b) {
              final selected = b.name == current;
              return ListTile(
                leading: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.storefront_outlined,
                  color: selected ? AppTheme.brand600 : AppTheme.ink500,
                ),
                title: Text(
                  b.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppTheme.brand600 : AppTheme.ink900,
                  ),
                ),
                subtitle: Text(
                  b.city,
                  style: const TextStyle(fontSize: 11, color: AppTheme.ink500),
                ),
                onTap: () {
                  final moved =
                      ref.read(activeBranchProvider.notifier).setBranch(b.name);
                  Navigator.pop(ctx);
                  LimsToast.show(
                    context,
                    moved
                        ? trf(locale, 'set.switched', {'branch': b.name})
                        : tr(locale, 'set.switchRefused'),
                    isSuccess: moved,
                    isError: !moved,
                  );
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showPhotoSheet(Locale locale, StaffMember me) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                tr(locale, 'set.changePhoto'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr(locale, 'set.photoHint'),
                style: const TextStyle(fontSize: 11.5, color: AppTheme.ink500),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _uploadOwnPhoto(locale);
                  },
                  icon: const Icon(Icons.upload_rounded, size: 17),
                  label: Text(tr(locale, 'set.uploadPhoto'),
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w800)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.brand600,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                tr(locale, 'set.orPick'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink500,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: AvatarService.presets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final asset = AvatarService.presets[i];
                    final selected = me.avatarAsset == asset;
                    return InkWell(
                      borderRadius: BorderRadius.circular(40),
                      onTap: () {
                        Navigator.pop(ctx);
                        _applyAvatar(locale, asset);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? AppTheme.brand600
                                : const Color(0xFFE2E8F0),
                            width: selected ? 2.5 : 1,
                          ),
                        ),
                        child: PersonAvatar(
                          name: me.name,
                          grad: me.grad,
                          asset: asset,
                          size: 60,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadOwnPhoto(Locale locale) async {
    setState(() => _savingPhoto = true);
    final service = AvatarService();
    final url = await service.pickAndUpload();
    if (!mounted) return;

    if (url == null) {
      setState(() => _savingPhoto = false);
      final reason = service.lastError;
      if (reason == null) return; // the person closed the picker
      LimsToast.show(context, tr(locale, 'set.photoFailed'), isError: true);
      return;
    }
    await _commit(locale, url, service);
  }

  Future<void> _applyAvatar(Locale locale, String value) async {
    setState(() => _savingPhoto = true);
    await _commit(locale, value, AvatarService());
  }

  Future<void> _commit(
      Locale locale, String value, AvatarService service) async {
    final ok = await service.save(value);
    if (!mounted) return;
    setState(() => _savingPhoto = false);

    if (!ok) {
      LimsToast.show(
        context,
        service.lastError ?? tr(locale, 'set.photoFailed'),
        isError: true,
      );
      return;
    }
    // Show it immediately: the session overlay wins over the staff row.
    ref.read(signedInAvatarProvider.notifier).state = value;
    LimsToast.show(context, tr(locale, 'set.photoSaved'), isSuccess: true);
  }
}
