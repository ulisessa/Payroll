---
aliases: ["Finales: vacaciones, SAC y descuentos coordinados"]
tipo: leccion
tema: vacaciones-sac-licencias
tags: [liquidacion-final, sac, descuentos, atributos]
fuente: [scripts/CorregirPendientesFinalOct12.sql, scripts/PrevisualizarDescuentosFinal.sql, src/Codeunits/Cod50014.MotorLiquidacion.al, src/Codeunits/Cod50016.ContextoLiquidacion.al]
actualizado: 2026-10-12
---

# Finales: vacaciones, SAC y descuentos coordinados

## Estado

Implementación AL compilada y configuración **preparada**, no aplicada por SQL.
Publicar primero los campos de orden alternativo. Aplicar después la configuración en una
transacción, reiniciar el servicio y recalcular. Ganancias queda para la siguiente etapa, con
las bases verificadas. No se alteró la versión de app.json ni llamadas a Commit.

## Mismo 3573, con orden por tipo y convenio

El concepto ya está restringido a su convenio. No se agrega otro adicional. El motor prepara
una copia temporal de los conceptos y ordena por el orden efectivo de cada liquidación:
`Fórmula Orden Cálculo`. Usa TIPO_LIQ, CONVENIO y ORDEN_BASE; el resultado debe ser un entero no negativo. No admite # ni @ a conceptos, porque el orden se resuelve antes de calcularlos.
Vacío conserva la configuración anterior. Las líneas y avisos usan el orden efectivo.

En LIQ_FINAL del 372/04: 3973 (665), 3974 (666), 3573 (667), 3813 (668).
En otras liquidaciones y convenios, 3573 conserva 455 y 3813 conserva 470.
La fórmula final del 3573 toma #3553 + #3973; su rama restante mantiene las vacaciones gozadas.
La base del SAC recoge todo el adicional, pero se resta la porción no devengada de su parte sobre
no gozadas: 10 % de #3973 por (1 - DIAS_ALTA_30/30). La diferencia pendiente de SAC del caso
analizado coincide con esa parte proporcional. No se alteran las vacaciones calculadas antes.

La restricción del orden del SAC al convenio es importante: no desplaza el SAC de los demás
tripulantes ni sus lectores. Se comprobó que 2003 y 4905 no aplican a LIQ_FINAL y que no hay
líneas de 2013 en las ocho finales de enero. Nuevas combinaciones con 2013 o con vacaciones
con historia requieren verificación, no quedan cubiertas por los datos de enero.

## El faltante de 04925 no era el 3554

Los haberes mapeados y ambas porciones del acuerdo coinciden. El faltante principal corresponde
a EGRESO_EXT_1_NR, también publicado como SAC_SIND_EXENMT: **SAC no remunerativo pagado por Meta4**.
No existía un concepto BC para ese pago. Se prepara 3814, no remunerativo, sólo LIQ_FINAL y
coeficiente entre cero y uno. Usa el SAC remunerativo redondeado a centavos antes de reconstruir
el complemento. Se mapea sólo EGRESO_EXT_1_NR; la columna duplicada no vuelve a sumarse.

Sus fracciones se copian del acuerdo, exceptuando BASE_PROMEDIO_NR. Aporta a OS y sindicato,
como muestra Meta4, y no a jubilación ni a su propio promedio. No se modifica 3554 ni AJ_PROM_PESQUERIA.
Esta excepción a evitar conceptos nuevos representa un pago existente en Meta4, no inventa un descuento.

## Descuentos existentes, condicionados a LIQ_FINAL

Se reutilizan 6002, 6012, 6034 y 8523. Los devengos 4751–4754 quedan apagados únicamente en
LIQ_FINAL para que sus fracciones no dupliquen deducciones en Ganancias.
Los ordinarios 6000, 6010, 6030 y 8522 restan el SAC remunerativo de su base actual.
Las otras ramas conservan sus fórmulas anteriores.

El tope mensual de la final se prorratea por DIAS_ALTA_30/30. Del importe acumulado se resta
lo ya aportado en otras liquidaciones del mes, permitiendo devoluciones. No se aplica MAX(0)
al descuento ordinario: eso ocultaba los reintegros de los dos egresados con tope.
El aporte de SAC usa el menor entre el SAC remunerativo pagado y la base contributiva topeada/12;
para OS usa su tope. El sindical de SAC usa el SAC remunerativo pagado. El SAC NR sigue en la
base ordinaria de OS y sindical, según las columnas de Meta4 del caso con pesquería.

Cuatro variables PERIODO_CONCEPTO restan descuentos de SAC reales ya pagados en el mes, no devengos:
SAC_JUB_PAGADO_MES, SAC_LEY_PAGADO_MES, SAC_OS_PAGADO_MES y SAC_SIND_PAGADO_MES.
Se siembran desde Gestión Variables Sistema y el script verifica su registro. La previsualización
compara ocho finales de enero; escenarios de junio/diciembre y múltiples finales del mes necesitan
pruebas adicionales. No se extendieron 6036 ni 7002 sin evidencia de esa necesidad.

## Fecha de atributos del empleado egresado

AtributoVigente usa el menor entre FechaRef y Cobertura Hasta en LIQ_FINAL sólo para Empleado.
Sin cobertura conserva FechaRef. El encuadre de la cabecera usa la misma fecha. No se cambia
Fecha Liquidación, parámetros, cotizaciones ni atributos de buque y proyecto.
El parche previo de abrir el atributo de zona permanece como dato; después de publicar se debe
verificar la resolución con el atributo correctamente cerrado en el día de baja.

## Verificación y límites

Compilación sin errores. Se agregaron pruebas AL de orden por tipo/convenio y de fecha de atributos
(con cobertura, sin cobertura, cobertura futura, regular y buque). Compilar no ejecuta esas pruebas.
La previsualización SQL de los ocho descuentos por cada una de las ocho finales coincide con Meta4
salvo cinco diferencias de un centavo. Incluye el adicional y el SAC proporcional del caso pendiente,
y el SAC NR; no es una ejecución del nuevo motor. Resta publicación y recálculo.

Ver [[Pendientes liquidación final]], [[atributo-cargado-que-nadie-lee]] y [[Parámetros y vigencias]].

## Simplificación del orden — 12/10/2026

Se reemplazaron los tres controles de orden alternativo por un único campo visible de fórmula.
Ejemplo del 3573: `IF(TIPO_LIQ = 'LIQ_FINAL' AND CONVENIO = '372/04', 667, ORDEN_BASE)`.
El 3813 utiliza 668 en la misma condición y el 3814 utiliza 669 en la final.
El script coordinado genera esas fórmulas y limpia los campos anteriores sólo en las nuevas
vigencias que inserta; la configuración previa no se modifica por SQL.

Los campos 30–32 ya estaban publicados: quedan como ObsoleteState=Pending y no se reutilizan
sus IDs. Se retiraron de la ficha. Si el campo nuevo está vacío y hay configuración anterior,
el motor genera y evalúa su fórmula equivalente. La fórmula explícita tiene prioridad.
El factor de consumo de francos (29) se conserva; este cambio no implementa todavía la matriz FIFO.

Compilación y previsualización del script realizadas. Las pruebas AL contemplan fórmula por tipo
y convenio, ORDEN_BASE, campo vacío y prioridad sobre datos anteriores; quedan pendientes de
ejecución en BC. Requiere publicación completa del campo 33; no se cargaron fórmulas en SQL.

## Aplicación posterior — 12/10/2026

El estado preparado de las secciones anteriores quedó superado: se aplicó
`scripts/CorregirPendientesFinalOct12.sql` y se recalcularon las ocho finales. El adicional del
3573, SAC NR y descuentos de SAC se verificaron contra Meta4. Se conserva configuración histórica
y se usan fórmulas de orden con valores literales de compatibilidad, según la publicación vigente.

La versión 1.0.0.633 incorpora además precio de francos por vigencia, Ganancias final anual con
descuentos reales y devolución, y recálculo atómico del mes para conservar topes. Ver
[[conciliacion-enero-vigencias-francos-ganancias]] para resultados y límites.
