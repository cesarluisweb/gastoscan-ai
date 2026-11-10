# Plan B1 — Endurecer las reglas de Firestore

## 0. Situacion actual

`firestore.rules` (15 lineas) concede `read, write` al dueño del documento sin validar
campos, tipos ni tamaños. Un cliente modificado puede escribir campos arbitrarios o
documentos de tamaño desmedido. No hay fuga entre usuarios: la comprobacion de UID es
correcta y se mantiene.

## 1. Inventario de la superficie de escritura (verificado en codigo)

### /users/{uid}/gastos/{uuid}

- Alta/edicion: `lib/data/datasources/remote/firestore_gastos_remote_data_source.dart:38-46`
  usando `GastoFirestoreMapper.toPayload` (`lib/data/models/gasto_firestore_mapper.dart:16-49`).
- Borrado logico: `:49-60` (solo 3 campos con merge: uuid, eliminado_en, actualizado_en).
- El id del documento es el `uuid` del gasto.
- Los items van EMBEBIDOS en el documento como lista, no en subcoleccion.
- Campos posibles (19): uuid, fecha, comercio, moneda, total_original, total_usd,
  total_usdt, total_eur, tasa_cambio, tasa_usdt, tasa_eur, fuente_tasa_cambio,
  fecha_tasa_cambio, categoria, items, creado_en, actualizado_en, eliminado_en, ocr_text.
- Todos los campos de fecha son String en el modelo (`lib/data/models/gasto_model.dart:9,20,23-25`).

### /users/{uid}/presupuestos/{anio_mes}

- `lib/services/sync_service.dart:387-395`, docId con formato YYYY_MM.
- Campos (7): anio, mes, presupuesto_general, meta_ahorro, moneda, categorias, actualizado_en.

### /config/recordatorios

- Lectura autenticada, escritura denegada. Ya correcto, no se toca.

## 2. Borrador de reglas propuestas

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isOwner(uid) {
      return request.auth != null && request.auth.uid == uid;
    }
    function esFechaISO(v) {
      return v is string && v.matches('^\\d{4}-\\d{2}-\\d{2}.*$');
    }
    function esMonto(v) {
      return v is number && v >= 0 && v <= 1000000000;
    }

    match /users/{uid}/gastos/{gastoId} {
      allow read, delete: if isOwner(uid);
      allow create, update: if isOwner(uid)
        && request.resource.data.keys().hasOnly([
          'uuid','fecha','comercio','moneda','total_original','total_usd',
          'total_usdt','total_eur','tasa_cambio','tasa_usdt','tasa_eur',
          'fuente_tasa_cambio','fecha_tasa_cambio','categoria','items',
          'creado_en','actualizado_en','eliminado_en','ocr_text'
        ])
        && request.resource.data.uuid is string
        && request.resource.data.uuid.size() <= 64
        && request.resource.data.uuid == gastoId
        && esFechaISO(request.resource.data.fecha)
        && request.resource.data.comercio is string
        && request.resource.data.comercio.size() <= 200
        && request.resource.data.moneda in ['VES','USD','EUR','USDT']
        && esMonto(request.resource.data.total_original)
        && esMonto(request.resource.data.total_usd)
        && request.resource.data.categoria in ['Alimentacion','Salud','Higiene','Educacion','Hogar','Servicios','Transporte','Ropa','Entretenimiento','Otros']
        && request.resource.data.items is list
        && request.resource.data.items.size() <= 100
        && (!('ocr_text' in request.resource.data)
            || (request.resource.data.ocr_text is string
                && request.resource.data.ocr_text.size() <= 15000));
    }

    match /users/{uid}/presupuestos/{presupuestoId} {
      allow read, delete: if isOwner(uid);
      allow create, update: if isOwner(uid)
        && request.resource.data.keys().hasOnly([
          'anio','mes','presupuesto_general','meta_ahorro','moneda','categorias','actualizado_en'
        ])
        && request.resource.data.anio is int
        && request.resource.data.mes is int
        && request.resource.data.mes >= 1
        && request.resource.data.mes <= 12
        && request.resource.data.presupuesto_general is number
        && request.resource.data.meta_ahorro is number
        && request.resource.data.moneda in ['VES','USD','EUR','USDT'];
    }

    match /config/recordatorios {
      allow read: if request.auth != null;
      allow write: if false;
    }
  }
}
```

NOTA: la lista de categorias del bloque de arriba esta sin acentos a proposito en el
borrador; al aplicarla hay que copiarla EXACTAMENTE desde AppConstants.categorias
(lib/core/constants/app_constants.dart) para no rechazar escrituras validas.

## 3. Limitaciones conocidas (no se pueden cerrar con reglas)

1. El contenido de cada item NO se puede validar: las reglas no recorren listas.
Se valida que items sea lista y su tamaño maximo, no sus campos internos.
2. categorias del presupuesto es un Map de forma variable: queda sin validar hasta
que se fije su contrato.
3. El tamaño maximo real de un documento lo impone Firestore (1 MiB); estas reglas
acotan los campos grandes (ocr_text) pero no lo sustituyen.

## 4. Prerrequisitos ANTES de aplicar las reglas

1. Cortar el despliegue automatico de reglas. Hecho: deploy_web.yml ya no publica
firestore:rules. Ahora vive en .github/workflows/deploy_rules.yml, que solo se
ejecuta a mano (workflow_dispatch) y exige escribir DEPLOY como confirmacion.
2. Verificar datos existentes en produccion (solo lectura): confirmar que ningun
documento antiguo tiene campos fuera de la lista blanca ni un uuid distinto del id
del documento. Si los hay, hay que migrarlos o ampliar la lista.
3. Fijar el contrato de categorias en presupuestos o aceptar el hueco por escrito.

## 5. Matriz de pruebas con el emulador

Herramienta: @firebase/rules-unit-testing + Firebase Emulator Suite.

Casos obligatorios:
 1. Dueño crea un gasto valido -> permitido.
 2. Otro uid intenta escribirlo -> denegado.
 3. Sin autenticacion -> denegado.
 4. Campo extra no listado -> denegado.
 5. total_usd como texto -> denegado.
 6. total_original negativo -> denegado.
 7. ocr_text de 15.001 caracteres -> denegado; 15.000 -> permitido.
 8. items con 101 elementos -> denegado.
 9. Borrado logico (3 campos, merge) -> permitido.
10. uuid distinto del id del documento -> denegado.
11. Presupuesto valido -> permitido; mes = 13 -> denegado.
12. Lectura de /config/recordatorios autenticado -> permitido; escritura -> denegado.

## 6. Riesgos, mitigacion y rollback

- Riesgo principal: rechazar escrituras legitimas y romper la sincronizacion en silencio.
- Mitigacion: emulador primero; despues una ventana controlada con un usuario real
creando un gasto, borrandolo y sincronizando un presupuesto.
- Rollback: guardar copia del firestore.rules actual antes de desplegar. Revertir es
firebase deploy --only firestore:rules con la copia. Las reglas no modifican datos
existentes: solo afectan a escrituras nuevas.
- Ventana recomendada: fuera del horario de uso, con el usuario presente.

## 7. Criterios de aceptacion

1. Los 12 casos del emulador en verde.
2. Un ciclo real completo: crear gasto, verlo en Firestore, borrarlo (tombstone),
sincronizar un presupuesto y recuperarlos tras reinstalar.
3. Rollback probado al menos una vez en un proyecto de pruebas.
4. deploy_web.yml ya no publica reglas automaticamente.
