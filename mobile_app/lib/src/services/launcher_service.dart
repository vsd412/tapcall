import 'package:url_launcher/url_launcher.dart';
import '../models/contact.dart';

class LauncherService {
  // Returns true if a launch was attempted successfully.
  static Future<bool> launchContact(Contact c) async {
    if (c.app == 'whatsapp') return _launchWhatsApp(c);
    final uri = _uriForGeneric(c);
    if (uri == null) return false;
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> _launchWhatsApp(Contact c) async {
    // WhatsApp expects digits only (with country code). Remove plus and any non-digits.
    final numeric = c.fullNumber.replaceAll(RegExp('[^0-9]'), '');
    if (numeric.isEmpty) return false;

    final deep = Uri.parse('whatsapp://send?phone=$numeric');
    if (!await canLaunchUrl(deep)) return false;
    return launchUrl(deep, mode: LaunchMode.externalApplication);
  }

  static Uri? _uriForGeneric(Contact c) {
    final id = c.fullNumber;
    switch (c.app) {
      case 'phone':
        return Uri.parse('tel:$id');
      default:
        return null;
    }
  }
}
