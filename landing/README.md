# Landing Page — Rinde Más 🌐

Sitio web oficial de presentación y captación de usuarios para la aplicación móvil **Rinde Más**.

- **URL de Producción:** [https://rindemas.cesarluis.com](https://rindemas.cesarluis.com)
- **Stack:** [Astro](https://astro.build/) + Tailwind CSS
- **Hosting:** Firebase Hosting (proyecto `gastoscan-ai`)

---

## 🛠️ Desarrollo Local

Desde la carpeta `landing/`:

```powershell
npm install
npm run dev
```

El servidor local estará disponible en `http://localhost:4321`.

---

## 🚀 Compilación y Despliegue en Producción

> **Importante:** Hacer `git push` **NO** actualiza la landing page. Cualquier cambio en esta carpeta requiere compilación estática y despliegue manual a Firebase Hosting.

### 1. Compilar Astro (en la carpeta `landing/`):
```powershell
$env:ASTRO_TELEMETRY_DISABLED="1"; .\node_modules\.bin\astro.cmd build
```

### 2. Desplegar en Firebase Hosting (desde la raíz del proyecto):
```powershell
firebase.cmd deploy --only hosting --non-interactive
```

### 3. Verificar en vivo:
```powershell
curl.exe -s https://rindemas.cesarluis.com
```

---

## 🎨 Lineamientos de Diseño y Copy

- **Paleta oficial:** Amarillo acento (`#FACC15` / `#EAB308`), fondo limpio (`#F8FAFC` / `#FFFFFF`), textos oscuros legibles (`#0F172A` / `#334155`). Prohibido el uso de tonos naranjas.
- **Mockup de la App:** Formato exclusivo de smartphone vertical (~20:9 con bordes redondeados y altavoz).
- **Mensaje central:** Simplicidad radical, presupuesto en Bs y $, escaneo automático con IA sin tutoriales ni configuraciones engorrosas, 100% gratuita.
