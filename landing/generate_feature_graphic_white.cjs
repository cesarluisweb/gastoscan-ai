const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const outDir = 'C:/Development/Control de gastos VE/Google Play Assets';
if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

// 1024 x 500 Canvas
// Phone is shifted right and centered vertically with margin
const svgBase = `
<svg width="1024" height="500" viewBox="0 0 1024 500" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF" />
      <stop offset="65%" stop-color="#F8FAFC" />
      <stop offset="100%" stop-color="#F1F5F9" />
    </linearGradient>

    <radialGradient id="phoneGlow" cx="84%" cy="50%" r="48%">
      <stop offset="0%" stop-color="#FACC15" stop-opacity="0.32" />
      <stop offset="55%" stop-color="#FEF08A" stop-opacity="0.10" />
      <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0" />
    </radialGradient>

    <filter id="btnShadow" x="-10%" y="-20%" width="130%" height="160%">
      <feDropShadow dx="0" dy="4" stdDeviation="6" flood-color="#CA8A04" flood-opacity="0.28" />
    </filter>
  </defs>

  <rect width="1024" height="500" fill="url(#bgGrad)" />
  <rect width="1024" height="500" fill="url(#phoneGlow)" />

  <!-- LEFT COLUMN CONTENT (x = 52) -->

  <!-- Tag Pill -->
  <g transform="translate(52, 42)">
    <rect width="216" height="30" rx="15" fill="#0F172A" />
    <circle cx="16" cy="15" r="4.5" fill="#FACC15" />
    <text x="29" y="20" font-family="system-ui, -apple-system, sans-serif" font-size="11" font-weight="800" fill="#FACC15" letter-spacing="0.8">FINANZAS INTELIGENTES VE</text>
  </g>

  <!-- Headline -->
  <g transform="translate(52, 125)">
    <text font-family="system-ui, -apple-system, sans-serif" font-size="44" font-weight="900" fill="#0F172A" letter-spacing="-0.8">
      Control de gastos
    </text>
    
    <g transform="translate(0, 52)">
      <path d="M 2 46 C 70 38, 170 38, 238 43" stroke="#FACC15" stroke-width="6" stroke-linecap="round" fill="none" />
      <text font-family="system-ui, -apple-system, sans-serif" font-size="44" font-weight="900" fill="#0F172A" letter-spacing="-0.8">
        inteligente <tspan fill="#0F172A">en Bs. y $</tspan>
      </text>
    </g>
  </g>

  <!-- Subtitle -->
  <g transform="translate(52, 246)">
    <text font-family="system-ui, -apple-system, sans-serif" font-size="15.5" font-weight="500" fill="#475569" letter-spacing="-0.2">
      Haz rendir tu dinero sin esfuerzo. Nuestra IA organiza tus finanzas
    </text>
    <text y="24" font-family="system-ui, -apple-system, sans-serif" font-size="15.5" font-weight="500" fill="#475569" letter-spacing="-0.2">
      personales en Venezuela por ti.
    </text>
  </g>

  <!-- CTA Button: Negro sobre fondo amarillo (DESIGN.md) -->
  <g transform="translate(52, 305)" filter="url(#btnShadow)">
    <rect width="170" height="42" rx="21" fill="#FACC15" />
    <text x="85" y="26" font-family="system-ui, -apple-system, sans-serif" font-size="14.5" font-weight="800" fill="#000000" text-anchor="middle">
      Descargar gratis
    </text>
  </g>

  <!-- Feature Badges -->
  <g transform="translate(52, 370)">
    <g transform="translate(0, 0)">
      <rect width="180" height="34" rx="10" fill="#0F172A" />
      <text x="90" y="22" font-family="system-ui, -apple-system, sans-serif" font-size="12" font-weight="700" fill="#FFFFFF" text-anchor="middle">
        Facturas con IA
      </text>
    </g>

    <g transform="translate(192, 0)">
      <rect width="180" height="34" rx="10" fill="#0F172A" />
      <text x="90" y="22" font-family="system-ui, -apple-system, sans-serif" font-size="12" font-weight="700" fill="#FFFFFF" text-anchor="middle">
        Tasa Oficial BCV
      </text>
    </g>

    <g transform="translate(0, 42)">
      <rect width="180" height="34" rx="10" fill="#0F172A" />
      <text x="90" y="22" font-family="system-ui, -apple-system, sans-serif" font-size="12" font-weight="700" fill="#FFFFFF" text-anchor="middle">
        Metas de Ahorro
      </text>
    </g>

    <g transform="translate(192, 42)">
      <rect width="180" height="34" rx="10" fill="#0F172A" />
      <text x="90" y="22" font-family="system-ui, -apple-system, sans-serif" font-size="12" font-weight="700" fill="#FFFFFF" text-anchor="middle">
        100% Seguro y Privado
      </text>
    </g>
  </g>

  <!-- Microcopy -->
  <text x="52" y="476" font-family="system-ui, -apple-system, sans-serif" font-size="11.5" font-weight="500" fill="#64748B">
    Sin cuentas bancarias ni contraseñas · Diseñado para la economía real · Hecho en Venezuela
  </text>
</svg>
`;

async function buildFeatureGraphic() {
  const appScreenPath = 'C:/Development/Control de gastos VE/landing/public/app-screen.jpg';

  // Total canvas height is 500. Let's make the phone height 464, leaving 18px top and 18px bottom!
  // Width will be 216px.
  // Phone will sit at left = 754, top = 18. This leaves 54px on the right margin!
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

  const baseSvgBuffer = Buffer.from(svgBase);
  const finalOutput = path.join(outDir, 'grafico_funciones_1024x500.png');

  await sharp(baseSvgBuffer)
    .composite([
      {
        input: assembledPhone,
        left: 750,
        top: 18
      }
    ])
    .png()
    .toFile(finalOutput);

  console.log('SUCCESS: Final adjusted graphic written to:', finalOutput);
}

buildFeatureGraphic().catch(err => {
  console.error(err);
  process.exit(1);
});
