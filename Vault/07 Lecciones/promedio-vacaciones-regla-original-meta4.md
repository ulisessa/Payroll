---
aliases: ["Regla original del promedio de vacaciones en Meta4"]
tipo: leccion
tema: vacaciones-sac-licencias
tags: [leccion, vacaciones, migracion-meta4, promedios]
fuente: [M4_TEXTO_FORMULA_1, M4SYS_SYSLONG, M4_ACUMULADO_RL]
actualizado: 2026-10-16
---

# Regla original del promedio de vacaciones en Meta4

**Fórmula** (leída de Oracle el 16/10/2026): `3553 = 4056 × 3550` (precio × unidades; en CG se descuenta el 4676); `4056` para MR/OF/FE es `4050 / 25` (FA/CE/MA/CA/EC usan `(4040 + 4443 + 4444 + 4573 + 4683 + 4895) / 25`; JO usa el mínimo entre el promedio y el valor hora); `4050` = `PROM_6_ULT_MES`.

`4050` suma `TOT_PROMEDIOS` con la TI `ACM_6_MESES_EXTR`: misma sociedad, empleado y **alta del vínculo**, tipos de imputación `1,10,11,12,13,14,15,3`, `FEC_IMPUTACION` entre el primer día del mes de (proceso − 6 meses) y el último día del mes anterior, y anterior a la fecha de proceso. Divisor: 6 si el alta lleva ≥ 181 días a la fecha de proceso; si no, `total / días desde el alta × 30`; alta del mismo mes = 0. Es la **misma TI de enfermedad** (ver [[enfermedad-regla-original-meta4]]), pero **por `FEC_IMPUTACION`**, no por mes contable.

**Medición sobre las 116 vacaciones de enero y febrero de 2026** (Oracle,
`M4_ACUMULADO_RL`): en **111** coinciden tanto la suma literal de `TOT_PROMEDIOS`
como la restringida a corridas con `TOT_REM_IMP` distinto de cero. En tres casos
de enero Meta4 excluyó las corridas sin base fiscal; en uno de febrero las incluyó;
otro caso de enero necesita sus ajustes históricos `AJ_HIST_AUS`.

La ventana temporal del caso de febrero sí contiene el antecedente de accidente.
El lector de BC suma líneas `BASE_PROMEDIO`, donde ese antecedente no está:
no hay un filtro de accidente durante el cálculo. La igualdad con la selección
por base fiscal está probada; no se localizó el predicado del importador histórico
para atribuirle una implementación concreta. No hay un flag original que explique
por qué Meta4 seleccionó distinto los tres testigos de enero.

No modificar globalmente `BASE_PROMEDIO`: también alimenta SAC y enfermedad,
y cambiar su historia rompería los testigos de enero.

## Comprobación posterior del precio

La revisión de febrero del 16/10/2026 confirma que en el caso explicado por ese
antecedente los días ya coinciden, el divisor sigue siendo seis meses y el
coeficiente es uno. Incorporar el único antecedente omitido reproduce el precio
y el importe original a menos de un centavo. Esto localiza la diferencia en la
base histórica; todavía no demuestra por qué Meta4 seleccionó ese antecedente
y excluyó otros equivalentes. No clasificarlo como error original definitivo.

## Separación aplicada desde febrero

Se cargaron los antecedentes auténticos faltantes como valores de
`HIST_VAC_NOFISC`, sin variable automática. La fuente `VAC_HIST_NOFISC` suma
por empleado y por la misma ventana del promedio; el `3553` de febrero suma
ese resultado a `SUMA_REM_VAC`. Conserva divisor, días, coeficiente y rama de
grossing-up. No es un precio personal impuesto para igualar el recibo.

La carga conserva procedencia por corrida, alta del vínculo y fecha, incluye
signos negativos y descarta un antecedente ya representado en BC. Son siete
grupos históricos para cuatro empleados. Los antecedentes revisados pertenecen
a una única fase exacta, sin otra alta en el mes; no generalizar ese supuesto
a una migración futura sin repetir el control de vínculos.

El contraste previo cubre 64 vacaciones de enero y 52 de febrero: la nueva
selección cambia sólo el caso diagnosticado de febrero. Se cierra la vigencia
anterior al 31/01 y la nueva termina el 28/02; se conserva la versión futura
de marzo y las dependencias anteriores de enero. La verificación final del
recálculo confirma 51 importes de vacaciones idénticos al respaldo y el caso
corregido a menos de un centavo de Meta4; enero conserva sus filas y revisiones.

Evidencia privada: `.snapshots/aplicar-netos-contribuciones-febrero-20261016/promedios/`.
Ver [[Preparar un mes contra Meta4]] y [[enfermedad-regla-original-meta4]].
