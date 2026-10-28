---
aliases: ["Familiares actuales de Meta4 y recibos históricos"]
tipo: leccion
tema: descuentos-ganancias-sipa
tags: [leccion, ganancias, familiares, migracion-meta4, auditoria]
fuente: [scripts/CorregirFamiliaresMeta4.ps1, src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Codeunits/Cod110068.DeduccionFamiliarHistorica.al]
actualizado: 2026-10-12
---

# Familiares actuales de Meta4 y recibos históricos

## Qué se verificó

Se revisaron los 14 casos de enero con diferencias atribuibles a cargas de familia,
contra `M4T_FAMILIARES`, `M4T_FAM_SIRADIG`, las fórmulas originales 4927/4929
y los acumulados de los recibos archivados en BC. Para estos casos no había filas
en `M4T_FAM_SIRADIG`: la fuente disponible es el maestro de familiares.

- **4927:** considera C y CC. El porcentaje de hijos no limita al cónyuge/conviviente.
- **4929:** considera H, HI y G con porcentaje positivo. Evalúa la bandera
  `INCAPAC_FAM = S` por separado para duplicar la deducción y excluir el límite de edad.
  El código HI por sí solo no acredita incapacidad.
- La vigencia fiscal procede de `FEC_ALTA_IMP` y `FEC_BAJA_IMP`, no del alta del vínculo.
  En BC son los campos canónicos 50008/50009. Ver [[familiar-alta-impuesto]].

## Corrección aplicada

Se corrigieron **seis campos de clasificación**: cinco convivientes CC sin tipo pasan
a CONYUGE, y un familiar HI con bandera N pasa de HIJO_INC a HIJO. Los otros dos HI
con bandera S se conservaron. No se modificaron fechas, porcentajes, parentescos,
identidades ni los parámetros o fórmulas del impuesto.

La ejecución validó una escritura con rollback, respaldó el estado anterior,
aplicó las seis correcciones en una transacción SQL, reinició BC252 por su caché
y recalculó **seis meses completos / 17 documentos**, mediante
`EjecutarMesEmpleado`. No requiere nueva versión de la app.

La verificación posterior confirma:

- Las deducciones de los **14 casos coinciden con el maestro actual** de Oracle.
- **Cinco diferencias históricas** de impuesto quedan inferiores al centavo.
- Se conservan bruto, estado y todos los conceptos numéricos distintos de 5010;
  cambian también sus trazas de deducción y retención, como corresponde.
- Los saldos de francos por documento y dimensiones se conservan. La cuenta corriente
  agrega los asientos normales de reversión y reposteo: no comparar sus IDs o filas
  como si fueran un saldo pendiente mutable.
- Las otras cabeceras de enero permanecen idénticas; no se crearon documentos.

Fuentes, claves, importes y respaldos están en carpetas privadas ignoradas
`.snapshots/revision-familiares-20261012` y `.snapshots/familiares-ganancias-*`.
El script rechaza cambios si el familiar ya no coincide con la revisión o existen
resultados aprobados/contabilizados o posteriores que requieren otra cadena.

## Por qué todavía difieren nueve recibos históricos

El maestro actual y la foto de enero no son la misma fuente. Hay hijos/cónyuges y
banderas de incapacidad con últimas actualizaciones de marzo a mayo, posteriores
a la emisión de esos recibos, y efectos fiscales retroactivos. En otro caso el
recibo deduce un conviviente cuya baja fiscal actual es anterior a enero.

Uno de los cinco CC corregidos fue actualizado después de enero: su clasificación
correcta **amplía** la diferencia histórica, porque el maestro reconoce también
un hijo ausente en el recibo original. No se suprime esa declaración para forzar
la coincidencia del comparador.

La fecha de última actualización indica que la fila cambió, pero **no demuestra por
sí sola cuál era cada campo en enero**. No se dispone de historial de versiones de
esas filas para reconstruir ese estado. Reproducir exactamente el recibo original
requiere esa evidencia o una presentación histórica, no alterar el dato actual
para igualar una retención. La revisión verificó reglas y datos actuales; la
recuperación posterior de sus totales originales se documenta a continuación.

Ver [[Deducciones de Ganancias y familiares]], [[diferencias-descuentos-enero]]
y [[Comparador BC vs Meta4]].

## Recuperación de las deducciones originales (versión 639)

Se encontraron y compararon directamente las **20 corridas originales** de los nueve
casos en `M4T_ACUMULADO_RL2` de Oracle y el archivo literal de BC. Dentro de cada
empleado, `IG_CONYUGE_REM` e `IG_HIJOS_REM` conservan los mismos importes en todas
las corridas de enero. Se verificaron también los ceros. No hay presentaciones
SIRADIG disponibles para estos casos; no se reconstruyeron individuos ni fechas
de declaración que el archivo no conserva.

La codeunit 110068 **Deducción Familiar Histórica** importa esos totales mensuales
en el parámetro existente de infraestructura **FAM_HIST_M4**, con nueve valores
por empleado desde 01/01/2026. No hay tablas ni campos propios nuevos para este
mecanismo. El parámetro tiene Nombre Variable vacío: lo consulta únicamente
`CalcDeduccionesGanancias` mediante `Obtener`.

La fila sólo rige cuando su fecha coincide **exactamente** con el inicio del período
y la referencia está dentro de ese mes. No se arrastra a febrero ni se usa en
`LIQ_FINAL`, que requiere deducción anual. Fila presente con importe cero significa
deducción familiar original cero; fila ausente conserva el cálculo desde los
familiares actuales. Los gastos deducibles siguen su camino habitual.

El importador valida empleado, sociedad, fecha y contador de cada corrida, y sus
importes contra el archivo de BC. Guarda entradas/contadores en las Notas del valor.
El cálculo lee el parámetro importado, no las tablas del archivo literal. El detalle
de Ganancias identifica la fuente FAM_HIST_M4, sin inventar cantidades de familiares.
Para incorporar una declaración posterior al recalcular el mes original, debe
revisarse explícitamente esa foto histórica, no cambiar el maestro actual.

Aplicación terminada: **nueve fotos y 20 liquidaciones recalculadas**, mediante AL;
ocho diferencias de impuesto quedan inferiores al centavo. Las nueve deducciones
coinciden con los totales originales. Familiares actuales, fórmulas de conceptos,
bruto, estados, demás conceptos y saldos de francos permanecen iguales al respaldo.
La simulación validó el alcance mensual/final y la integración; detectó y revirtió
un residuo adicional de impuesto en el noveno caso, ajeno a la deducción familiar.
Luego se aplicaron las correcciones familiares verificadas sin modificar SAC.

## SAC fiscal adicional: aplicado en versión 643

Con autorización explícita se corrigieron las dos fórmulas vigentes desde
01/01/2026, conservando una única versión de cada concepto para todo enero.
El historial existente registra las fórmulas anteriores y nuevas mediante AL.

- **4750:** `ROUND((BASE_IG4 + BASE_EXT_IG4 - #4683) / 12, 0.0001)`.
  Excluye el incremento no remunerativo STIA de la provisión fiscal de SAC.
  El ingreso pagado permanece en BASE_IG4; no cambia el SAC real.
- **4754:** conserva la fórmula y tasas anteriores, reemplazando únicamente
  BASE_SAC_DEV por `ROUND((BASE_IG4 + BASE_EXT_IG4) / 12, 0.0001)`.
  Así conserva exactamente el importe previo de la cuota sindical virtual.

La simulación recalculó las nueve fotos familiares y los 13 casos de SAC fiscal
(21 empleados, 32 documentos, con un caso común). Terminó con rollback y los
doce conjuntos de datos respaldados quedaron idénticos. El control de aportantes
de BASE_SAC_DEV verifica vigencia: el aportante histórico cerrado en diciembre
no afecta enero. No se agregaron Commit ni se escribieron datos por SQL.

Después se aplicaron las fórmulas y se recalcularon los 13 empleados afectados.
Los importes de 4754, los haberes brutos, el SAC real, los aportes y demás importes
económicos se conservan; también los familiares actuales, valores/vigencias de
parámetros, estados, cabeceras ajenas y saldos netos de francos por dimensiones.
El recálculo actualiza los metadatos de algunos parámetros sin cambiar sus datos.
Se generan seis filas informativas de 5397 con importe/cantidad/base cero. Una
cabecera y sus líneas actualizan una categoría congelada a la categoría vigente
desde junio de 2024; sus importes no cambian y el maestro no se modificó.

Los 13 tienen corrida original archivada. Uno es LIQ_FINAL, con impuesto cero
y sin provisión mensual de SAC en Meta4; no corresponde certificar su 4750
informativo como provisión mensual original. Su impuesto y SAC real se conservan.
En otro caso, la diferencia conocida de antigüedad continúa reflejada en la base
de SAC, aunque el impuesto sigue siendo cero; esa regla salarial no se cambió.

Quedan conciliados al centavo los 14 casos familiares y los otros dos casos de
Ganancias por SAC STIA. Sobre los 329 empleados presentes en ambos sistemas,
queda un caso con diferencia de impuesto superior a un peso, explicado por los
aportes regulares aún pendientes de revisión. Hay otros 21 residuos inferiores
a un peso pero iguales o superiores al centavo; no afirmar coincidencia exacta
de todo enero ni esconderlos con un filtro de materialidad.

Los respaldos, fuentes, payload y verificaciones son privados en
`.snapshots/ganancias-historicas-20261012`. Las copias de código se guardan como
`.al.txt` para que el compilador no las tome como objetos adicionales.
