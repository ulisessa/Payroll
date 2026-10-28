---
aliases: ["Pilotaje y dique: sueldo y a cuenta de futuros aumentos (1043, 1033, 2033, 2023)"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
origen: 4b151484-1884-4407-a1bb-01b9ea3741c8
actualizado: 2026-10-20
---

# Pilotaje y dique: sueldo y a cuenta de futuros aumentos (1043, 1033, 2033, 2023)

Los cuatro conceptos existían en BC sin fórmula (1033 y 1043 ni activos) y no había fuente de días de pilotaje: BC pagaba cero y no avisaba. En 2026 sólo se notaría en abril, que es el primer mes con pilotaje: en la corrida del 21/4/2026 Meta4 pagó el 1043 a 40 empleados (5 días cada uno) y el 2033 a 7. En Meta4 el pilotaje es recurrente (6 a 19 empleados con 2033 por mes en 2024-2025).

## Qué se midió en Meta4 (`M4_ACUMULADO_RL3`, columnas `SUELDO_PILOTAJE`, `DIAS_PILOTAJE`, `A_CT_FUT_AUM_PI`, `BRUTO_PRORRAT`, `TOT_HAB_GZDO`)

- **Precio del día de pilotaje** (concepto 1042): `2 × PRECIO_PUERTO / 30` en 175/75 OF02/OF04 (120.000 y 102.000) y en marinería (MR00: 133.885,33 = 2.008.279 × 2 / 30); `1 × PRECIO_PUERTO / 30` en 768/19 OF01 y OF03, porque ahí el `PRECIO_PUERTO` ya es el garantizado mensual en USD (en realidad el precio de Meta4 es la garantía de navegación, 6.900 y 5.400 USD × 1.370 / 30 = 315.100 y 246.600; ver más abajo). En la lista de Meta4 son los coeficientes COEF_PUERTO 2, COEF_DIQUE 2 y COEF_PILOTAJE 4 sobre el sueldo / 30.
- **Precio del día de dique** (1032): `1 × PRECIO_PUERTO / 30` en todos.
- **2033 por fórmula** (03664): garantizado de puerto prorrateado por los días de pilotaje − lo ganado (1043 + antigüedad) = 1.370.000 − 685.200 = 684.800. Misma estructura que el 2013 ([[a-cuenta-futuros-aumentos-puerto]]): `G − H` con piso en cero, sólo oficiales.
- **6 de los 7 2033 de abril son incidencias manuales** (importe), no fórmula: van por novedad (`scripts/NovedadesMeta2033Abril.sql`).

## Qué se cambió (desde el 1/4/2026, vigencias nuevas; las anteriores cerradas el 31/3)

`scripts/ConceptosPilotajeYDique.sql` y `scripts/ParametroCoefPilotajePuerto.sql`:

- Fuente `DIAS_PILOTAJE` (copia de `DIAS_DIQUE` con el estado PI).
- Parámetro `COEF_PILOTAJE_PUERTO`: 2 general; 1 en 768/19 OF01 y OF03 (clave por convenio + categoría).
- 1043 = `DIAS_PILOTAJE * PRECIO_PUERTO / 30 * COEF_PILOTAJE_PUERTO * #COEF_PESQUERIA`; 1033 = `DIAS_DIQUE * PRECIO_PUERTO / 30 * #COEF_PESQUERIA`. Activos, cantidad = los días, tipos de liquidación del 1083.
- 2033 / 2023 = `MAX(0, VALOR_PUERTO_EMP / 30 * días − (#1043|#1033 + #1023 + #1053 * días / días de la antigüedad))`.
- La suma de días de la antigüedad (1053), el feriado (1023) y la resta de antigüedad de 2013 y 2083 ahora incluye `DIAS_DIQUE + DIAS_PILOTAJE`: la antigüedad de Meta4 cuenta esos días.

## Los días que se pagan son los del tramo del convenio (21/10/2026)

El pilotaje no se paga por los días reales del estado PI sino por un **mínimo por tramo de duración**: CCT SOMU art. 43 (el cuádruplo del básico mensual, con un mínimo en días: 5 hasta 120 horas, 10 hasta 240, 15 hasta 360, 30 hasta 720; prolongaciones a razón del quíntuplo del valor diario por día) y, para oficiales, el art. 29 de la copia del usuario (el quíntuplo de cinco días de la remuneración garantizada en navegación, más 50 % pasados los 5 días). Meta4 lo confirma en toda su historia (`M4_ACUMULADO_RL3`, 2001-2026): `DIAS_PILOTAJE` pagado es 5 con 1, 2, 3, 4, 5 o 6 días reales (`DS_PILOT_REALES`); en abril de 2026, 2 días de PI y 5 pagados, `SUELDO_PILOTAJE` = 5 × `PRECIO_PILOTAJE` = 502.070 en 04839.

`scripts/PilotajeDiasPagadosCCT.sql`: tabla escalonada `TAB_DIAS_PILOTAJE` (1-6 → 5, 7-11 → 10, 12-16 → 15, 17-31 → 30, más de 31 → 30 + 5 por día; los cortes están en días de calendario porque el estado no lleva horas) y concepto informativo `DIAS_PILOT_PAGO` (orden 26) = `IF(DIAS_PILOTAJE > 0, TRAMO('TAB_DIAS_PILOTAJE', DIAS_PILOTAJE), 0)`. Las fórmulas de 1023, 1043, 1053, 2013, 2023, 2033, 2073 y 2083 leen `#DIAS_PILOT_PAGO` en lugar de `DIAS_PILOTAJE`. Las 40 novedades 1043 de abril (importe de Meta4) se anularon para que rija la fórmula: sin ellas, el 1043 de BC es 5 × 2 × `PRECIO_PUERTO` / 30 = 502.069,33 (Meta4 502.070). **Límite:** si el pilotaje de un empleado cae en dos liquidaciones, cada una pagaría el mínimo por sus días.

## El pilotaje se liquida aparte, con su proyecto (22/10/2026, 1.0.0.681)

Decisión del usuario, y es un **paralelo** contra la corrida de pilotaje de Meta4 (`TP_IMPUT` 12, 21/4/2026): el pilotaje tiene su propio proyecto (fecha y hora de zarpada y de arribo, un proyecto por marea: `PN-128-260424`, `PN-801-260423`, `PN-802-260423`) y su tipo de liquidación `PILOTAJE` (proyectos Improductivos, disparador Arribo, tripulantes). Las horas del proyecto dan el tramo del convenio, así que **la tabla en días del 21/10 se reemplazó por una en horas**.

`scripts/PilotajeLiquidacionAparte.sql` y el código de 1.0.0.681:
- Variable de sistema `HORAS_PROYECTO` (Cod50016 `CalcHorasProyecto`, sembrada en Cod50077, listada en Tab60018): de la zarpada (fecha y hora) al arribo (fecha y hora de ingreso a puerto); hora en blanco = 00:00; sin zarpe, sin arribo o arribo antes del zarpe = 0. Test `HorasProyectoSaleDeLaFechaYHoraDeZarpadaYArribo` (compila, no se corrió).
- Tabla `TAB_HORAS_PILOTAJE`: 0,0001 → 5; 120,0001 → 10; 240,0001 → 15; 360,0001 → 30; 720,0001 → 30 + 20,8333 % por hora (5 días por 24 h). El "hasta 120" del convenio incluye el 120, y `TRAMO` en el borde exacto toma el tramo siguiente, de ahí el 0,0001.
- `DIAS_PILOT_PAGO` = `TRAMO('TAB_HORAS_PILOTAJE', HORAS_PROYECTO)` y sólo aplica a `PILOTAJE`: en las demás liquidaciones vale 0 y el pilotaje deja de contarse en la antigüedad, el 2013, el 2083, etc.
- 1043 sólo en `PILOTAJE`; `PILOTAJE` se agregó a los conceptos de la corrida de Meta4 (puerto, categoría superior, SAC devengado y sus aportes, aportes, Ganancias, sindicales, contribuciones patronales y los auxiliares de aportes y Ganancias). Quedan fuera navegación, feriado, dique, francos y vacaciones.
- Los tres proyectos estaban como Productivo y el cierre de marea (mismo disparador) los habría tomado: pasaron a Improductivo.
- Se revirtió la baja ampliada de las asignaciones a la marea (24/4 → 23/4): el día de puerto extra de Meta4 es el arribo del pilotaje, que ahora paga esta liquidación.

**La corrida de Meta4 del 21/4** (A28/62, 03664): sueldo de pilotaje 5 × 120.000, sueldo de puerto 1 × 60.000, antigüedad con 5 + 1 días (14 % de 900.000 / 30 × 6), a cuenta de futuros aumentos de pilotaje 684.800, redondeo, Ganancias y cuota sindical; en marinería además aportes y contribuciones. Antigüedad total del mes de 04839: 11.547,61 (cierre, 23 días) + 2.510,35 (regular, 5) + 3.012,42 (pilotaje, 6) = 17.070,38.

## Primera corrida de PILOTAJE (22/10/2026)

Se creó a mano (el tipo no entra en la corrida completa): 40 liquidaciones, **5 de oficiales no se guardaron** con "el grossing-up no convergió en 20 iteraciones". `NETO_GARANT` (orden 5, Tipos Liq. Aplicables vacío) encendía el grossing-up con el neto mensual pactado, y el motor evalúa la fórmula del neto garantizado **sin mirar los tipos aplicables** (`ResolverNetoGarantizado`): el pilotaje no calcula complemento (1003, 3553 y 4743 no aplican) y el neto nunca llegaba. `scripts/NetoGarantizadoSinPilotaje.sql`: vigencia del 1/4/2026 con la fórmula envuelta en `IF(TIPO_LIQ = 'PILOTAJE', 0, ...)`. Un concepto comodín que alimenta al grossing-up hay que cortarlo por la fórmula, no por el tipo.

Primera comparación contra Meta4 (40 recibos), tres fallas de configuración:
- **1043 en cero en los 40**: `DIAS_PILOT_PAGO` (orden 26) heredó del molde 5802 una `Fórmula Orden Cálculo` = 883 que pisa al orden y lo hacía correr después del 1043 (27). Lo arregla `scripts/DiasPilotPagoOrdenCalculo.sql`. Al copiar un concepto de molde hay que mirar también `Fórmula Orden Cálculo`, no sólo `Orden Cálculo`.
- **1083 y 1053 con días del período**: sumaban `DIAS_GP_PERIODO` / `DIAS_PROYECTO` y compañía, que son del mes y no del pilotaje (03664: 360.000 contra 60.000). En PILOTAJE sólo cuentan `DIAS_PUERTO` (y `#DIAS_PILOT_PAGO` en la antigüedad).
- **1603 sin el sueldo de pilotaje** en la base: Meta4 lo incluye; se sumó `#1043`.
`scripts/PilotajeDiasPuertoAntiguedadCategoria.sql` (vigencias del 1/4/2026 de 1083 y 1603; 1053 editado en el lugar por ser de este mes). Falta recalcular y volver a comparar.

Segunda comparación (40 recibos, tras el recálculo): 1043 exacto en 34 (los otros 6, de 768/19 OF01/OF03, se explican abajo). Quedaban:
- **Puerto de 2 días** en los proyectos de 23 a 25/4 (PN-801 y PN-802; el de 24 a 25/4 daba 1): Meta4 paga 1 día de puerto en el pilotaje siempre. `PilotajePuertoUnDia.sql`: `MIN(DIAS_PUERTO, 1)` en el 1083 y el 1053.
- **Comodines que corrían en PILOTAJE** y Meta4 no trae: 2013, 2023, 2043, 2073, 2083 (`ACuentaFuturosAumentosSinPilotaje.sql`) y 1543 / 1547. Se enumeraron los tipos existentes menos PILOTAJE. Un tipo de liquidación nuevo hay que sumarlo a mano a estos siete.
- **Las novedades no miran "Tipos Aplicables"** y con fecha 25/4 sin tipo las tomó el PILOTAJE (ventana 24-25/4): 19 eran de la corrida mensual de Meta4 (tp1: 8850, 2013, 2043, 8563, 8893) y 6 de la de pilotaje (tp12: 2033 y dos 8893). `NovedadesAbrilTipoExplicitoPilotaje.sql` les fijó el tipo (REGULAR / PILOTAJE). Para saber de qué corrida de Meta4 es una novedad se mira en qué `TP_IMPUT` está su importe (`scripts` de comparación, columnas de `M4_ACUMULADO_RL..RL5`).
- **768/19 OF01/OF03 (6 recibos): no era el TC.** Meta4 cobra 1.575.500 / 1.233.000 por 5 días = 6.900 / 5.400 USD × 1.370 / 30 × 5, la **garantía de navegación del CCT** (`GARANT_POT_CCT`, sin los pisos personales de `VALOR_NAV_EMP`: 01477 y 04791 tienen 7.000), con el mismo TC que BC (1.370, el del 24/4). BC usaba `PRECIO_PUERTO` (5.500 / 4.304). El "1.718,7" salía de dividir pesos por el USD equivocado (error de esta nota). Las planillas CLC de las tres mareas traen TC 1.365 (celda C7), 5 pesos menos que el `TC_COMPRADOR` del 24/4. `Pilotaje1043GarantiaNavegacion768.sql`: 1043 = `#DIAS_PILOT_PAGO * IF(GARANT_POT_CCT > 0, GARANT_POT_CCT, PRECIO_PUERTO) / 30 * COEF_PILOTAJE_PUERTO * #COEF_PESQUERIA`. Coincide con el art. 29 (garantía en navegación).
- **Antigüedad (1053) de marinería en 0** (Meta4: 03487 paga 37.655 = `PR_NAVEG` 25.103,50 × 25 % × 6 días): `PCT_ANTIG_SOMU` tiene una vigencia futura (1/7/2026) y `PilotajeLiquidacionAparte.sql` agregó PILOTAJE sólo a la abierta; la que rige en abril (1/1 al 30/6) quedó sin PILOTAJE, así que el porcentaje salía 0. `PctAntigSomuPilotajeVigenciaAbril.sql`. **Trampa:** filtrar por `Vigencia Hasta` en blanco para tocar "la vigente" falla cuando ya hay una vigencia futura; se revisó y es el único concepto en esa situación. Esa falta explicaba además el 1603 de las marineras (un tercio de la base, le faltaba la antigüedad) y, aguas abajo, parte de 5010, aportes y 8522.
- **Resultado tras el segundo recálculo:** 1043 y 1083 exactos en los 40; 2033 exacto en 6 de 7.
- **Abierto:** 2033 de 03664 (BC 481.618, Meta4 684.800): Meta4 usa 6.000 USD de garantía de puerto (8.220.000 / 1.370) y BC la categoría (4.783 USD); sin parámetro personal. 2033 de 04455: BC 652.233, Meta4 no paga. 8563 (contribución solidaria SOMU) en 04913, 04914 y 04915: Meta4 la deduce en el pilotaje (29.454,77 y 22.091,08) y el concepto no tiene fórmula en BC.

## La cobertura del pilotaje (22/10/2026, código)

El PILOTAJE salía con cobertura 1/4 al 30/4 (el mes entero): `Tipo Liquidación.CubreSoloElProyecto` sólo daba verdadero para tipo de proyecto Productivo, y el pilotaje es Improductivo (para que el cierre de marea, mismo disparador, no lo tome). Tapaba los días de la regular y ésta no se generaba. Ahora también da verdadero para los tipos disparados al **Arribo**: el pilotaje cubre el tramo de su proyecto (24 al 25/4), igual que una marea. Test `TipoQueLiquidaAlArriboCubreSoloSuProyectoAunqueSeaImproductivo` (compila, no se corrió). **Requiere publicar** y recalcular el PILOTAJE y la regular de esos empleados.

## Resultado tras recalcular abril en orden (22/10/2026, 1.0.0.682)

40 liquidaciones de PILOTAJE contra la corrida de Meta4: 1043 y 1083 exactos en 40, 1053 en 28 de 28, 1603 en 9 de 9, aportes (6000/6010/6030) en 25 de 25 con los 3 de 8563 sin fórmula, 5010 en 28 de 36 y 8522 en 34 de 37. Los desvíos que quedan en el pilotaje son los de 2033 (03664, 04455, 04826: ver arriba) y lo que arrastran (5010 y 8522 de 02452, 03664, 04455, 04826, 04906). **El orden de cálculo importa para Ganancias**: se calcula con el YTD de las liquidaciones anteriores del mes (CIERRE 1, PILOTAJE 2, REGULAR 100); si el cierre se recalcula después, el pilotaje y la regular quedan con el 5010 negativo (−1,16 M en 03487) hasta rehacerlos en orden. Totales de abril contra Meta4 (332 empleados): bruto fuera de 1 peso 105 (antes 103), descuentos 52 (67), contribuciones sin 7080 ni 7090-7099 70 (86).

## Revisión de 03664, 04455, 04826 y 8563 (22/10/2026)

- **03664 y las incidencias de 2033:** los 7 pagos de 2033 de Meta4 son incidencias manuales, también el de 03664 (684.800; la coincidencia con 1.370.000 − 685.200 es un número redondo cargado a mano, y la nota anterior que lo daba por fórmula estaba mal). La novedad 10884 estaba tipada REGULAR y la pagó la regular además de la fórmula del pilotaje (1.158.918). Se tipó PILOTAJE. Las planillas CLC no traen nada del pilotaje (su "Garantía de Máquinas", 15.000 USD, es de producción).
- **04455:** Meta4 no pagó 2033 y la fórmula de BC da 650.690. Se cargó una novedad de importe cero, tipo PILOTAJE, que apaga la fórmula. **Pendiente de decidir:** si el 2033 pasa a ser sólo por novedad (sin fórmula), porque Meta4 siempre lo carga a mano. `NovedadesPilotajeTipoExplicito2033y8563.sql`.
- **8563 (contribución solidaria SOMU)** es un concepto sin fórmula que se carga por novedades de Meta4 (en Meta4 es 4 % de `PR_CONT_SOLID`, el total remunerativo, para quienes no están afiliados). Las tres novedades del 21/4 (04913, 04914, 04915) eran de la corrida de pilotaje y las tomó el cierre; ahora van tipadas PILOTAJE. Cada corrida de Meta4 se identifica por la fecha de su novedad (13/4 cierre, 20/4 tp11, 21/4 pilotaje, 25/4 mensual).
- **04826 y la categoría superior:** categoría OF04 (765.000) y puesto OF02 (900.000) desde el 13/2, igual en BC y Meta4 (MQ01 = OF02). Meta4 le paga 1603 de 17,647 % de la base (100 / 85 − 1): 99.540 en el pilotaje. BC pagaba cero porque todas las categorías de oficiales tenían escala 100. La escala sale de Meta4 (`M4T_VAL_CONVENIO_CATEG_PUESTO`, concepto 2082): OF01 115, OF02 100, OF03 90, OF04 85, OF05 77,83. `EscalaOficialesPorCategoriaMeta4.sql`. Meta4 empieza a pagarla en marzo (13/3 el cierre) y BC ahora lo hace desde el 13/2: febrero va a diferir. El sueldo de navegación de 04826 ya era 765.000 en todas las liquidaciones de abril.

## El pilotaje se calcula sobre navegación (22/10/2026)

Indicación del usuario, y es la regla de Meta4 (`COEF_PILOTAJE` 4 sobre el sueldo de navegación / 30, concepto 1042): el 1043 pasó de `2 × PRECIO_PUERTO` a `IF(GARANT_POT_CCT > 0, GARANT_POT_CCT, PRECIO_NAV) / 30 × COEF_PILOTAJE_NAV` (4; 768/19 OF01 y OF03: 1 sobre la garantía de navegación en USD). El parámetro `COEF_PILOTAJE_PUERTO` se retiró. Mismo criterio en el 2033: `VALOR_NAV_EMP` en vez de `VALOR_PUERTO_EMP` (`Concepto2033GarantiaNavegacion.sql`). Scripts `Concepto1043PrecioNavegacion.sql`. Las menciones de arriba a `PRECIO_PUERTO` y `COEF_PILOTAJE_PUERTO` son de la versión anterior.

## El 2033 seguía por fórmula: una novedad con tipo explícito era rechazada por el historial (22/10/2026, código)

Tras retipar PILOTAJE las novedades de 2033 de 04826, 03664 y 04455 (y crear la de 04455 en cero), siguieron **Pendientes** y el 2033 salió por la fórmula nueva de navegación (846.670, 2.793.500, 650.690). Causa: `ProyectoAplica` (Cod50061), con el proyecto de la novedad en blanco, mira el estado del empleado a la fecha de la novedad; ese día es PI sobre su nómina (PN-802-NOMINA), que tiene su Regular, y concluía "esta novedad es de la Regular" **aunque tuviera Tipo Liq. PILOTAJE**. Sólo entraba si la Regular todavía no existía cuando se calculaba el pilotaje, por eso 04724, 04868 y 04921 sí se aplicaron (en un lote donde la Regular se estaba rehaciendo): el resultado dependía del orden en que se calculara. Ahora un tipo explícito con proyecto en blanco decide solo y el historial no se consulta (misma excepción que la fecha). **Requiere publicar**. Para los que no tienen pilotaje no hay diferencias de 2033: los ocho empleados con 2033 son los del pilotaje.

## CORRECCIÓN: el 2033 no son incidencias manuales, es la diferencia contra el asegurado (22/10/2026)

Las secciones anteriores que dan seis de los siete 2033 como incidencias manuales (y el de 03664 como incidencia o fórmula de puerto) **estaban mal**: comparaba contra las novedades que yo mismo había cargado, que reemplazan a la fórmula, y por eso "coincidía" por construcción. Regla real, leída de las columnas de Meta4 de la corrida de pilotaje (`M4_ACUMULADO_RL3`) y confirmada por el usuario ("cuando el asegurado supera la liquidación de convenio, diferencia entre uno y otro monto"):

- **Sin neto garantizado (03664, 04455):** 2033 = `BRUTO_PRORRAT` − `TOT_HAB_GZDO`, mínimo cero. `BRUTO_PRORRAT` = `NTO_GARANTIZADO` (USD de navegación del empleado) × TC / 30 × **días PI reales (2)**; `TOT_HAB_GZDO` = 1043 + 1053 + 1083 + 1603. 03664: 15.000 × 1.370 / 30 × 2 = 1.370.000 − 685.200 = 684.800. 04455: 502.333 − 667.200 < 0 → 0. Es la misma rama que la de la 2003 en las mareas.
- **Con neto garantizado (04163, 04724, 04826, 04836, 04868, 04921):** tienen `NETO_GU_MAREA` (el asegurado del CLC) y su 2033 es el **complemento del grossing-up**. Neto de la corrida de pilotaje = asegurado × 70 % × TC / 30 × 2: 04826, 22.000 × 0,7 × 1.370 / 30 × 2 = 1.406.533, que es el neto de su recibo (2.372.310 − 859.023 de Ganancias − 106.754 de cuota sindical). Cuatro de los seis tienen además el mismo cociente de gross-up (1,185) contra asegurado × TC / 30 × 2.

Cambios (`PilotajeNetoGarantizadoComplemento2033.sql`): `NETO_GARANT` en PILOTAJE = `NETO_GU_MAREA * DIAS_PILOTAJE / 30 * PCT_NETO_GU / 100` (había quedado en 0 por `NetoGarantizadoSinPilotaje.sql`, que se hizo porque el complemento caía en 1003/3553/4743 y el grossing-up no convergía: lo correcto era darle un receptor en el pilotaje); 2033 = `IF(ES_GROSSING_UP > 0, COMPLEMENTO_GU, <rama sin neto>)`; **1003 (comodín) deja de correr en PILOTAJE** para que no tome el complemento (se enumeraron los tipos menos PILOTAJE); y se anularon las 14 novedades de 2033 de abril. Los dos `scripts` anteriores del 2033 (`NovedadesMeta2033Abril.sql`, `NovedadesPilotajeTipoExplicito2033y8563.sql` para el 2033) quedan sin efecto. La corrección de `ProyectoAplica` (novedad con tipo explícito no consulta el historial) es válida aunque ya no se use para el 2033; está sin publicar. **Trampa:** una novedad de importe "coincide" con Meta4 por definición; para validar una fórmula hay que anular las novedades del concepto.

## Resultado del 2033 por regla y el 1603 de los oficiales 175/75 (22/10/2026)

Tras recalcular los ocho: 03664 exacto (684.800), 04455 en 0 y los seis con neto garantizado a 7-13 pesos de Meta4 (04163, 04724, 04836, 04868) por la tolerancia del grossing-up; 04826 +99.526 y 04921 −358.138 (Ganancias del pilotaje: BC 438.913 contra 780.930; el neto converge igual en los dos, con otro bruto; el cierre y la regular de 04921 sí coinciden).

**04826:** el +99.526 es su 1603 (categoría OF04, puesto OF02, 99.540 en Meta4): `1603` y `PCT_PUESTO` sólo estaban habilitados para 729/15 en `Concepto CCT Vigente`, y el complemento del grossing-up absorbía la diferencia. Las escalas ya existían como parámetro `PCT_ESCALA_CONV` (175/75: 1,15 / 1 / 0,9 / 0,85), así que lo de "% Escala" de Categoría CCT de más arriba **fue un error y se devolvió a 100**. `Concepto1603Oficiales175.sql`: habilitado para 175/75 desde el 1/4 (Meta4 lo paga desde marzo: revisar marzo) y 1603 con `IF(#PCT_PUESTO = 0, 0, ...)` para un puesto sin escala (03664: puesto FE02 del convenio ESP). 768/19 queda afuera hasta que tenga los `PCT_ESCALA_CONV` de OF02 y OF04.

## 2033 sólo en PILOTAJE (22/10/2026)

Recalculados 04826 y 03664: pilotaje exacto (03664: 2033 684.800 y Ganancias 496.082; 04826: 2033 1.708.697, 1603 99.540). Pero el 2033 era comodín y con la rama `ES_GROSSING_UP > 0 → COMPLEMENTO_GU` tomó también el complemento del cierre de 04826 (11.990.048, duplicado con el 2003): `Concepto2033SoloPilotaje.sql` lo limita a PILOTAJE. **Regla:** todo concepto que lea `COMPLEMENTO_GU` tiene que estar acotado por tipo; los comodines lo toman en cualquier liquidación con neto garantizado. El 1603 de 04826 en cierre (110.070 contra 169.470) y regular (123.300 contra 102.825) difiere por el reparto de francos (el 1063 de BC es de la regular y el de Meta4 lo parte con el cierre), no por el 1603. La Ganancias del cierre de 03664 (−317.813) viene del 2003 de oficiales 175/75, ya abierto.

## Trampas

> [!warning] Orden de cálculo
> El 2033 y el 2023 leen el 1023 (orden 470) y estaban en 186 y 184: lo leían antes de calcularse. Se pasaron a 553 y 552 (el 2013 está en 551).

> [!warning] Sin verificar
> Falta crear abril y comparar el 1043 (40 casos) y el 2033 de 03664 contra Meta4. El TC de las corridas de pilotaje de Meta4 es 1.370 (no 1.718,7, que era un error de cuenta); si BC usa otro `TC_COMPRADOR` las categorías en USD (768/19 OF01 y OF03) no van a coincidir (ver [[tc-de-marea-no-es-cotizacion]]). El CG (`× (100 − 4676) / 100` de Meta4) no se replicó, igual que en el 1083.

> [!info] Un script a medias
> En `ConceptosPilotajeYDique.sql` el alta de las tres filas vigentes del parámetro salió vacía (la lista de columnas restantes quedaba nula y anulaba el `INSERT` dinámico). Las tres filas se dieron de alta con `ParametroCoefPilotajePuerto.sql`. Un `STRING_AGG` vacío es `NULL`, no cadena vacía.

## Devengo de francos del pilotaje: sólo los días PI (22/10/2026)

El 1062 en PILOTAJE devengaba `COEF_FRANCOS * DIAS_MAREA`; en HF801/802 el proyecto de pilotaje empieza el 23/4 (llegada, ya devengada por el cierre) y daba 1 día de más. Vigencia nueva del 1062 desde el 1/4/2026 con `IF(TIPO_LIQ = 'PILOTAJE', ROUND(COEF_FRANCOS * DIAS_PILOTAJE, 1), …)` (`scripts/Devengo1062PilotajeSoloDiasPI.sql`). Verificado tras recalcular: el 2803 y el bruto de las finales de los 8 empleados de A28/HF801/HF802 coinciden con Meta4.
