---
aliases: ["Enfermedad usa la base total original, no la base fiscal"]
tipo: leccion
tema: vacaciones-sac-licencias
tags: [leccion, ausentismo, migracion-meta4, acumuladores]
fuente: [scripts/AplicarBaseEnfermedadFebrero.ps1, scripts/CorregirBaseEnfermedadFebrero.sql, scripts/VerificarBaseEnfermedadFebrero.ps1, scripts/CorregirVinculoEnfermedad.sql, scripts/VerificarVinculoEnfermedad.ps1, src/Codeunits/Cod50016.ContextoLiquidacion.al, test/Codeunits/Cod110072.TestPromedioEnfermedad.al]
actualizado: 2026-10-16
---

# Enfermedad usa la base total original, no la base fiscal

En Meta4, el precio de enfermedad embarcada utiliza `TOT_PROMEDIOS`: total 19 de las salidas
originales. `TOT_REM_IMP` es la base fiscal y tiene otros aportes. No se pueden intercambiar.
La suma histórica admite los tipos de imputación `1, 10, 11, 12, 13, 14, 15, 3`.

La regla primaria completa está en [[enfermedad-regla-original-meta4]]. La
configuración de BC descrita abajo no equivale literalmente a Meta4 en todos los
períodos parciales ni en las ramas de jornales por hora.

La migración de 2024/2025 mezcló ambos criterios en `BASE_PROMEDIO`. Además, la creación de
cabeceras de 2024 exigía `SUM(TOT_REM_IMP) <> 0`: dejó afuera meses con `TOT_PROMEDIOS` y
haberes con aportes positivos. Desde 2026, el acumulador de un recibo real puede contener sólo
la porción remunerativa, aunque la enfermedad necesita el total previo al coeficiente.

## Configuración específica

Se aplicó una vigencia del `4110` desde febrero de 2026. Cambia su referencia y `Variable Base`
de `#PROM_AUS_MES` a `#PROM_ENF_MES`, conservando condición, días, coeficiente y fracciones.
La versión de enero se cierra al 31/1; `PROM_AUS_MES` y sus consumidores de accidente se conservan.

La primera configuración de `PROM_ENF_MES`, informativo de orden 360, utilizaba:

```text
IF(MESES_AUS >= 12,
 (PROM_AUS_12 + AUS_AJUSTE_HIST_12 + AUS_NO_REM_ACT_12)
   / MAX(1, MESES_PROM_AUS_12),
 (PROM_AUS_6 + AUS_AJUSTE_HIST_6 + AUS_NO_REM_ACT_6)
   / MAX(1, MESES_PROM_AUS_6))
```

- `AUS_AJUSTE_HIST_6/12` suma `AJ_HIST_AUS`, un informativo histórico sin distribución,
  impresión, devengo ni efecto sobre los totales del recibo. Su importe es
  `TOT_PROMEDIOS original - BASE_PROMEDIO migrado`. Admite ajustes positivos y negativos.
- Los meses omitidos de la migración se incorporan como cabeceras `HIST_REMUN` informativas,
  con importes económicos en cero y una sola línea `AJ_HIST_AUS`. No se inventa un pago histórico.
- `AUS_NO_REM_ACT_6/12` suma `BASE_PROMEDIO_NR` de recibos reales. Excluye `HIST_REMUN`, donde
  el ajuste ya reconstruye el total, y `LIQ_FINAL`, donde `AJ_PROM_PESQUERIA` lo reconstruye
  dentro de `BASE_PROMEDIO`. Así se evita sumar dos veces la misma porción.
- Esta primera reparación conservó empleado, estado distinto de borrador y los mismos tokens de
  ventana de `PROM_AUS_6/12`. El recorte por vínculo confirmado posteriormente se describe abajo.

## Alcance y validación

El histórico original se coteja en lectura con Oracle y con el archivo literal importado.
La reparación se limita a los empleados con enfermedad de febrero revisados; no equivale a
una conciliación de toda la historia de la empresa. La edición manual de un estado se restauró
sólo después de la confirmación expresa del usuario.

El control posterior de enfermedad de enero confirmó otro caso con el ancla y divisor
correctos: faltaban dos meses de 2024 con `TOT_REM_IMP = 0` y `TOT_PROMEDIOS > 0`.
Los otros diez meses coincidían con Oracle y los meses omitidos explicaban toda la diferencia.
Esto requiere completar el histórico informativo; no corregir el promedio con un porcentaje
ni clasificar automáticamente una novedad de enfermedad como precio original de Meta4.
Una novedad compensatoria de BC se debe retirar junto con la validación del cálculo normal,
después de reparar el histórico. La investigación del 16/10 fue sólo de lectura.

La escritura se ensayó con rollback y se cotejaron los respaldos antes de aplicar. Se verificaron
65 ajustes sobre cabeceras existentes y tres meses nuevos. El servicio BC252 se reinició y se
recalcularon los 22 empleados con días de enfermedad confirmados. Se conservaron todos sus días,
los estados y los resultados de enero; las líneas históricas originales y fuentes `PROM_AUS_*`
permanecieron intactas. No se detectaron cambios concurrentes fuera del alcance durante el cierre.

La prueba en ejecución valida la vigencia de febrero, el numerador/divisor efectivo y la base
visible del `4110`. Quince casos coinciden con Meta4 o tienen diferencias inferiores a diez
centavos. Persisten seis diferencias por recaídas y fracciones de alta ya documentadas; no se
fuerza una igualdad cambiando las ventanas aprobadas por RRHH.

## Vínculo actual confirmado el 13/10/2026

El usuario confirmó que enfermedad reconoce **sólo el vínculo actual**, como Meta4. Desde la
vigencia 2/2/2026, `PROM_ENF_MES` usa fuentes `ENF_BASE_6/12` y `ENF_NR_6/12`, con tokens
`ENF_PROM6_DESDE`, `ENF_PROM12_DESDE` y `ENF_PROM_HASTA`. El primer grupo suma
`BASE_PROMEDIO|AJ_HIST_AUS`; el segundo conserva las exclusiones de históricos y finales.
Las fuentes anteriores, los tokens `AUS_*` y el promedio usado por ART se conservan.

La ventana termina el último día del mes previo al **inicio de AU1**, y empieza en el mayor
entre el comienzo del semestre/año y el alta del vínculo que contenía ese inicio. Así, una
licencia continuada conserva el mismo promedio. Los nuevos divisores `DIV_PROM_ENF_6/12`:

- Miden días desde el alta hasta el primer día del mes de la enfermedad, sin sumar uno.
- Con al menos 181/362 días, dividen por 6/12.
- Con menos, dividen por `días / 30`, admitiendo fracciones menores que uno.
- Si el alta pertenece al mismo mes, devuelven cero; la fuente queda en una fecha centinela
  válida, evitando el filtro vacío y la lectura circular del recibo que se está calculando.

`4110` conserva su fórmula y ocho fracciones en la nueva vigencia. La base visible distingue
el promedio del tripulante de `BASE_AUSENTISMO` del mensualizado. Se versionó la fracción de
`1053` hacia esa base desde 2/1/2026: la antigüedad unificada debe seguir integrándola en
`372/04`, como ocurría con su concepto anterior.

En la configuración de BC, AU1 mensualizado cuenta el mes comercial de 30: enero omite el día 31 y febrero completa
los días faltantes en su último día calendario. Los tripulantes conservan los días calendario.
`DIAS_ALTA_30` aplica la misma regla, evitando una deducción de dos días en febrero completo.
La deducción espejo `4115` importada de Meta4 se conserva; no se elimina para recuperar AU1.
La revisión primaria del 15/10 confirmó que Meta4 completa febrero sólo si la
ausencia cubre todo el mes; un período parcial puede diferir de esta configuración.

Se publicó la versión **1.0.0.648**, se renovó la caché y se recalcularon los 23 casos de febrero.
La restauración de AU1 también requirió rehacer enero de ese empleado y su febrero en una
sola cadena atómica. Dieciocho casos coinciden con Meta4 dentro de diez centavos; persisten
cinco diferencias por ventanas de licencia y precios continuados. El resto de enero, los
históricos y los estados ajenos a la restauración conservaron sus valores.

La conciliación anterior corresponde al concepto de enfermedad, no al bruto completo.
Se detectó aparte una novedad `4683` presente en Meta4 y ausente en BC; ese faltante no integra
la base de enfermedad del mensualizado y queda identificado en el respaldo privado para revisión.

Las doce pruebas nuevas de ventana, divisor y mes comercial pasaron en el servidor. La suite
completa ejecutó 102 pruebas y reportó cinco fallas fuera de este cambio: comparación de
atributos, decimal con coma, corte de formato, filtros con apóstrofes y una prueba de antigüedad
que intenta rehacer enero con febrero ya calculado. No se considera aprobada la suite completa.

No se agregaron tablas ni campos. Los dos divisores se resuelven y siembran en el catálogo de
variables; el test nuevo está en los tres permisos y el runner. Los datos individuales y
respaldos se conservan fuera del vault, en `.snapshots/`.

## Conteo y promedio configurables

Desde la versión 1.0.0.649, la elección del calendario de enfermedad se expresa en las fórmulas
con el parámetro vigente `AUS_MES_COMERCIAL`. Las fuentes `DIAS_ENFERMEDAD` y `DIAS_ACCIDENTE`
cuentan días calendario; `DIAS_ENFERMEDAD_30` utiliza el agregado genérico `DIAS_OVERLAP_30`.
El estado se elige en los filtros de cada fuente. El motor no distingue AU1 de otras licencias
ni decide el calendario por el tipo de empleado. La configuración inicial conserva esa regla
mediante valores por convenio. Fórmula, condición y cantidad visible utilizan la misma elección.

`DIAS_ACC_PREVIOS` conserva el cálculo genérico `DIAS_ESTADO_PREVIOS`, con `Cód. Estado` visible
en Variables de Sistema. El inicio se busca en una licencia de ese mismo estado, evitando que
una ausencia diferente determine el corte del accidente.

El promedio usa una variable configurable `DIV_PROM_LIC`, cuyo campo `Cód. Estado` determina
el ancla, y tres parámetros vigentes: `PROM_LIC_MESES`, `PROM_LIC_UMBRAL` y `PROM_LIC_DIAS_MES`.
Las fuentes `ENF_BASE` y `ENF_NR` delimitan la historia mediante
`{PROM_LIC_DESDE:DIV_PROM_LIC}..{PROM_LIC_HASTA:DIV_PROM_LIC}`. Numerador y divisor leen la misma
definición y se recortan al vínculo vigente al inicio de la licencia. La configuración inicial
mantiene las ventanas y umbrales verificados contra Meta4. Los tokens antiguos se conservan
para las fórmulas anteriores; sus variables también deben tener estado y parámetros válidos.

El fin explícito de un intervalo tiene prioridad. Con `Fin Efectivo` y fin vacío se deriva del
inicio siguiente de la entidad, ignorando el filtro de estado al buscar ese siguiente registro.
El mes comercial aplica pesos sólo a días cubiertos por los tramos, incluidos sus huecos.

Los parámetros se seleccionan a la fecha de referencia de la liquidación. El ancla de una
licencia continuada permanece fija; una modificación futura de la regla puede cambiar su
ventana si se configura una nueva vigencia. Congelar también la regla al inicio requeriría
una decisión adicional, distinta de conservar el ancla de la licencia.

La siembra de variables generales no crea asociaciones de estados ni divisores incompletos.
Las instalaciones nuevas deben recibir las fuentes, filtros, parámetros y variables necesarias
como datos de configuración. La migración conserva fórmulas anteriores y agrega nuevas vigencias
con sus fracciones; los nombres que pasan de variable de sistema a fuente se trasladan en una
misma transacción para evitar colisiones.

La migración se ensayó con rollback, guardas de filas y conjuntos completos de filtros y
fracciones, y firma del plan y sus respaldos. Se aplicaron cinco fuentes, cuatro parámetros,
nueve valores y seis vigencias con veinticuatro fracciones. El servicio se reinició tras SQL.
La versión final instalada es **1.0.0.651**; pasaron las **34 pruebas** del subconjunto de
ausentismo y fin efectivo, incluidas las comparaciones en lectura con recibos calculados.
Esto no constituye una nueva aprobación de la suite completa, que conserva las fallas
documentadas en el cierre anterior.

Al comparar un recibo ya calculado, no se debe reconstruir todo su contexto actual: su consumo
de francos ya está en la cuenta corriente y la valoración FIFO puede pedir saldo que ya consumió.
La comparación de ausentismo carga sólo sus parámetros y consulta sus fuentes y divisores.
El runner abreviado entra en `OnRun` mediante una instancia tipada, para activar los eventos de
`TestRunner` y rechazar correctamente una corrida sin pruebas.

Se observaron cambios concurrentes de cuota sindical y otros conceptos ajenos a esta migración;
no se sobrescribieron. Los estados y la cuenta corriente conservaron sus registros. Los datos
individuales, los resultados y el detalle de concurrencia permanecen en el respaldo privado.

## Relacionado

- [[ventana-promedio-ausentismo]]
- [[historia-remuneraciones-migrada]]
- [[base-promedio-no-mezcla-porciones-y-totales]]
- [[recaida-accidente-mismo-valor]]
- [[generica-nueva-pisa-especifica-vieja]]
