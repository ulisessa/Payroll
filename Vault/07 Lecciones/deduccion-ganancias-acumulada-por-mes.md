---
aliases: ["La deducción de familia de Ganancias se acumula mes por mes"]
tipo: leccion
tema: ganancias
tags: [leccion, ganancias, motor-calculo]
origen: 4b151484-1884-4407-a1bb-01b9ea3741c8
actualizado: 2026-10-20
---

# La deducción de familia de Ganancias se acumula mes por mes

El 5010 multiplicaba la deducción del mes en curso por los meses del año: `(MNI + DESP + DEDUC_GANANCIAS) × MES_ANUAL`. Meta4 acumula mes por mes. Las dos cuentas coinciden mientras la ficha de familia no cambie dentro del año y se separan cuando cambia.

## Casos de marzo de 2026

- **Hijo que cumple 18 en enero o febrero** (00794, 04169, 03664): Meta4 lo deduce hasta su mes de cumpleaños (el mes del cumpleaños cuenta); BC, con la ficha de marzo, no lo deducía ningún mes. Hijo nacido el 1/1/2008: sólo enero; el 17/1: sólo enero; el 5/2: enero y febrero.
- **Altas y bajas de mitad de año** (90251, 04874, 04877, 04843, 04809, 04313): Meta4 había liquidado marzo con la ficha de ese momento y la corrigió en abril con fechas retroactivas; ver `FamiliaGananciasComoMeta4Marzo.sql` (se revierte en abril).

## Cambio

- `Cod50016`: variable de sistema nueva **`DEDUC_GANANCIAS_ACUM`** (`CalcDeduccionesGananciasAcum`): suma, para cada mes de enero al de la fecha de referencia, la deducción familiar de ese mes calculada con los familiares tal como estaban a esa fecha (alta de impuesto a fin de mes, baja no anterior al inicio, tope de edad al inicio del mes, parámetro vigente a esa fecha, foto mensual si existe), más los gastos declarados vigentes por los meses transcurridos (esos siguen la regla de siempre).
- El loop de familiares de `CalcDeduccionesGanancias` pasó a `FraccionesFamiliares`, que usan el mes en curso y cada mes del acumulado: una sola regla. `DentroDeEdad` quedó como `DentroDeEdadAl(familiar, inicio del mes)`.
- 5010: vigencia nueva desde el 1/3/2026 (`scripts/DeduccionGananciasAcumuladaPorMes.sql`) con `((MNI_ANUAL + DESP_4CAT_ANUAL) * MES_ANUAL + DEDUC_GANANCIAS_ACUM)` en las dos cuentas (la deducción y su doceava parte). La rama de LIQ_FINAL y el 5020 no cambian.
- Publicado en la versión 1.0.0.676. La fila de la variable la siembra el upgrade (Cod50077): el primer intento de publicar falló porque la descripción pasaba los 100 caracteres.

> [!warning] Sin verificar
> No se recalculó ninguna liquidación con la fórmula nueva. Para quien tiene la ficha estable no cambia nada; los que deberían moverse son 00794, 04169 y 03664 y los seis de la ficha ajustada. Los meses de enero y febrero siguen con la vigencia anterior del 5010.

## Las fotos mensuales de Meta4 no entran en el acumulado (20/10/2026, versión 1.0.0.678)

Primer intento (1.0.0.676): el acumulado sumaba la foto `FAM_HIST_M4` de un mes como un mes más; 00794 y 04169 quedaron pasados porque la foto de febrero es el **acumulado de Meta4 a febrero dividido 2**. Segundo intento (1.0.0.677): una foto fijaba el acumulado a ese mes (`foto × mes`); arregló 00794 y 04169 pero rompió 04926 y 90447, porque la foto es la ficha **de entonces** y no ve una alta retroactiva cargada después: en marzo Meta4 acumuló de golpe tres meses de un hijo dado de alta el 6/3 con fecha 1/1 (611.716), y la foto de febrero tenía cero. Con la regla vieja (×3) esos dos coincidían de casualidad (un hijo × 3 meses = tres hijo-mes).

Versión final: el acumulado calcula **cada mes con la ficha actual y no usa fotos**. Eso da el acumulado de Meta4 en los cuatro casos (00794: hijo de 18 años sólo en enero → 1.416.896; 04169: 203.905; 04926: 611.716; 90447: 3.048.139) y recoge solos los retroactivos. Las fotos siguen valiendo en el mes que corresponden (`CalcDeduccionesGanancias`, sin cambio), que es para lo que se importaron.
