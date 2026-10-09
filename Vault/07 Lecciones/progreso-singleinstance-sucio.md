---
aliases: ["Progreso: SingleInstance sucio"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, project]
actualizado: 2026-10-04
---

# Progreso: SingleInstance sucio

**En una frase:** un lote detenido deja el Progreso SingleInstance encendido y el siguiente pinta los números del anterior

`Progreso Liq.` es **SingleInstance**, así que su estado sobrevive a la corrida. Cuando un lote
se **detiene** —el usuario lo corta, o un error se escapa— el `Cerrar` nunca corre y quedan
`FAbierta` en true, `FNivel` en uno o dos, los contadores viejos y un `FInicio` de hace rato.
El `Abrir` siguiente veía `FAbierta` encendido y salía sin tocar nada, así que **el lote nuevo
pintaba los números del viejo**: "519 de 519, 100 %" y un reloj de 36 minutos mientras recién
empezaba a procesar.

No se puede distinguir "quedó sucio" de "estoy anidado" mirando el estado: los dos se ven
igual. Por eso lo declara el que llama — **`AbrirLote`** reinicia todo y `Abrir` queda para los
procesos anidados. Los dos lotes (`Proceso Liq. por Lotes` y `Lotes Liquidación Liq.`) llaman
`AbrirLote`.

**Por qué:** el síntoma no parece un bug de progreso sino del cálculo — da la impresión de que el
lote terminó y se colgó, o de que va lentísimo. El handle de la ventana vieja tampoco sirve:
la plataforma ya la cerró al abortar, así que los `Update` no pintan nada.

**Cómo aplicarlo:** cualquier estado en un SingleInstance que se limpie sólo en el camino feliz
tiene este problema. Ver [[codeunit-run-necesita-commit]] para la otra mitad del mismo patrón.

## Relacionado

- [[rad-json-removed-peligroso]]
- [[rangos-licencia-objetos]]
- [[report-sin-layout-compila]]
- [[setselectionfilter-tabla-temporal]]
- [[symbolos-final-version-tienen-fuente]]
- [[version-app-json-manual]]
- Tema: `desarrollo-al` (ver [[_Convenciones del vault]])
