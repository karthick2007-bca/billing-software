import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class UpdateService {
  // This URL points to version.json hosted on your GitHub repo (raw content)
  static const String _versionUrl =
      'https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/version.json';

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
    title: const Row(children: [
      Icon(Icons.system_update, color: Color(0xFF1565C0)),
      SizedBox(width: 8),
      Text('Update Available'),
    ]),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('A new version ${widget.version} is available.'),
      const SizedBox(height: 8),
      const Text('Please update to get the latest features and fixes.',
          style: TextStyle(color: Colors.grey, fontSize: 13)),
      if (_downloading) ...[ 
        const SizedBox(height: 16),
        LinearProgressIndicator(value: _progress),
        const SizedBox(height: 8),
        Text(_status, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    ]),
    actions: _downloading
        ? []
        : [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: _download,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white),
              child: const Text('Update Now'),
            ),
          ],
  );
}
