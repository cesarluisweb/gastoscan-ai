---
trigger: model_decision
description: "Consultar al trabajar con autenticación (Google/Anónimo), sincronización con Firestore, almacenamiento local SQLite, Google Play Data Safety o comunicación de privacidad."
---

# Privacidad, Seguridad de Datos y Sincronización

## 1. Arquitectura de Almacenamiento y Sincronización
- **Modelo Local-First:** Rinde Más almacena todos los registros financieros, categorías, presupuestos y listas de compras localmente en SQLite (`sqflite`).
- **Modo Anónimo (Sin Cuenta de Google):** Al iniciar la app por primera vez, `FirebaseAuth.instance.signInAnonymously()` genera un identificador anónimo en Firebase Auth para autenticar solicitudes seguras ante el Cloudflare Gateway. Sin embargo, `SyncService` no envía ningún dato a la nube (`user.isAnonymous == true`); todos los registros financieros quedan confinados en el dispositivo.
- **Sincronización Opcional en Cloud Firestore:** La sincronización en la nube solo se ejecuta si el usuario inicia sesión voluntariamente con su cuenta de Google. Los datos se persisten bajo `/users/{userId}/gastos` y `/users/{userId}/presupuestos`.
- **Aislamiento Criptográfico en Firestore:** Las reglas de seguridad en `firestore.rules` validan estrictamente `request.auth.uid == userId`, garantizando que ningún usuario pueda leer ni escribir información de otra cuenta.
- **Persistencia de Ajustes en Firestore y Aislamiento de BYOK:** Los ajustes generales sincronizables residen en `/users/{userId}/presupuestos/user_settings` (la lectura de presupuestos debe ignorar este documento con `if (anio == 0 || mes == 0) continue`). Queda estrictamente PROHIBIDO sincronizar, leer o persistir claves API o tokens privados (ej. `gemini_api_key`) en Firestore. La clave BYOK debe residir exclusivamente en el almacenamiento seguro local del dispositivo (`FlutterSecureStorage`) para evitar su exposición en paneles web con persistencia local o descargas sin cifrar.
- **Redacción Obligatoria en Documentos de Auditoría (`docs/*.md`):** Al documentar hallazgos de seguridad o inspeccionar archivos locales ignorados por git (`.env*`, configs locales), NUNCA copiar valores literales de claves o tokens en archivos Markdown versionados (`<REDACTED_KEY>`), evitando bloqueos de GitHub Push Protection (`GH013`).

## 2. Tránsito de Datos con IA y Modo BYOK
- **Tránsito por el Gateway:** Todo escaneo de comprobantes o consulta al asistente transita a través de Cloudflare Workers (`rindemas-gateway`) hacia la API de Google Gemini. El Worker valida el Firebase JWT y aplica límites de tasa (30 rpm). Cloudflare puede registrar metadatos técnicos conforme a sus políticas y configuración de observabilidad; el tratamiento y retención exactos de los cuerpos de solicitud quedan pendientes de confirmación.
- **Tratamiento en Modo Clave Propia (BYOK):** Si el usuario ingresa su propia clave de Google AI Studio, las peticiones continúan enrutándose a través del Cloudflare Worker enviando la cabecera `x-custom-gemini-key`. El tratamiento, revisión o uso de datos para entrenamiento quedan pendientes de confirmación según los términos vigentes aplicables a la cuenta, tipo de clave y servicio.
- **Retención de Datos por Gemini API:** Google Gemini API conserva prompts, contexto enviado (gastos del mes y lista de compras en chat) y respuestas hasta por 55 días conforme a su política oficial de detección de abusos y cumplimiento legal. Cualquier otra afirmación sobre retención o entrenamiento de modelos queda pendiente de confirmación formal contra las fuentes y contratos vigentes.


## 3. Estándares de Comunicación y Microcopy
- **Microcopy Obligatorio al Vincular Google:** En todo diálogo o pantalla que solicite iniciar sesión o vincular cuenta de Google, incluir textualmente:
  > *"Solo usamos tu cuenta de Google para respaldar tus facturas en tu propio espacio privado. Sin bancos ni contraseñas."*
- **Transparencia en Respuestas Públicas:** Enfatizar la ausencia de riesgo bancario (la app nunca solicita claves bancarias, tarjetas ni acceso a SMS). Aclarar con precisión que la app opera de forma local-first con respaldo en la nube en su cuenta privada de Google.

## 4. Frases Prohibidas en Textos Públicos (Landing, Play Store, Respuestas)
Queda terminantemente prohibido utilizar las siguientes afirmaciones en la web, tiendas de apps o comunicaciones oficiales:
1. **"100% local":** Engañosa, dado que existe sincronización opcional con Firestore y procesamiento externo con IA.
2. **"Sin subir a ningún servidor":** Falsa, ya que las fotos de facturas y los textos del asistente transitan por Cloudflare y Google Gemini.
3. **"Efímero" o "No se guarda":** Incorrecta, dado que Google retiene los datos de consultas hasta por 55 días bajo su política de prevención de abusos.
4. **"No se usa para entrenar":** Prohibido afirmarlo hasta contar con verificación documental definitiva sobre el contrato y consola de Google AI Studio del proyecto.

## 5. Notificaciones Push, Broadcast Anónimo y Configuración Remota
- **Difusión Masiva por Temas (FCM Topic Broadcast):** Para enviar avisos o notificaciones masivas sin comprometer el modelo Local-First ni recopilar identificadores de dispositivo, la app suscribe al usuario anónimamente a un tema general (`anuncios_generales`). Queda prohibido almacenar tokens FCM o IDs de instalación en colecciones de usuarios en Firestore para envíos dirigidos.
- **Canales Nativos Independientes de Android (`NotificationChannel`):** Toda notificación local o push DEBE asociarse a un canal nativo específico (`weekend_reminders`, `inactivity_reminders`, `broadcast_announcements`). Esto cumple las directrices de Google Play (Android 13+) y permite al usuario silenciar un tipo de aviso específico sin apagar el resto de la app.
- **Textos y Recordatorios Dinámicos desde Firestore (`/config/recordatorios`):**
  - La regla en `firestore.rules` permite lectura autenticada abierta (`allow read: if request.auth != null; allow write: if false;`).
  - La app consulta esta colección en segundo plano y guarda los textos en `SharedPreferences`.
  - Debe mantenerse siempre un banco de mensajes base local como fallback offline para que la app funcione plenamente sin conexión o si el documento aún no ha sido creado.
