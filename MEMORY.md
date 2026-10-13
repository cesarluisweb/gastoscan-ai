# MEMORIA DE TRABAJO (Rinde Más)
> Regla de oro: Mantener en máximo ~50 líneas. Lo permanente se gradúa a AGENTS.md o DESIGN.md.

## Estado Actual Inmediato
- **Rama:** `main`.
- **Fase activa:** Finalizada corrección integral del flujo de eliminación de datos y cuenta.
- **Últimos hitos:** 
  1. **Eliminación Segura de Cuenta y Datos (Remota y Local):** `eliminarCuentaYDatos()` en `SyncService` no silencia fallos remotos de Firestore ni Firebase Auth. Si la operación remota crítica falla (red o reautenticación), se preserva la base local y se notifica el error.
  2. **Inclusión de Usuarios Anónimos:** Limpieza remota en Firestore y eliminación de usuario Auth aplicada por igual a anónimos y registrados.
  3. **Limpieza Selectiva de Storage y Archivos:** Borrado específico de claves de Rinde Más en `FlutterSecureStorage` (`AppConstants.prefApiKey`) sin usar `deleteAll()`. `ImageService.limpiarArchivosApp()` purga comprobantes y temporales propios (`recibo_*.jpg`, directorios internos) protegiendo fotos y exportaciones del usuario.
  4. **Exclusión de `ruta_foto_local` en Firestore:** `GastoModel.toFirestoreMap()` excluye la ruta física del teléfono enviando solo datos semánticos, mientras `toMap()` preserva el campo para SQLite.
  5. **Manejo de UI y Reautenticación en `more_screen.dart`:** Éxito mostrado únicamente si la operación concluyó sin fallos; gestión de `requires-recent-login` con flujo de reautenticación Google.
  6. **Pruebas Automatizadas y CI 100% Verde:** Suite unitaria `sync_service_delete_account_test.dart` y widget tests en `more_screen_test.dart` validados exitosamente en GitHub Actions (run 38465349237, conclusión `success`).

## Decisiones Técnicas y de Negocio Recientes
- **Orden de Eliminación Transaccional:** 1. Purgar Firestore (colección gastos y presupuestos), 2. Eliminar cuenta en Firebase Auth (o reautenticar si expira token), 3. Limpiar SQLite local y archivos de comprobantes, 4. Limpiar credenciales específicas en secure storage, 5. Reiniciar sesión anónima fresca. Si paso 1 o 2 falla, la base local queda intacta.
- **Exclusión de Rutas Locales en Firestore:** Firestore nunca debe almacenar rutas del sistema de archivos local (`/data/user/0/...`). Usar `toFirestoreMap()` para la nube y `toMap()` para SQLite.
- **Limpieza Específica de Claves Seguras:** Solo borrar `AppConstants.prefApiKey` en `FlutterSecureStorage` para no colisionar con otros plugins.
- **Aislamiento de Tests con Inyección de Usuario:** `MoreScreen` soporta `customUser` y `customUserStream` para pruebas deterministas sin backend simulado.

## Errores y Fricciones a Evitar
- No borrar datos locales antes de asegurar que la purga remota crítica fue exitosa.
- Prohibido `deleteAll()` ciego en `FlutterSecureStorage`.
- En UI, no asumir éxito de `eliminarCuentaYDatos()` sin evaluar el valor devuelto.
- No usar `>` en PowerShell ni `&&` en PowerShell 5.1.
- Contraste estricto en UI (`DESIGN.md`): Texto sobre amarillo SIEMPRE negro; texto sobre blanco SIEMPRE negro o gris, NUNCA amarillo.

## Próximo Paso Inmediato
- Esperar retroalimentación de César tras la revisión de los cambios de eliminación de cuenta.
