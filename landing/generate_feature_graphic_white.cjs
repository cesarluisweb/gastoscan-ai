const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const outDir = 'C:/Development/Control de gastos VE/Google Play Assets';
if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

// 1024 x 500 Canvas
// Minimalist, high-converting layout:
// Top: Logo image + "Rinde Más" brand name
// Main Title: "Control de gastos inteligente en Bs. y $" (with yellow curved stroke right under "inteligente")
// Subtitle: "Haz rendir tu dinero sin esfuerzo. Nuestra IA organiza tus finanzas personales en Venezuela por ti."
// CTA Button: "Descargar gratis" (Yellow background with black text)
// Right: Clean smartphone mockup

const svgBase = `
<svg width="1024" height="500" viewBox="0 0 1024 500" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF" />
      <stop offset="65%" stop-color="#F8FAFC" />
      <stop offset="100%" stop-color="#F1F5F9" />
    </linearGradient>

    <radialGradient id="phoneGlow" cx="84%" cy="50%" r="48%">
      <stop offset="0%" stop-color="#FACC15" stop-opacity="0.30" />
      <stop offset="55%" stop-color="#FEF08A" stop-opacity="0.10" />
      <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0" />
    </radialGradient>

    <filter id="btnShadow" x="-10%" y="-20%" width="130%" height="160%">
      <feDropShadow dx="0" dy="4" stdDeviation="6" flood-color="#CA8A04" flood-opacity="0.25" />
    </filter>

    <filter id="logoShadow" x="-10%" y="-10%" width="125%" height="125%">
      <feDropShadow dx="0" dy="2" stdDeviation="3" flood-color="#0F172A" flood-opacity="0.12" />
    </filter>
  </defs>

  <rect width="1024" height="500" fill="url(#bgGrad)" />
  <rect width="1024" height="500" fill="url(#phoneGlow)" />

  <!-- LEFT COLUMN CONTENT (x = 58) -->

  <!-- 1. Brand Row: Logo (composited by sharp at left=58, top=58) + Brand Text -->
  <g transform="translate(108, 86)">
    <text font-family="system-ui, -apple-system, sans-serif" font-size="23" font-weight="900" fill="#0F172A" letter-spacing="-0.4">
      Rinde Más
    </text>
  </g>

  <!-- 2. Headline: Clean, large, with exact underline under 'inteligente' -->
  <g transform="translate(58, 168)">
    <text font-family="system-ui, -apple-system, sans-serif" font-size="46" font-weight="900" fill="#0F172A" letter-spacing="-1">
      Control de gastos
    </text>
    
    <g transform="translate(0, 56)">
      <!-- Yellow curved accent stroke exactly under 'inteligente' (starts at x=2, width ~232, y=6) -->
      <path d="M 3 8 C 65 -1, 165 -1, 235 6" stroke="#FACC15" stroke-width="6" stroke-linecap="round" fill="none" />
      <text font-family="system-ui, -apple-system, sans-serif" font-size="46" font-weight="900" fill="#0F172A" letter-spacing="-1">
        inteligente <tspan fill="#0F172A">en Bs. y $</tspan>
      </text>
    </g>
  </g>

  <!-- 3. Subtitle / Value proposition -->
  <g transform="translate(58, 310)">
    <text font-family="system-ui, -apple-system, sans-serif" font-size="16.5" font-weight="500" fill="#475569" letter-spacing="-0.2">
      Haz rendir tu dinero sin esfuerzo. Nuestra IA organiza tus finanzas
    </text>
    <text y="26" font-family="system-ui, -apple-system, sans-serif" font-size="16.5" font-weight="500" fill="#475569" letter-spacing="-0.2">
      personales en Venezuela por ti.
    </text>
  </g>

  <!-- 4. CTA Pill Button: 'Descargar gratis' (DESIGN.md: Amarillo con texto NEGRO) -->
  <g transform="translate(58, 384)" filter="url(#btnShadow)">
    <rect width="186" height="46" rx="23" fill="#FACC15" />
    <text x="93" y="28" font-family="system-ui, -apple-system, sans-serif" font-size="15.5" font-weight="800" fill="#000000" text-anchor="middle">
      Descargar gratis
    </text>
  </g>
</svg>
`;

async function buildFeatureGraphic() {
  const appScreenPath = 'C:/Development/Control de gastos VE/landing/public/app-screen.jpg';
  const logoPath = 'C:/Development/Control de gastos VE/landing/public/logo.jpg';

  // 1. Process Logo (40x40 rounded)
  const logoSize = 40;
  const logoResized = await sharp(logoPath).resize(logoSize, logoSize).toBuffer();
  const logoMask = Buffer.from(`
    <svg width="${logoSize}" height="${logoSize}">
      <rect width="${logoSize}" height="${logoSize}" rx="10" ry="10" fill="#FFF" />
    </svg>
  `);
  const logoRounded = await sharp(logoResized)
    .composite([{ input: logoMask, blend: 'dest-in' }])
    .png()
    .toBuffer();

  // 2. Process Smartphone Frame
  const phoneWidth = 216;
  const phoneHeight = 464;
  const screenWidth = 202;
  const screenHeight = 450;

  const screenResized = await sharp(appScreenPath)
    .resize(screenWidth, screenHeight, { fit: 'cover', position: 'top' })
    .toBuffer();

  const screenMask = Buffer.from(`
    <svg width="${screenWidth}" height="${screenHeight}">
      <rect width="${screenWidth}" height="${screenHeight}" rx="28" ry="28" fill="#FFF" />
    </svg>
  `);

  const screenRounded = await sharp(screenResized)
    .composite([{ input: screenMask, blend: 'dest-in' }])
    .png()
    .toBuffer();

  const phoneFrameSvg = Buffer.from(`
    <svg width="${phoneWidth}" height="${phoneHeight}" viewBox="0 0 ${phoneWidth} ${phoneHeight}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <filter id="chassisShadow" x="-20%" y="-20%" width="150%" height="150%">
          <feDropShadow dx="-3" dy="12" stdDeviation="16" flood-color="#0F172A" flood-opacity="0.32" />
          <feDropShadow dx="0" dy="2" stdDeviation="4" flood-color="#0F172A" flood-opacity="0.15" />
        </filter>
      </defs>
      <rect x="0" y="0" width="${phoneWidth}" height="${phoneHeight}" rx="34" ry="34" fill="#0F172A" filter="url(#chassisShadow)" />
      <rect x="2" y="2" width="${phoneWidth - 4}" height="${phoneHeight - 4}" rx="32" ry="32" fill="#1E293B" />
      <rect x="5" y="5" width="${phoneWidth - 10}" height="${phoneHeight - 10}" rx="29" ry="29" fill="#000000" />
    </svg>
  `);

  const islandOverlay = Buffer.from(`
    <svg width="${screenWidth}" height="32" viewBox="0 0 ${screenWidth} 32" xmlns="http://www.w3.org/2000/svg">
      <rect x="${(screenWidth - 58) / 2}" y="7" width="58" height="14" rx="7" fill="#000000" />
      <circle cx="${(screenWidth - 58) / 2 + 45}" cy="14" r="3" fill="#111827" />
    </svg>
  `);

  const assembledPhone = await sharp(phoneFrameSvg)
    .composite([
      { input: screenRounded, left: 7, top: 7 },
      { input: islandOverlay, left: 7, top: 7 }
    ])
    .png()
    .toBuffer();

  // 3. Composite everything onto canvas
  const baseSvgBuffer = Buffer.from(svgBase);
  const finalOutput = path.join(outDir, 'grafico_funciones_1024x500.png');

  await sharp(baseSvgBuffer)
    .composite([
      {
        input: logoRounded,
        left: 58,
        top: 58
      },
      {
        input: assembledPhone,
        left: 750,
        top: 18
      }
    ])
    .png()
    .toFile(finalOutput);

  console.log('SUCCESS: Clean Minimalist Feature Graphic generated at:', finalOutput);
}

buildFeatureGraphic().catch(err => {
  console.error(err);
  process.exit(1);
});
