# Documentación Técnica: Rediseño del Medidor de Presupuesto ("Tanque con Desgaste de Izquierda a Derecha")

## 1. Justificación y Modelo Mental

### Problema Previo:
En la pantalla de Inicio (`SummaryCard`), el monto protagonista de 32sp muestra el **saldo disponible restante** (`Disponible para gastar`), el cual decrece conforme el usuario realiza consumos. Sin embargo, la barra de progreso inferior operaba anteriormente con la semántica de **acumulación de gasto** (`0% → 100%`), llenándose hacia la derecha.

### Solución Implementada ("Tanque con Desgaste de Izquierda a Derecha"):
Se unifica la representación visual en un modelo de **combustible o batería que se desgasta de izquierda a derecha**:
1. **Dirección Canónica:** La barra inicia al `100%` (presupuesto general) y se va desgastando de izquierda a derecha conforme se ejecutan gastos:
   - El dinero consumido entra por la izquierda como un tramo consumido/gris que avanza hacia la derecha (`0% → 100%`).
   - El saldo disponible restante queda anclado a la derecha, reduciéndose hacia el extremo derecho:
     $$\text{barFillRatio} = \text{clamp}\left(\frac{\text{presupuesto} - \text{gastado}}{\text{presupuesto}}, 0.0, 1.0\right)$$
2. **Reserva Protegida a la Derecha:** La meta de ahorro se sitúa a la derecha delimitando el límite para gastar:
   $$\text{savingsMarkerPos} = \text{clamp}\left(\frac{\text{limiteParaGastar}}{\text{presupuesto}}, 0.0, 1.0\right) = \text{clamp}\left(\frac{\text{presupuesto} - \text{metaAhorro}}{\text{presupuesto}}, 0.0, 1.0\right)$$
   El límite para gastar es el punto donde el desgaste alcanza la rayita vertical desde la izquierda.
3. **Semáforo Físico de Batería:**
   - **Verde (`AppColors.balancePositive` / `#16A34A`):** Nivel saludable (`spent < 0.85 * targetBudget`).
   - **Ámbar (`AppColors.caution` / `#D97706`):** Precaución física (`spent >= 0.85 * targetBudget`), avisando que queda `<= 15%` de saldo antes de tocar la rayita o agotar el presupuesto.
   - **Ahorro Invadido (`targetBudget < spent < budget`):** El desgaste cruza la rayita de ahorro hacia la derecha. El tramo consumido dentro de la reserva (entre el divisor y el gasto) se tiñe de **Rojo Suave (`AppColors.errorTint` / `#FEE2E2`)**, el saldo que aún queda vivo de ahorro se pinta en **Rojo Fuerte (`AppColors.errorStrong` / `#DC2626`)**, y el marcador vertical cambia a rojo fuerte.
   - **Tanque Agotado (`spent >= budget`):** Relleno al `0%` con carril completo teñido en **Rojo Suave (`AppColors.errorTint` / `#FEE2E2`)** y borde rojo (`AppColors.errorBorder` / `#FCA5A5`), evitando que un sobregasto se confunda con una barra inactiva.
4. **Identidad de Color en Categorías:**
   En `CategoryChart`, las barras de presupuesto por categoría se desgastan de izquierda a derecha conservando en estado normal el color oficial de la categoría (`AppColors.categoryColors[cat]`), vinculándose armónicamente con la dona superior. Cambian a Ámbar al quedar `<= 15%` y a carril rojo al igualar o superar el presupuesto.

---

## 2. Componentes Modificados

| Componente | Archivo | Rol en el Rediseño |
| :--- | :--- | :--- |
| **Tokens Semánticos** | `lib/core/constants/app_colors.dart` | Agregados `balancePositive`, `caution`, `errorStrong`, `errorTint`, `errorBorder`, `trackNeutral` y `markerNeutral`. |
| **Resumen Principal** | `lib/ui/widgets/summary_card.dart` | Tanque con desgaste de izq. a der., reserva protegida a la derecha, banda de ahorro invadida en doble rojo, carril rojo en tanque agotado y `Semantics`. |
| **Tarjeta General Análisis** | `lib/ui/screens/analysis_screen.dart` | Homologación completa de la barra general con `SummaryCard`. |
| **Control por Categorías** | `lib/ui/widgets/category_chart.dart` | Desgaste de categoría con color propio, microcopy dual `'X% consumido · Queda $Y'` en `FittedBox` y carril de alerta. |
| **Panel Web** | `landing/src/pages/panel.astro` | `progress-track` con `progress-savings-zone-tint`, rayita en límite a la derecha, semáforo de tanque y barras por categoría con `CATEGORIA_BAR_COLORS`. |
| **Sistema de Diseño** | `DESIGN.md` (§6.4 y §6.5) | Reescritura normativa: tanque de saldo con desgaste LTR vs barras de asignación/distribución. |
| **Lógica Financiera** | `.agents/rules/dinero-datos.md` (§4) | Reescritura de la geometría física del divisor a la derecha y avance del gasto de izquierda a derecha. |
| **Reglas Web** | `.agents/rules/web.md` (§3) | Excepción explícita para el ámbar de precaución financiera en medidores web. |

---

## 3. Protocolo de Pruebas Manuales para César (Validación en Dispositivo)

Descarga el APK de desarrollo (**Rinde Más Dev**) generado en la corrida de CI y verifica los siguientes escenarios:

### Caso 1: Mes con Presupuesto y Meta de Ahorro (Estado Saludable)
1. Configura un Presupuesto General de **$500** y Meta de Ahorro de **$100** (Límite = $400).
2. Con **$0** gastados: la barra debe verse **100% llena en verde**, con la rayita vertical gris situada al 80% (delimitando el ahorro al final a la derecha).
3. Registra gastos por **$200** (50% del límite): el tramo gris consumido entra por la izquierda ocupando el 40% del total (de 0% a 40%), y el saldo disponible restante queda a la derecha (del 40% al 100%) en verde.

### Caso 2: Nivel de Precaución (Cerca de la Rayita)
1. Registra gastos adicionales hasta llegar a **$360** (90% del límite de $400):
2. El gasto ocupa del 0% al 72% en gris. El saldo restante (del 72% al 100%) se tiñe de **color ámbar** al quedar solo $40 de saldo libre antes de tocar la rayita en el 80%.

### Caso 3: Ahorro Invadido (Cruce de la Rayita hacia la Derecha)
1. Registra un gasto que lleve el total a **$450** (supera el límite de $400 por $50, pero menor al presupuesto de $500).
2. El desgaste llega al 90%, cruzando la rayita del 80%:
   - De 0% a 80%: Gris (gasto normal dentro del límite).
   - Rayita vertical en 80%: **Rojo Fuerte**.
   - De 80% a 90%: **Rojo Suave** (los $50 de ahorro ya consumidos/dañados).
   - De 90% a 100%: **Rojo Fuerte** (los $50 de ahorro que aún quedan vivos).
   - El texto superior indica pastilla roja `Excedido del límite` con `-$50.00`.

### Caso 4: Presupuesto Total Agotado / Excedido
1. Registra gastos hasta alcanzar o superar **$500** (ej. $520).
2. Todo el carril de la barra debe teñirse en **Rojo Suave** con borde rojo fino y relleno en 0%.

### Caso 5: Control por Categorías en Análisis
1. Asigna presupuesto a Alimentación de **$100**.
2. Con **$30** gastados: el tramo consumido (30%) entra por la izquierda en gris y el 70% restante a la derecha luce con el color verde azulado propio de Alimentación. El texto inferior indica: `30% consumido · Queda $ 70,00`.
3. Al superar los $100: la barra se vacía por completo con fondo rojo y alerta de exceso.

### Caso 6: Panel Web (`https://rindemas.cesarluis.com/panel`)
1. Inicia sesión en el panel web con la misma cuenta.
2. Comprueba que la barra principal refleje el porcentaje consumido y disponible (`X% consumido · Y% en tanque`), el desgaste avanzando de izquierda a derecha y los colores de las categorías.
