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
  final bool isMajor;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.releaseNotes,
    required this.apkUrl,
    required this.hasUpdate,
    this.isMajor = false,
  });

  /// Compara dos versiones semánticas (ej. '1.0.4' > '1.0.3')
  static bool isVersionHigher(String remote, String current) {
    if (remote.isEmpty || current.isEmpty) return false;
    try {
      final rParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      
      final maxLen = rParts.length > cParts.length ? rParts.length : cParts.length;
      for (int i = 0; i < maxLen; i++) {
        final rVal = i < rParts.length ? rParts[i] : 0;
        final cVal = i < cParts.length ? cParts[i] : 0;
        if (rVal > cVal) return true;
        if (rVal < cVal) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  factory UpdateInfo.fromJson(Map<String, dynamic> json, {required String currentVersion, required int currentBuildNumber}) {
    final int remoteBuildNumber = json['buildNumber'] is int
        ? json['buildNumber']
        : int.tryParse(json['buildNumber']?.toString() ?? '0') ?? 0;
    final String remoteVersion = json['version']?.toString() ?? '';
    final String notes = json['releaseNotes']?.toString() ?? 'Mejoras y correcciones en la aplicación.';
    final String url = json['apkUrl']?.toString() ?? 'https://rindemas.cesarluis.com/rindemas.apk';
    final bool isMajorUpdate = json['isMajor'] == true || json['isCritical'] == true;

    // Hay actualización si la versión semántica es mayor O si el buildNumber es mayor teniendo igual o superior versión
    final bool versionHigher = isVersionHigher(remoteVersion, currentVersion);
    final bool buildHigher = remoteVersion == currentVersion && remoteBuildNumber > currentBuildNumber;
    final bool hasNewUpdate = versionHigher || buildHigher;

    return UpdateInfo(
      version: remoteVersion,
      buildNumber: remoteBuildNumber,
      releaseNotes: notes,
      apkUrl: url,
      hasUpdate: hasNewUpdate,
      isMajor: isMajorUpdate,
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
    String? currentVersion,
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
        String activeVersion = currentVersion ?? '';

        if (currentBuildNumber == null || currentVersion == null) {
          try {
            final packageInfo = await PackageInfo.fromPlatform();
            activeBuildNumber = int.tryParse(packageInfo.buildNumber) ?? activeBuildNumber;
            activeVersion = packageInfo.version.isNotEmpty ? packageInfo.version : activeVersion;
          } catch (e) {
            debugPrint('Error obteniendo PackageInfo: $e');
          }
        }

        final updateInfo = UpdateInfo.fromJson(
          data,
          currentVersion: activeVersion,
          currentBuildNumber: activeBuildNumber,
        );
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
