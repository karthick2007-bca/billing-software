import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class UpdateService {
  // This URL points to version.json hosted on your GitHub repo (raw content)
  static const String _versionUrl =
      'https://raw.githubusercontent.com/karthick2007-bca/billing-software/main/version.json';

  // Current app version — must match pubspec.yaml version
  static const String _currentVersion = '1.0.0';

  /// Call this on app startup to check for updates
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final res = await http.get(Uri.parse(_versionUrl));
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      final latestVersion = data['version'] as String;
      final downloadUrl = data['url'] as String;

      if (_isNewer(latestVersion, _currentVersion)) {
        if (context.mounted) {
          _showUpdateDialog(context, latestVersion, downloadUrl);
        }
      }
    } catch (_) {
      // Silently ignore — no internet or server down
    }
  }

  /// Compares version strings like "1.0.1" > "1.0.0"
  static bool _isNewer(String latest, String current) {
    final l = latest.split('.').map(int.parse).toList();
    final c = current.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  static void _showUpdateDialog(BuildContext context, String version, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDialog(version: version, downloadUrl: url),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final String version;
  final String downloadUrl;
  const _UpdateDialog({required this.version, required this.downloadUrl});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double _progress = 0;
  bool _downloading = false;
  String _status = '';

  Future<void> _download() async {
    setState(() { _downloading = true; _status = 'Downloading...'; });

    try {
      final dir = await getTemporaryDirectory();
      final zipPath = '${dir.path}\\update.zip';
      final extractPath = '${dir.path}\\update_extracted';

      // Download ZIP with progress
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.downloadUrl));
      final response = await client.send(request);
      final total = response.contentLength ?? 1;
      int received = 0;

      final file = File(zipPath);
      final sink = file.openWrite();
      await response.stream.forEach((chunk) {
        sink.add(chunk);
        received += chunk.length;
        setState(() => _progress = received / total);
      });
      await sink.close();

      setState(() => _status = 'Extracting...');

      // Extract ZIP using Windows built-in PowerShell
      await Process.run('powershell', [
        '-Command',
        'Expand-Archive -Path "$zipPath" -DestinationPath "$extractPath" -Force',
      ]);

      setState(() => _status = 'Installing...');

      // Run the installer/updater script inside the ZIP
      // Assumes the ZIP contains an install.bat or setup.exe
      final installer = File('$extractPath\\install.bat');
      if (await installer.exists()) {
        await Process.start(installer.path, [], runInShell: true);
      }

      setState(() => _status = 'Update complete! Please restart the app.');
    } catch (e) {
      setState(() { _status = 'Update failed: $e'; _downloading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    contentPadding: EdgeInsets.zero,
    content: Container(
      width: 380,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2744), Color(0xFF1E3A5F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 12),
              const Text('Update Available', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Version ${widget.version} is ready', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
            ]),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              if (!_downloading) ...[
                const Text(
                  'A new version of School Billing Software is available. Update now to get the latest features and bug fixes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Later', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _download,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ] else ...[
                const SizedBox(height: 4),
                Text(_status, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E3A5F))),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF1E3A5F)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _progress > 0 ? '${(_progress * 100).toStringAsFixed(0)}%' : 'Please wait...',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                if (_status.contains('complete') || _status.contains('failed')) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
            ]),
          ),
        ],
      ),
    ),
  );
}
