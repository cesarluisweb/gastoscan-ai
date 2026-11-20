import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connectivity_service.dart';

/// Servicio local-first para cachear en disco la foto de perfil del usuario
/// autenticado por [uid], validar la integridad de la imagen descargada y
/// purgarla al cerrar sesión o eliminar cuenta.
class ProfileAvatarService {
  static const String _avatarsDirName = 'avatars';
  static const String _prefUrlPrefix = 'profile_avatar_url_';
  static const int _maxAvatarBytes = 2 * 1024 * 1024; // 2 MB
  static const Duration _downloadTimeout = Duration(seconds: 6);

  static ProfileAvatarService _instance = ProfileAvatarService();
  static ProfileAvatarService get instance => _instance;

  @visibleForTesting
  static void setMockInstance(ProfileAvatarService service) {
    _instance = service;
  }

  @visibleForTesting
  static void reset() {
    _instance = ProfileAvatarService();
  }

  final http.Client? _injectedHttpClient;
  final ConnectivityService _connectivityService;
  final Future<Directory?> Function()? _baseDirectoryProvider;
  final Future<SharedPreferences> Function()? _prefsProvider;
  final Map<String, Future<File?>> _inFlight = {};

  ProfileAvatarService({
    http.Client? httpClient,
    ConnectivityService? connectivityService,
    Future<Directory?> Function()? baseDirectoryProvider,
    Future<SharedPreferences> Function()? prefsProvider,
  })  : _injectedHttpClient = httpClient,
        _connectivityService = connectivityService ?? ConnectivityService.instance,
        _baseDirectoryProvider = baseDirectoryProvider,
        _prefsProvider = prefsProvider;

  /// Sanitiza el [uid] para usarlo de forma segura como segmento de nombre de archivo.
  static String sanitizeUid(String uid) {
    final cleaned = uid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').trim();
    return cleaned.isEmpty ? 'user' : cleaned;
  }

  /// Hash determinista FNV-1a de 32 bits en hexadecimal de 8 caracteres.
  /// Permite que el nombre de archivo cambie cuando el usuario actualiza su foto
  /// en Google, evitando colisiones con la caché en RAM de Flutter (`ImageCache`).
  static String shortUrlHash(String url) {
    int hash = 0x811c9dc5;
    for (int i = 0; i < url.length; i++) {
      hash ^= url.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Valida magic bytes de formatos de imagen soportados por Flutter
  /// (JPEG, PNG, WebP, GIF) para rechazar HTML de portales cautivos o basura.
  static bool hasValidImageSignature(Uint8List bytes) {
    if (bytes.length < 12) return false;
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true;
    }
    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return true;
    }
    // WebP: RIFF....WEBP
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    // GIF: GIF87a / GIF89a
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) &&
        bytes[5] == 0x61) {
      return true;
    }
    return false;
  }

  static bool isValidHttpsPhotoUrl(String? photoUrl) {
    if (photoUrl == null) return false;
    final trimmed = photoUrl.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  Future<Directory?> _resolveAvatarsDirectory({bool create = false}) async {
    try {
      final dirProvider = _baseDirectoryProvider;
      final baseDir = dirProvider != null
          ? await dirProvider()
          : await getApplicationSupportDirectory();
      if (baseDir == null) return null;
      final avatarsDir = Directory(p.join(baseDir.path, _avatarsDirName));
      if (create && !await avatarsDir.exists()) {
        await avatarsDir.create(recursive: true);
      }
      return avatarsDir;
    } catch (e) {
      debugPrint('ProfileAvatarService: No se pudo resolver el directorio de avatares: $e');
      return null;
    }
  }

  Future<SharedPreferences?> _resolvePrefs() async {
    try {
      final provider = _prefsProvider;
      return provider != null
          ? await provider()
          : await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('ProfileAvatarService: No se pudo acceder a SharedPreferences: $e');
      return null;
    }
  }

  String _fileNameFor(String safeUid, String photoUrl) {
    return 'avatar_${safeUid}_${shortUrlHash(photoUrl)}.img';
  }

  /// Devuelve el archivo de avatar ya almacenado en disco para [uid].
  /// Prioriza la coincidencia exacta con [photoUrl]; si no existe pero hay un
  /// archivo previo del mismo [uid], lo devuelve como respaldo offline.
  Future<File?> getCachedAvatarFile({required String uid, String? photoUrl}) async {
    final safeUid = sanitizeUid(uid);
    final avatarsDir = await _resolveAvatarsDirectory(create: false);
    if (avatarsDir == null || !await avatarsDir.exists()) return null;

    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      final exactFile = File(p.join(avatarsDir.path, _fileNameFor(safeUid, photoUrl.trim())));
      if (await _isValidLocalFile(exactFile)) {
        return exactFile;
      }
    }

    // Respaldo offline: buscar cualquier archivo válido de ese mismo uid
    try {
      final prefix = 'avatar_${safeUid}_';
      final entries = avatarsDir.listSync();
      for (final entity in entries) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (name.startsWith(prefix) && name.endsWith('.img')) {
            if (await _isValidLocalFile(entity)) {
              return entity;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('ProfileAvatarService: Error inspeccionando avatares locales: $e');
    }
    return null;
  }

  /// Verifica si ya existe el archivo exacto correspondiente a [uid] y [photoUrl].
  Future<bool> hasExactCachedAvatar({required String uid, required String photoUrl}) async {
    final safeUid = sanitizeUid(uid);
    final avatarsDir = await _resolveAvatarsDirectory(create: false);
    if (avatarsDir == null || !await avatarsDir.exists()) return false;
    final exactFile = File(p.join(avatarsDir.path, _fileNameFor(safeUid, photoUrl.trim())));
    return _isValidLocalFile(exactFile);
  }

  Future<bool> _isValidLocalFile(File file) async {
    try {
      if (!await file.exists()) return false;
      final stat = await file.stat();
      return stat.size > 0 && stat.size <= _maxAvatarBytes;
    } catch (e) {
      debugPrint('ProfileAvatarService: Error validando archivo local ${file.path}: $e');
      return false;
    }
  }

  /// Garantiza que el avatar de [uid] para [photoUrl] esté persistido en disco.
  /// - Si ya existe para esa URL, retorna el archivo en 0 ms sin tocar red.
  /// - Si falta o cambió la URL, descarga (si hay red), valida y persiste de forma atómica.
  /// - Deduplica descargas concurrentes para el mismo `uid|url`.
  Future<File?> ensureAvatarCached({
    required String uid,
    required String photoUrl,
  }) {
    final trimmedUrl = photoUrl.trim();
    if (!isValidHttpsPhotoUrl(trimmedUrl)) {
      return Future.value(null);
    }

    final safeUid = sanitizeUid(uid);
    final flightKey = '$safeUid|$trimmedUrl';
    final existing = _inFlight[flightKey];
    if (existing != null) {
      return existing;
    }

    final future = _downloadAndCacheAvatar(
      safeUid: safeUid,
      photoUrl: trimmedUrl,
    );
    _inFlight[flightKey] = future;
    return future.whenComplete(() {
      if (identical(_inFlight[flightKey], future)) {
        _inFlight.remove(flightKey);
      }
    });
  }

  Future<File?> _downloadAndCacheAvatar({
    required String safeUid,
    required String photoUrl,
  }) async {
    final avatarsDir = await _resolveAvatarsDirectory(create: true);
    if (avatarsDir == null) return null;

    final targetFileName = _fileNameFor(safeUid, photoUrl);
    final targetPath = p.join(avatarsDir.path, targetFileName);
    final targetFile = File(targetPath);

    if (await _isValidLocalFile(targetFile)) {
      return targetFile;
    }

    final hasConnection = await _connectivityService.isConnected();
    if (!hasConnection) {
      return null;
    }

    final bool ownsClient = _injectedHttpClient == null;
    final http.Client client = _injectedHttpClient ?? http.Client();
    File? tempFile;

    try {
      final response = await client.get(
        Uri.parse(photoUrl),
        headers: const {'User-Agent': 'RindeMas/1.0 (Android; Linux)'},
      ).timeout(_downloadTimeout);

      if (response.statusCode != 200) {
        debugPrint('ProfileAvatarService: Descarga rechazada con HTTP ${response.statusCode}.');
        return null;
      }

      final contentType = response.headers['content-type']?.toLowerCase().trim();
      if (contentType != null && contentType.isNotEmpty && !contentType.startsWith('image/')) {
        debugPrint('ProfileAvatarService: Content-Type no válido ($contentType). Posible portal cautivo.');
        return null;
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty || bytes.length > _maxAvatarBytes) {
        debugPrint('ProfileAvatarService: Tamaño de avatar fuera de rango (${bytes.length} bytes).');
        return null;
      }

      if (!hasValidImageSignature(bytes)) {
        debugPrint('ProfileAvatarService: Firma mágica de imagen no válida.');
        return null;
      }

      // Escritura atómica mediante archivo temporal + rename
      tempFile = File('$targetPath.tmp_${DateTime.now().microsecondsSinceEpoch}');
      await tempFile.writeAsBytes(bytes, flush: true);
      final savedFile = await tempFile.rename(targetPath);
      tempFile = null;

      await _deleteOldUserAvatars(avatarsDir, safeUid: safeUid, keepFileName: targetFileName);

      final prefs = await _resolvePrefs();
      if (prefs != null) {
        try {
          await prefs.setString('$_prefUrlPrefix$safeUid', photoUrl);
        } catch (e) {
          debugPrint('ProfileAvatarService: No se pudo guardar metadato de URL en SharedPreferences: $e');
        }
      }

      return savedFile;
    } catch (e) {
      debugPrint('ProfileAvatarService: Error descargando avatar: $e');
      return null;
    } finally {
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (e) {
          debugPrint('ProfileAvatarService: Error limpiando archivo temporal de avatar: $e');
        }
      }
      if (ownsClient) {
        client.close();
      }
    }
  }

  Future<void> _deleteOldUserAvatars(
    Directory avatarsDir, {
    required String safeUid,
    String? keepFileName,
  }) async {
    try {
      if (!await avatarsDir.exists()) return;
      final prefix = 'avatar_${safeUid}_';
      final entries = avatarsDir.listSync();
      for (final entity in entries) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (name.startsWith(prefix) && name != keepFileName) {
            await _evictFromImageCache(entity);
            try {
              await entity.delete();
            } catch (e) {
              debugPrint('ProfileAvatarService: Error borrando avatar previo ($name): $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('ProfileAvatarService: Error limpiando avatares previos: $e');
    }
  }

  Future<void> _evictFromImageCache(File file) async {
    try {
      await FileImage(file).evict();
    } catch (e) {
      debugPrint('ProfileAvatarService: Evict en ImageCache omitido: $e');
    }
  }

  /// Purga los archivos de avatar locales y sus metadatos en `SharedPreferences`.
  /// Si [uid] es `null`, elimina todos los avatares cacheados.
  Future<void> clearAvatarCache({String? uid}) async {
    final avatarsDir = await _resolveAvatarsDirectory(create: false);
    if (avatarsDir != null && await avatarsDir.exists()) {
      if (uid != null && uid.trim().isNotEmpty) {
        final safeUid = sanitizeUid(uid);
        await _deleteOldUserAvatars(avatarsDir, safeUid: safeUid, keepFileName: null);
      } else {
        try {
          final entries = avatarsDir.listSync();
          for (final entity in entries) {
            if (entity is File) {
              await _evictFromImageCache(entity);
              try {
                await entity.delete();
              } catch (e) {
                debugPrint('ProfileAvatarService: Error borrando archivo de avatar (${entity.path}): $e');
              }
            }
          }
        } catch (e) {
          debugPrint('ProfileAvatarService: Error recorriendo carpeta de avatares al limpiar: $e');
        }
      }
    }

    final prefs = await _resolvePrefs();
    if (prefs != null) {
      try {
        if (uid != null && uid.trim().isNotEmpty) {
          await prefs.remove('$_prefUrlPrefix${sanitizeUid(uid)}');
        } else {
          final keys = prefs.getKeys().where((k) => k.startsWith(_prefUrlPrefix)).toList();
          for (final key in keys) {
            await prefs.remove(key);
          }
        }
      } catch (e) {
        debugPrint('ProfileAvatarService: Error limpiando metadatos de avatar en SharedPreferences: $e');
      }
    }
  }
}
