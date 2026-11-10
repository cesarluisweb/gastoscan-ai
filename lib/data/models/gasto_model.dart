import '../../core/constants/app_constants.dart';
import 'item_gasto_model.dart';

const Object _unsetSentinel = Object();

class GastoModel {
  final int? id;
  final String uuid;
  final String fecha;
  final String comercio;
  final String moneda;
  final int totalOriginal;
  final int totalUsd;
  final int? totalUsdt;
  final int? totalEur;
  final double tasaCambio;
  final double? tasaUsdt;
  final double? tasaEur;
  final String? fuenteTasaCambio;
  final String? fechaTasaCambio;
  final String categoria;
  final String? rutaFotoLocal;
  final String creadoEn;
  final String? actualizadoEn;
  final String? eliminadoEn;
  final List<ItemGastoModel> items;
  final String? firestoreId;
  final int synced;
  final String? ocrText;

  GastoModel({
    this.id,
    required this.uuid,
    required this.fecha,
    required this.comercio,
    required this.moneda,
    required this.totalOriginal,
    required this.totalUsd,
    this.totalUsdt,
    this.totalEur,
    this.tasaCambio = 1.0,
    this.tasaUsdt,
    this.tasaEur,
    this.fuenteTasaCambio,
    this.fechaTasaCambio,
    required this.categoria,
    this.rutaFotoLocal,
    required this.creadoEn,
    this.actualizadoEn,
    this.eliminadoEn,
    this.items = const [],
    this.firestoreId,
    this.synced = 0,
    this.ocrText,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'fecha': fecha,
      'comercio': comercio,
      'moneda': moneda,
      'total_original': totalOriginal,
      'total_usd': totalUsd,
      'total_usdt': totalUsdt,
      'total_eur': totalEur,
      'tasa_cambio': tasaCambio,
      'tasa_usdt': tasaUsdt,
      'tasa_eur': tasaEur,
      'fuente_tasa_cambio': fuenteTasaCambio,
      'fecha_tasa_cambio': fechaTasaCambio,
      'categoria': categoria,
      'ruta_foto_local': rutaFotoLocal,
      'creado_en': creadoEn,
      'actualizado_en': actualizadoEn,
      'eliminado_en': eliminadoEn,
      'firestore_id': firestoreId,
      'synced': synced,
      'ocr_text': ocrText,
    };
  }

  /// Mapa preparado exclusivamente para sincronización con Firestore.
  /// Excluye 'ruta_foto_local' para no almacenar rutas locales del dispositivo en la nube.
  Map<String, dynamic> toFirestoreMap() {
    final map = toMap();
    map.remove('ruta_foto_local');
    return map;
  }

  factory GastoModel.fromMap(Map<String, dynamic> map, {List<ItemGastoModel> items = const []}) {
    final int tUsd = (map['total_usd'] as num?)?.toInt() ?? 0;
    final int? tUsdt = (map['total_usdt'] as num?)?.toInt();
    final int? tEur = (map['total_eur'] as num?)?.toInt();
    final double tCambio = (map['tasa_cambio'] as num?)?.toDouble() ?? 1.0;
    final double? tUsdtRate = (map['tasa_usdt'] as num?)?.toDouble();
    final double? tEurRate = (map['tasa_eur'] as num?)?.toDouble();

    return GastoModel(
      id: map['id'] as int?,
      uuid: map['uuid'] as String? ?? '',
      fecha: map['fecha'] as String? ?? '',
      comercio: map['comercio'] as String? ?? 'Comercio Desconocido',
      moneda: map['moneda'] as String? ?? 'USD',
      totalOriginal: (map['total_original'] as num?)?.toInt() ?? 0,
      totalUsd: tUsd,
      totalUsdt: tUsdt,
      totalEur: tEur,
      tasaCambio: tCambio,
      tasaUsdt: tUsdtRate,
      tasaEur: tEurRate,
      fuenteTasaCambio: map['fuente_tasa_cambio'] as String?,
      fechaTasaCambio: map['fecha_tasa_cambio'] as String?,
      categoria: AppConstants.normalizarCategoria(map['categoria'] as String?),
      rutaFotoLocal: map['ruta_foto_local'] as String?,
      creadoEn: map['creado_en'] as String? ?? DateTime.now().toIso8601String(),
      actualizadoEn: map['actualizado_en'] as String?,
      eliminadoEn: map['eliminado_en'] as String?,
      items: items,
      firestoreId: map['firestore_id'] as String?,
      synced: map['synced'] as int? ?? 0,
      ocrText: map['ocr_text'] as String?,
    );
  }

  GastoModel copyWith({
    int? id,
    String? uuid,
    String? fecha,
    String? comercio,
    String? moneda,
    int? totalOriginal,
    int? totalUsd,
    Object? totalUsdt = _unsetSentinel,
    Object? totalEur = _unsetSentinel,
    double? tasaCambio,
    Object? tasaUsdt = _unsetSentinel,
    Object? tasaEur = _unsetSentinel,
    Object? fuenteTasaCambio = _unsetSentinel,
    Object? fechaTasaCambio = _unsetSentinel,
    String? categoria,
    Object? rutaFotoLocal = _unsetSentinel,
    String? creadoEn,
    String? actualizadoEn,
    Object? eliminadoEn = _unsetSentinel,
    List<ItemGastoModel>? items,
    Object? firestoreId = _unsetSentinel,
    int? synced,
    Object? ocrText = _unsetSentinel,
  }) {
    return GastoModel(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      fecha: fecha ?? this.fecha,
      comercio: comercio ?? this.comercio,
      moneda: moneda ?? this.moneda,
      totalOriginal: totalOriginal ?? this.totalOriginal,
      totalUsd: totalUsd ?? this.totalUsd,
      totalUsdt: identical(totalUsdt, _unsetSentinel) ? this.totalUsdt : totalUsdt as int?,
      totalEur: identical(totalEur, _unsetSentinel) ? this.totalEur : totalEur as int?,
      tasaCambio: tasaCambio ?? this.tasaCambio,
      tasaUsdt: identical(tasaUsdt, _unsetSentinel) ? this.tasaUsdt : tasaUsdt as double?,
      tasaEur: identical(tasaEur, _unsetSentinel) ? this.tasaEur : tasaEur as double?,
      fuenteTasaCambio: identical(fuenteTasaCambio, _unsetSentinel) ? this.fuenteTasaCambio : fuenteTasaCambio as String?,
      fechaTasaCambio: identical(fechaTasaCambio, _unsetSentinel) ? this.fechaTasaCambio : fechaTasaCambio as String?,
      categoria: categoria ?? this.categoria,
      rutaFotoLocal: identical(rutaFotoLocal, _unsetSentinel) ? this.rutaFotoLocal : rutaFotoLocal as String?,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      eliminadoEn: identical(eliminadoEn, _unsetSentinel) ? this.eliminadoEn : eliminadoEn as String?,
      items: items ?? this.items,
      firestoreId: identical(firestoreId, _unsetSentinel) ? this.firestoreId : firestoreId as String?,
      synced: synced ?? this.synced,
      ocrText: identical(ocrText, _unsetSentinel) ? this.ocrText : ocrText as String?,
    );
  }

  /// Devuelve una copia del gasto sin la foto local desvinculada
  GastoModel sinFoto() {
    return GastoModel(
      id: id,
      uuid: uuid,
      fecha: fecha,
      comercio: comercio,
      moneda: moneda,
      totalOriginal: totalOriginal,
      totalUsd: totalUsd,
      totalUsdt: totalUsdt,
      totalEur: totalEur,
      tasaCambio: tasaCambio,
      tasaUsdt: tasaUsdt,
      tasaEur: tasaEur,
      fuenteTasaCambio: fuenteTasaCambio,
      fechaTasaCambio: fechaTasaCambio,
      categoria: categoria,
      rutaFotoLocal: null,
      creadoEn: creadoEn,
      actualizadoEn: DateTime.now().toIso8601String(),
      eliminadoEn: eliminadoEn,
      items: items,
      firestoreId: firestoreId,
      synced: synced,
      ocrText: ocrText,
    );
  }

  double get totalOriginalDisplay => totalOriginal / 100.0;
  double get totalUsdDisplay => totalUsd / 100.0;
  double? get totalUsdtDisplay => totalUsdt != null ? totalUsdt! / 100.0 : null;
  double? get tasaUsdtDisplay => (tasaUsdt != null && tasaUsdt! > 0) ? tasaUsdt! : null;
  double? get totalEurDisplay => totalEur != null ? totalEur! / 100.0 : null;
  double? get tasaEurDisplay => tasaEur;
}
