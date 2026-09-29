# Guía de Estilo y Sistema de Diseño — Rinde Más

Este documento define la identidad visual, el uso del color y los componentes de la aplicación.

---

## 1. Identidad de Marca (Colores Principales)

La identidad de **Rinde Más** se basa estrictamente en tres tonos principales:

| Rol | Color | Código Hex | Uso |
|---|---|---|---|
| **Acento de Marca** | Amarillo | `#FEF08A` (`primary`) / `#FACC15` (`primaryDark`) | Botón flotante central (+), iconos de acción, barras de progreso y fondos de acento. |
| **Superficie y Fondo** | Blanco / Gris Neutro | `#FFFFFF` (`surface`) / `#F9FAFB` (`background`) | Fondo de pantalla, tarjetas modales y contenedores. |
| **Texto y Estructura** | Negro / Gris Carbón | `#111827` (`textPrimary`) / `#0F172A` (`secondary`) | Títulos, montos principales, botones oscuros y textos legibles. |

> **Regla estricta:** Queda prohibido el uso de amarillo en textos regulares. Todo texto sobre fondo blanco o gris debe ser negro/oscuro (`#111827`). Todo texto sobre fondo amarillo debe ser explícitamente negro.

---

## 2. Colores Funcionales o Semánticos (Estados)

Son los colores técnicos que indican el estado de las finanzas y el sistema. No son colores de la marca, sino indicadores universales:

| Estado | Color | Código Hex | Uso |
|---|---|---|---|
| **Positivo / Disponible** | Verde | `#10B981` | Saldo a favor, porcentaje dentro de meta, indicadores de éxito. |
| **Alerta / Precaución** | Ámbar / Naranja | `#F59E0B` | Consumo entre 80% y 99% del presupuesto, elementos en pausa. |
| **Exceso / Peligro** | Rojo | `#EF4444` | Presupuesto superado (100%+), confirmaciones de borrado, errores. |
| **Informativo** | Azul | `#3B82F6` | Ayudas visuales y enlaces secundarios. |

---

## 3. Colores Categóricos (Gráficos y Distribución)

Se utilizan exclusivamente en la visualización de datos (gráfico de rosquilla y lista de gastos por categoría) para diferenciar rubros:

- **Alimentación:** Verde Esmeralda (`#10B981`)
- **Educación:** Azul (`#3B82F6`)
- **Salud:** Rojo Coral (`#EF4444`)
- **Hogar:** Ámbar (`#F59E0B`)
- **Servicios:** Púrpura (`#8B5CF6`)
- **Transporte:** Cian (`#06B6D4`)
- **Otros / Varios:** Gris Pizarra (`#64748B`)

---

## 4. Patrones de Componentes

### Botón de Acción Principal (FAB central)
- Círculo amarillo sólido (`#FACC15`).
- Icono `+` en color oscuro (`#111827`), nunca blanco para garantizar contraste.

### Pastillas Interactivas (Chips de edición)
- Contenedor con fondo gris tenue (`#F3F4F6`), borde sutil (`#E5E7EB`) y esquinas redondeadas.
- Texto oscuro de 12px.
- Micro-icono de acción integrado para indicar que es presionable.

### Barra de Progreso de Presupuesto (Semáforo)
- **Hasta 79% del presupuesto:** Verde (`#10B981`) como refuerzo positivo.
- **Entre 80% y 99% del presupuesto:** Amarillo/Ámbar (`#F59E0B`) como advertencia preventiva.
- **100% o más:** Rojo (`#EF4444`) indicando exceso.

---

## 5. Tipografía y Jerarquía
- **Cifra principal (Gasto del mes):** 32px, negrita (bold), tracking reducido.
- **Equivalente secundario (Bs):** 13px, gris medio (`#6B7280`), precedido de icono.
- **Títulos de sección:** 16-18px, negrita.
- **Etiquetas y metadatos:** 12-14px, peso medio (`#6B7280`).
