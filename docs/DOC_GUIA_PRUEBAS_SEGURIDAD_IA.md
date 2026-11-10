# Guía de pruebas en dispositivo — Seguridad de IA (A1a, B2, C1, C2)

- **Build:** 672
- **Commit:** 87c8da0cff829e35a55e755f2f0c2031f39244dc
- **Run de CI:** 42857112563 (success)
- **Artefacto:** `rindemas-dev-apk` (*Rinde Más Dev*)
- **App oficial de Google Play:** no tocar.

## Requisito previo (hacer antes de empezar)

El Worker debe estar desplegado con el binding D1. Si no, las pruebas 2 a 6 fallarán con
"Servicio de cuotas no disponible".

    cd workers
    npx wrangler deploy

Verificación: `GET /health` del Worker debe responder 200.

## P1 — Gasto manual sin foto NO muestra el aviso de galería
Este es el bug corregido: el aviso salía aunque no hubiera foto.

1. En la pantalla principal, pulsa el botón flotante (`lib/ui/screens/main_screen.dart:565-566`).
2. Elige "Registrar gasto — Escribe los datos de tu compra" (`main_screen.dart:390-391`).
3. Llena comercio y monto, pulsa guardar (`review_expense_screen.dart:2098` o `:2113`).

**Esperado:** el gasto se guarda y NO aparece el diálogo sobre la galería.
**Si aparece el diálogo:** el fix no está en la build.

## P2 — El aviso aparece la primera vez que se guarda una foto
1. Botón flotante → "Escanear factura (IA)" (`main_screen.dart:427`).
2. Escanea un comprobante y espera la extracción.
3. Pulsa guardar.

**Esperado:** antes de guardar aparece el diálogo "Tus comprobantes también se guardan en la
galería" (`review_expense_screen.dart:940-966`), con un solo botón "Entendido".
**Si no aparece:** el flag `aviso_galeria_mostrado` ya estaba marcado; borra los datos de la app y repite.

## P3 — La foto llega al álbum "Rinde Más"
1. Abre la app de Galería del teléfono.
2. Busca el álbum "Rinde Más" (`lib/services/image_service.dart:40`).

**Esperado:** el comprobante de P2 está ahí.

## P4 — El aviso no se repite
1. Escanea y guarda un segundo comprobante.

**Esperado:** no vuelve a salir el diálogo.

## P5 — Con el interruptor apagado no se guarda copia en la galería
1. Pestaña "Más" (`main_screen.dart:610`) → sección "Almacenamiento de fotos".
2. Apaga "Guardar copia en la galería del teléfono" (`lib/ui/screens/more_screen.dart:814-827`).
3. Escanea y guarda un tercer comprobante.
4. Revisa el álbum "Rinde Más".

**Esperado:** el tercer comprobante NO aparece en la galería. Los dos anteriores siguen ahí.

## P6 — Los montos extraídos siguen siendo correctos
1. Escanea un comprobante con varios ítems y total visible.
2. Compara el total y los precios con el papel.

**Esperado:** coinciden. El saneamiento de C2 solo actúa sobre negativos, valores no
numéricos y cifras absurdas; no debe alterar montos normales.

## Qué hacer si algo falla

Anota: prueba, comportamiento observado, y si el error menciona cuota o validación.
Si el mensaje es "No pudimos validar los montos del comprobante", es la validación de
visión (tolerancia 0.50) rechazando la factura: hay que subir la tolerancia, no es un fallo
del dispositivo.
