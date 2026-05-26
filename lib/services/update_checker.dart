import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  // ── உங்கள் GitHub repo details இங்க மாத்துங்க ──
  static const _owner = 'karthick2007-bca';
  static const _repo  = 'billing-software';
  static const _currentVersion = '0.9.0'; // pubspec version-உடன் match பண்ணுங்க

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final res = await http.get(
        Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      final latestTag = (data['tag_name'] as String).replaceAll('v', '').trim();
      final downloadUrl = data['html_url'] as String? ?? '';
      final releaseNotes = data['body'] as String? ?? '';

      if (_isNewer(latestTag, _currentVersion)) {
        return UpdateInfo(
          latestVersion: latestTag,
          currentVersion: _currentVersion,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static bool _isNewer(String latest, String current) {
    final l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (l.length < 3) l.add(0);
    while (c.length < 3) c.add(0);
    for (int i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  static Future<void> openDownloadPage(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class UpdateInfo {
  final String latestVersion, currentVersion, downloadUrl, releaseNotes;
  const UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}
