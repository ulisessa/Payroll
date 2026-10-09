---
aliases: ["Los cuatro conceptos que no disparan"]
tipo: leccion
tema: descuentos-ganancias-sipa
tags: [leccion, descuentos-ganancias-sipa, project]
actualizado: 2026-10-04
---

# Los cuatro conceptos que no disparan

8553 arreglado (1% de BASE_SINDICAL, no 1,5x); 8542/8543 necesitan un atributo por empleado, no una fórmula; 8593 sin el parámetro base

Los cuatro conceptos que estaban **activos y con cero líneas en enero** no comparten causa; cada uno
falla por su cuenta.

**8553 Centro de capacitación — ARREGLADO el 2/10/2026.** Eran dos cosas, y mi primer diagnóstico
(«compara el Valor Numérico con un texto y nunca entra por el then») **era equivocado**: la
comparación por código ya funciona sola, ver [[atributo-comparar-por-codigo]]. La prueba era que en
la Regular de 01591 la fórmula evaluó `IF('PAT' = 'PAT', 6.351,8764 * 1.5, 0)` y pagó. Lo que
estaba mal:

1. **El factor estaba invertido.** Meta4 cobra `CENTRO_CAPACIT` = **1/3 de la cuota sindical**, no
   1,5 veces. Ratio 0,333333 en los 15 casos de enero y en los cuatro tipos de imputación. Contra
   la base es **1% de `BASE_SINDICAL`**, que cierra al centavo: 211.729,21 → 2.117,29 y
   10.938.229,95 → 109.382,30, los dos iguales a Meta4. Y es **sólo PAT**, así que la guarda estaba
   bien puesta.
2. **No aparecía en Vacaciones**, con la lista de tipos vacía y ese tipo en lista blanca — ver la
   nota nueva de [[vacio-en-tipos-liq-aplicables-es-comodin]]. Ni línea ni aviso.

Quedó `IF(PCT_SINDICATO = 'PAT', round(BASE_SINDICAL * PCT_CENTRO_CAPACIT / 100, PRECISION_REDONDEO), 0)`
con el parámetro global nuevo `PCT_CENTRO_CAPACIT` = 1 y los tipos
`CIERRE_MAREA|DEVENGADOS|LIQ_FINAL|REGULAR|RELIQUIDACION|VACACIONES` (la unión del 8522 y el 8525,
que es donde Meta4 lo cobra). El `#8553` que se referenciaba a sí mismo salió con el cambio.

**8542 Caja compensadora y 8543 Fondo de desempleo: no se arreglan con una fórmula.** La fórmula
está vacía, pero el que falta es el dato, y **no sale del sindicato**:

- `PORC_FDO_DESEMP` vale **0,25 para todos** sin excepción, pero *quién lo paga* no se deduce del
  sindicato: históricamente lo pagan CON (184 empleados), CAP (79), SOM (12), SSI (11) y PAT (2).
  Una guarda por sindicato dejaría afuera al grueso.
- `PORC_CAJA_COMP` **varía por empleado**: 2, 3, 5, 6, 7 y 8 entre los pocos que lo tienen, incluso
  dentro de CAP. Es asignación compensadora, no una tasa de convenio.

Los dos piden un **atributo por empleado** con su porcentaje y migrar los valores desde
`PORC_CAJA_COMP` / `PORC_FDO_DESEMP`; el porcentaje en cero es lo que apaga el concepto, como en
[[un-valor-una-fuente]]. Ver [[atributos-tipados]].

**8593 Cuota extraordinaria acción social CAP**: usa `PCT_CUOTA_EXT_CAP`, que **no existe sin
sufijo**. Lo único cargado es `PCT_CUOTA_EXT_CAP_ESP_FE01` = 0,03, así que sólo resuelve para quien
tenga ese sufijo. Ver [[get-con-menos-argumentos]]. Sigue abierto.

**8893 Cuota alimentaria — ARREGLADO el 2/10/2026, y no era la novedad.** Las novedades estaban
cargadas y con el importe exacto de Meta4 (01477: 159.470,60 en 202601). El concepto estaba clavado
en `Tipos Liq. Aplicables = VACACIONES` mientras sus ocho hermanos 88xx la tienen vacía, así que en
una Regular, un Devengado o un Cierre de Marea no aplicaba y la novedad quedaba sin consumir: **43
novedades y 25,07 M en enero**, de las cuales 31 empleados sólo tenían Regular. Quedó con
`AGUINALDO|CIERRE_MAREA|DEVENGADOS|LIQ_FINAL|REGULAR|RELIQUIDACION|VACACIONES`. Como el lote corre
por Orden de Tipo Liq., Vacaciones (30) sigue ganándole a Regular (100) y quien hoy la cobra ahí la
sigue cobrando ahí, igual que Meta4.

El **8883 (embargo judicial)** tiene el bug espejo —lista vacía, o sea fuera de Vacaciones— pero su
exposición en enero es **cero**: todos sus empleados tienen al menos una liquidación de un tipo que
no es lista blanca. Queda latente.

Los valores del atributo SINDICATO y su número, que es lo que llega a las fórmulas cuando se lo lee
sin comillas: SSI y UOM 0; STI 2; ASO, CAP y FEC 2,5; **MAQ y PAT 3**; SOM 4; CON, SBA y SEC 4,5.
Dos pares comparten número, así que para distinguirlos hay que comparar por código.

## La fórmula sin la fracción de acumulador deja la mitad del arreglo

Corregir el importe del 8553 **no alcanzaba**: el concepto no tenía ninguna fila en `Fracción
Acumulador`, mientras el 8522 y el 8525 aportan los dos a `CUOTA_SINDICAL_RET`, que es lo que la
fórmula del 5010 resta de la base de Ganancias. Resultado: el importe salía bien, el neto salía
bien, y el impuesto quedaba calculado sobre una base más alta que la de Meta4.

**Y el arreglo parcial lo empeoró**: antes el 8553 pagaba 9.527,81 y la deducción que faltaba era
chica; al pasar a pagar los 111.499,59 correctos, la brecha creció y recién ahí se vio. Es el
mismo mecanismo de [[grossing-up-tapa-errores]] pero al revés — acá el neto siempre estuvo bien y
el que se movió fue el impuesto.

En 01591 la diferencia de Ganancias descompuso **al centavo**:

- 8553 centro de capacitación 109.382,30 + 2.117,29 = **111.499,59** sin deducir
- 4754 cuota sindical SAC **9.291,63** de menos (el 3% de BC contra el 4% de Meta4, ver
  [[sindical-sac-base-equivocada]])
- base faltante 120.791,22 × 35% = **42.276,93** = exactamente la diferencia del 5010
  (BC 1.975.848,65 contra Meta4 1.933.571,72)

**Regla**: al tocar un concepto de descuento, mirar siempre si aporta a los acumuladores que lo
necesitan. El control de orden existe ([[acumuladores-orden-calculo]]) y el de precedencia también
([[control-precedencia-formulas]]), pero **ninguno detecta la fracción que no está** — un
acumulador al que nadie aporta no se distingue de uno que vale cero.

## El 01477 no era el 8893, y tampoco le falta una liquidación

Ampliar el alcance del 8893 no lo cambió. Su novedad tiene **Fecha 25/1** y su única liquidación de
enero es un DEVENGADOS que cubre **29–31**, así que `NovedadAplica` la descarta por fecha. Primero
lo leí como "falta la mensual de los días 1–28": **está mal**. El estado de esos días es OI y **OI
no se paga**, así que no corresponde ninguna liquidación — la cobertura 29–31 es la correcta.

Y el DEVENGADOS **cuadra con Meta4 al centavo en 17 de 18 conceptos** (sueldo, antigüedad, puerto,
art. 23, premio, jubilación, ley 19032, obra social, sindical, los cuatro del SAC). El único hueco
es la cuota alimentaria: Meta4 la cobró entera en esa misma corrida. **Una cuota alimentaria es una
obligación mensual, no un evento de un día**, así que la Fecha de la novedad —que viene estampada
de la migración— no debería filtrar nada.

## Las novedades perdidas por fecha son casi todas otro bug

En enero hay 10 novedades sin aplicar cuya Fecha cae fuera de toda cobertura (665.652), y las 10
coinciden **exactamente** con lo que Meta4 cobró. Pero se parten en dos causas:

- **8 de 10** son de los **7 empleados de baja de enero** (04190, 04775, 04807, 04889, 04900,
  04925, 90448), cuyas REGULAR tienen la **cobertura en blanco y Total Haberes = 0**: son
  liquidaciones vacías, no novedades rechazadas. La fecha es el síntoma. Se arregla con el
  LIQ_FINAL, ver [[cuando-corresponde-una-liquidacion]].
- **2 de 10** son cobertura legítimamente angosta: 01477 (29–31, novedad del 25/1, 159.470,60) y
  04382 (31–31, novedad del 25/1, 17.033,40). Ahí sí la que sobra es la Fecha.

Moraleja: antes de tocar la Fecha de una novedad, mirar si la liquidación tiene cobertura. Una
cobertura en blanco rechaza **toda** novedad con fecha y no se parece a un error de fecha.

## El mismo error, dos veces: escribir la fórmula sin la fracción

El 3/10/2026 volví a hacerlo. Le escribí las fórmulas al 8542, 8543 y 8593 y **ninguno de los tres
tenía fila en `Fracción Acumulador`**, mientras el 8522, 8523, 8525, 8553 y 4754 aportan todos a
`CUOTA_SINDICAL_RET`. Efecto: los conceptos empiezan a cobrar, `Total Descuentos` sube, el neto baja
**y la base de Ganancias no se mueve**, así que el impuesto queda calculado de más. Visto desde el
recibo parece que el cambio "empeoró" al empleado, y en cierto modo sí.

En 04924 cerró exacto: deducción que faltaba 684.858,41 + 34.242,92 + 296.213,86 = 1.015.315,19, al
35% son 355.360,32, y la diferencia de Ganancias pasa de 384.973,68 al residuo del 4754 (84.609,60
× 35% = 29.613,36).

**Regla, ahora con el chequeo concreto**: después de escribirle o cambiarle la fórmula a un concepto
de descuento, correr esto ANTES de dar el cambio por hecho —

```sql
SELECT c.[Código], c.[Orden Cálculo], ISNULL(f.[Cód_ Acumulador],'(NINGUNA)')
FROM [...Concepto Liquidación...] c
LEFT JOIN [...Fracción Acumulador...] f ON f.[Cód_ Concepto] = c.[Código]
WHERE c.[Código] IN (...)
```

y compararlo contra un concepto hermano que ya funcione. Un acumulador al que nadie aporta **no se
distingue de uno que vale cero**: no hay control que lo detecte, ni el de orden
([[acumuladores-orden-calculo]]) ni el de precedencia ([[control-precedencia-formulas]]).

## Y el 8593 estaba restringido por el eje equivocado

Además de la fracción, no aparecía ninguna línea: su `Concepto CCT Vigente` lo limitaba a
**ESP/FE01 y ESP/FE03**, y los que lo pagan son 768/19 OF03. Es el mismo malentendido que el
parámetro `PCT_CUOTA_EXT_CAP_ESP_FE01`: alguien lo tomó por un concepto de españoles fuera de
convenio cuando es la cuota de acción social del **sindicato** CAP. Se le borraron las dos filas de
CCT y el alcance lo decide ahora la guarda `PCT_SINDICATO = 'CAP'` de la fórmula, que es el eje
correcto. Sin guarda eso lo habría cobrado a todos, así que el script lo verifica antes de borrar.

Un atributo de lista **siempre** tiene entrada en `FCodigosAtributos` —`LoadAtributos` hace el `Set`
incluso sin fila vigente, con `Cód. Valor` vacío—, así que la comparación por código devuelve falso
en vez de cortar con error para quien no tiene el atributo cargado. Por eso es seguro dejar que la
guarda haga de alcance.

## Relacionado

- [[atributo-comparar-por-codigo]]
- [[vacio-en-tipos-liq-aplicables-es-comodin]]
- [[un-valor-una-fuente]]
- [[atributos-tipados]]
- [[get-con-menos-argumentos]]
- [[grossing-up-tapa-errores]]
- [[sindical-sac-base-equivocada]]
- [[acumuladores-orden-calculo]]
- [[control-precedencia-formulas]]
- [[cuando-corresponde-una-liquidacion]]
- [[cuota-sindical-deducida-dos-veces]]
- [[diferencias-descuentos-enero]]
- [[embargo-cuota-alimentaria-como-retencion]]
