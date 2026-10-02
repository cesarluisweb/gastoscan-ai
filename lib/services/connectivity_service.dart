import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Servicio para verificar y escuchar reactivamente el estado de conectividad a internet.
class ConnectivityService {
  static ConnectivityService? _instance;
  static ConnectivityService get instance => _instance ??= ConnectivityService();

  static bool get isTestEnvironment =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  final Connectivity? _connectivity;
  final StreamController<bool>? _testController;
  final bool? _testConnected;

  ConnectivityService({
    Connectivity? connectivity,
    StreamController<bool>? testController,
    bool? testConnected,
  })  : _connectivity = (testController != null || (connectivity == null && isTestEnvironment))
            ? null
            : (connectivity ?? Connectivity()),
        _testController = testController,
        _testConnected = testConnected;

  @visibleForTesting
  static void setMockInstance(ConnectivityService service) {
    _instance = service;
  }

  @visibleForTesting
  static void reset() {
    _instance = null;
  }

  /// Verifica si el dispositivo cuenta con alguna interfaz de red activa.
  Future<bool> isConnected() async {
    if (_testConnected != null) return _testConnected!;
    final conn = _connectivity;
    if (conn == null) return true;
    try {
      final results = await conn.checkConnectivity();
      if (results.isEmpty) return true;
      return _hasActiveConnection(results);
    } catch (e) {
      // Fallback seguro ante fallos de canal nativo o emuladores
      return true;
    }
  }

  /// Stream reactivo que emite `true` cuando se recupera red y `false` cuando se pierde.
  Stream<bool> get onConnectivityChanged {
    if (_testController != null) {
      return _testController!.stream;
    }
    final conn = _connectivity;
    if (conn == null) {
      return const Stream.empty();
    }
    try {
      return conn.onConnectivityChanged
          .map(_hasActiveConnection)
          .handleError((error) {
            debugPrint('Aviso en stream de conectividad: $error');
          })
          .distinct();
    } catch (e) {
      return const Stream.empty();
    }
  }

  bool _hasActiveConnection(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }
}
