import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/gasto_model.dart';
import '../data/repositories/gasto_repository.dart';

/// Mantiene un índice local `gasto.uuid -> ruta_foto_local` en SharedPreferences
/// y reconcilia automáticamente comprobantes huérfanos (`recibo_<timestamp>.<ext>`)
/// en el almacenamiento interno de la app tras cierres de sesión o reemplazos desde la nube.
class ReceiptPhotoRegistry {
  static const String prefsKey = 'local_receipt_photo_map_v1';

  /// Ventana máxima de diferencia entre el timestamp del archivo `recibo_<ms>.ext`
  /// y `creado_en` / `actualizado_en` del gasto (2 minutos).
  static const int maxTimestampDeltaMs = 120000;

  /// Tolerancia pequeña para desfases de reloj o redondeos (5 segundos).
  static const int maxClockSkewAfterMs = 5000;

  static final RegExp _receiptFileRegex = RegExp(r'^recibo_(\d+)\.[a-zA-Z0-9]+$');

  static Future<SharedPreferences?> _getPrefs(SharedPreferences? override) async {
    if (override != null) return override;
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('ReceiptPhotoRegistry: Error accediendo a SharedPreferences: $e');
      return null;
    }
  }

  static Future<Map<String, String>> loadMap({SharedPreferences? prefsOverride}) async {
    final prefs = await _getPrefs(prefsOverride);
    if (prefs == null) return {};
    try {
      final raw = prefs.getString(prefsKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <String, String>{};
      decoded.forEach((k, v) {
        if (k is String && v is String && k.isNotEmpty && v.isNotEmpty) {
          result[k] = v;
        }
      });
      return result;
    } catch (e) {
      debugPrint('ReceiptPhotoRegistry: Error decodificando mapa local de comprobantes: $e');
      return {};
    }
  }

  static Future<void> saveMap(
    Map<String, String> map, {
    SharedPreferences? prefsOverride,
  }) async {
    final prefs = await _getPrefs(prefsOverride);
    if (prefs == null) return;
    try {
      await prefs.setString(prefsKey, jsonEncode(map));
    } catch (e) {
      debugPrint('ReceiptPhotoRegistry: Error guardando mapa local de comprobantes: $e');
    }
  }

  static Future<void> register(
    String uuid,
    String path, {
    SharedPreferences? prefsOverride,
  }) async {
    if (uuid.isEmpty || path.isEmpty) return;
    final map = await loadMap(prefsOverride: prefsOverride);
    if (map[uuid] == path) return;
    map[uuid] = path;
    await saveMap(map, prefsOverride: prefsOverride);
  }

  static Future<void> registerBatch(
    Map<String, String> entries, {
    SharedPreferences? prefsOverride,
  }) async {
    if (entries.isEmpty) return;
    final map = await loadMap(prefsOverride: prefsOverride);
    bool changed = false;
    entries.forEach((uuid, path) {
      if (uuid.isNotEmpty && path.isNotEmpty && map[uuid] != path) {
        map[uuid] = path;
        changed = true;
      }
    });
    if (changed) {
      await saveMap(map, prefsOverride: prefsOverride);
    }
  }

  static Future<void> unregister(
    String uuid, {
    SharedPreferences? prefsOverride,
  }) async {
    if (uuid.isEmpty) return;
    final map = await loadMap(prefsOverride: prefsOverride);
    if (map.remove(uuid) != null) {
      await saveMap(map, prefsOverride: prefsOverride);
    }
  }

  static Future<void> unregisterBatch(
    Iterable<String> uuids, {
    SharedPreferences? prefsOverride,
  }) async {
    final map = await loadMap(prefsOverride: prefsOverride);
    bool changed = false;
    for (final uuid in uuids) {
      if (map.remove(uuid) != null) {
        changed = true;
      }
    }
    if (changed) {
      await saveMap(map, prefsOverride: prefsOverride);
    }
  }

  static Future<void> clearAll({SharedPreferences? prefsOverride}) async {
    final prefs = await _getPrefs(prefsOverride);
    if (prefs == null) return;
    try {
      await prefs.remove(prefsKey);
    } catch (e) {
      debugPrint('ReceiptPhotoRegistry: Error limpiando mapa local de comprobantes: $e');
    }
  }

  /// Reconcilia los gastos locales activos sin `rutaFotoLocal` válida:
  /// 1. Busca coincidencia exacta por `uuid` en el mapa persistido (`local_receipt_photo_map_v1`).
  /// 2. Para los gastos restantes, empareja archivos huérfanos `recibo_<ms>.<ext>` en `app_flutter/`
  ///    con el gasto cuyo `creado_en` o `actualizado_en` coincida dentro de [maxTimestampDeltaMs].
  static Future<int> reconcileMissingPhotos({
    required GastoRepository repository,
    Directory? appDirOverride,
    SharedPreferences? prefsOverride,
  }) async {
    List<GastoModel> gastos;
    try {
      gastos = await repository.obtenerGastos();
    } catch (e) {
      debugPrint('ReceiptPhotoRegistry: No se pudieron leer gastos para reconciliar comprobantes: $e');
      return 0;
    }

    if (gastos.isEmpty) return 0;

    final savedMap = await loadMap(prefsOverride: prefsOverride);
    bool mapChanged = false;

    final Set<String> usedPaths = {};
    final List<GastoModel> missingPhotoGastos = [];

    for (final g in gastos) {
      final path = g.rutaFotoLocal;
      if (path != null && path.isNotEmpty) {
        bool exists = false;
        try {
          exists = File(path).existsSync();
        } catch (e) {
          debugPrint('ReceiptPhotoRegistry: Error verificando archivo $path: $e');
        }
        if (exists) {
          usedPaths.add(path);
          if (savedMap[g.uuid] != path) {
            savedMap[g.uuid] = path;
            mapChanged = true;
          }
          continue;
        }
      }
      if (g.id != null) {
        missingPhotoGastos.add(g);
      }
    }

    if (missingPhotoGastos.isEmpty) {
      if (mapChanged) {
        await saveMap(savedMap, prefsOverride: prefsOverride);
      }
      return 0;
    }

    int recoveredCount = 0;
    final List<GastoModel> stillMissing = [];

    // Paso 1: Reconciliación exacta por UUID desde el registro persistido
    for (final g in missingPhotoGastos) {
      final mappedPath = savedMap[g.uuid];
      if (mappedPath != null &&
          mappedPath.isNotEmpty &&
          !usedPaths.contains(mappedPath)) {
        bool exists = false;
        try {
          exists = File(mappedPath).existsSync();
        } catch (e) {
          debugPrint('ReceiptPhotoRegistry: Error verificando ruta mapeada $mappedPath: $e');
        }
        if (exists) {
          try {
            await repository.actualizarRutaFotoLocal(g.id!, mappedPath);
            usedPaths.add(mappedPath);
            recoveredCount++;
            continue;
          } catch (e) {
            debugPrint('ReceiptPhotoRegistry: Error actualizando ruta mapeada para gasto ${g.id}: $e');
          }
        }
      }
      stillMissing.add(g);
    }

    // Paso 2: Auto-recuperación de huérfanos `recibo_<ms>.<ext>` por marca de tiempo
    if (stillMissing.isNotEmpty) {
      Directory? appDir = appDirOverride;
      if (appDir == null) {
        try {
          appDir = await getApplicationDocumentsDirectory();
        } catch (e) {
          debugPrint('ReceiptPhotoRegistry: No se pudo resolver appDir: $e');
        }
      }

      if (appDir != null) {
        bool dirExists = false;
        try {
          dirExists = appDir.existsSync();
        } catch (e) {
          debugPrint('ReceiptPhotoRegistry: Error verificando appDir: $e');
        }

        if (dirExists) {
          // Mapa inverso path -> uuid para no reasignar fotos ya vinculadas a otra cuenta/UUID
          final Map<String, String> ownerByPath = {};
          savedMap.forEach((uuid, path) {
            ownerByPath[path] = uuid;
          });

          final List<_OrphanReceiptFile> orphanFiles = [];
          try {
            for (final entity in appDir.listSync()) {
              if (entity is! File) continue;
              if (usedPaths.contains(entity.path)) continue;
              final baseName = p.basename(entity.path);
              final match = _receiptFileRegex.firstMatch(baseName);
              if (match == null) continue;
              final tsMs = int.tryParse(match.group(1)!);
              if (tsMs == null) continue;
              orphanFiles.add(_OrphanReceiptFile(path: entity.path, timestampMs: tsMs));
            }
          } catch (e) {
            debugPrint('ReceiptPhotoRegistry: Error listando archivos en appDir: $e');
          }

          if (orphanFiles.isNotEmpty) {
            final List<_ReceiptMatchCandidate> candidates = [];

            for (final g in stillMissing) {
              final int? creadoMs = DateTime.tryParse(g.creadoEn)?.millisecondsSinceEpoch;
              final int? actualizadoMs = g.actualizadoEn != null
                  ? DateTime.tryParse(g.actualizadoEn!)?.millisecondsSinceEpoch
                  : null;
              if (creadoMs == null && actualizadoMs == null) continue;

              for (final file in orphanFiles) {
                final mappedOwner = ownerByPath[file.path];
                if (mappedOwner != null && mappedOwner != g.uuid) continue;

                int? bestDelta;
                if (creadoMs != null) {
                  final diff = creadoMs - file.timestampMs;
                  if (diff >= -maxClockSkewAfterMs && diff.abs() <= maxTimestampDeltaMs) {
                    bestDelta = diff.abs();
                  }
                }
                if (actualizadoMs != null) {
                  final diff = actualizadoMs - file.timestampMs;
                  if (diff >= -maxClockSkewAfterMs && diff.abs() <= maxTimestampDeltaMs) {
                    final absDiff = diff.abs();
                    if (bestDelta == null || absDiff < bestDelta) {
                      bestDelta = absDiff;
                    }
                  }
                }

                if (bestDelta != null) {
                  candidates.add(
                    _ReceiptMatchCandidate(
                      gasto: g,
                      path: file.path,
                      deltaMs: bestDelta,
                    ),
                  );
                }
              }
            }

            candidates.sort((a, b) => a.deltaMs.compareTo(b.deltaMs));

            final Set<int> assignedGastoIds = {};
            final Set<String> assignedPaths = {};

            for (final cand in candidates) {
              final gId = cand.gasto.id;
              if (gId == null) continue;
              if (assignedGastoIds.contains(gId) || assignedPaths.contains(cand.path)) {
                continue;
              }
              try {
                await repository.actualizarRutaFotoLocal(gId, cand.path);
                assignedGastoIds.add(gId);
                assignedPaths.add(cand.path);
                usedPaths.add(cand.path);
                savedMap[cand.gasto.uuid] = cand.path;
                mapChanged = true;
                recoveredCount++;
              } catch (e) {
                debugPrint('ReceiptPhotoRegistry: Error vinculando comprobante huérfano para gasto $gId: $e');
              }
            }
          }
        }
      }
    }

    if (mapChanged) {
      await saveMap(savedMap, prefsOverride: prefsOverride);
    }

    return recoveredCount;
  }
}

class _OrphanReceiptFile {
  final String path;
  final int timestampMs;

  const _OrphanReceiptFile({
    required this.path,
    required this.timestampMs,
  });
}

class _ReceiptMatchCandidate {
  final GastoModel gasto;
  final String path;
  final int deltaMs;

  const _ReceiptMatchCandidate({
    required this.gasto,
    required this.path,
    required this.deltaMs,
  });
}
