---
aliases: ["El coeficiente del franco no cambia los días FIFO"]
tipo: leccion
tema: francos
tags: [francos, pesqueria, sac, liquidacion-final]
fuente: [src/Codeunits/Cod50014.MotorLiquidacion.al, src/Tables/Tab60007.ConceptoLiquidacion.al, scripts/CorregirFrancosPesqueriaFinal.sql]
actualizado: 2026-10-11
---

# El coeficiente del franco no cambia los días FIFO

El concepto con rol Consumo devuelve **días**, no pesos. Aplicar pesquería en su fórmula principal
reduce los días consumidos. El motor dispone ahora de `Factor Importe Consumo`: vacío conserva el
comportamiento previo; una fórmula configurada multiplica el importe de cada tajada FIFO después
de calcular su cantidad. Se valida `0 < factor <= 1`, se redondea con `PRECISION_REDONDEO` sólo
cuando el factor es distinto de uno y el total aportado a los acumuladores suma los importes pagados.
La traza conserva la fórmula del factor, su resultado y sus variables. No cambia el precio del lote.

## Configuración coordinada

El script `scripts/CorregirFrancosPesqueriaFinal.sql` prepara seis versiones desde **02/01/2026**.
Esa fecha conserva las versiones ya existentes del 01/01; las ocho finales verificadas de enero
se liquidan al 31/01. No retrotraer esta solución al 01/01 sin definir otra política de vigencias.

- `1063`: fórmula principal `DIAS_FRANCOS_PERIODO`; factor
  `IF(TIPO_LIQ = 'LIQ_FINAL', #COEF_PESQUERIA, 1)`.
- `3554`: en `LIQ_FINAL`, sólo `#1063 / coeficiente * (1 - coeficiente)`;
  para los otros tipos conserva la fórmula previa. Las indemnizaciones quedan fuera del corte final.
- `2803`: resta el franco completo reconstruido, para conservar la indemnización de días no gozados.
- `1603` y `2083`: conservan la lectura del franco completo en la final. Este cambio no redefine
  la diferencia de puesto ni los aumentos: mantiene la semántica que tenían antes del desdoblamiento.
- `AJ_PROM_PESQUERIA`: incorpora también el complemento no remunerativo del `1063`. La proporción
  del `1603` conserva el denominador con franco completo. La única fracción del ajuste sigue siendo
  `BASE_PROMEDIO`; no se agrega una fracción del `3554` a esa base y no se duplica el complemento.

## Estado y verificación

Implementación AL y configuración preparadas, previsualización SQL ejecutada en las ocho finales.
El sueldo de francos y el complemento coinciden al centavo con la historia importada de Meta4;
la recomposición conserva la base del SAC, salvo precisión interna de redondeo sin diferencia al centavo.
Esto es **previsualización**, no una corrida del motor nuevo. Las ramas adicionales de `1603`
y `2083` requieren contraste si hay combinaciones no presentes en las finales verificadas.

**Pendiente de publicar**: el campo nuevo exige publicación completa con Synchronize. La versión
local 1.0.0.612 ya está instalada globalmente; según [[Versionado de app.json]], el usuario sube
la versión al publicar. No se aplicó aún configuración SQL: el script rechaza la aplicación sin
el campo publicado. Después de publicar, aplicar las seis versiones en una transacción, refrescar
la caché del servicio y recalcular; verificar días, 1063, 3554, 2803, BASE_PROMEDIO y SAC.

Ver [[francos-fifo-ledger]], [[base-promedio-no-mezcla-porciones-y-totales]]
y [[Pendientes liquidación final]].

## Configuración aplicada después de publicar

El 11/10/2026 se confirmó el campo nuevo en SQL y se aplicaron las seis versiones en una
transacción. Las fórmulas históricas se conservaron y sus intervalos se encadenaron hasta
el 01/01/2026. El recálculo que el usuario había hecho antes de esa carga todavía ejecutó
la configuración anterior. Pendiente verificar una nueva corrida posterior a la carga.


Caché refrescada: se reinició MicrosoftDynamicsNavServer$BC252 en mimir y se confirmó
Running → Stopped → Running después de cargar las versiones.


## Rectificación del alcance del 3554

El recálculo posterior confirmó 1063, días consumidos, 2803 y SAC, pero el 3554 quedó corto.
La premisa de limitarlo sólo al franco era incompleta: Meta4 paga también el complemento de
puerto y gratificación en TP_IMPUT=15; BC reúne esos haberes en la final. La comparación correcta
suma TP_IMPUT=14 y 15. La reconstrucción informativa de BASE_PROMEDIO ya contenía ambos tramos,
pero ese informativo no paga un haber.

Aplicada nueva versión de 3554 desde 03/01/2026 mediante
`scripts/CorregirComplementoPuertoFinal.sql`: la rama LIQ_FINAL reproduce la reconstrucción
completa de AJ_PROM_PESQUERIA mediante sus componentes directos. No lee #AJ_PROM_PESQUERIA,
porque su orden 469 es posterior al 3554 (452). Todos los componentes están disponibles;
el último es 1023 (450). Otras liquidaciones conservan la fórmula histórica.
No se alteraron las fracciones ni la base de promedio: el complemento ya se incorporaba una vez
por el informativo. Quedan excluidas las indemnizaciones. Pendiente verificar el nuevo recálculo.
