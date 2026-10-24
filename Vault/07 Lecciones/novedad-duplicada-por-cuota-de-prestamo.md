---
aliases: ["Novedades duplicadas por cuotas de préstamos o anticipos"]
tipo: leccion
tema: migracion-meta4
tags: [meta4, migracion, anticipos, prestamos, novedades, auditoria]
fuente: [src/Codeunits/Cod50051.GestionPrestamos.al, src/Codeunits/Cod50061.GestionNovedadesLiq.al, src/Tables/Tab110038.NovedadLiquidacion.al, src/Tables/Tab60020.IncidenciaLiquidacion.al]
actualizado: 2026-10-16
---

# Novedades duplicadas por cuotas de préstamos o anticipos

Una novedad de descuento es redundante cuando el mismo movimiento ya está
representado por una cuota vigente de `Préstamo Empleado`. El encabezado tiene
tipo Anticipo o Préstamo; el cálculo se decide por concepto y destino de la cuota,
no por ese tipo informativo. La sola existencia del encabezado no basta.

## Cómo acreditar el duplicado

Contrastar empleado, concepto de descuento, período, importe y destino efectivo.
Conservar las claves de cada cuota y novedad. Si hay varias cuotas o novedades del
mismo grupo, comprobar el conjunto completo para no retirar un movimiento legítimo.
Una cuota anulada o sin un destino recuperable no reemplaza una novedad.

Para recibos calculados, verificar cuota → incidencia → línea, tipo y proyecto.
Para meses futuros, comprobar el plan y sus vencimientos originales. Si sólo hay
un destino por `No. Liquidación`, revisar también el período: al reabrir se libera
ese número y puede perderse la aplicación automática de la cuota.

La comparación decimal y la comparación al centavo son controles distintos. En la
depuración del 16/10/2026, dos novedades eran el redondeo de débitos originales
con más decimales que ya estaban reproducidos en sus cuotas. Se acreditó la misma
concesión y cada débito antes de anularlas; no se cambió el importe de las cuotas.
La tolerancia monetaria, por sí sola, no demuestra identidad.

## Conservar cálculos y trazabilidad

El motor materializa cuotas antes de novedades. Una novedad pendiente puede estar
salteada porque ya existe incidencia del concepto; no es por eso una deuda sin
descontar. Comprobar su motivo y la línea del recibo antes de duplicar entradas.

Dar de baja lógica sólo las novedades acreditadas, con motivo y respaldo anterior,
conservando préstamos, cuotas e incidencias. Mantener vacío `No. Liquidación` en
la novedad anulada: `Gestión Novedades Liq..LimpiarParaRecalculo` libera todas las
vinculadas al recibo y las devuelve a Pendiente, incluso si estaban anuladas.

> [!warning] La acción de anular puede afectar otras incidencias
> `AnularNovedad` sobre una Aplicada llama a la limpieza del recibo completo.
> Ese camino elimina sus incidencias de novedades y libera otras novedades.
> No usarlo como una baja aislada cuando se deben conservar exactamente esos datos.

Una baja directa respaldada debe validar la revisión de cada fila, tocar sólo
estado, vínculo, motivo y metadata, y comprobar los cálculos y las demás novedades
antes y después. Las anuladas quedan fuera de aplicación, copia y recurrencia.
Ver [[previsualizar-antes-de-migrar]] y [[sql-directo-deja-cache-rancia]].

## Aplicación comprobada

El 16/10/2026 se revisaron los siete encabezados y veinte cuotas existentes. Todos
usaban el concepto `8870`. De sus 31 novedades se anularon trece pendientes: cinco
históricas ya sustituidas por incidencia de cuota y ocho con programación futura.
Se conservaron seis ya anuladas y doce sin cuota equivalente del período.

Los préstamos, cuotas, incidencias, líneas y demás novedades quedaron iguales.
Nueve conjuntos de datos de cálculo de los titulares de los préstamos conservaron
sus huellas completas; no se creó ni recalculó ningún recibo. Respaldos, cruce con
el origen y confirmación de la transacción están en
`.snapshots/depurar-anticipos-novedades-20261016/`.

## Relacionado

[[Préstamos y cuotas]] · [[anticipos-cta-cte-meta4]] ·
[[Preparar un mes contra Meta4]] · [[Novedades pre-liquidación]]
