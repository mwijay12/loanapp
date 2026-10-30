import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/data/branch_provider.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/data/member_admin.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';

/// The console's member list: every login in the shop, with the one thing an
/// admin actually needs from it — the ability to give somebody a way in, take it
/// away, or correct their role.
///
/// The rows here come from `public.profiles`, which is where `current_staff_role()`
/// reads from. A person who appears only in the `staff` roster cannot sign in, and
/// that difference is the whole point of this panel.
class MembersPanel extends ConsumerWidget {
  const MembersPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final members = ref.watch(membersProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4E5FF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F3478),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C5CFC), Color(0xFF4F2FD6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x337C5CFC),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.key_rounded, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(locale, 'member.sectionTitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink900,
                      ),
                    ),
                    Text(
                      members.maybeWhen(
                        // Only people with a login can sign in; a profile row
                        // with no auth user would inflate this number.
                        data: (list) => trf(locale, 'member.sectionSub', {
                          'n': list.where((m) => m.hasLogin).length,
                        }),
                        orElse: () => tr(locale, 'member.onlyLogins'),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.ink500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => showAddMemberSheet(context, ref),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: Text(
                  tr(locale, 'member.add'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 12),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brand600,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          members.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => _MembersNotice(
              message: e.toString(),
              onRetry: () => ref.invalidate(membersProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const _MembersNotice();
              }
              return Column(
                children: [
                  for (final m in list) ...[
                    _MemberRow(member: m),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MembersNotice extends StatelessWidget {
  const _MembersNotice({this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: AppTheme.ink500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message ?? tr(locale, 'member.noLogins'),
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: AppTheme.ink600,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(tr(locale, 'common.retry')),
            ),
        ],
      ),
    );
  }
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({required this.member});

  final MemberRecord member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final palette = _rolePalette(member.role);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFDFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EFFA)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: palette,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: palette.last.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              member.initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.fullName.isEmpty ? member.email : member.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: palette.last.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        member.role,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: palette.last,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    member.email,
                    if ((member.branchName ?? '').isNotEmpty) member.branchName!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.ink500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!member.hasLogin)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                tr(locale, 'member.notLinked'),
                style: const TextStyle(fontSize: 9.5, color: Color(0xFFB45309)),
              ),
            ),
          PopupMenuButton<String>(
            tooltip: '',
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_horiz_rounded,
                size: 18, color: AppTheme.ink500),
            onSelected: (value) => _handle(context, ref, value),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'password',
                child: _menuLabel(Icons.lock_reset_rounded,
                    tr(locale, 'member.resetPassword')),
              ),
              PopupMenuItem(
                value: 'role',
                child: _menuLabel(Icons.swap_horiz_rounded,
                    tr(locale, 'member.changeRole')),
              ),
              PopupMenuItem(
                value: 'suspend',
                child: _menuLabel(Icons.block_rounded,
                    tr(locale, 'member.suspend')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _menuLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.ink600),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12.5)),
      ],
    );
  }

  Future<void> _handle(BuildContext context, WidgetRef ref, String action) async {
    final locale = ref.read(localeProvider);
    final service = ref.read(memberAdminServiceProvider);

    if (action == 'password') {
      await _resetPasswordSheet(context, ref, member);
      return;
    }

    if (action == 'role') {
      await _roleSheet(context, ref, member);
      return;
    }

    if (action == 'suspend') {
      final result =
          await service.setActive(profileId: member.id, active: false);
      if (!context.mounted) return;
      if (result.ok) {
        ref.invalidate(membersProvider);
        LimsToast.show(
          context,
          trf(locale, 'member.roleChanged',
              {'name': member.fullName, 'role': tr(locale, 'member.suspended')}),
          isSuccess: true,
        );
      } else {
        LimsToast.show(context, result.error ?? 'Failed', isError: true);
      }
    }
  }

  Future<void> _resetPasswordSheet(
      BuildContext context, WidgetRef ref, MemberRecord member) async {
    final locale = ref.read(localeProvider);
    final controller = TextEditingController(text: generateMemberPassword());
    var busy = false;
    await LimsBottomSheet.show(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setState) => LimsBottomSheet(
          title: tr(locale, 'member.resetPassword'),
          subtitle: member.email,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: tr(locale, 'member.password'),
                  isDense: true,
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    tooltip: tr(locale, 'member.regenerate'),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    onPressed: () =>
                        setState(() => controller.text = generateMemberPassword()),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          final result =
                              await ref.read(memberAdminServiceProvider).resetPassword(
                                    profileId: member.id,
                                    password: controller.text.trim(),
                                  );
                          if (!modalCtx.mounted) return;
                          setState(() => busy = false);
                          Navigator.pop(modalCtx);
                          if (!context.mounted) return;
                          LimsToast.show(
                            context,
                            result.ok
                                ? trf(locale, 'member.passwordReset',
                                    {'name': member.fullName})
                                : (result.error ?? 'Failed'),
                            isError: !result.ok,
                            isSuccess: result.ok,
                          );
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.brand600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    busy ? tr(locale, 'member.creating') : tr(locale, 'common.save'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _roleSheet(
      BuildContext context, WidgetRef ref, MemberRecord member) async {
    final locale = ref.read(localeProvider);
    var role = UserRoles.assignable.contains(member.role)
        ? member.role
        : UserRoles.assignable.first;
    await LimsBottomSheet.show(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setState) => LimsBottomSheet(
          title: tr(locale, 'member.changeRole'),
          subtitle: member.fullName,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: role,
                items: [
                  for (final r in UserRoles.assignable)
                    DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => role = v);
                },
                decoration: InputDecoration(
                  labelText: tr(locale, 'adm.roleLabel'),
                  isDense: true,
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final result = await ref
                        .read(memberAdminServiceProvider)
                        .setRole(profileId: member.id, role: role);
                    if (!modalCtx.mounted) return;
                    Navigator.pop(modalCtx);
                    if (!context.mounted) return;
                    if (result.ok) ref.invalidate(membersProvider);
                    LimsToast.show(
                      context,
                      result.ok
                          ? trf(locale, 'member.roleChanged',
                              {'name': member.fullName, 'role': role})
                          : (result.error ?? 'Failed'),
                      isError: !result.ok,
                      isSuccess: result.ok,
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.brand600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(tr(locale, 'common.save'),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<Color> _rolePalette(String role) {
  return switch (UserRoles.normalize(role)) {
    UserRoles.superAdmin => const [Color(0xFF7C5CFC), Color(0xFF4F2FD6)],
    UserRoles.branchManager => const [Color(0xFF2E7BF5), Color(0xFF0B4FCE)],
    UserRoles.loanOfficer => const [Color(0xFF0FB5A5), Color(0xFF0A7D74)],
    UserRoles.storekeeper => const [Color(0xFFF79009), Color(0xFFC25E00)],
    UserRoles.counterCashier => const [Color(0xFF64748B), Color(0xFF334155)],
    UserRoles.auditor => const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    _ => const [Color(0xFF94A3B8), Color(0xFF64748B)],
  };
}

/// The sheet an admin uses to create a login: name, email, role, branch and a
/// password that is shown once.
///
/// The password is generated rather than typed, because a shop admin picking
/// "1234" is the likeliest way this database gets opened. It is still editable,
/// and it is displayed in full so it can be read to the new member on the spot.
Future<void> showAddMemberSheet(BuildContext context, WidgetRef ref) async {
  final locale = ref.read(localeProvider);
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final pinCtrl = TextEditingController(text: generateMemberPassword());
  String role = UserRoles.loanOfficer;
  final branchList = ref.read(branchesProvider).where((b) => b.active).toList();
  String branch = branchList.isEmpty
      ? ''
      : branchList.first.name;
  var busy = false;
  String? error;
  MemberRecord? created;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (modalCtx) => StatefulBuilder(
      builder: (sheetCtx, setState) {
        if (created != null) {
          return LimsBottomSheet(
            title: tr(locale, 'member.created'),
            showClose: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF4F9FF), Color(0xFFF0EBFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD4E5FF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _credentialLine(
                          Icons.person_outline_rounded, created!.fullName),
                      const SizedBox(height: 10),
                      _credentialLine(
                          Icons.alternate_email_rounded, created!.email),
                      const SizedBox(height: 10),
                      _credentialLine(
                          Icons.lock_outline_rounded, pinCtrl.text.trim()),
                      const SizedBox(height: 10),
                      _credentialLine(Icons.shield_outlined, created!.role),
                      if ((created!.branchName ?? '').isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _credentialLine(
                            Icons.storefront_outlined, created!.branchName!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  trf(locale, 'member.shareHint', {'name': created!.fullName}),
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: AppTheme.ink600,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(
                            text: '${created!.email}\n${pinCtrl.text.trim()}',
                          ));
                          if (!context.mounted) return;
                          LimsToast.show(
                              context, tr(locale, 'member.copied'),
                              isSuccess: true);
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: Text(tr(locale, 'member.copy')),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.brand600,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(tr(locale, 'member.done'),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return LimsBottomSheet(
          title: tr(locale, 'member.addTitle'),
          subtitle: tr(locale, 'member.addSub'),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration(tr(locale, 'adm.fullName'),
                      Icons.person_outline_rounded),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: _decoration(
                      tr(locale, 'member.email'), Icons.alternate_email_rounded),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: _decoration(
                      tr(locale, 'adm.phoneNumber'), Icons.call_outlined),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: role,
                  items: [
                    for (final r in UserRoles.assignable)
                      DropdownMenuItem(value: r, child: Text(r)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => role = v);
                  },
                  decoration: _decoration(
                      tr(locale, 'adm.roleLabel'), Icons.shield_outlined),
                ),
                if (branchList.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: branch,
                    items: [
                      for (final b in branchList)
                        DropdownMenuItem(value: b.name, child: Text(b.name)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => branch = v);
                    },
                    decoration: _decoration(tr(locale, 'adm.assignedBranch'),
                        Icons.storefront_outlined),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: pinCtrl,
                  decoration: _decoration(
                    tr(locale, 'member.password'),
                    Icons.lock_outline_rounded,
                  ).copyWith(
                    suffixIcon: IconButton(
                      tooltip: tr(locale, 'member.regenerate'),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      onPressed: () => setState(
                          () => pinCtrl.text = generateMemberPassword()),
                    ),
                    helperText: tr(locale, 'member.needPassword'),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDF1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFBCFE0)),
                    ),
                    child: Text(
                      error!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: Color(0xFFB00020),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final email = emailCtrl.text.trim();
                            if (name.isEmpty) {
                              setState(() =>
                                  error = tr(locale, 'adm.nameRequired'));
                              return;
                            }
                            if (email.isEmpty) {
                              setState(
                                  () => error = tr(locale, 'member.needEmail'));
                              return;
                            }
                            setState(() {
                              busy = true;
                              error = null;
                            });
                            final result = await ref
                                .read(memberAdminServiceProvider)
                                .createMember(
                                  email: email,
                                  password: pinCtrl.text.trim(),
                                  fullName: name,
                                  role: role,
                                  branchName: branch,
                                  phone: phoneCtrl.text.trim(),
                                );
                            if (!sheetCtx.mounted) return;
                            setState(() {
                              busy = false;
                              if (result.ok) {
                                created = result.member;
                              } else {
                                error = result.error;
                              }
                            });
                            if (result.ok) {
                              ref.invalidate(membersProvider);
                              ref.invalidate(staffProvider);
                            }
                          },
                    icon: busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: Text(
                      busy
                          ? tr(locale, 'member.creating')
                          : tr(locale, 'member.create'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.brand600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Widget _credentialLine(IconData icon, String value) {
  return Row(
    children: [
      Icon(icon, size: 15, color: AppTheme.brand600),
      const SizedBox(width: 8),
      Expanded(
        child: SelectableText(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.ink900,
            letterSpacing: 0.2,
          ),
        ),
      ),
    ],
  );
}

InputDecoration _decoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    isDense: true,
    prefixIcon: Icon(icon, size: 18),
    prefixIconConstraints: const BoxConstraints(minWidth: 38),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}
