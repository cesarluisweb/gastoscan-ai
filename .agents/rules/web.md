---
trigger: glob
globs: "landing/**, firebase.json"
description: "Estándares de desarrollo web, enrutamiento en Astro, cabeceras de seguridad en Firebase Hosting y paleta de diseño."
---

# Estándares de la Landing Page y Panel Web (Astro + Firebase Hosting)

## 1. Configuración de Hosting y Enrutamiento Multi-Página
- **Enrutamiento Estático en Astro:** Prohibido utilizar reescrituras comodín de SPA (`"rewrites": [{"source": "**", "destination": "/index.html"}]`) en `firebase.json`. Para que subrutas como `/panel`, `/privacidad` o `/eliminar-cuenta` resuelvan limpiamente sus HTML estáticos (`dist/panel/index.html`), `firebase.json` DEBE incluir:
  ```json
  "cleanUrls": true,
  "trailingSlash": false
  ```
- **Prohibición de Binarios APK en Firebase Spark:** En el plan gratuito Spark, Firebase Hosting bloquea ejecutables con error HTTP 400. Queda terminantemente prohibido alojar o compilar archivos `.apk` en `landing/public/` o `landing/dist/`.
- **Redirección de Descargas a BanaHosting:** Las rutas `/rindemas.apk` y `/app-release.apk` en `firebase.json` deben mantenerse configuradas como redirección HTTP 302 hacia el almacenamiento en BanaHosting (`https://cesarluis.com/rindemas/rindemas.apk`).
- **Cabeceras de Seguridad Obligatorias:** Toda configuración de hosting en `firebase.json` DEBE incluir cabeceras estrictas de protección contra clickjacking y ataques MIME:
  - `X-Frame-Options: DENY`
  - `X-Content-Type-Options: nosniff`
  - `X-XSS-Protection: 1; mode=block`
  - `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`
  - `Referrer-Policy: strict-origin-when-cross-origin`
  - `Permissions-Policy: camera=(), microphone=(), geolocation=()`

## 2. Flujo de Despliegue y Publicación
- **Canal Único Autorizado:** GitHub Actions (`build_apk.yml`) es el único canal autorizado de despliegue a producción en Firebase Hosting.
- **Prohibición de Despliegue Local:** Prohibido ejecutar `firebase deploy --only hosting` en local salvo emergencia técnica expresa autorizada por César.
- **Compilación Local de Verificación:** En tareas de la web, compilar localmente con telemetría desactivada (`$env:ASTRO_TELEMETRY_DISABLED="1"; npm run build` en `landing/`) exclusivamente para confirmar que no hay errores de build antes de hacer `git push`.

## 3. Identidad Visual y Paridad con la App Móvil
- **Paleta de Colores Web:** Usar estrictamente la paleta oficial de Rinde Más: amarillo (`#FACC15` / `#EAB308`) para acentos y botones principales, fondos limpios (`#F8FAFC` / `#FFFFFF`) y textos oscuros legibles (`#0F172A` / `#334155`). Prohibido el uso de tonos naranjas.
- **Representación Gráfica (Mockups):** Las vistas previas de la app móvil DEBEN presentarse dentro de un chasis de smartphone vertical (~20:9 con bordes redondeados y notch/cámara). Las capturas del panel web se representan con marco de navegador de escritorio.
- **Paridad de Negocio:** El panel web (`landing/src/pages/panel.astro`) debe mantener paridad matemática exacta con la app móvil: catálogo único de las 8 categorías canónicas de `AppConstants.categorias` y soporte para las 4 divisas (VES, USD, EUR, USDT) con tasas dinámicas.
