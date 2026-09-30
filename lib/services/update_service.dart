import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final String version;
  final int buildNumber;
  final String releaseNotes;
  final String apkUrl;
  final bool hasUpdate;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.releaseNotes,
    required this.apkUrl,
    required this.hasUpdate,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json, int currentBuildNumber) {
    final int remoteBuildNumber = json['buildNumber'] is int
        ? json['buildNumber']
        : int.tryParse(json['buildNumber']?.toString() ?? '0') ?? 0;
    final String remoteVersion = json['version']?.toString() ?? '';
    final String notes = json['releaseNotes']?.toString() ?? 'Mejoras y correcciones en la aplicación.';
    final String url = json['apkUrl']?.toString() ?? 'https://rindemas.cesarluis.com/app-release.apk';

    return UpdateInfo(
      version: remoteVersion,
      buildNumber: remoteBuildNumber,
      releaseNotes: notes,
      apkUrl: url,
      hasUpdate: remoteBuildNumber > currentBuildNumber,
    );
  }
}

class UpdateService {
  static const String versionCheckUrl = 'https://rindemas.cesarluis.com/version.json';
  static const String prefLastCheckTime = 'update_last_check_timestamp';

  final http.Client _client;

  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  /// Comprueba si existe una versión superior en el servidor.
  /// Si [force] es false, puede omitirse si se verificó hace muy poco (ej. menos de 6 horas)
  /// en comprobaciones automáticas de inicio para optimizar datos de red.
  Future<UpdateInfo?> checkForUpdate({
    bool force = false,
    Duration throttleDuration = const Duration(hours: 4),
    int? currentBuildNumber,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;

      if (!force) {
        final lastCheck = prefs.getInt(prefLastCheckTime) ?? 0;
        if (now - lastCheck < throttleDuration.inMilliseconds) {
          return null;
        }
      }

      final response = await _client.get(
        Uri.parse(versionCheckUrl),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        await prefs.setInt(prefLastCheckTime, now);
        final Map<String, dynamic> data = jsonDecode(response.body);

        int activeBuildNumber = currentBuildNumber ?? 0;
        if (currentBuildNumber == null) {
          try {
            final packageInfo = await PackageInfo.fromPlatform();
            activeBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
          } catch (e) {
            debugPrint('Error obteniendo PackageInfo: $e');
          }
        }

        final updateInfo = UpdateInfo.fromJson(data, activeBuildNumber);
        return updateInfo;
      }
    } catch (e) {
      debugPrint('Error al verificar actualización: $e');
    }
    return null;
  }

  /// Inicia la descarga abriendo la URL del APK directo
  static Future<bool> openDownloadUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error abriendo enlace de descarga: $e');
      return false;
    }
  }
}
