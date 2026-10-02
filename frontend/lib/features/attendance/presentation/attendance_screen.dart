import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/inventory_provider.dart';
import '../../../core/data/mock_lims_data.dart';
import '../../../core/theme/app_theme.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> with SingleTickerProviderStateMixin {
  late Timer _clockTimer;
  String _currentTime = '08:00:00';
  String _currentAmPm = 'AM';
  final String _currentDate = 'Friday, 02 October 2026';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    final h = now.hour;
    final displayHour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    setState(() {
      _currentTime = '${displayHour.toString().padLeft(2, '0')}:$m:$s';
      _currentAmPm = h >= 12 ? 'PM' : 'AM';
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _handleClockAction(AttendanceRecord? currentRecord, StaffMember activeStaff, String branch) {
    if (currentRecord == null) {
      // Clock In
      ref.read(attendanceProvider.notifier).clockIn(
            staffId: activeStaff.id,
            staffName: activeStaff.name,
            role: activeStaff.role,
            branch: branch,
            customTime: '$_currentTime $_currentAmPm',
          );
      _showTopAlert(
        context,
        title: 'Clock-In Confirmed',
        message: 'Stationed at $branch · Biometrics & GPS validated.',
        isSuccess: true,
      );
    } else if (currentRecord.clockOutTime == null) {
      // Clock Out
      ref.read(attendanceProvider.notifier).clockOut(currentRecord.id);
      _showTopAlert(
        context,
        title: 'Shift Ended',
        message: 'Clocked out successfully at $_currentTime $_currentAmPm.',
        isSuccess: false,
      );
    }
  }

  void _handleBreakToggle(AttendanceRecord currentRecord) {
    if (currentRecord.status == 'On Break') {
      ref.read(attendanceProvider.notifier).endBreak(currentRecord.id);
      _showTopAlert(
        context,
        title: 'Break Ended',
        message: 'Resumed active shift duties at $currentRecord.branch.',
        isSuccess: true,
      );
    } else {
      ref.read(attendanceProvider.notifier).startBreak(currentRecord.id);
      _showTopAlert(
        context,
        title: 'Meal Break Started',
        message: 'Break period recorded. POS till temporarily locked.',
        isSuccess: false,
      );
    }
  }

  void _showTopAlert(BuildContext context, {required String title, required String message, required bool isSuccess}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 160,
          left: 18,
          right: 18,
        ),
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13.5),
                  ),
                  Text(
                    message,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTimesheetExportModal(BuildContext context, List<AttendanceRecord> records) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),

            // Modal Header with LIMS Official Brand Stamp
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Icon(Icons.description_rounded, color: Color(0xFF1E60F2), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Official Timesheet Audit',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'LIMS Tanzania Ltd · Payroll Compliance',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 24, color: Color(0xFFE2E8F0)),

            // Timesheet Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Official Metadata Block
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildTimesheetMetaRow('Company', 'Loan & Investment Management System Ltd'),
                        _buildTimesheetMetaRow('Branch', 'Kariakoo Main Hub (Branch #01)'),
                        _buildTimesheetMetaRow('TIN / VRN', '142-998-314 / 40-028912-K'),
                        _buildTimesheetMetaRow('Pay Period', '01 Oct 2026 - 31 Oct 2026'),
                        _buildTimesheetMetaRow('Approved By', 'David Erick Mwijage · Managing Director'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Shift Attendance Log Table',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 10),

                  // Ledger Items
                  ...records.map((r) {
                    final isComplete = r.clockOutTime != null;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.staffName,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  '${r.role} · ${r.date}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${r.clockInTime} → ${r.clockOutTime ?? "Active"}',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '${r.shiftHours} hrs · ${r.status}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isComplete ? const Color(0xFF10B981) : const Color(0xFF1E60F2),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Print / Export Actions
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share CSV'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showTopAlert(context, title: 'CSV Exported', message: 'Timesheet dispatched to finance email.', isSuccess: true);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.print_rounded, size: 18, color: Colors.white),
                      label: const Text('Print PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showTopAlert(context, title: 'Document Sent to Printer', message: 'Kariakoo Office EFD network printer.', isSuccess: true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E60F2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimesheetMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeStaff = ref.watch(activeStaffMemberProvider);
    final activeBranch = ref.watch(activeBranchProvider);
    final attendanceLogs = ref.watch(attendanceProvider);

    // Look for active shift log for the current logged-in staff member
    final todayLogs = attendanceLogs.where((l) => l.date.contains('Today') || l.date.contains('02 Oct')).toList();
    final currentStaffRecord = todayLogs.cast<AttendanceRecord?>().firstWhere(
          (l) => l?.staffName == activeStaff.name,
          orElse: () => null,
        );

    final isClockedIn = currentStaffRecord != null && currentStaffRecord.clockOutTime == null;
    final isOnBreak = currentStaffRecord?.status == 'On Break';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink900),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Staff Attendance & Shifts',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.ink900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Color(0xFF1E60F2)),
            tooltip: 'Timesheet Audit',
            onPressed: () => _showTimesheetExportModal(context, attendanceLogs),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
          children: [
            // Current User Profile Header Chip
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x080F3478), blurRadius: 14, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: activeStaff.grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        activeStaff.initials,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeStaff.name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          '${activeStaff.role} · ${activeStaff.staffCode}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isClockedIn
                          ? (isOnBreak ? const Color(0xFFFEF3F2) : const Color(0xFFECFDF5))
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isClockedIn
                            ? (isOnBreak ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0))
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Text(
                      isClockedIn ? (isOnBreak ? 'On Break' : 'Clocked In') : 'Off Duty',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isClockedIn
                            ? (isOnBreak ? const Color(0xFFDC2626) : const Color(0xFF059669))
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Live Digital Shift Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF1E60F2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Color(0x331E60F2), blurRadius: 24, offset: Offset(0, 8)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentTime,
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _currentAmPm,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentDate,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Shift Action Buttons
                  if (!isClockedIn) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.fingerprint_rounded, size: 22),
                        label: const Text('Clock In (Shift Start)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        onPressed: () => _handleClockAction(currentStaffRecord, activeStaff, activeBranch),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(isOnBreak ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 18),
                            label: Text(isOnBreak ? 'Resume' : 'Meal Break'),
                            onPressed: () => _handleBreakToggle(currentStaffRecord),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: const Text('Clock Out'),
                            onPressed: () => _handleClockAction(currentStaffRecord, activeStaff, activeBranch),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Status detail text
                  Text(
                    isClockedIn
                        ? 'Clocked in at ${currentStaffRecord.clockInTime} · GPS: Within 15m of $activeBranch'
                        : 'Tap Clock In upon arriving at store terminal · Geofence Active',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Geofence & Hardware Security Verification Bar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.satellite_alt_rounded, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Store Geofence Hardware Lock',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Connected to Kariakoo Branch AP · Terminal #01 EFD Sync Active',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.lock_rounded, size: 16, color: Color(0xFF10B981)),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Tabs for Roster vs Timesheet Analytics
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1E60F2),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF1E60F2),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              tabs: const [
                Tab(text: "Today's Branch Roster"),
                Tab(text: "Audit Timesheet Report"),
              ],
            ),
            const SizedBox(height: 14),

            // Tab Content
            SizedBox(
              height: 440,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Today's Roster
                  _buildTodayRosterList(todayLogs),

                  // Tab 2: Audit Timesheet Report
                  _buildTimesheetAuditReport(attendanceLogs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayRosterList(List<AttendanceRecord> todayLogs) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: todayLogs.map((log) {
        final isLate = log.status.contains('Late');
        final isCompleted = log.status == 'Completed';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x060F3478), blurRadius: 10, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isLate ? const Color(0xFFFEF3F2) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isLate ? Icons.access_time_rounded : Icons.how_to_reg_rounded,
                  color: isLate ? const Color(0xFFD92D20) : const Color(0xFF1E60F2),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.staffName,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${log.role} · In at ${log.clockInTime}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    Text(
                      log.verifiedBy,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLate
                      ? const Color(0xFFFEF3F2)
                      : (isCompleted ? const Color(0xFFF1F5F9) : const Color(0xFFECFDF5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  log.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isLate
                        ? const Color(0xFFDC2626)
                        : (isCompleted ? const Color(0xFF475569) : const Color(0xFF059669)),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimesheetAuditReport(List<AttendanceRecord> records) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        // 4 KPI Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'On-Time Rate',
                value: '97.4%',
                sub: '+2.1% this month',
                color: const Color(0xFF10B981),
                icon: Icons.check_circle_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Avg Arrival',
                value: '07:52 AM',
                sub: 'Target: 08:00 AM',
                color: const Color(0xFF1E60F2),
                icon: Icons.alarm_on_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Total Shift Hrs',
                value: '182.5 hrs',
                sub: 'Target: 176 hrs',
                color: const Color(0xFF7C3AED),
                icon: Icons.timelapse_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Late Flags',
                value: '1 Incident',
                sub: 'Storekeeper 12m',
                color: const Color(0xFFF59E0B),
                icon: Icons.warning_amber_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Export Timesheet Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF1E60F2)),
            label: const Text('Export Official Monthly Timesheet', style: TextStyle(fontWeight: FontWeight.w800)),
            onPressed: () => _showTimesheetExportModal(context, records),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String sub,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}
