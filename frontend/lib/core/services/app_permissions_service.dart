import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Central Android (na iOS) runtime-permission gate.
///
/// Inaitwa **mapeema**: mara tu app inapofunguka (splash/onboarding/login)
/// ili mtumiaji asiulizwe katikati ya kazi kama scan au clock-in.
///
/// Permissions zinazohitajika na LIMS:
/// - [Permission.camera] — scanner ya IMEI + picha ya passport (counter).
/// - [Permission.location] — geofence ya attendance (300–350 m).
/// - [Permission.notification] — arifa za mikopo / stock (Android 13+).
/// - [Permission.phone] — kupiga simu mkopaji/mdhamini.
/// - [Permission.sms] — kutuma SMS reminders.
/// - [Permission.photos] / [Permission.storage] — PDF reports, receipts, picha.
class AppPermissionsService {
  AppPermissionsService._();

  static bool _earlyRequestDone = false;

  // `dart:io` Platform throws on web, and this service is reached from the
  // login flow, so the web build logged "Unsupported operation:
  // Platform._operatingSystem" on every boot. Platform checks now go through
  // foundation, which is safe on every target.
  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Permissions za msingi zinazoombwa pamoja mwanzoni.
  static List<Permission> get _earlyPermissions {
    final list = <Permission>[
      Permission.camera,
      Permission.location,
      Permission.notification,
      Permission.phone,
      Permission.sms,
      if (_isAndroid) Permission.storage,
      if (_isIOS) Permission.photos,
    ];
    return list;
  }

  /// Omba permissions zote za msingi **mapeema**.
  ///
  /// - [showRationale]: ionyeshe bottom-sheet ya Kiswahili/Kiingereza kabla
  ///   ya system dialog (inapendekezwa kwenye onboarding/login).
  /// Returns `true` kama angalau camera + location zimeruhusiwa.
  static Future<bool> requestEarlyPermissions(
    BuildContext context, {
    bool showRationale = true,
  }) async {
    if (!_isAndroid && !_isIOS) return true;
    if (_earlyRequestDone) return true;

    if (showRationale) {
      if (!context.mounted) return false;
      final proceed = await _showRationaleSheet(context);
      if (!proceed) return false;
    }

    for (final p in _earlyPermissions) {
      try {
        if (await p.isGranted) continue;
        // Location ina flow yake kupitia geolocator (inaeleweka zaidi).
        if (p == Permission.location) {
          await _requestLocationViaGeolocator();
          continue;
        }
        final status = await p.request();
        // Permanently denied -> acha; tutaelekeza settings ukihitajika.
        if (status.isPermanentlyDenied) continue;
      } catch (_) {
        // Permission moja ikifeli isiue mfululizo mzima.
        continue;
      }
    }

    _earlyRequestDone = true;
    return true;
  }

  /// Just-in-time: hakikisha kamera inaruhusiwa kabla ya scanner/passport.
  static Future<bool> ensureCamera(BuildContext context) async {
    if (await Permission.camera.isGranted) return true;
    final status = await Permission.camera.request();
    if (status.isGranted) return true;
    if (!context.mounted) return false;
    if (status.isPermanentlyDenied) {
      await _showOpenSettingsSheet(
        context,
        title: 'Ruhusa ya Kamera inahitajika',
        message:
            'Ili kuscan IMEI na kupiga picha ya passport, washa Kamera kwenye App settings.',
      );
    }
    return false;
  }

  /// Just-in-time: hakikisha location inaruhusiwa kabla ya clock-in.
  static Future<bool> ensureLocation(BuildContext context) async {
    final ok = await _requestLocationViaGeolocator();
    if (ok) return true;
    if (!context.mounted) return false;
    final permanentlyDenied =
        await Geolocator.checkPermission() == LocationPermission.deniedForever;
    if (permanentlyDenied && context.mounted) {
      await _showOpenSettingsSheet(
        context,
        title: 'Ruhusa ya Location inahitajika',
        message:
            'Clock-in inahitaji GPS ili kuthibitisha uko branch (geofence 300–350 m). Washa Location kwenye App settings.',
      );
    }
    return false;
  }

  /// Just-in-time: notifications (Android 13+).
  static Future<bool> ensureNotifications() async {
    if (await Permission.notification.isGranted) return true;
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Just-in-time: phone + sms kabla ya kuwapigia / kutumia SMS wakopaji.
  static Future<bool> ensureTelecom() async {
    var ok = true;
    if (!await Permission.phone.isGranted) {
      ok = (await Permission.phone.request().isGranted) && ok;
    }
    if (!await Permission.sms.isGranted) {
      // SMS ni hiari (tunafungua SMS app kupitia intent) — usizuie flow.
      await Permission.sms.request();
    }
    return ok;
  }

  /// Just-in-time: storage/photos kabla ya PDF / receipts / gallery.
  static Future<bool> ensureStorage() async {
    if (_isIOS) {
      if (await Permission.photos.isGranted) return true;
      return (await Permission.photos.request()).isGranted;
    }
    // Android 13+: READ_MEDIA_IMAGES haina haja ya dialog ngumu;
    // chini ya hapo tumia storage.
    if (await Permission.storage.isGranted) return true;
    final status = await Permission.storage.request();
    // Kwenye Android 13+ storage inaweza kuwa 'restricted' lakini
    // media bado inafanya kazi kupitia SAF/MediaStore — usizuie flow.
    return status.isGranted || status.isLimited;
  }

  // ---------------------------------------------------------- internals

  static Future<bool> _requestLocationViaGeolocator() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  /// Bottom-sheet fupi (EN/SW rafiki) inayoeleza kwa nini tunaomba ruhusa.
  static Future<bool> _showRationaleSheet(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4E0F0),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9F2FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: Color(0xFF1B6EF3),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ruhusa za Simu / App Permissions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0D1B34),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Tunaomba ruhusa hizi mapeema ili app ifanye kazi vizuri',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF68758C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _PermRow(
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'Kamera — Camera',
                    subtitle: 'Kuscan IMEI na kupiga picha ya passport',
                  ),
                  const _PermRow(
                    icon: Icons.location_on_rounded,
                    title: 'Location — GPS',
                    subtitle: 'Clock-in/out ndani ya branch (geofence)',
                  ),
                  const _PermRow(
                    icon: Icons.notifications_active_rounded,
                    title: 'Notifications — Arifa',
                    subtitle: 'Marejesho, stock ndogo na mikopo iliyochelewa',
                  ),
                  const _PermRow(
                    icon: Icons.phone_rounded,
                    title: 'Simu & SMS — Phone',
                    subtitle: 'Kuwapigia wakopaji na kutuma reminders',
                  ),
                  const _PermRow(
                    icon: Icons.picture_as_pdf_rounded,
                    title: 'Files — Mafaili',
                    subtitle: 'PDF reports, risiti na picha kuhifadhiwa',
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B4FCE),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Endelea — Allow',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text(
                        'Baadaye — Skip for now',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  static Future<void> _showOpenSettingsSheet(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4E0F0),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0D1B34),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF68758C),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Baadaye'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            openAppSettings();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0B4FCE),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Fungua Settings',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PermRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PermRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F9FF),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon, size: 19, color: const Color(0xFF1B6EF3)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D1B34),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF68758C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
