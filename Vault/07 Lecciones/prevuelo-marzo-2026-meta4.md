---
aliases: ["Prevuelo de marzo de 2026 contra Meta4"]
tipo: leccion
tema: migracion-meta4
tags: [meta4, migracion, marzo, anticipos, salarios, ausentismo, auditoria]
fuente: [M4T_VAL_FASE_ALTA, M4T_VAL_CONVENIO_CATEGORIA, M4T_VAL_INCIDENCIA, M4T_CTA_CTE_ANTICIPOS, M4T_AUSENTISMOS, M4T_ACUMULADO_RL, M4T_ACUMULADO_RL2, src/Codeunits/Cod50016.ContextoLiquidacion.al]
actualizado: 2026-10-16
---

# Prevuelo de marzo de 2026 contra Meta4

Auditoría de lectura realizada el 16/10/2026 para preparar marzo. No se cargaron
datos, ejecutaron pruebas AL ni recalcularon recibos. Las consultas, las claves,
los planes y los importes están en `.snapshots/prevuelo-marzo-20261016/`.

La carga posterior autorizada quedó aplicada y verificada. Ver
[[marzo-2026-cargas-aplicadas-meta4]] para el alcance real y los controles de
conservación; esta nota mantiene el diagnóstico anterior a la aplicación.

La población original de marzo contiene 623 corridas de 349 empleados: 485
corridas salariales y 138 pagos de anticipo. Marzo existe en BC como Creado,
todavía sin cabeceras de liquidación en el corte revisado.

## Precios que faltan

Se preparó un plan privado de 41 altas de `BASICO` desde el 01/03/2026:

- Siete precios de Alimentación, con origen en `M4T_VAL_CONVENIO_CATEGORIA`,
  concepto `1002`, que alcanzan a doce empleados.
- Treinta y cuatro precios personales fijos en pesos de Fuera de Convenio, con
  origen en `M4T_VAL_FASE_ALTA`, concepto `1002`.

El modelo offline de selección reproduce los 46 precios originales al centavo.
Conserva enero/febrero, cuatro acuerdos por grossing-up y un básico en divisa.
Las categorías BC `CA02` y `CA10` son aliases descriptivos de las originales
`CA12` y `CA15`: el plan dirige sus precios a los códigos que BC ya utiliza,
sin reencuadrar empleados sólo para resolver el precio.

`M4T_HIST_DATOS_SALARIALES` no era la fuente de esos precios: sus importes en
la extracción eran cero. No convertir `PR_SUELDO` calculado a pesos en contrato
personal cuando el origen es un neto acordado o una divisa.

## Bono y precios informados

Meta4 tiene una nueva vigencia de `4874`, Bono Fin de Año STIA, limitada a marzo.
La fórmula y la norma originales aplican a convenio `CA`; doce pagos originales
la confirman. No hay concepto ni equivalencia BC en el corte. Debe parametrizarse
con sus aportes originales antes de considerar completa la base de marzo.

Existen 51 precios originales `1022` de marzo, todos asociados a cierres de marea,
sin novedades equivalentes en BC. El auxiliar informativo y el fallback ya
implementados permiten incorporarlos conservando los días y el cálculo general.
Los días/horas/indicadores de otros conceptos no se comparan como si cada `VALOR`
original fuera el importe de un haber.

## Anticipos y programación

Los descuentos por empleado de `8850`, `8840` y `8830` coinciden con la cuenta
corriente original. No corresponde volver a cargar esas sumas.

Las seis cuotas AHA de marzo tienen novedad `8870`; sólo dos tienen también
programación de préstamo. Deben completarse los otros cuatro programas y revisar
las novedades redundantes de las dos cuotas ya programadas. El motor materializa
primero la cuota y respeta esa incidencia al procesar la novedad: no se demostró
doble descuento en el mismo recibo. Una novedad sobrante puede seguir disponible
para otra liquidación del mes, por lo que el destino debe quedar definido.

La trazabilidad debe distinguir entradas originales de salidas importadas. Se
identificaron 59 novedades con importe coincidente con una salida calculada sin
entrada manual directa acreditada; no deben eliminarse ni ratificarse sólo por
esa coincidencia. Ver [[prevuelo-febrero-2026-migracion-meta4]].

## Calendario, estados y acuerdos

Las 349 fases originales coinciden con BC y los 10.394 días activos revisados
tienen un único estado. Convenios y categorías resueltos existen en el catálogo.
Los quince acuerdos de oficiales poteros conservan sus escalones vigentes; los
tres precios informados de enfermedad de marzo coinciden con el original y no
hay novedades activas de importe `4110` en ese mes.

El calendario BASE de BC marca 23 y 24 de marzo; Meta4 sólo registra el 24.
La diferencia del 23 requiere definir su tratamiento para el paralelo hasta junio,
sin atribuir automáticamente a un error legal ninguno de los dos calendarios.

Persisten dos controles de vacaciones: faltan ceros preventivos en marzo y abril
para un bloque ya pagado en febrero; otro caso tiene AU9 en AUSENTISMOS y FR en
HIST_ESTADOS/BC, y el pago original incluye un día de un tramo iniciado antes de
marzo. Corregir sólo el estado del tramo nuevo no reproduce toda la cantidad.
`ANT_VAC_LIQ` no resolvió esa diferencia. No alterar el goce para forzar el pago.

También debe verificarse que la creación masiva incluya los días PS de marzo de
una marea cuyo zarpe es el 01/04. El filtro por comienzo del proyecto y el recorrido
por asignaciones del empleado no abarcan necesariamente los mismos proyectos.
El contraste ampliado de viajes, kilos, calidad y tarifas por puesto está en
[[marzo-2026-proyectos-fechas-produccion]].

## Ganancias y límites del control

Los topes SIPA/obra social y las referencias mensuales de mínimo no imponible,
deducción especial, cónyuge e hijos coinciden con Meta4 a la precisión mensual.
Los valores acumulados originales de marzo se normalizaron por tres cuando
correspondía; no deben compararse directamente con parámetros mensuales.

Las fotos `FAM_HIST_M4` existentes son de enero y no se arrastran a marzo.
Un modelo offline con el maestro familiar actual al 31/03, multiplicado por tres,
coincide con 317 de 336 corridas mensuales; las otras 19 requieren revisar el
histórico y los cambios fiscales del año. Evaluar cada corte de enero/febrero/marzo
y sumar mejora la coincidencia a 321 de 336: quedan quince diferencias y se observan
cinco cambios de composición entre esos cortes. No equivalen a maestros incorrectos
ni certifican el impuesto final. Una foto acumulada no se debe importar como
deducción mensual. Ver [[ganancias-familiares-meta4-vs-recibo-historico]].

El contraste posterior de entradas acredita las 1.013 filas familiares originales
en BC, incluidas dos cotejadas como multiconjunto. Los catorce eventos de marzo
conservan vigencias, fechas fiscales y porcentaje; las 31 incapacidades originales
tienen clasificación compatible. No hay una carga faltante demostrada para esos
eventos. Esto no resuelve ni convierte en error de maestro las quince diferencias
de salidas fiscales. Evidencia en el subdirectorio privado
`agente-encuadres/familiares-marzo-entradas/` del prevuelo.

## Relacionado

- [[prevuelo-febrero-2026-migracion-meta4]]
- [[enfermedad-regla-original-meta4]]
- [[vacaciones-fraccionadas-meta4-paga-el-bloque]]
- [[generica-nueva-pisa-especifica-vieja]]
