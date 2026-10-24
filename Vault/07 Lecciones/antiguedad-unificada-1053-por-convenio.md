---
tipo: leccion
tags: [antiguedad, conceptos, acumuladores, vigencias]
fuente: [src/Codeunits/Cod110066.UnificarAntiguedadLiq.al, src/Codeunits/Cod50014.MotorLiquidacion.al, src/Tables/Tab60017.FraccionAcumulador.al]
actualizado: 2026-10-12
---

# Antigüedad unificada en 1053 por convenio

El 1055 de Alimentación y el 1053 de tripulación pueden compartir código, conservando sus
reglas y su orden. La unificación no corrige porcentajes históricos discordantes de Meta4:
sólo hace que la antigüedad se liquide y compare bajo el mismo código.

`Unificar Antigüedad Liq.` (110066) aplica la conversión al **01/01/2026**. Requiere enero completo
en Borrador. Conserva el historial anterior a esa fecha y rechaza usos posteriores incompatibles.

La fórmula del 1053 queda como `IF(CONVENIO = '372/04', fórmula del 1055, fórmula del 1053)`.
Usa la configuración de ambas vigencias, sin volver a escribir sus reglas salariales. La fórmula
de orden conserva **50** para Alimentación y **100** para tripulación. Se agrega 372/04 a los
convenios del 1053. El par de convenio/categoría, condiciones y tipos aplicables deben coincidir.

## Conservar las bases

Las ocho fracciones compartidas coinciden en porcentaje y signo. Sin embargo, el 1053 además
aporta a BASE_AUSENTISMO y BASE_FERIADO, mientras el 1055 no lo hacía. Copiar sin más las
fracciones del 1053 cambia esas bases para Alimentación.

Se incorpora **Filtro Convenio**, opcional, en Fracción Acumulador. Vacío conserva el comportamiento
existente. El motor resuelve el filtro de la vigencia ganadora y lo aplica al convenio efectivo
de la línea/concepto; no cambia porcentajes ni signos. Para esas dos fracciones se configura
`<>372/04`, manteniendo las bases de ambos conjuntos.

La distribución se sigue versionando independientemente del concepto. Ver [[Acumuladores y fracciones]].

## Retirar el 1055 desde enero

- Se quita la vigencia y distribución de enero del 1055, conservando las anteriores.
- El historial del 1055 queda cerrado al 31/12/2025. No se usa Activo: ese campo es obsoleto.
- Las referencias de líneas Borrador de enero pasan a 1053, sin alterar importes anteriores
  al recálculo. Los documentos históricos anteriores conservan sus referencias al 1055.
- Las fórmulas futuras de vacaciones y descuento de vacaciones que sumaban ambos conceptos
  dejan de sumar el 1055. Reemplazarlo por otro 1053 habría duplicado la antigüedad.
- Las variables configuradas por concepto pasan a 1053 si apuntaban al 1055.

La conversión es idempotente. Se ejecuta mediante AL para invalidar las cachés correctamente.
La prueba de integración compara meses completos de Alimentación y tripulación, incluidos
francos y final; verifica los filtros de las bases y usa rollback.

Ver [[escala-antiguedad-meta4]] y [[Tests automatizados]].

## Cantidad presentada

El 1053 conserva unidad % para ambos convenios. Para Alimentación, Variable Cantidad calcula
los años completos por el factor de ANTIGÜEDAD_MENS; para tripulación conserva PCT_ANTIG_SOMU.
La expresión cabe en el campo existente Code100. Variable Base conserva AÑOS_ANTIG_30JUN sólo
en tripulación y cero para Alimentación. La prueba comprueba que cantidad por básico dividido
por cien coincide con el importe: no se presentan años con una etiqueta de porcentaje.


Operación repetible: scripts/UnificarAntiguedadEnero.ps1 -Aplicar guarda el respaldo en
.snapshots, reabre enero y llama a Aplicar('2026-01-01') mediante las herramientas de BC.
No se cambia la configuración por SQL directo; las cachés se invalidan mediante AL.


## Aplicado y verificado

Versión 1.0.0.637 instalada. Diez pruebas con rollback aprobadas. Conversión aplicada mediante
AL después de respaldar en .snapshots/antiguedad-unificada-20261012-192149. Las 570 liquidaciones
de enero quedaron Borrador; no quedan movimientos activos de francos de esos documentos.
El 1055 conserva sólo el historial cerrado al 31/12/2025; no quedan líneas de enero ni fórmulas
actuales que lo referencien. Dos fracciones del 1053 tienen filtro <>372/04. Enero queda listo
para recalcular por el usuario. No hizo falta reiniciar por SQL porque se modificó mediante AL.

