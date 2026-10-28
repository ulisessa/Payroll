---
tipo: proceso
tags: [francos, fifo, matriz, reversión]
fuente: [src/Tables/Tab110065.MovimientoFrancoLiq.al, src/Codeunits/Cod110059.CuentaCorrienteFrancos.al, src/Codeunits/Cod50014.MotorLiquidacion.al, src/Pages/Pag110065.CuentaCorrienteFrancos.al]
actualizado: 2026-10-25
---

# Cuenta corriente y matriz de francos

## Lecturas de Total optimizadas (25/10/2026, pendientes de publicar)

`Total` filtra `Movimiento Franco Liq.Revertido = false`. Es un FlowField de existencia
por `Revierte Movimiento`, calculado por SQL y apoyado en la clave Reversion existente;
no es un saldo ni una marca persistida. Reemplaza la consulta de reversión por cada fila.
La comprobación de una línea ya asentada reúne documento, línea, tipo Devengo y ausencia
de reversión en una sola existencia. Los escritores y validadores de asiento conservan
sus métodos anteriores; no se modifican movimientos, trazas ni llamadas a `Commit`.

El alcance de la reversión sigue siendo global por número, sin recortar empleado, fecha,
documento ni tipo. La existencia de un origen tampoco se restringe al ámbito temporal de
la suma. Se mantienen corte de fase, exclusión de documento, inclusividad, precisión y
orden por clave primaria, incluido el comportamiento previo del rol Ninguno.

Los roles se recuerdan únicamente dentro de cada invocación: por código/versión exacta,
y por fecha de línea cuando hace falta la búsqueda de respaldo. Se conserva la asimetría
anterior: Fuente Matriz convierte la coincidencia exacta en Consumo; el respaldo devuelve
Rol Franco. La siguiente llamada vuelve a leer líneas, fases, versiones y movimientos.
Las proyecciones parciales cargan sólo los campos utilizados.

La reproducción independiente en memoria del estado estable de 468 recibos comparó
5.616 combinaciones de rol, fecha inclusiva/exclusiva y documento excluido/vacío:
cero diferencias frente al algoritmo anterior. No equivale a ejecutar AL ni a validar
todos los importes del motor. Cinco regresiones nuevas cubren mutaciones entre llamadas,
reversiones fuera del ámbito, versiones y matriz, precisión y conservación de trazas.
Están compiladas; su ejecución en BC queda pendiente de instalar el paquete en la empresa
aislada, mediante `Runner Tests Liq.EjecutarLecturasParciales` (61 casos, 15 de francos).
No usar el runner histórico sobre ArbuTest para esta validación.

Evidencia agregada: `artifacts/optimizacion-total-francos-20261025/`. Ver
[[Rendimiento y caché del cálculo]] y [[Tests automatizados]].

Publicada y aplicada en BC252 / ArbuTest (versión 1.0.0.629). El concepto 1063 usa la matriz desde 04/01/2026; las versiones previas conservan su fórmula de días. Las seis pruebas de integración pasaron con rollback y se recalcularon los documentos de enero alcanzados por la conversión.

## Criterio de redondeo durante la migración

La confirmación funcional aportada por el usuario el 15/10/2026 distingue dos reglas: Meta4 redondea los francos devengados en cada liquidación; el criterio posterior de ARB conserva el devengo fraccionario y redondea al pagar. El usuario confirmó la opción 2 de la consulta de vigencia: conservar Meta4 hasta el **30/6/2026 inclusive** y aplicar el nuevo criterio desde el **1/7/2026**.

> [!note] Fecha confirmada; parametrización pendiente
> La confirmación fija la fecha de corte, pero todavía no se aplicó una nueva vigencia en BC. Antes deben revisarse conjuntamente el devengo 1062, su valorización 2803 y el redondeo del saldo al pagar, respetando las fracciones del lote y evitando consumir más saldo del disponible.

**Redondeo verificado contra Oracle el 15/10/2026:** el concepto original 1059 (`DS_FRANCOS_DEV`) usa `RedondeoN(dias_dev, 0)` y su descripción distingue valores menores a 1,5 (resultado 1) de valores mayores o iguales (resultado 2). Es redondeo al entero más cercano, no techo general. El `ROUND(..., 1)` del 1062 vigente en BC coincide en esa dirección; sumar después los feriados enteros no altera esa equivalencia. No se necesita cambiar la fórmula actual por esta confirmación.

En BC el `CIERRE_MAREA` usa el tramo del mes de cierre, no toda la marea otra vez. El devengo mensual previo y el tramo final se redondean por separado. Por eso su suma puede superar al redondeo único de toda la marea, sin duplicar días de cobertura: es consecuencia del criterio temporal aceptado, no un motivo para descontar de nuevo el devengo de enero.

La transición debe parametrizarse por vigencia del devengo y del pago, conservando lotes, consumos y reversiones. No se deben redondear otra vez los lotes al asentarlos en la cuenta corriente ni reescribir recibos ya calculados. El error de calendario reconocido para tres finales de enero se trata por separado: [[feriado-de-guardia-del-1-de-enero]].

El objetivo confirmado para enero a junio es poder **recalcular y reproducir los resultados de Meta4**, incluidas las tres omisiones conocidas del feriado del 1/1. Se admiten las novedades individuales autorizadas para esa compatibilidad; no convertir esas omisiones en una condición general de la fórmula ni duplicar novedades originales ya cargadas.

## Cuenta corriente

`Movimiento Franco Liq.` conserva devengos positivos, consumos negativos y contramovimientos. El lote es el identificador del movimiento de devengo. No hay un campo de pendientes que se actualice: el saldo es la suma de movimientos del lote.

### Fecha de corte del cálculo (corrección comprobada el 15/10/2026)

El saldo solicitado por una liquidación debe tener la misma fecha de corte que su matriz. La
consulta global incluía devengos de recibos posteriores ya calculados; al valuar un cierre anterior,
la matriz rechazaba correctamente esos lotes futuros y daba un faltante aparente. El error podía
ocurrir al precalcular `PAGO_FRANCOS_SALDO`, aunque el cierre no pagara el concepto 1063.

La nueva sobrecarga `SaldoFrancos(Empleado, Documento, FechaCorte)` incluye devengos y consumos
hasta esa fecha y excluye la pasada del documento actual. `SALDO_FRANCOS`, `PAGO_FRANCOS_SALDO`,
la guarda de consumo tradicional y los recorridos FIFO usan el corte del recibo. La búsqueda del
último lote para el precio tampoco toma un origen futuro. La consulta de dos argumentos sigue
siendo global; `SaldoFrancosAFecha`, usado para la duración de estados, conserva su consumo
estrictamente anterior al inicio. La guarda de asiento contra consumos posteriores permanece global:
mostrar saldo histórico no habilita aplicar dos veces un lote ya comprometido.

Compilación sin errores y reconstrucción independiente del caso sobre una captura estable, sólo
con archivos locales. Se agregaron dos regresiones para cuentas activas y para el camino anterior
a inicializar la cuenta, con devengos futuros, consumos futuros, exclusión del documento y reversión.
Están compiladas, sin ejecutar suites sobre la empresa operativa. La intervención no cambió
fórmulas, movimientos, estados ni recibos. El usuario informó su publicación; el cálculo posterior
del cierre que fallaba terminó Calculado y su resumen tomó el saldo histórico correcto, con un
único devengo propio asentado. La captura posterior de febrero es completa y estable: todos los
recibos están Calculados, sin anomalías del ledger ni residuos de prueba. La revisión no ejecutó
el recálculo. `app.json` local conserva su versión; no se deduce de ello la identidad del paquete
instalado. Ver [[Tests automatizados]] y [[Versionado de app.json]].

La tabla nueva es necesaria porque las líneas del recibo se borran al recalcular o eliminar. La cuenta conserva documento y línea de origen sin exigir que sigan existiendo. Los movimientos guardan fecha efectiva; `SystemCreatedAt` registra cuándo se asentaron. Las reversiones usan la fecha efectiva original: las consultas muestran la situación vigente, no una reconstrucción de lo que se conocía en una fecha pasada.

- Cierre del cálculo: registra créditos y aplicaciones de la pasada definitiva, después del grossing-up.
- Recálculo: revierte movimientos previos antes de eliminar líneas.
- Reapertura y eliminación: agregan contramovimientos; repetir no duplica la reversión.
- Saldo inicial: su aplicación registra los nuevos lotes y su reversión revierte sólo los lotes seleccionados.
- Devengo usado por otra liquidación: bloquea la reversión hasta revertir la liquidación dependiente.
- Concurrencia: el asiento bloquea la tabla y vuelve a comprobar el saldo antes de insertar consumos. No agrega `Commit`.

## Reconstrucción inicial

Desde la ficha del empleado, **Cuenta corriente de francos → Reconstruir cuenta del empleado**. Al calcular con un concepto de matriz aplicable, el motor también inicializa la cuenta automáticamente antes de retirar las líneas del cálculo anterior. Es una operación explícita e idempotente; no cambia importes ni líneas de recibos. Incluye documentos no borradores y reconoce devengo/consumo por la versión del concepto registrada en la línea, con búsqueda por fecha si no hay versión exacta.

El histórico no guardaba aplicaciones a lotes. La acción reconstruye FIFO en orden de fecha, identifica esos movimientos como `Reconstruido` y exige devengo suficiente a la fecha de cada consumo. Si falla, la transacción revierte también el marcador de activación. No interpreta como consumos los conceptos históricos sin ese rol ni infiere días a partir de sus importes.

> [!note] Reconstrucción histórica verificada para enero
> La prueba de reconstrucción de las cuentas con consumo de enero pasó con rollback antes de su aplicación. La atribución de consumos históricos a lotes es una reconstrucción FIFO, no información que antes se hubiera persistido.

## Matriz

El buffer temporal existente `Lote Franco Buffer Liq.` se amplía con empleado, puesto, estado, período, identificador de lote/línea y selección. Armar o valuar una matriz no consume días. La pesquería se obtiene del origen y el precio mantiene el convenio/categoría del documento que paga; ver [[valor-franco-por-terna]].

En una **nueva vigencia** del concepto:

| Campo | Ejemplo |
|---|---|
| Fuente Matriz | `FRANCOS_FIFO` |
| Cantidad Matriz | `DIAS_FRANCOS_PERIODO` o la expresión de saldo/devengo correspondiente |
| Fórmula | `ROUND(FILA_CANTIDAD * FILA_VALOR_FRANCO, PRECISION_REDONDEO)` |

`Cantidad Matriz` selecciona días; la fórmula principal devuelve pesos por fila. Se insertan líneas por lote, con su identidad persistida en el recibo. El desglose de una línea identificada usa ese lote y el importe guardado, sin reconstruir otra aplicación FIFO.

Las variables por fila son `FILA_CANTIDAD`, `FILA_SALDO`, `FILA_DEVENGADO`, `FILA_VALOR_FRANCO`, `FILA_COEFICIENTE`, `FILA_LOTE` y las dimensiones por código `FILA_EMPLEADO`, `FILA_CONVENIO`, `FILA_CATEGORIA`, `FILA_PUESTO`, `FILA_ESTADO`, `FILA_PROYECTO`, `FILA_PERIODO`, `FILA_PESQUERIA`. Son contexto temporal del evaluador, no variables de sistema globales. El valor unitario ya incorpora su proporción: no volver a multiplicar por `FILA_COEFICIENTE` salvo que la fórmula lo requiera expresamente.

Todos los componentes de `FRANCOS_FIFO` del documento comparten selección y deben pedir los mismos días. Se valúan por separado y se asienta un consumo por lote/selección. Si cambian los días entre componentes, o se mezclan conceptos de consumo tradicional y de matriz, el cierre falla. Los créditos de la propia pasada pueden entrar como lotes virtuales; se resuelven a un lote persistido al cerrar. Una nueva pasada de grossing-up descarta la selección temporal anterior.

`Factor Importe Consumo` sigue perteneciendo al camino tradicional. En una fórmula de matriz, el factor debe figurar explícitamente en la fórmula de pesos; no se aplica automáticamente por segunda vez. Las fracciones y la base del SAC no se cambian al elegir la matriz.

## Verificación

`Test Cuenta Francos` tiene pruebas con rollback para consumo compartido, asiento repetido, reversión idempotente, dependencia entre liquidaciones, recálculo después de reabrir y selección parcial sin consumo. Ejecutadas en BC. También cubre eliminación de un documento, reconstrucción histórica de enero y comparación del cálculo por filas en recibos reales, incluidas las ocho finales. Ver `scripts/ProbarCuentaFrancos.ps1` para repetirlas con rollback.

Ver [[Francos - ledger FIFO]], [[Orden de cálculo y precedencia]].

## Publicación 2026-10-12

Publicada la versión **1.0.0.623** en `mimir`, instancia `BC252`, con `scripts/Publicar.ps1` y `SchemaUpdateMode=Synchronize`. Compilación sin errores. Verificación SQL: tabla de movimientos creada en ArbuTest y 314 conceptos con fórmula de orden completa, confirmando la conversión del Upgrade. No se inicializaron cuentas de empleados ni se recalcularon recibos como parte de la publicación. Las pruebas funcionales de cuenta corriente siguen pendientes.

## Prueba en BC 2026-10-12

Publicada **1.0.0.627**. Se incorporó `Runner Cuenta Francos` (TestRunner, aislamiento por función), ejecutable desde `Invoke-NAVCodeunit` en `mimir` con empresa ArbuTest. Los tres tests de `Test Cuenta Francos` pasaron con rollback: componentes/asiento repetido/reversión/recálculo, selección parcial sin consumo y bloqueo de devengo utilizado.

Se inicializó un empleado de control con consumo de enero y sin documentos posteriores. Se ejecutó la reapertura mediante `Gestión Liquidación.ReabrirPorNumero` (delegación a Reabrir habitual), se comprobó el contramovimiento y se recalculó con `Motor Liquidación.Liquidar`. El documento quedó Calculada; el saldo volvió al original, con un consumo activo y su aplicación vinculada al lote. Las huellas SHA-256 de los grupos de concepto/convenio/categoría (cantidades, importes y bases) y de los totales de cabecera fueron idénticas antes y después. No se guardan aquí identificadores ni importes del empleado.

La prueba real verificó el consumo tradicional sobre la cuenta ya activada. La configuración `Fuente Matriz` de los conceptos sigue vacía: queda pendiente la conversión por nuevas vigencias y la prueba de las fórmulas por fila en recibos. No se activaron otros empleados. La eliminación del documento completo está integrada en código, pero no se ejercitó sobre un recibo real en esta prueba.


## Conversión aplicada y verificada (2026-10-12)

`Migrar Matriz Francos.Convertir('2026-01-04')` creó la nueva vigencia de 1063 mediante AL, conservando metadatos y fracciones. La versión del 02/01 queda cerrada el 03/01 y conserva su fórmula y factor. La selección nueva sigue siendo `DIAS_FRANCOS_PERIODO`. El importe por fila usa cantidad por valor unitario; en LIQ_FINAL incorpora el mismo factor de pesquería que antes. Sólo redondea al aplicar un factor distinto de uno, conservando la precisión anterior en las regulares.

No se convierte 3554 a filas: mezcla complemento de franco con otros haberes. Su referencia al total de 1063 y sus fracciones siguen iguales; trasladar la fórmula completa a cada lote duplicaría la parte ajena al franco. No se agregaron conceptos ni fracciones y no se modificó BASE_PROMEDIO.

Se reconstruyeron las cuentas con consumo de enero y se recalcularon los 41 documentos alcanzados (consumos y ocho finales). Quedaron 40 cuentas activas y 39 aplicaciones vigentes por lote/selección: cada una respalda exactamente los días de su línea y ninguna está duplicada. Todas las líneas de consumo tienen lote y selección. Las 570 liquidaciones de enero permanecen Calculadas.

Las huellas de los 84.297 grupos de documento/concepto/convenio/categoría de enero (cantidades y sumas de importes/bases a centavos) y los totales de sus 570 cabeceras coinciden antes y después. La prueba incluye las bases del SAC y 3554. No se registran aquí datos identificatorios ni importes de empleados. Los cambios de configuración se hicieron mediante AL: no requieren reinicio por caché SQL.

Se volvió a abrir y recalcular el recibo de control con la matriz ya activa. La eliminación completa se ejercitó en un documento de prueba con rollback: desaparecen cabecera y líneas y permanecen consumo y contramovimiento en la cuenta.

## Precio por vigencia — 12/10/2026

Versión 1.0.0.633 instalada. La configuración de precio ahora respeta la vigencia a la fecha de
valuación e invalida su caché al cambiar esa fecha. Nueva vigencia de 1063 desde 05/01/2026:
PESQ_FRANCO selecciona la tarifa de Merluza sin modificar la clasificación de los otros haberes.
Cantidad, fórmula de pesos por fila y fracciones acumuladoras conservadas. Ocho pruebas AL
pasaron con rollback, incluidas alternancia de fechas en la misma instancia de Gestión Francos
y repetición del mes completo sin perder aportes por tope. El recálculo mensual reabre en orden
inverso antes de rehacer las liquidaciones; los contramovimientos preservan la cuenta corriente.
Ver [[conciliacion-enero-vigencias-francos-ganancias]] para mantenimiento del atributo y conciliación.

## Reapertura de períodos

La acción Revertir Calculadas consulta dependencias vigentes y retira primero los consumos del
período antes de revertir sus devengos. Una dependencia externa queda bloqueada; no se elimina
la validación de la cuenta corriente. Ver [[reapertura-periodo-dependencias-francos]].

