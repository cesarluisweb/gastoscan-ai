# Documentación Técnica: Sincronización y Respaldo de Presupuestos en la Nube

## 1. Diagnóstico del Problema
Al vincular una cuenta de Google en la app móvil o acceder tras una reinstalación, los gastos históricos se restauraban correctamente pero el **presupuesto mensual y la meta de ahorro aparecían en $0**, obligando al usuario a reconfigurarlos manualmente.

### Causas Raíz Identificadas:
1. **Reglas de Seguridad de Firestore no desplegadas en CI/CD:**
   El pipeline de GitHub Actions (`.github/workflows/build_apk.yml`) ejecutaba `firebase deploy --only hosting`. Aunque el archivo local `firestore.rules` definía permisos para `/users/{userId}/presupuestos/{document=**}`, estas reglas nunca se subieron a Firebase. En producción, Firestore denegaba el acceso (`PERMISSION_DENIED`) en silencio.
2. **Adopción de Presupuesto Rígida a 1 Mes:**
   En `GastoProvider.cargarDatos()`, si el mes actual no tenía presupuesto, el sistema únicamente consultaba el mes inmediatamente anterior (`mes - 1`). Si el presupuesto se había definido hace 2 meses (o hubo un mes sin gastos registrados que consolidaran la fila en SQLite), el mes actual ignoraba el historial y arrojaba $0.
3. **Excepción de Tipos en Deserialización Dart (`TypeError`):**
   En `SyncService.syncPresupuestosFromFirestore`, `data['categorias']` se casteaba como `Map<String, dynamic>`. En plataformas móviles, Firestore puede retornar mapas anidados como `Map<dynamic, dynamic>`, lo que provocaba un fallo no controlado que abortaba la sincronización.
4. **Falta de Aislamiento de Errores en `syncBidirectional()`:**
   La sincronización de gastos, presupuestos y ajustes de usuario se ejecutaba en un único bloque `try-catch`. Cualquier demora o fallo en gastos abortaba el procesamiento de presupuestos.
5. **Falta de Herencia de Presupuesto en el Panel Web (`panel.astro`):**
   Al consultar un mes sin presupuesto propio en el panel web, `currentPresupuesto` se reseteaba a ceros sin buscar el último presupuesto previo del usuario en Firestore.

---

## 2. Modificaciones Implementadas

### A. CI/CD (`.github/workflows/build_apk.yml`)
- Se actualizó el paso de despliegue para publicar tanto hosting como las reglas de Firestore:
  ```yaml
  npx firebase-tools deploy --only hosting,firestore:rules --project gastoscan-ai --token "${{ secrets.FIREBASE_SERVICE_ACCOUNT_GATOSCAN_AI }}" --non-interactive
  ```

### B. SQLite y Repositorio (`DatabaseHelper` y `GastoRepository`)
- Se implementó `getUltimoPresupuestoConfigurado({int? antesDeAnio, int? antesDeMes, bool estrictamenteAnterior})`:
  - Consulta `presupuestos_mensuales` filtrando por meses anteriores al mes consultado, ordenando por `anio DESC, mes DESC` con límite 1.
  - Si encuentra un registro histórico con `presupuesto_general > 0` o `meta_ahorro > 0`, extrae sus categorías y moneda asociada.
  - Si solo existen categorías configuradas en `presupuestos_categorias_mensuales`, las recupera de igual forma.
- Se expuso la llamada correspondiente en `GastoRepository.obtenerUltimoPresupuestoConfigurado()`.

### C. Proveedor de Estado (`GastoProvider`)
- En `cargarDatos()`, al detectar que el mes consultado no posee presupuesto propio:
  - Se invoca `obtenerUltimoPresupuestoConfigurado(antesDeAnio: _selectedYear, antesDeMes: _selectedMonth, estrictamenteAnterior: true)`.
  - Si existe un presupuesto en cualquier mes previo del historial (hace 1, 3 o 6 meses), se adopta en memoria (`_presupuestoEsAdoptado = true`), preservando la regla de no escribir filas fantasmas en SQLite hasta que el usuario registre un gasto o edite el presupuesto.

### D. Servicio de Sincronización (`SyncService`)
- **Aislamiento por Dominios:** En `syncBidirectional()`, la sincronización de gastos, presupuestos y clave de Gemini operan en bloques `try-catch` independientes.
- **Casteo Seguro:** En `syncPresupuestosToFirestore()` y `syncPresupuestosFromFirestore()`, la lectura y conversión de `categorias` se realiza iterando sobre `Map` genérico con claves en `String`, evitando `TypeError`.
- **Soporte de Metas de Ahorro Puras:** Se permite la sincronización de presupuestos que tengan `metaAhorro > 0` incluso si `general <= 0`.
- **Captura y Registro Defensivo:** Ambos métodos capturan `FirebaseException` u otros errores registrando el fallo sin tumbar el hilo principal.

### E. Panel Web (`landing/src/pages/panel.astro`)
- Al cargar los datos del mes en `loadDashboardData()`, si el documento `users/{uid}/presupuestos/{anio}_{mes}` no existe:
  - Se consultan los documentos de la colección `presupuestos`.
  - Se descarta `user_settings`.
  - Se filtran los documentos con `anio < selectedYear` o `(anio === selectedYear && mes < selectedMonth)`.
  - Se selecciona el registro más reciente y se adopta en `currentPresupuesto`, logrando paridad idéntica con la app móvil.

---

## 3. Protocolo de Pruebas y Validación para César

1. **Prueba de Persistencia en Móvil con Cuenta de Google:**
   - Abre la app e inicia sesión con tu cuenta de Google (o vincula desde "Más" -> "Vincular con Google").
   - Configura un presupuesto mensual (ej. $250) y una meta de ahorro (ej. $50) para el mes en curso.
   - Cierra sesión o limpia el almacenamiento de la app (o instala un nuevo build limpio).
   - Inicia sesión nuevamente con la misma cuenta de Google.
   - **Resultado Esperado:** Al terminar la carga, la tarjeta `SummaryCard` en Inicio debe mostrar inmediatamente el límite de $200 para gastar y la meta de ahorro de $50 sin requerir ingresar los datos nuevamente.

2. **Prueba de Continuidad Histórica (Meses con Brecha):**
   - Configura un presupuesto en un mes anterior (ej. retrocediendo 2 o 3 meses en el selector).
   - Avanza al mes actual donde nunca se había registrado presupuesto.
   - **Resultado Esperado:** El mes actual debe adoptar automáticamente el presupuesto y meta del mes previo del historial.

3. **Prueba en Panel Web (`https://rindemas.cesarluis.com/panel`):**
   - Inicia sesión con la misma cuenta de Google en el panel web.
   - Selecciona el mes en curso o un mes posterior.
   - **Resultado Esperado:** La tarjeta de presupuesto debe reflejar el presupuesto adoptado o configurado en el móvil.
