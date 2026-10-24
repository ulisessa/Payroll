---
aliases: ["SSI paga según el convenio"]
tipo: leccion
tema: parametros-atributos
tags: [leccion, parametros-atributos, project]
fuente: [src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Codeunits/Cod50014.MotorLiquidacion.al, src/Tables/Tab110005.AtributoEntidadLiq.al]
actualizado: 2026-10-16
---

# SSI puede generar contribuciones patronales según el convenio

**En una frase:** SSI no significa "sin contribución patronal": la empresa paga lo que corresponde al convenio, y en 729/15 son USD 40 por cierre de marea como un SOM. Esto no determina la cuota descontada al empleado.

Confirmado por RRHH el 15/10/2026: SSI en el convenio de SOMU paga como SOMU; el capitán paga las contribuciones de la asociación; en el convenio del STIA, las del STIA. Enero de 2026: SOM y SSI de 729/15 pagan 40 USD × TC de la marea en cada cierre (56.200 con 1.405 y 56.600 con 1.415; 78 cierres). Dentro van `CAPACIT_SOMU` y `PR_ACSOC_SOMU`, 7,50 USD cada uno; la planilla `CONTRIBUCIONES EMPRESA.xlsx` dice sólo 7,50 + 7,50, y se sigue a Meta4 durante el paralelo. Los 44 SSI de FA sólo pagan el 8/1000 de Chubut ([[aporte-ley-3270-chubut]]); un SSI de 372/04 paga 5.004 y la regla no se entiende.

**Cómo aplicarlo:** parámetro `CONTRIB_SIND_USD` (eje SINDICATO) con una vigencia por sindicato **y convenio** (`CONTRIB_SIND_USD_SOM_729/15`, `_SSI_729/15`) y concepto `7092` sólo en `CIERRE_MAREA`: `CONTRIB_SIND_USD * TC_COMPRADOR`. El comparador lo excluye de las contribuciones junto con 7080, 7090 y 7091. Script: `scripts/ContribSindUsdPorMarea.sql`.

**Trampa que me hizo creer en un SOM de 768/19:** el filtro de vigencia vigente `Vigencia Hasta >= fecha OR Vigencia Hasta < '20000101'` toma como abierta cualquier vigencia terminada antes del 2000; el centinela abierto es `1753-01-01`, así que el corte tiene que ser `< '19000101'`. El "SOM" era una afiliación de 1995 de un empleado que hoy es ASO. El **Código de parámetro** además es `Code[20]`: un nombre de 22 caracteres trunca al insertar.

Ver [[otras-contribuciones-por-sindicato]] y [[sindicato-obra-social-atributos]].

## La cuota del empleado puede ser cero

En cuatro casos de febrero se verificó `SINDICATO = SSI` abierto en BC, valor numérico cero y
cuota voluntaria `C_SINDIC_VOL` de Meta4 cero. `8522` reemplaza ese cero por `PCT_CUOTA_SIND` del convenio mediante
`IF(PCT_SINDICATO > 0, PCT_SINDICATO, PCT_CUOTA_SIND)` y descuenta una cuota que no corresponde
al original. El concepto original multiplica por la tarifa `622` sin ese reemplazo.

La configuración aplicada el 16/10/2026 agrega una vigencia de `8522` desde **01/02/2026**:
`IF(TIENE_SINDICATO > 0, PCT_SINDICATO, PCT_CUOTA_SIND)`. La fuente `TIENE_SINDICATO`
cuenta filas de `Atributo Entidad Liq.` del empleado, atributo SINDICATO, con ambas fechas
de vigencia: inicio anterior o igual a la referencia y fin abierto o posterior o igual.
Una fila vigente con tarifa cero conserva ese cero; sólo la ausencia usa la tarifa del convenio.
La fórmula anterior se cierra al 31/01 sin cambiar su expresión ni los recibos de enero.

**Cero en `8522` no significa cero descuento sindical total.** Los cuatro casos ya tenían
`8563`, contribución solidaria SOMU, pagada por novedad; coincide con `CONT_SOLIDARIA`
original y reconstruye las retenciones y el líquido de Meta4. Ese pago se conserva.
Antes se descontaban ambos conceptos: eliminar el duplicado de `8522` es correcto.
El piloto mostró además que `8563` carece de fracciones fiscales: al retirar `8522`,
`CUOTA_SINDICAL_RET` deja de deducir la contribución solidaria efectivamente pagada.
Se aplicaron dos fracciones desde febrero hacia
`CUOTA_SINDICAL_RET` y `CUOTA_SIND_REAL`, sin fórmulas ni pagos adicionales. La lectura
global de enero no encontró pagos `8563`: esas altas no duplican su arrastre anual.

**No trasladar esa corrección a `4754`.** La comparación de las 51 líneas de cuota virtual
de los 48 empleados SSI de febrero coincide al centavo con `C_SINDICAL_SAC_MES` original.
Meta4 conserva esa cuota virtual incluso en los casos cuya cuota efectiva es cero. Por eso
`4754` mantiene su selección anterior de tasa, el adicional STIA y la capacitación PAT.
Su único cambio de base desde febrero es restar `#2803`, para compensar la nueva fracción
de francos no gozados hacia `BASE_EXT_IG4`; conserva la condición que excluye LIQ_FINAL.

No cambiar `7092/7093` por analogía: son contribuciones patronales con otra regla. La captura
final estable verificó los siete recibos de los cuatro casos: `8522` cero, `8563` ya pagado
conservado, `4754` sin trasladar el cambio de tasa y ambos acumuladores fiscales recompuestos.
Las retenciones mensuales coinciden con Meta4 con una tolerancia de dos centavos; el arrastre
de enero no se duplica. Esta verificación comprende esos cuatro casos, no todos los recibos.
Evidencia privada en `.snapshots/aplicar-netos-contribuciones-febrero-20261016/`.
Ver [[cuota-sindical-deducida-dos-veces]] y [[ganancias-familiares-meta4-vs-recibo-historico]].

## STIA (convenio 372/04): resuelto el 15/10/2026

El SSI de 372/04 (90440) pagaba 5.004 porque en ese convenio rige la contribución solidaria del STIA, y **depende del convenio, no del sindicato**: los 11 STI y el SSI pagan igual. Es `$4 + 2,5% × suma no remunerativa` (200.000 en enero y febrero → 5.004), y **+8% si la obra social es ADOS Trelew (603100)** → 21.004 (5 empleados). Verificado en los 12 empleados de los dos meses; `OTR_CONTR_A_PAG = C_CHUBUT + C_SINDICATO` sin resto.

Modelo: `CONTRIB_STIA_FIJO` (4) y `PCT_CONTRIB_NR` (eje OBRA_SOCIAL: 2,5 y `ADOS` 10,5) con vigentes del convenio 372/04, y concepto `7093` (`CONTRIB_STIA_FIJO + PCT_CONTRIB_NR / 100 * NO_REMUNERATIVO`, REGULAR / LIQ_FINAL / RELIQUIDACION). Script: `scripts/ContribStia372.sql`. El comparador lo excluye junto con 7080, 7090, 7091 y 7092.

## Un parámetro en USD con Variable TC ya llega en pesos (15/10/2026)

Los vigentes de `CONTRIB_SIND_USD` llevan `Moneda = USD` y `Cód. Variable TC = TC_COMPRADOR`. Con el TC cargado el motor entrega el parámetro **ya convertido** (56.200 con 1.405, 56.600 con 1.415, iguales a Meta4), así que el concepto `7092` es sólo `ROUND(CONTRIB_SIND_USD, PRECISION_REDONDEO)`. La primera fórmula multiplicaba otra vez por `TC_COMPRADOR` y daba 78.961.000 sin avisar. Sin el TC cargado el parámetro no resolvía y el concepto no generaba línea. Verificado en los cierres de 03062 y 04913.

## FEC: el INACAP (15/10/2026)

La única contribución de FEC (Comercio) es un aporte patronal mensual del 0,5% sobre el salario inicial de la categoría Maestranza A, que va al INACAP. Meta4: `CNT_INACAP` (5.278,975 = 0,5% × 1.055.795 en 90157, único FEC, convenio 130/75, categoría EC01 = Maestranza A). Modelo: `PCT_INACAP` (eje SINDICATO, `PCT_INACAP_FEC` = 0,5) y concepto `7094` = `PCT_INACAP / 100 * BASICO`, sólo REGULAR. **Ojo:** usa el `BASICO` del propio empleado porque EC01 es la única categoría de 130/75; si el convenio suma categorías hay que apuntar al BASICO de EC01. Script: `scripts/ContribInacapFec.sql`. El comparador ahora excluye de las contribuciones SICOSS **todo el rango 7090..7099**, así que un concepto nuevo de "otras contribuciones" no necesita tocar código.

Para los **aportes del empleado**, la configuración aplicada el 16/10 agrega inclusiones
del convenio 130/75 en `6010` y `6030` desde 01/02/2026. Enero conserva sus restricciones.
Los virtuales `4752/4753` ya eran irrestrictos: no se agregaron inclusiones para ellos.
Esto es independiente de INACAP y queda sujeto a la verificación del recálculo de febrero.
