import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../services/imei_scan.dart';

/// A camera viewfinder that reports the first valid IMEI it sees.
///
/// This replaces the animated rectangle that used to sit over a fake feed. The
/// widget owns three things: the camera, the decode, and the deduplication. It
/// does not own what a valid IMEI means — the caller asks the database.
///
/// Deliberate behaviour:
///   * scanning pauses after the first hit, so one label cannot fire the callback
///     thirty times a second while the cashier reaches for the button
///   * a barcode that is not an IMEI keeps the camera running but shows why, so a
///     price tag does not silently do nothing
///   * when there is no camera (desktop browser, denied permission) the caller is
///     told, and the manual field underneath remains usable
class ImeiScannerView extends StatefulWidget {
  const ImeiScannerView({
    super.key,
    required this.onImei,
    this.locale = const Locale('en'),
    this.height = 260,
  });

  /// Called once per scan with a payload that parses and passes the checksum.
  final void Function(String imei) onImei;

  final Locale locale;
  final double height;

  @override
  State<ImeiScannerView> createState() => ImeiScannerViewState();
}

class ImeiScannerViewState extends State<ImeiScannerView> {
  MobileScannerController? _controller;
  bool _running = false;
  bool _paused = false;
  String? _hint;
  bool _denied = false;

  Locale get _locale => widget.locale;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> start() async {
    if (_running) return;
    final controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode, BarcodeFormat.code128, BarcodeFormat.dataMatrix, BarcodeFormat.ean13],
      detectionSpeed: DetectionSpeed.normal,
      autoStart: false,
    );
    setState(() {
      _controller = controller;
      _running = true;
      _paused = false;
      _hint = null;
      _denied = false;
    });
    try {
      await controller.start();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _denied = true;
        _hint = tr(_locale, 'scan.cameraDenied');
      });
    }
  }

  Future<void> stop() async {
    final controller = _controller;
    setState(() {
      _running = false;
      _controller = null;
    });
    await controller?.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_paused) return;
    for (final barcode in capture.barcodes) {
      final imei = ImeiScan.parseImei(barcode.rawValue);
      if (imei == null) continue;
      if (!ImeiScan.isValid(imei)) {
        setState(() => _hint = tr(_locale, 'scan.invalid'));
        continue;
      }
      setState(() {
        _paused = true;
        _hint = null;
      });
      widget.onImei(imei);
      return;
    }
  }

  /// Called by the screen after it has finished acting on a scan.
  void resume() {
    if (!mounted) return;
    setState(() => _paused = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_running) {
      return _buildIdle();
    }
    final controller = _controller;
    if (controller == null) return _buildIdle();

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) {
                // A browser without a camera, or a denied permission, lands here.
                return _cameraUnavailable(error.errorCode.name);
              },
            ),
            _buildReticle(),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.black.withValues(alpha: 0.55),
                child: Text(
                  _hint ?? tr(_locale, 'scan.looking'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReticle() {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 210,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _paused ? const Color(0xFF10B981) : Colors.white70,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdle() {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _denied ? Icons.no_photography_outlined : Icons.qr_code_scanner_rounded,
            color: Colors.white70,
            size: 40,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _hint ?? tr(_locale, 'scan.manual'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: start,
            icon: const Icon(Icons.camera_alt_rounded, size: 16),
            label: Text(tr(_locale, 'scan.start')),
          ),
        ],
      ),
    );
  }

  Widget _cameraUnavailable(String code) {
    // `kIsWeb` is included in the message because a browser without a camera is
    // the common case, and "no camera" alone makes the cashier think the phone
    // is broken.
    final text = kIsWeb
        ? tr(_locale, 'scan.noCamera')
        : tr(_locale, 'scan.cameraDenied');
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 36),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            code,
            style: const TextStyle(color: Colors.white24, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

/// The small "scan instead of typing" button used beside IMEI fields.
class ScanImeiButton extends StatelessWidget {
  const ScanImeiButton({
    super.key,
    required this.locale,
    required this.onPressed,
    this.label,
  });

  final Locale locale;
  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
      label: Text(
        label ?? tr(locale, 'stock.scanWithCamera'),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.brand600,
        side: const BorderSide(color: Color(0xFFCEE1FE)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
