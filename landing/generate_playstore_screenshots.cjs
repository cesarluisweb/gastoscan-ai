const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const outDir = 'C:/Development/Control de gastos VE/Google Play Assets/screenshots';
if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

// Screenshot Dimensions: 1080 x 2280 px (Standard high-res Android 19:9 ratio)
const CANVAS_W = 1080;
const CANVAS_H = 2280;

// Phone Mockup Dimensions:
const PHONE_W = 860;
const PHONE_H = 1680;
const PHONE_LEFT = Math.round((CANVAS_W - PHONE_W) / 2); // 110 px centered
const PHONE_TOP = 520; // leaves 520px at the top for clean, large titles!

const SCREEN_W = 824;
const SCREEN_H = 1644;

const screenshots = [
  {
    id: 1,
    file: 'C:/Development/Control de gastos VE/Capturas para Google Play/WhatsApp Image 2026-10-13 at 10.12.10 AM (5).jpeg',
    tag: 'CONTROL TOTAL',
    title: 'Toma el control',
    highlight: 'de tu dinero',
    subtitle: 'Administra tus gastos en USD y bolívares en tiempo real'
  },
  {
    id: 2,
    file: 'C:/Development/Control de gastos VE/Capturas para Google Play/WhatsApp Image 2026-10-13 at 10.12.10 AM (4).jpeg',
    tag: 'REGISTRO INTELIGENTE',
    title: 'Tus compras del día',
    highlight: 'organizadas',
    subtitle: 'Consulta el desglose y montos convertidos a tasa oficial'
  },
  {
    id: 3,
    file: 'C:/Development/Control de gastos VE/Capturas para Google Play/WhatsApp Image 2026-10-13 at 10.12.10 AM (3).jpeg',
    tag: 'FINANZAS Y METAS',
    title: 'Protege tu meta',
    highlight: 'de ahorro',
    subtitle: 'Semáforo de ritmo diario y presupuesto mensual por categorías'
  },
  {
    id: 4,
    file: 'C:/Development/Control de gastos VE/Capturas para Google Play/WhatsApp Image 2026-10-13 at 10.12.10 AM (1).jpeg',
    tag: 'ASISTENTE CON IA',
    title: 'Consulta inteligente',
    highlight: 'en lenguaje natural',
    subtitle: 'Pregúntale al asistente cuánto has gastado y cómo va tu meta'
  },
  {
    id: 5,
    file: 'C:/Development/Control de gastos VE/Capturas para Google Play/WhatsApp Image 2026-10-13 at 10.12.10 AM (2).jpeg',
    tag: 'SEGURIDAD Y PRIVACIDAD',
    title: 'Respaldo seguro',
    highlight: 'en la nube',
    subtitle: 'Tus datos siempre a salvo, sin bancos ni contraseñas'
  }
];

function generateHeaderSvg(item) {
  return `
  <svg width="${CANVAS_W}" height="${CANVAS_H}" viewBox="0 0 ${CANVAS_W} ${CANVAS_H}" xmlns="http://www.w3.org/2000/svg">
    <defs>
      <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#FFFFFF" />
        <stop offset="60%" stop-color="#F8FAFC" />
        <stop offset="100%" stop-color="#F1F5F9" />
      </linearGradient>
      <radialGradient id="haloGlow" cx="50%" cy="40%" r="55%">
        <stop offset="0%" stop-color="#FACC15" stop-opacity="0.25" />
        <stop offset="60%" stop-color="#FEF08A" stop-opacity="0.08" />
        <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0" />
      </radialGradient>
      <filter id="phoneShadow" x="-20%" y="-10%" width="140%" height="130%">
        <feDropShadow dx="0" dy="28" stdDeviation="32" flood-color="#0F172A" flood-opacity="0.22" />
        <feDropShadow dx="0" dy="6" stdDeviation="12" flood-color="#0F172A" flood-opacity="0.10" />
      </filter>
    </defs>

    <!-- Canvas Background -->
    <rect width="${CANVAS_W}" height="${CANVAS_H}" fill="url(#bgGrad)" />
    <rect width="${CANVAS_W}" height="${CANVAS_H}" fill="url(#haloGlow)" />

    <!-- Top Badge / Pill -->
    <g transform="translate(${CANVAS_W / 2}, 110)">
      <rect x="-140" y="0" width="280" height="42" rx="21" fill="#0F172A" />
      <circle cx="-112" cy="21" r="5" fill="#FACC15" />
      <text x="-95" y="27" font-family="system-ui, -apple-system, sans-serif" font-size="14.5" font-weight="800" fill="#FACC15" letter-spacing="1">${item.tag}</text>
    </g>

    <!-- Main Title -->
    <text x="${CANVAS_W / 2}" y="235" font-family="system-ui, -apple-system, sans-serif" font-size="64" font-weight="900" fill="#0F172A" text-anchor="middle" letter-spacing="-1.5">
      ${item.title}
    </text>

    <!-- Highlighted second line with accent underline -->
    <g transform="translate(${CANVAS_W / 2}, 310)">
      <text font-family="system-ui, -apple-system, sans-serif" font-size="64" font-weight="900" fill="#0F172A" text-anchor="middle" letter-spacing="-1.5">
        ${item.highlight}
      </text>
    </g>

    <!-- Subtitle -->
    <text x="${CANVAS_W / 2}" y="405" font-family="system-ui, -apple-system, sans-serif" font-size="25" font-weight="500" fill="#475569" text-anchor="middle" letter-spacing="-0.3">
      ${item.subtitle}
    </text>
  </svg>
  `;
}

async function buildScreenshots() {
  // Screen rounded mask
  const screenMask = Buffer.from(`
    <svg width="${SCREEN_W}" height="${SCREEN_H}">
      <rect width="${SCREEN_W}" height="${SCREEN_H}" rx="54" ry="54" fill="#FFF" />
    </svg>
  `);

  // Phone chassis SVG
  const chassisSvg = Buffer.from(`
    <svg width="${PHONE_W}" height="${PHONE_H}" viewBox="0 0 ${PHONE_W} ${PHONE_H}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <filter id="chassisShadow" x="-15%" y="-10%" width="130%" height="130%">
          <feDropShadow dx="0" dy="24" stdDeviation="30" flood-color="#0F172A" flood-opacity="0.25" />
        </filter>
      </defs>
      <!-- Outer body -->
      <rect x="0" y="0" width="${PHONE_W}" height="${PHONE_H}" rx="68" ry="68" fill="#0F172A" filter="url(#chassisShadow)" />
      <!-- Bezel ring -->
      <rect x="4" y="4" width="${PHONE_W - 8}" height="${PHONE_H - 8}" rx="64" ry="64" fill="#1E293B" />
      <rect x="14" y="14" width="${PHONE_W - 28}" height="${PHONE_H - 28}" rx="58" ry="58" fill="#000000" />
    </svg>
  `);

  // Camera punch hole / Dynamic Island
  const islandSvg = Buffer.from(`
    <svg width="${SCREEN_W}" height="60" viewBox="0 0 ${SCREEN_W} 60" xmlns="http://www.w3.org/2000/svg">
      <rect x="${(SCREEN_W - 140) / 2}" y="14" width="140" height="32" rx="16" fill="#000000" />
      <circle cx="${(SCREEN_W - 140) / 2 + 110}" cy="30" r="6" fill="#111827" />
    </svg>
  `);

  for (const item of screenshots) {
    console.log(`Processing Screenshot ${item.id}: ${item.tag}...`);

    // Clean original screenshot (crop status bar at top y:48 and nav bar at bottom y:1230)
    // Original image: 576 x 1280
    // Crop area: top=46, height=1190
    const rawImage = sharp(item.file);
    const croppedBuffer = await rawImage
      .extract({ left: 0, top: 46, width: 576, height: 1190 })
      .resize(SCREEN_W, SCREEN_H, { fit: 'cover', position: 'top' })
      .toBuffer();

    const roundedScreen = await sharp(croppedBuffer)
      .composite([{ input: screenMask, blend: 'dest-in' }])
      .png()
      .toBuffer();

    const assembledPhone = await sharp(chassisSvg)
      .composite([
        { input: roundedScreen, left: 18, top: 18 },
        { input: islandSvg, left: 18, top: 18 }
      ])
      .png()
      .toBuffer();

    const headerSvgBuffer = Buffer.from(generateHeaderSvg(item));

    const finalScreenshot = await sharp(headerSvgBuffer)
      .composite([
        {
          input: assembledPhone,
          left: PHONE_LEFT,
          top: PHONE_TOP
        }
      ])
      .png()
      .toFile(path.join(outDir, `screenshot_${item.id}_${item.tag.toLowerCase().replace(/[^a-z0-9]/g, '_')}.png`));

    console.log(`Created: screenshot_${item.id}.png`);
  }

  console.log('ALL PLAY STORE SCREENSHOTS SUCCESSFULLY GENERATED!');
}

buildScreenshots().catch(err => {
  console.error('Error generating screenshots:', err);
  process.exit(1);
});
