import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Cloudinary Media Service for LIMS (Tanzania Phone Loan & Inventory)
/// Configured for David Erick Mwijage (mwijay12)
class CloudinaryConfig {
  static const String cloudName = 'fbwhgkbe';
  static const String apiKey = '525153827353587';
  static const String apiSecret = 'GIPN40HsDhbjtYcJ45ZJuKSSkXA';
  static const String uploadPreset = 'loan app tz';
  static const String uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  // Cloudinary Hosted Assets for Phones & Hardware Inventory
  static const String imgIphone15ProMax = 'https://res.cloudinary.com/fbwhgkbe/image/upload/v1792103982/blue_iphones_duo.png';
  static const String imgRedmiNote13Pro = 'https://res.cloudinary.com/fbwhgkbe/image/upload/v1792103996/redmi_note_13_pro.png';
  static const String imgSamsungS24Ultra = 'https://res.cloudinary.com/fbwhgkbe/image/upload/v1792104008/samsung_galaxy_ultra.png';
  static const String imgTecnoCamon30 = 'https://res.cloudinary.com/fbwhgkbe/image/upload/v1792104019/tecno_camon_30.png';

  /// Maps SKU or Model name to Cloudinary CDN URL
  static String? getProductImageUrl(String skuOrName) {
    final lower = skuOrName.toLowerCase();
    if (lower.contains('iphone') || lower.contains('ip15') || lower.contains('apple')) {
      return imgIphone15ProMax;
    }
    if (lower.contains('redmi') || lower.contains('rn13') || lower.contains('xiaomi')) {
      return imgRedmiNote13Pro;
    }
    if (lower.contains('samsung') || lower.contains('s24') || lower.contains('ultra')) {
      return imgSamsungS24Ultra;
    }
    if (lower.contains('tecno') || lower.contains('camon') || lower.contains('tc30')) {
      return imgTecnoCamon30;
    }
    return null;
  }
}

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  /// Uploads raw image bytes (e.g. from Camera, Gallery, or ID scan) directly to Cloudinary
  Future<String?> uploadImageBytes({
    required Uint8List bytes,
    required String fileName,
    String? folder,
  }) async {
    try {
      final uri = Uri.parse(CloudinaryConfig.uploadUrl);
      final request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;
      if (folder != null && folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final secureUrl = data['secure_url'] as String?;
        return secureUrl;
      } else {
        return null;
      }
    } catch (_) {
      return null;
    }
  }
}

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryService();
});
