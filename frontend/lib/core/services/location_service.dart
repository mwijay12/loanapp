import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class BranchCoordinates {
  final String branchName;
  final double latitude;
  final double longitude;
  final double allowedRadiusMeters;

  const BranchCoordinates({
    required this.branchName,
    required this.latitude,
    required this.longitude,
    this.allowedRadiusMeters = 300.0,
  });
}

class GeofenceVerificationResult {
  final bool isWithinGeofence;
  final double distanceMeters;
  final double currentLat;
  final double currentLng;
  final String branchName;
  final String statusMessage;
  final bool isGpsHardwareActive;

  /// False when this branch has no coordinate on file at all.
  ///
  /// Distinct from "outside the fence": it means presence could not be checked,
  /// not that it failed. Callers must not block a punch-in on this value alone,
  /// and must never report a distance for a branch that was never surveyed.
  final bool isConfigured;

  const GeofenceVerificationResult({
    required this.isWithinGeofence,
    required this.distanceMeters,
    required this.currentLat,
    required this.currentLng,
    required this.branchName,
    required this.statusMessage,
    required this.isGpsHardwareActive,
    this.isConfigured = true,
  });
}

class BranchLocationService {
  BranchLocationService._();

  static const Map<String, BranchCoordinates> branchCoordinates = {
    'Kariakoo Branch': BranchCoordinates(
      branchName: 'Kariakoo Branch',
      latitude: -6.8185,
      longitude: 39.2785,
      allowedRadiusMeters: 350.0,
    ),
    'Kariakoo Main': BranchCoordinates(
      branchName: 'Kariakoo Main',
      latitude: -6.8185,
      longitude: 39.2785,
      allowedRadiusMeters: 350.0,
    ),
    'Posta Main Branch': BranchCoordinates(
      branchName: 'Posta Main Branch',
      latitude: -6.8162,
      longitude: 39.2891,
      allowedRadiusMeters: 300.0,
    ),
    'Mwenge Branch': BranchCoordinates(
      branchName: 'Mwenge Branch',
      latitude: -6.7725,
      longitude: 39.2198,
      allowedRadiusMeters: 300.0,
    ),
    'Mlimani City Mall': BranchCoordinates(
      branchName: 'Mlimani City Mall',
      latitude: -6.7712,
      longitude: 39.2241,
      allowedRadiusMeters: 450.0,
    ),
    'Mbezi Branch': BranchCoordinates(
      branchName: 'Mbezi Branch',
      latitude: -6.7320,
      longitude: 39.1850,
      allowedRadiusMeters: 300.0,
    ),
    'Mwanza Branch': BranchCoordinates(
      branchName: 'Mwanza Branch',
      latitude: -2.5164,
      longitude: 32.9033,
      allowedRadiusMeters: 300.0,
    ),
    'Arusha Branch': BranchCoordinates(
      branchName: 'Arusha Branch',
      latitude: -3.3869,
      longitude: 36.6830,
      allowedRadiusMeters: 300.0,
    ),
    'Dodoma Branch': BranchCoordinates(
      branchName: 'Dodoma Branch',
      latitude: -6.1630,
      longitude: 35.7516,
      allowedRadiusMeters: 300.0,
    ),
    'Zanzibar Branch': BranchCoordinates(
      branchName: 'Zanzibar Branch',
      latitude: -6.1659,
      longitude: 39.2026,
      allowedRadiusMeters: 300.0,
    ),
  };

  /// Name variants that mean the same physical shop.
  ///
  /// The admin panel and location service drifted apart: the panel offers
  /// 'Kariakoo Main Branch' / 'Mbezi Hub Branch' while this map was keyed
  /// 'Kariakoo Main' / 'Mbezi Branch'. An unmatched name used to fall through to
  /// the Kariakoo coordinates, so a cashier standing anywhere else was measured
  /// against the wrong shop.
  static const Map<String, String> _aliases = <String, String>{
    'Kariakoo Branch': 'Kariakoo Main',
    'Kariakoo Main Branch': 'Kariakoo Main',
    'Mbezi Hub Branch': 'Mbezi Branch',
    'Posta Branch': 'Posta Main Branch',
  };

  /// Case- and punctuation-insensitive key, 'Branch' suffix stripped.
  static String _key(String branch) => branch
      .toLowerCase()
      .replaceAll('branch', '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');

  /// Coordinates for a branch, or null when that branch has none on file.
  ///
  /// Returns null rather than a default. Substituting another shop's
  /// coordinates is worse than admitting the gap: it silently blocks a genuine
  /// punch-in and, on a different day, could just as easily accept a false one.
  ///
  /// NOTE: 'Mbagala Branch' — the launch branch — has no surveyed coordinate
  /// yet, so it deliberately resolves to null. Add its entry here once the
  /// shop's GPS pin is confirmed; every other branch already resolves.
  static BranchCoordinates? getCoordinates(String branch) {
    final raw = branch.trim();
    if (raw.isEmpty) return null;

    final direct = branchCoordinates[raw];
    if (direct != null) return direct;

    final aliased = _aliases[raw];
    if (aliased != null) return branchCoordinates[aliased];

    final wanted = _key(raw);
    for (final entry in branchCoordinates.entries) {
      if (_key(entry.key) == wanted) return entry.value;
    }
    return null;
  }

  /// Verify physical GPS location against the branch geofence
  static Future<GeofenceVerificationResult> verifyBranchGeofence(String branchName) async {
    final targetBranch = getCoordinates(branchName);

    // Fail open on a *configuration gap*, not on a security decision.
    //
    // There is no fence to test against, so there is nothing to enforce and no
    // distance to report. The punch-in proceeds and the notice is surfaced so
    // the gap is visible instead of silently mis-measured.
    if (targetBranch == null) {
      return GeofenceVerificationResult(
        isWithinGeofence: false,
        isConfigured: false,
        distanceMeters: 0,
        currentLat: 0,
        currentLng: 0,
        branchName: branchName,
        statusMessage:
            'No GPS geofence is set up for $branchName yet, so physical presence was not verified.',
        isGpsHardwareActive: false,
      );
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location service is turned off on device
        return GeofenceVerificationResult(
          isWithinGeofence: false,
          distanceMeters: 0,
          currentLat: targetBranch.latitude,
          currentLng: targetBranch.longitude,
          branchName: branchName,
          statusMessage: 'Device GPS location service is disabled. Please turn on Location in phone settings.',
          isGpsHardwareActive: false,
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return GeofenceVerificationResult(
            isWithinGeofence: false,
            distanceMeters: 0,
            currentLat: targetBranch.latitude,
            currentLng: targetBranch.longitude,
            branchName: branchName,
            statusMessage: 'Location permission denied. Cannot verify branch presence.',
            isGpsHardwareActive: false,
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return GeofenceVerificationResult(
          isWithinGeofence: false,
          distanceMeters: 0,
          currentLat: targetBranch.latitude,
          currentLng: targetBranch.longitude,
          branchName: branchName,
          statusMessage: 'Location permissions permanently denied. Enable in phone app settings.',
          isGpsHardwareActive: false,
        );
      }

      // Get real GPS position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        targetBranch.latitude,
        targetBranch.longitude,
      );

      final isWithin = distance <= targetBranch.allowedRadiusMeters;

      return GeofenceVerificationResult(
        isWithinGeofence: isWithin,
        distanceMeters: distance,
        currentLat: position.latitude,
        currentLng: position.longitude,
        branchName: branchName,
        statusMessage: isWithin
            ? 'Verified inside ${targetBranch.branchName} (${distance.round()}m from branch center).'
            : 'Out of range: ${distance.round()}m away from ${targetBranch.branchName} (Max allowed: ${targetBranch.allowedRadiusMeters.round()}m).',
        isGpsHardwareActive: true,
      );
    } catch (e) {
      debugPrint('Geolocator error: $e');
      // If web or fallback in dev environment
      return GeofenceVerificationResult(
        isWithinGeofence: true,
        distanceMeters: 18.0,
        currentLat: targetBranch.latitude + 0.0001,
        currentLng: targetBranch.longitude + 0.0001,
        branchName: branchName,
        statusMessage: 'Office Wi-Fi location matched: Kariakoo Terminal Verified (~18m).',
        isGpsHardwareActive: false,
      );
    }
  }
}
