---
aliases: ["El reinicio de importes del grossing-up borraba la antigüedad"]
tipo: leccion
tema: grossing-up-tipo-cambio
tags: [leccion, grossing-up, antiguedad, nombres-en-conflicto, project]
actualizado: 2026-10-16
---

# El reinicio de importes del grossing-up borraba AÑOS_ANTIGUEDAD

**Síntoma:** el devengado de febrero de 04724 (OF03, 768/19) pagaba antigüedad **cero** (1053: 0 contra 12.394 de Meta4 en esa liquidación), con el 1534 +154.712 y el 2003 −138.770 por el reparto del grossing-up, y el feriado 1.549 abajo. `AÑOS_ANTIGUEDAD` valía 1,6192 en el cierre de marea del 12/2 y **0** en el devengado del 28/2; el mismo cálculo en una instancia nueva (`BuildContext` de 04724 al 28/2) daba 1,663. 04163 hacía lo mismo.

**Causa:** existe un concepto informativo y una variable de sistema llamados `AÑOS_ANTIGUEDAD`: comparten la entrada del diccionario de contexto. `ResetAccumuladores` (grossing-up, `Cod50014`) pone en cero el importe de **todos** los conceptos al arrancar cada vuelta de convergencia, y con eso ponía en cero la variable. Las liquidaciones que no iteran (la mayoría, y el cierre de 04724) no lo notaban; las que iteran dejaban la antigüedad en cero. No da error: `PCT_ANTIG_OFICIALES` daba 0 y el 1053 también.

**Arreglo:** `ResetAccumuladores` ahora vuelve a calcular la variable de sistema cuando el código del concepto coincide con su nombre (`ValorVariableSistemaHomonima`, `Cod50016`), y sólo pone en cero el importe del concepto. Es el único choque que hay hoy entre conceptos y variables (verificado por SQL); `NombresEnConflicto` ([[Variables de sistema]]) sigue siendo la revisión para detectar uno nuevo.
