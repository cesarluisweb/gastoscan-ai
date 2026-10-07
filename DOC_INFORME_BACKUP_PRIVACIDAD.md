# Análisis de Arquitectura: Almacenamiento, Backup y Privacidad

El usuario ha planteado una preocupación válida: *Quiere que los datos estén en su propio Drive para tener control sobre ellos.* 
Analizamos las opciones disponibles y su impacto en la privacidad, complejidad y control del usuario.

## Comparativa de Opciones

### Opción A — Firestore actual
* **Flujo:** SQLite Local -> Sincronización Firestore bajo `uid`.
* **Privacidad:** Media. Los datos están aislados por `uid` y protegidos por Security Rules, pero residen físicamente en infraestructura de Google/Firebase. Firebase también maneja tokens y metadatos de acceso.
* **Control:** El usuario depende de Rinde Más para acceder a sus datos en la nube.
* **Complejidad:** Ya implementada.

### Opción B — Google Drive del usuario (100% nativo)
* **Flujo:** App -> API Drive del usuario.
* **Privacidad:** Paradójicamente, la privacidad **disminuye** frente a Google. Solicitar el scope `https://www.googleapis.com/auth/drive.file` obliga al usuario a pasar por una advertencia severa de Google ("Esta aplicación no verificada quiere acceder a tus archivos"). Google sigue analizando los metadatos.
* **Control:** Alto. El usuario ve sus archivos en Drive.
* **Complejidad:** Alta. Requiere auditorías formales y costosas (CASA Tier 2) para publicar en Google Play si se usan scopes restringidos de Drive. Sincronización conflictiva (conflictos de versiones, conexión).

### Opción C — Híbrida (Operativos en Firestore + Backup en Drive)
* **Flujo:** Operación normal con Firestore, exportación a Drive bajo demanda.
* **Privacidad / Control:** Igual a la Opción B, requiere los mismos permisos invasivos de Google y auditoría costosa.

### Opción D — Backup Local Portable / Exportación Cifrada (RECOMENDADA)
* **Flujo:** App empaqueta SQLite + Imágenes -> Archivo comprimido (`.rindemas` o `.zip`) -> El usuario usa "Compartir" de Android para guardarlo donde prefiera (Drive, Telegram, Pendrive, Email).
* **Privacidad:** **Máxima.** Rinde Más no solicita permisos invasivos ni envía el archivo a servidores propios. El usuario decide su destino.
* **Control:** Absoluto. Cero "vendor lock-in". Puede guardar sus comprobantes e historial eternamente.
* **Complejidad:** Baja. No requiere auditorías de Google.
* **Offline:** 100% funcional sin internet.

## Diseño de la Solución (Opción D)

Para cumplir la expectativa de privacidad extrema (el usuario no quiere depender obligatoriamente de Rinde Más), la implementación deberá:

1. **Estructura del Backup (`backup_YYYYMMDD.zip`):**
   - `rindemas.sqlite` (Base de datos completa con gastos, configuraciones, presupuestos e historial OCR).
   - Carpeta `/comprobantes/` (Contiene todos los archivos físicos referenciados en `rutaFotoLocal`).
2. **Restauración:**
   - La app permitirá seleccionar el archivo `.zip`.
   - Limpiará la base de datos actual y reemplazará todo el contenido local y las imágenes con las del backup.
3. **Flujo Cero Fricción:**
   - El backup local no debe forzar cifrado obligatorio para no dificultar la recuperación futura si el usuario olvida la clave, pero podría ofrecerse como opción.
   - En la sección "Privacidad" de la app, destacar: *"Descarga una copia completa de tu información, incluyendo fotos. Guárdala donde quieras."*

## Conclusión

El paradigma más privado no es integrar Google Drive en el código de Rinde Más (lo que expone la app a políticas de Google y asusta al usuario con pantallas de permisos), sino **darle al usuario un archivo portable y dejar que él use la app nativa de Drive/Archivos de su teléfono para guardarlo**.

Recomendamos proceder exclusivamente con la **Opción D**.
