# Documentación Técnica: Rediseño del Medidor de Presupuesto ("Tanque que se Vacía")

## 1. Justificación y Modelo Mental

### Problema Previo:
En la pantalla de Inicio (`SummaryCard`), el monto protagonista de 32sp muestra el **saldo disponible restante** (`Disponible para gastar`), el cual decrece conforme el usuario realiza consumos. Sin embargo, la barra de progreso inferior operaba con la semántica opuesta de **acumulación de gasto** (`0% → 100%`), llenándose hacia la derecha.
Esta discrepancia provocaba disonancia cognitiva:
- El número grande decía "te queda menos dinero" (bajaba).
- La barra gráfica decía "se está completando" (subía).
- Al tener meta de ahorro, la reserva protegida se situaba a la derecha del medidor, requiriendo cruzar el divisor para invadirla.

### Solución Implementada ("Tanque de Saldo Disponible"):
Se unifica la representación visual en un modelo de **combustible o batería que se vacía**:
1. **Dirección Canónica:** La barra inicia al `100%` (presupuesto general) y se va vaciando de derecha a izquierda a medida que se ejecutan gastos:
   $$\text{barFillRatio} = \text{clamp}\left(\frac{\text{presupuesto} - \text{gastado}}{\text{presupuesto}}, 0.0, 1.0\right)$$
2. **Reserva Protegida a la Izquierda:** La meta de ahorro se sitúa en el extremo izquierdo:
   $$\text{savingsMarkerPos} = \text{clamp}\left(\frac{\text{metaAhorro}}{\text{presupuesto}}, 0.0, 1.0\right)$$
   El límite para gastar es el punto donde la barra toca la rayita vertical.
3. **Semáforo Físico de Batería:**
   - **Verde (`AppColors.balancePositive` / `#16A34A`):** Nivel saludable (`spent < 0.85 * targetBudget`).
   - **Ámbar (`AppColors.caution` / `#D97706`):** Precaución física (`spent >= 0.85 * targetBudget`), avisando que queda `<= 15%` de saldo antes de tocar la rayita o agotar el presupuesto.
   - **Ahorro Invadido (`targetBudget < spent < budget`):** Toda la zona de reserva entra en estado de emergencia. El saldo vivo de ahorro se pinta en **Rojo Fuerte (`AppColors.errorStrong` / `#DC2626`)**, el tramo ya consumido se tiñe de **Rojo Suave (`AppColors.errorTint` / `#FEE2E2`)**, y el marcador vertical cambia a rojo.
   - **Tanque Agotado (`spent >= budget`):** Relleno al `0%` con carril completo teñido en **Rojo Suave (`AppColors.errorTint` / `#FEE2E2`)** y borde rojo (`AppColors.errorBorder` / `#FCA5A5`), evitando que un sobregasto se confunda con una barra inactiva.
4. **Identidad de Color en Categorías:**
   En `CategoryChart`, las barras de presupuesto por categoría se vacían de `100% → 0%` conservando en estado normal el color oficial de la categoría (`AppColors.categoryColors[cat]`), vinculándose armónicamente con la dona superior. Cambian a Ámbar al quedar `<= 15%` y a carril rojo al igualar o superar el presupuesto.

---

## 2. Componentes Modificados

| Componente | Archivo | Rol en el Rediseño |
| :--- | :--- | :--- |
| **Tokens Semánticos** | `lib/core/constants/app_colors.dart` | Agregados `balancePositive`, `caution`, `errorStrong`, `errorTint`, `errorBorder`, `trackNeutral` y `markerNeutral`. |
| **Resumen Principal** | `lib/ui/widgets/summary_card.dart` | Tanque que se vacía, reserva protegida a la izquierda, banda de ahorro invadida en doble rojo, carril rojo en tanque agotado y `Semantics`. |
| **Tarjeta General Análisis** | `lib/ui/screens/analysis_screen.dart` | Homologación completa de la barra general con `SummaryCard`. |
| **Control por Categorías** | `lib/ui/widgets/category_chart.dart` | Vaciado de categoría con color propio, texto limpio `'Disponible: $Y'` en `FittedBox` y carril de alerta. |
| **Panel Web** | `landing/src/pages/panel.astro` | `progress-track` con `progress-savings-zone-tint`, rayita en meta, semáforo de tanque y barras por categoría con `CATEGORIA_BAR_COLORS`. |
| **Sistema de Diseño** | `DESIGN.md` (§6.4 y §6.5) | Reescritura normativa: tanque de saldo vs barras de asignación/distribución. |
| **Lógica Financiera** | `.agents/rules/dinero-datos.md` (§4) | Reescritura de la geometría física del divisor a la izquierda y vaciado de derecha a izquierda. |
| **Reglas Web** | `.agents/rules/web.md` (§3) | Excepción explícita para el ámbar de precaución financiera en medidores web. |

---

## 3. Protocolo de Pruebas Manuales para César (Validación en Dispositivo)

Descarga el APK de desarrollo (**Rinde Más Dev**) generado en la corrida de CI y verifica los siguientes escenarios:

### Caso 1: Mes con Presupuesto y Meta de Ahorro (Estado Saludable)
1. Configura un Presupuesto General de **$500** y Meta de Ahorro de **$100** (Límite = $400).
2. Con **$0** gastados: la barra debe verse **100% llena en verde**, con la rayita vertical gris situada al 20% desde el borde izquierdo.
3. Registra gastos por **$200** (50% del límite): la barra debe reducirse hasta el medio (50% del ancho total), manteniéndose en verde.

### Caso 2: Nivel de Precaución (Cerca de la Rayita)
1. Registra gastos adicionales hasta llegar a **$360** (90% del límite de $400):
2. La barra debe teñirse de **color ámbar**, situada justo a la derecha de la rayita vertical (quedan solo $40 de saldo libre).

### Caso 3: Ahorro Invadido (Cruce de la Rayita hacia la Izquierda)
1. Registra un gasto que lleve el total a **$450** (supera el límite de $400 por $50, pero menor al presupuesto de $500).
2. La barra debe mostrar la zona de ahorro en alerta:
   - Los $50 de ahorro que aún quedan vivos (de 0% a 10%) en **Rojo Fuerte**.
   - Los $50 de ahorro ya comidos (de 10% a 20%) en **Rojo Suave**.
   - La rayita vertical en **Rojo Fuerte**.
   - El texto superior indica pastilla roja `Excedido del límite` con `-$50.00`.

### Caso 4: Presupuesto Total Agotado / Excedido
1. Registra gastos hasta alcanzar o superar **$500** (ej. $520).
2. Todo el carril de la barra debe teñirse en **Rojo Suave** con borde rojo fino y relleno en 0%.

### Caso 5: Control por Categorías en Análisis
1. Asigna presupuesto a Alimentación de **$100**.
2. Con **$30** gastados: la barra de Alimentación debe mostrar un 70% lleno con el color verde azulado propio de Alimentación, y el texto inferior debe indicar: `Disponible: $ 70,00`.
3. Al superar los $100: la barra se vacía por completo con fondo rojo y alerta de exceso.

### Caso 6: Panel Web (`https://rindemas.cesarluis.com/panel`)
1. Inicia sesión en el panel web con la misma cuenta.
2. Comprueba que la barra principal refleje el ritmo sugerido sin porcentajes redundantes, la reserva a la izquierda y los colores de las categorías.
