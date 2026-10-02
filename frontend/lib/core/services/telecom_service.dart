import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/ui_kit.dart';

/// Telecom and messaging service to initiate real phone calls, WhatsApp messages, and SMS.
class TelecomService {
  TelecomService._();

  /// Clean telephone number to international format without spaces
  static String sanitizePhone(String rawPhone) {
    String clean = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.startsWith('0') && clean.length == 10) {
      clean = '+255${clean.substring(1)}';
    } else if (clean.startsWith('255') && !clean.startsWith('+')) {
      clean = '+$clean';
    }
    return clean;
  }

  /// Clean telephone number for WhatsApp wa.me links (digits only, no +)
  static String sanitizeForWhatsApp(String rawPhone) {
    String clean = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0') && clean.length == 10) {
      clean = '255${clean.substring(1)}';
    }
    return clean;
  }

  /// Make a real voice call using native phone dialer
  static Future<bool> makePhoneCall(BuildContext context, String rawPhone, {String? recipientName}) async {
    final clean = sanitizePhone(rawPhone);
    final uri = Uri.parse('tel:$clean');
    final name = recipientName != null ? ' ($recipientName)' : '';

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
        return true;
      }
    } catch (_) {
      // Fallback: Copy to clipboard and notify
      await Clipboard.setData(ClipboardData(text: clean));
      if (context.mounted) {
        LimsToast.show(
          context,
          'Dialer not available. Phone number $clean$name copied to clipboard!',
          isSuccess: true,
          icon: Icons.phone_forwarded_rounded,
        );
      }
      return false;
    }
  }

  /// Open WhatsApp directly to chat with borrower or guarantor
  static Future<bool> openWhatsAppChat(
    BuildContext context,
    String rawPhone, {
    String? message,
    String? recipientName,
  }) async {
    final waPhone = sanitizeForWhatsApp(rawPhone);
    final text = message ??
        'Habari, huu ni ujumbe kutoka LIMS kuhusiana na akaunti yako ya kifaa cha mkononi.';
    final encoded = Uri.encodeComponent(text);
    final uri = Uri.parse('https://wa.me/$waPhone?text=$encoded');

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return true;
      await launchUrl(uri, mode: LaunchMode.platformDefault);
      return true;
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: '$rawPhone - $text'));
      if (context.mounted) {
        LimsToast.show(
          context,
          'WhatsApp could not be opened. Phone & reminder message copied!',
          isSuccess: true,
          icon: Icons.chat_bubble_outline_rounded,
        );
      }
      return false;
    }
  }

  /// Send native SMS message
  static Future<bool> sendSmsMessage(
    BuildContext context,
    String rawPhone, {
    String? body,
  }) async {
    final clean = sanitizePhone(rawPhone);
    final text = body ?? 'LIMS payment reminder';
    final uri = Uri.parse('sms:$clean?body=${Uri.encodeComponent(text)}');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
        return true;
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: clean));
      if (context.mounted) {
        LimsToast.show(
          context,
          'SMS app not available. Phone $clean copied to clipboard!',
          isSuccess: true,
        );
      }
      return false;
    }
  }
}
