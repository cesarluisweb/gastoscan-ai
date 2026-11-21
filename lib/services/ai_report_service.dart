import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'connectivity_service.dart';

/// Error con mensaje apto para mostrarse al usuario.
class AiReportException implements Exception {
  final String message;

  const AiReportException(this.message);

  @override
  String toString() => message;
}

/// Envía reportes de respuestas de IA a Firestore (`ai_reports`).
///
/// Cumple la política "Contenido generado por IA" de Google Play: el usuario
/// reporta desde la app y el desarrollador recibe el reporte en Firebase Console.
class AiReportService {
  static const List<String> motivos = ['Inexacta', 'Inapropiada', 'Ofensiva', 'Otro'];
  static const int maxTextoRespuesta = 4000;
  static const int maxComentario = 500;

  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  AiReportService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _customFirestore = firestore,
        _customAuth = auth;

  FirebaseFirestore? get _firestore =>
      _customFirestore ?? (Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null);

  FirebaseAuth? get _auth =>
      _customAuth ?? (Firebase.apps.isNotEmpty ? FirebaseAuth.instance : null);

  /// Construye el documento sin tocar Firebase. Se usa en pruebas unitarias.
  static Map<String, dynamic> buildPayload({
    required String uid,
    required String textoRespuesta,
    required String motivo,
    String comentario = '',
    String origen = 'app',
    Object? creadoEn,
  }) {
    final texto = _recortar(textoRespuesta, maxTextoRespuesta);
    if (texto.isEmpty) {
      throw const AiReportException('No pudimos identificar la respuesta a reportar.');
    }

    return {
      'uid': uid,
      'texto_respuesta': texto,
      'motivo': motivos.contains(motivo) ? motivo : 'Otro',
      'comentario': _recortar(comentario, maxComentario),
      'origen': origen,
      'creado_en': creadoEn ?? FieldValue.serverTimestamp(),
    };
  }

  Future<void> enviar({
    required String textoRespuesta,
    required String motivo,
    String comentario = '',
  }) async {
    final firestore = _firestore;
    final auth = _auth;
    if (firestore == null || auth == null) {
      throw const AiReportException('No pudimos enviar tu reporte. Intenta de nuevo.');
    }

    final online = await ConnectivityService.instance.isConnected();
    if (!online) {
      throw const AiReportException('Necesitas conexión a internet para enviar el reporte.');
    }

    var user = auth.currentUser;
    if (user == null) {
      try {
        user = (await auth.signInAnonymously()).user;
      } on FirebaseAuthException catch (e) {
        debugPrint('AiReportService: fallo al iniciar sesión anónima (${e.code})');
        throw const AiReportException('No pudimos enviar tu reporte. Intenta de nuevo.');
      } catch (e) {
        debugPrint('AiReportService: error inesperado al iniciar sesión anónima');
        throw const AiReportException('No pudimos enviar tu reporte. Intenta de nuevo.');
      }
    }

    if (user == null) {
      throw const AiReportException('No pudimos enviar tu reporte. Intenta de nuevo.');
    }

    final payload = buildPayload(
      uid: user.uid,
      textoRespuesta: textoRespuesta,
      motivo: motivo,
      comentario: comentario,
    );

    try {
      await firestore
          .collection('ai_reports')
          .add(payload)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      debugPrint('AiReportService: tiempo de espera agotado al enviar el reporte');
      throw const AiReportException('El envío tardó demasiado. Intenta de nuevo.');
    } on FirebaseException catch (e) {
      debugPrint('AiReportService: error de Firestore (${e.code})');
      throw const AiReportException('No pudimos enviar tu reporte. Intenta de nuevo.');
    } catch (e) {
      debugPrint('AiReportService: error inesperado al enviar el reporte');
      throw const AiReportException('No pudimos enviar tu reporte. Intenta de nuevo.');
    }
  }

  static String _recortar(String valor, int maximo) {
    final limpio = valor.trim();
    if (limpio.length <= maximo) return limpio;
    return limpio.substring(0, maximo);
  }
}
