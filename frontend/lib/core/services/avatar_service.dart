import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_service.dart';

/// Changing your own photo.
///
/// The profile card used to draw a fixed blue circle with two initials, so the
/// only way to look like yourself was for a developer to edit a seed file. This
/// service writes a portrait for the signed-in person to `profiles.avatar_asset`:
/// either one of the bundled portraits, or a photo picked from the device and
/// uploaded to the `avatars` bucket.
///
/// It refuses to pretend. With no database configured, or when storage has not
/// been created yet, [save] returns a failure with the reason, and the caller
/// shows that instead of a tick.
class AvatarService {
  AvatarService();

  /// Portraits that ship with the app, offered first because they always work.
  static const List<String> presets = <String>[
    'assets/images/avatar_manager.png',
    'assets/images/avatar_admin.png',
    'assets/images/avatar_loan.png',
    'assets/images/avatar_store.png',
    'assets/images/avatar_cashier.png',
    'assets/images/avatar_auditor.png',
    'assets/images/avatar_person_m30.png',
    'assets/images/avatar_person_f20.png',
    'assets/images/avatar_person_f40.png',
  ];

  static const String bucket = 'avatars';

  bool get canReachDatabase => ApiService().isInitialized;

  /// Pick a photo from the device and upload it. Returns the public URL, or null
  /// with a reason in [lastError].
  String? lastError;

  Future<String?> pickAndUpload() async {
    lastError = null;
    if (!canReachDatabase) {
      lastError = 'This build has no database, so a photo cannot be saved.';
      return null;
    }

    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
    } catch (e) {
      // Browsers without a file input, or a denied permission. Saying "cancelled"
      // here would be a lie: the picker failed.
      lastError = 'Could not open the photo picker: $e';
      return null;
    }
    if (picked == null) return null; // user closed the picker: not an error

    final Uint8List bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (e) {
      lastError = 'Could not read the chosen file: $e';
      return null;
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      lastError = 'Sign in again before changing your photo.';
      return null;
    }

    final ext = _extension(picked.name);
    final path = '${user.id}/avatar.$ext';

    try {
      await client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentType(ext),
            ),
          );
      final url = client.storage.from(bucket).getPublicUrl(path);
      // Cache-bust: the path is stable (one photo per person), so a browser that
      // already has the old image would keep showing it.
      return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
    } on StorageException catch (e) {
      lastError = e.message.contains('Bucket not found')
          ? 'Photo storage is not set up yet. Ask your Super Admin to run the '
              'avatars migration.'
          : 'Upload failed: ${e.message}';
      return null;
    } catch (e) {
      lastError = 'Upload failed: $e';
      return null;
    }
  }

  /// Persist the choice. Returns true only when the row was actually written.
  Future<bool> save(String value) async {
    lastError = null;
    if (!canReachDatabase) {
      lastError = 'This build has no database, so the photo was not saved.';
      return false;
    }
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      lastError = 'Sign in again before changing your photo.';
      return false;
    }

    try {
      // `profiles` is keyed by its own id, not by the auth id, and older rows
      // carry only the email. Try the auth link first, then fall back.
      final matched = await client
          .from('profiles')
          .update({'avatar_asset': value})
          .eq('auth_user_id', user.id)
          .select('id');
      if ((matched as List).isNotEmpty) return true;

      final byEmail = await client
          .from('profiles')
          .update({'avatar_asset': value})
          .eq('email', user.email ?? '')
          .select('id');
      if ((byEmail as List).isNotEmpty) return true;

      lastError = 'No profile row belongs to this account, so the photo was '
          'not saved.';
      return false;
    } catch (e) {
      debugPrint('LIMS: avatar save failed -> $e');
      lastError = 'Could not save the photo: $e';
      return false;
    }
  }

  static String _extension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return 'jpg';
    final ext = name.substring(dot + 1).toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'webp'}.contains(ext) ? ext : 'jpg';
  }

  static String _contentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
