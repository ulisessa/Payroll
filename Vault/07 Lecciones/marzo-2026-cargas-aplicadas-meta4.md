---
aliases: ["Marzo 2026 - cargas aplicadas y conservación de enero y febrero"]
tipo: leccion
tema: migracion-meta4
tags: [meta4, migracion, marzo, parametros, produccion, vacaciones, auditoria]
fuente: [src/Codeunits/Cod50014.MotorLiquidacion.al, src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Codeunits/Cod50018.ProcesoLiqPorLotes.al, src/Tables/Tab60007.ConceptoLiquidacion.al]
actualizado: 2026-10-20
---

# Marzo 2026 - cargas aplicadas y conservación de enero y febrero

El 16/10/2026 se aplicaron los faltantes preparados en
[[prevuelo-marzo-2026-meta4]] y [[marzo-2026-proyectos-fechas-produccion]], con
autorización del usuario y enero/febrero sin actividad concurrente. Esta nota
registra la aplicación posterior a esas auditorías de lectura.

Se trabajó con parametrización y datos existentes. No se agregaron campos ni
tablas, no se modificó AL y no se crearon ni recalcularon recibos.
Evidencia privada: `.snapshots/aplicacion-marzo-20261016/`.

Las reglas para repetir la preparación en los próximos meses están en
[[Preparar un mes contra Meta4]]. Las excepciones y cantidades de esta nota conservan
su alcance propio de marzo.

## Precios, bono y feriado

- Se cargaron 41 vigencias de `BASICO` desde el 01/03: siete de convenio y 34
  personales en pesos. Se conservaron los acuerdos por grossing, en moneda
  extranjera y las vigencias futuras que ya existían.
- `4874` quedó limitado a marzo, convenio `372/04` y tipo `REGULAR`, con tres
  fracciones verificadas contra la norma original y mapeo `BONO_FIN_ANIO`.
  `REGULAR` evita duplicar el bono entre recibos adicionales: es una decisión de
  parametrización respaldada por los doce pagos tipo 1, no una condición literal
  adicional de la fórmula Meta4.
- Se cargaron 51 novedades de precio `1022` para marzo, con proyecto y tipo de
  cierre exactos. Quedaron pendientes para su aplicación por el cálculo normal.

## Anticipos y vacaciones

Se agregaron tres programas de anticipo administrativo y siete cuotas originales,
conservando los tres programas existentes. Tras comprobar las seis cuotas de
marzo se anularon las seis novedades `8870` redundantes, manteniendo su contenido
e historial. Al calcular, comprobar aplicación única al recibo `REGULAR` previsto.

Para vacaciones se cargaron dos ceros explícitos por bloques ya pagados, y una
cantidad informada que debe valorizar la fórmula. La nueva vigencia de `3553`
desde marzo prioriza la cantidad informada positiva; conserva la cantidad normal
cuando no existe esa entrada. La anterior quedó cerrada al 28/02, sin cambiar su
fórmula. Se registró el alta en el historial de fórmulas.

Se recuperó el tramo `AU9` nuevo de marzo y se desplazó el comienzo de `FR` al fin
de ese tramo. El bloque de vacaciones que comenzó en febrero permaneció intacto.
No se alteró el goce anterior para forzar el importe.

## Calendarios y proyectos

Se crearon cuatro calendarios propios del paralelo desde los originales: todas
sus reglas se conservan salvo el 23/03 laboral según Meta4; el 24/03 sigue feriado.
Marzo y los tres convenios pertinentes usan esos calendarios. Los calendarios
operativos originales siguen intactos; enero/febrero tienen las mismas reglas.

La hora de zarpe de **PP-802-000009** del 24/03 quedó a las **11:00**, confirmada
por el usuario. No se modificó la fecha de inicio ni se dedujo una hora desde el
histórico Meta4, que sólo acreditaba la clasificación de navegación.

> [!warning] Incluir presencia anterior al zarpe
> **PP-128-000062** mantiene su zarpe real del 01/04. Sus treinta asignaciones
> incluyen 31 días-persona `PS` de marzo. Crear los `DEVENGADOS` por
> empleado/asignación: el filtro masivo por fecha de comienzo del proyecto los
> excluye. Después comprobar un único recibo por empleado/proyecto y cobertura PS.

## Calidad de producción

El atributo de proyecto `DTO_CALIDAD_PROD` representa el 5 % de A28/61 desde
marzo. `APLICA_CALIDAD_PROD`, resuelto por puesto, conserva las excepciones
originales de Máquinas. `COEF_CALIDAD_PROD` obtiene el factor antes de sus lectores.

Se agregaron seis vigencias desde marzo: `2498`, `1534`, `2003`, `ADIC_PROD_PESCA`,
`BASE_PROD_CAL` y `PROD_EMPRESA`. Las versiones anteriores se cerraron al 28/02;
no cambiaron sus fórmulas. La nueva `1534` conserva el orden parametrizado de la
versión vigente del 04/02, incluyendo su rama de grossing.

El factor se aplica a la producción valorada antes de descontar devengados.
Conserva descarga física, precios, días, TC, mínimos y acuerdos netos. No implica
que todo bruto disminuya 5 %: las garantías y el grossing pueden absorberlo.
Los controles offline conservan los dos parciales; dan 0,95 para 28 salidas de
A28/61, 1 para sus dos oficiales de Máquinas y 1 para los otros 59 cierres.

## Comprobación y alcance

Las tres cargas quedaron comprometidas. La configuración posterior reproduce
21.544 selecciones efectivas de conceptos, parámetros, fracciones y restricciones
de enero/febrero, sin diferencias. Las once huellas completas confirman **686.501
filas históricas idénticas**, incluidas metadata y revisiones, contra la referencia
tomada después de que el usuario liberó ambos meses.

Se reinició `MicrosoftDynamicsNavServer$BC252` con guarda de inactividad y quedó
`Running`. Las huellas finales se obtuvieron después del reinicio. Resumen y
firmas en `cierre-verificado.json`; no confundirlo con los sellos de preparación.

Los datos familiares originales de marzo ya estaban representados; no se cargaron
correcciones de maestro sin una falta demostrada. Las diferencias fiscales de
salida siguen requiriendo su contraste propio. Los resultados de marzo quedan
pendientes del cálculo normal y su comparación contra Meta4.

## Calidad de producción: excepción de MR04 (Máquinas de marinería) (20/10/2026)

El 5 % de A28/61 se aplicaba también a 04526 y 03772 (puesto MR04 en BC, MQ05 en Meta4): su 2498 era 3.799.477,96 contra 3.999.450,49 de Meta4 (razón 0,95 exacta, −199.973 de bruto). Meta4 no descuenta a Máquinas, y BC sólo tenía esa excepción para oficiales (OF02/OF04...). Se agregó `APLICA_CALIDAD_PROD_729/15_MR04` = 0 desde el 1/3 (`scripts/CalidadProdMR04Maquinas.sql`). El puesto MQ05 se corresponde con MR04 en 18 de 20 marineros de BC; si aparece un MR04 que en Meta4 no sea de Máquinas (hay dos con CB05) en un proyecto con calidad, revisarlo.

## Atributos revisados contra Meta4 (20/10/2026)

Se agregaron dos asignaciones `TIPOEMPLEADO = MENSUAL`, número 1, con las fechas
originales de la historia de tipos de salario. No se importaron los tramos
quincenales anteriores ni se confundió esa clasificación con la de producción.

Los 16 casos de zona quedaron como `ZONA_DESFAVORABLE = SIN_ADICIONAL`, número
cero, desde el inicio original de sus historias vigentes. Se agregó sólo ese
valor de catálogo; no se modificaron los códigos existentes. Meta4 excluye
expresamente sus zonas subsidiarias de `2703`; las 51 corridas de enero a marzo
confirman pago cero. No se usó la zona fiscal como derecho salarial. La regla
reutilizable está en [[Preparar un mes contra Meta4]].

El único acuerdo mensual pendiente de `PRIMA_VAC_GU` se mantuvo sin completar
por indicación expresa del usuario, hasta confirmar contrato y fecha. Meta4 no
acredita una equivalencia que permita elegir `ADENTRO` o `ARRIBA`.

La primera guarda abortó sin escrituras ante una publicación concurrente. Se
documentó también un recálculo externo de marzo anterior a la aplicación y se
conservó su resultado. Desde el corte previo a la carga quedaron idénticas las
11.635 cabeceras y las 57 tablas operativas no intervenidas. La comparación
completa de las dos tablas intervenidas acredita exclusivamente 18 asignaciones
y un valor de catálogo nuevos, sin alterar sus filas anteriores. Las cuatro
capturas de configuración permanecieron iguales desde el inicio de la revisión.

Se renovó la caché con el servicio `MicrosoftDynamicsNavServer$BC252`, confirmado
`Running`. No se cambiaron fórmulas, metadatos de obligatoriedad ni recibos, ni
se ejecutaron recálculos. Evidencia privada y plan con origen por fila:
`.snapshots/atributos-meta4-20261020/cierre-verificado.json`.
