---
tipo: leccion
tags: [francos, vigencias, reapertura, pruebas]
fuente: [src/Codeunits/Cod50019.GestionLiquidacion.al, src/Codeunits/Cod110059.CuentaCorrienteFrancos.al, src/Pages/Pag50110.PeriodosLiquidacion.al, scripts/UnificarConceptosEnero.sql]
actualizado: 2026-10-12
---

# Reabrir un período respetando sus consumos de francos

La acción **Revertir Calculadas** recorría por número de documento. Cuando un recibo generaba
un lote utilizado por otro del mismo período, intentaba revertir primero el origen y la cuenta
corriente bloqueaba correctamente la operación. No se debe eliminar esa protección.

`Gestión Liquidación.ReabrirPeriodo` reúne primero las claves y recorre los pendientes en pasadas:

1. Consulta `PuedeReabrir` para respetar los períodos posteriores.
2. Consulta `Cuenta Corriente Francos.PuedeRevertir`, que identifica consumos activos ajenos.
3. Reabre los documentos libres mediante la transición habitual, sin modificar el ledger original.
4. Repite hasta agotar la lista o hasta que no quede ningún documento liberado.

Los consumidores del mismo período liberan sus orígenes en la siguiente pasada. Una dependencia
externa permanece bloqueada y se informa en el resultado. No se presupone un orden por fecha o
número, ni se agregan Commit. Cada reversión conserva su contramovimiento.

El método administrativo `ReabrirPeriodoPorCodigo` exige que se puedan reabrir todas: si quedan
bloqueadas, lanza un error y se revierte toda la transacción. La acción de página conserva su
comportamiento de reabrir las permitidas e informar las bloqueadas.

## Consolidación de enero

Por indicación del usuario, las correcciones de conceptos deben regir desde **01/01/2026**,
sin versiones sucesivas durante el mes. `AplicarUnificacionEnero.ps1`:

- Guarda configuración y referencias de las líneas en `.snapshots`, fuera del vault y de Git.
- Reabre enero completo usando el método administrativo anterior.
- Ejecuta `UnificarConceptosEnero.sql`: toma la última configuración de enero para cada concepto
  que tenga vigencia dentro del mes y la establece desde el primer día; conserva bajas,
  metadatos, fórmulas de matriz y las vigencias posteriores.
- Cierra al 31/12/2025 las versiones anteriores que aún alcanzaban enero. Las versiones
  intermedias de enero se retiran del catálogo y quedan respaldadas en la copia local.
- Consolida también las últimas fracciones por concepto/acumulador desde el primer día,
  conservando porcentaje y signo. No modifica restricciones de convenio ni parámetros.
- Actualiza las referencias de las líneas Borrador a la nueva versión, sin recalcular importes.
- Reinicia BC252 para invalidar la caché tras SQL directo.

El SQL requiere todas las liquidaciones de enero en Borrador y rechaza referencias a versiones
intermedias desde otros períodos. Su ejecución predeterminada sólo previsualiza.

## Pruebas

La nueva prueba cubre origen y consumidor del mismo período y misma fecha, con el origen primero
en la PK; también verifica bloqueo del consumidor externo y repetición sin contramovimientos nuevos.
La prueba de precio crea sus propias versiones con rollback, sin depender de las fechas de los
ajustes productivos. Las pruebas de integración de recálculo comparan meses completos repetidos:
un recibo aislado lee topes consumidos por los restantes y no produce una comparación equivalente.

Ver [[Cuenta corriente y matriz de francos]] y [[Tests automatizados]].

Verificación: versión **1.0.0.635** publicada; las nueve pruebas finalizaron correctamente con
rollback antes de la consolidación de las vigencias.


## Aplicado y verificado

Consolidación aplicada en ArbuTest: 293 conceptos y 1.276 fracciones desde 01/01/2026.
Las 570 liquidaciones de enero quedaron Borrador. No quedan movimientos de devengo/consumo
activos de esos documentos ni reversiones duplicadas. No quedan versiones intermedias de
conceptos en enero ni versiones anteriores que alcancen enero para los códigos consolidados.
La vigencia posterior de julio permanece. BC252 reiniciado tras SQL; importes pendientes de
recálculo por el usuario. Respaldo en .snapshots/unificacion-enero-20261012-182706.


Comparación posterior contra el respaldo: las 293 filas de conceptos y 1.276 fracciones
conservan todos sus campos de configuración, excepto fecha inicial y auditoría técnica.


## El árbol y la lista también deben compartir el recorrido

La corrección inicial del período no alcanzaba al árbol: éste llamaba a Lotes Liquidación Liq.,
que todavía recorría por número y fallaba al revertir un devengo consumido. Desde la versión
1.0.0.636, Lotes.Reabrir y ReabrirPeriodo delegan en Gestión Liquidación.ReabrirSeleccion.
Se conservan las claves exactas del alcance, incluso selecciones marcadas. El noveno test
ejercita el camino de Lotes usado por árbol/lista, además del bloqueo externo del período.

