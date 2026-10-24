---
aliases: ["Diferencias de descuentos de enero"]
tipo: leccion
tema: descuentos-ganancias-sipa
tags: [leccion, descuentos-ganancias-sipa, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-10-12
---

# Diferencias de descuentos de enero

## Estado tras familiares históricos y SAC fiscal (643)

Los 14 casos familiares y los otros dos casos de impuesto por SAC STIA concilian
al centavo. 4750 excluye 4683; 4754 conserva la base anterior independiente.
Se aplicaron las fórmulas con historial AL y se recalcularon los 13 afectados.
La cuota sindical virtual, SAC real, bruto y demás importes se conservaron.
La comparación final de enero comprende 329 empleados: un caso superior a un peso
por aportes regulares, más 21 residuos de al menos un centavo y menos de un peso.
Ver [[ganancias-familiares-meta4-vs-recibo-historico]] para pruebas y alcance.
Los apartados siguientes son mediciones anteriores, no pendientes actuales.

## Revisión posterior al devengo 5397 y la carga de febrero

**Actualización posterior: familiares corregidos.** Se revisaron los 14 casos contra
el maestro actual y las fórmulas 4927/4929: seis clasificaciones corregidas y seis
meses completos recalculados. Cinco diferencias quedan inferiores al centavo;
nueve conservan diferencias frente a enero, con deducciones coincidentes con el
maestro actual. Ver [[ganancias-familiares-meta4-vs-recibo-historico]] para distinguir
las declaraciones actuales de la foto histórica. Los dos casos de SAC STIA y el
caso de aportes regulares siguen pendientes. La medición de abajo es anterior
a estas correcciones.

El 12/10/2026 se volvió a medir el mes entero siguiendo el código del comparador:
329 empleados en ambos sistemas, **17 con diferencias de Ganancias superiores a un peso**.
Hay 36 con diferencias superiores al centavo; no todos son problemas económicos importantes.
El resto de esta nota conserva fotos anteriores y no debe usarse como lista actual de pendientes.

- **14 casos:** deducciones de familia diferentes. Se confirmó un mapeo incompleto de
  concubinos (CC sin Cód. Tipo Ded. en BC) y al menos un familiar tipificado como HIJO_INC
  cuya bandera actual INCAPAC_FAM en Oracle es N. Otros dos HI sí tienen S actualmente:
  no corresponde cambiar esos tipos sólo para igualar el recibo histórico.
  La fórmula original 4927 considera C y CC;
  4929 evalúa H/HI/G, porcentaje y bandera de incapacidad por separado. No alcanza con
  interpretar el parentesco HI como incapacidad. Los otros casos requieren distinguir
  declaración/vigencia actual de Oracle de lo que existía cuando se emitió el recibo.
- **Dos casos:** 4750 incluye el incremento no remunerativo STIA **4683** en la provisión
  mensual de SAC; Meta4 no lo incluye en BSAC_MES_RG3976 de esos recibos. La diferencia
  de bases equivale a ese concepto dividido doce y su efecto por la alícuota marginal
  explica la diferencia de impuesto. Se verificó la fórmula 5192: lee la base 3700,
  no toda la base de Ganancias. Debe corregirse el devengo fiscal, no el SAC real ni
  sacar el ingreso efectivamente pagado de BASE_IG4. Falta auditar el alcance completo
  de las fracciones de esa base en Meta4 antes de configurar una corrección general.
- **Un caso:** jubilación y ley 19032 regulares son menores en BC; los aportes de vacaciones
  coinciden. Esa diferencia en descuentos reales explica prácticamente todo el impuesto
  restante a la alícuota marginal. Falta determinar por qué difieren sus bases/topes.

Esta medición inicial fue en lectura; las correcciones familiares posteriores están
documentadas arriba. No se cambiaron 4750 ni aportes en ninguna de estas dos revisiones.
Los respaldos privados y fórmulas originales se guardaron junto a la auditoría de febrero,
en `.snapshots/carga-febrero-20261012`; los identificadores no se copian al vault.

> [!tip] Revisado el 12/10/2026: de 120 empleados y 5,06 M a **19 y −149.334,57**
> La foto de abajo es del 2/10 y sirve como mapa de causas, pero los números ya no corren. Hoy, de
> **282** con bruto coincidente difieren **19**, por **−149.334,57** —y BC retiene de **menos**, no de
> más—. La descomposición por concepto suma −149.334,61: **no queda nada sin explicar**.
>
> | | |
> |---|---|
> | Sindical, mirado como **total** (`8525` +8.565.969 / `8522` −8.456.870) | **+109.098** |
> | `8563` Contribución solidaria SOMU — BC no lo liquida, 1 empleado | −164.234 |
> | `5010` Ganancias | −74.327 |
> | `6003` jubilación vacaciones | −31.029 |
> | `6000` jubilación | +28.799 |
> | `8893` cuota alimentaria — la novedad de 04382 | −17.033 |
> | `6035`, `6013`, `6030`, `6010` | ±8.400 cada uno |
>
> Lo que se cerró desde entonces: los anticipos dejaron de ser ruido, el `4750` y el `4751` cierran,
> el `8553` y el `8893` se arreglaron, y el caso grande —04766, +2.000.000— era una novedad **de
> febrero** metida en enero, no un duplicado de carga.
>
> **Dos cegueras de medición propias, anotadas para no repetirlas:** filtrar `Es Devengo = 0` del lado
> de BC saca la familia 475x y la enfrenta al 0 del otro lado; y clasificar las columnas `_SAC_MES`
> como RT/SS inventa 12,9 M de diferencia, porque son el **espejo** de una retención ya contada y
> `TOT_RETEN` no las incluye. Ver [[Pendientes liquidación final]], punto 4.

de 260 con bruto coincidente, 120 difieren en descuentos; el mapa de causas y cuál es ruido del comparador

Enero de 2026: de 330 empleados, **260 tienen el bruto coincidente** y de ésos **120 difieren en
descuentos**, por 5.055.817 (BC retiene de más). Desglosado por concepto, las causas son cuatro
familias y **una de ellas no es una diferencia real**.

**1. Los anticipos, −10,25 M: el mapeo está BIEN y la clasificación mal.** `ANTICIPO_LLEGAD`→4813 (el
pago, que vive sólo en el `ti=4`) y `DESC_ANT_LLEGAD`→8840 (el descuento del mes) son dos conceptos
distintos de Meta4, cada uno apuntando al suyo. Lo que está mal es que en BC **el 4813 tiene Tipo
Concepto 2 (Descuento) mientras sus hermanos 4803 y 4823 son 0 (Haber)**: por eso se cuela en
cualquier análisis de descuentos y aparece como 10,25 M que BC no retiene. No lo retiene porque no
liquida el 4813, a propósito. Ver [[anticipo-no-es-haber-del-recibo]].

**2. Ganancias (5010) — 108 empleados, +3.858.444.** Es la diferencia real más grande.

**3. El SAC Devengado (4750) está BIEN; lo que falla son sus descuentos.** Entre los 120 de bruto
coincidente el 4750 coincide en **119** y difiere en uno por 16.667. La diferencia de +1.384.866 que
medí al principio era sobre toda la población, donde están los del grossing-up al 70% y los del
Puente Mayor: ahí el 4750 ARRASTRA un bruto que ya difiere, no lo causa.

Los que sí fallan son 4751, 4752 y 4753, y la fórmula del 4751 lo muestra:
`MIN(BASE_SS_TRAB + BASE_SS_VAC + BASE_SAC, TOPE_SIPA) * PCT_JUB / 100 / 12`, que en 03196 evalúa
`561.283,33 + 0 + 561.283,33` — **la base va duplicada**, porque `BASE_SS_TRAB` y `BASE_SAC` valen lo
mismo y se suman. Como después hay un tope, a unos los corta y a otros no, y por eso el desvío varía
por empleado (129%, 114%…) en vez de ser un factor fijo. El **4754** es otra causa: da el 2,95% de lo
que paga Meta4 y su fórmula usa `PCT_SINDICATO`, que convive en dos unidades.

**4. Conceptos que BC no liquida — −2,2 M.** Dos subgrupos distintos:
  - **6032 y 6037** (Adicional obra social y su variante de vacaciones) están **inactivos** en BC.
  - **8542 Caja compensadora, 8543 Fondo de desempleo, 8553 Centro de capacitación, 8593 Cuota
    extraordinaria acción social CAP** están **activos y con cero líneas en enero**: configurados
    pero algo no los dispara (CCT, parámetro o condición).

Más dos chicos de pocos casos: **8830** descuento anticipo poder (2 empleados, +1.969.414) y **8893**
cuota alimentaria (4 empleados, +1.505.040).

**Cómo se mide**: el bruto de Meta4 es `TOT_REMUN_27617` y se toma el **MAX** del mes, no la suma
(ver [[tot-remun-27617-es-acumulador]]); los descuentos son `TOT_RETEN` (col 169) y el neto `LIQUIDO`
(col 90). Del lado de BC, los descuentos son los `Tipo Concepto` **2 (Descuento Empleado), 4
(Retención) y 5 (Seguridad Social)** — el 0 y el 1 son haberes y el 3 son contribuciones patronales,
que no entran en el recibo de Meta4.

## Relacionado

- [[anticipo-no-es-haber-del-recibo]]
- [[tot-remun-27617-es-acumulador]]
- [[cuatro-conceptos-sin-disparar]]
- [[cuota-sindical-deducida-dos-veces]]
- [[embargo-cuota-alimentaria-como-retencion]]
