---
aliases: ["Exclusividad de vacaciones"]
tipo: leccion
tema: vacaciones-sac-licencias
tags: [leccion, vacaciones-sac-licencias, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-28
---

# Exclusividad de vacaciones

las vacaciones se pagan en la liquidación de Vacaciones si existe y en la Regular si no; la condición lo pregunta en tiempo de cálculo

## Cuándo corresponde una liquidación de Vacaciones aparte (27/9/2026)

**Sólo cuando se paga anticipado**, y anticipado quiere decir que la **fecha de liquidación es
anterior a la fecha de inicio de las vacaciones**. Si las vacaciones ya empezaron cuando se liquida,
no hay anticipo: los días van dentro de la Regular.

En `Estado Tipo Liq.` eso es **una sola línea**: `Exige AU9`, ventana **Período**, y
**`Empieza en la Ventana` = Sí**. O sea: **el recibo va en el mes en que las vacaciones EMPIEZAN.**

**Medido contra Meta4, enero 2026** — es el test que decide, y desmiente dos intentos previos:

    AU9 que empieza en FEBRERO (63 empleados) -> 54 tienen su corrida aparte en FEBRERO, sólo 1 en enero
    AU9 que empieza en ENERO   (82 empleados) -> 64 tienen corrida aparte en enero, 18 dentro de la mensual

Esos 64 + 18 = 82 son exactamente los del AU9 que arranca en enero, y coinciden con el reparto
TP_IMPUT 3 / TP_IMPUT 1 que ya estaba anotado abajo.

**Que se pague por adelantado es cierto pero no se puede leer de la fecha de liquidación**: BC
estampa todas con el último día del período, así que "fecha de liquidación anterior al inicio de las
vacaciones" da verdadero tanto para el que arranca el 5 de enero como para el que arranca en febrero.
Lo que sí se puede leer es **en qué mes arrancan**.

**Dos intentos fallidos, y cada uno enseña algo distinto.**

Primero borré la línea `Período` dejando la de `MesSiguiente`, creyendo que ésa era la regla del
anticipo. Resultado: el recibo salía **un mes antes** de las vacaciones. La ventana correcta era la
que había borrado — lo que estaba mal no era la ventana sino que faltaba pedir que el estado
*empezara* ahí.

**Y borrar la línea no alcanzó por otra razón más.** `HayEstado` filtra por **solapamiento**:

```al
Estado.SetFilter("Fecha Inicio", '<=%1', Hasta);
Estado.SetFilter("Fecha Fin", '%1|>=%2', 0D, Desde);
```

así que "Exige AU9 con ventana MesSiguiente" pregunta si el empleado tiene un AU9 que **toque** el mes
siguiente — y eso da verdadero para quien empezó las vacaciones el 1 de enero y las termina el 4 de
febrero, que no cobra ningún anticipo. En enero de 2026 seguían saliendo 132 recibos: 63 anticipos
reales y **69 de más, 547 millones**.

Por eso se agregó **`Empieza en la Ventana`** (campo 8 de `Estado Tipo Liq.`): con Sí, la línea pide
`SetRange("Fecha Inicio", Desde, Hasta)` — que el estado **arranque** en la ventana, no que la roce.
Es ortogonal a la ventana y sirve para cualquiera; por eso es un campo y no un valor nuevo del enum.

**Y el sembrador tuvo que pasar a converger, no sólo a crear.** `ExigirEstado` salía si ya existía
una línea con el mismo (tipo, estado, ventana), así que en una instalación que ya había corrido la
bandera nueva nunca se habría escrito. Ahora, si la encuentra distinta, la modifica.

El caso testigo es el legajo 90016: `Fecha Liquidación` 31/1/2026 y AU9 desde el 1/1/2026 — 31/1 es
posterior al 1/1, no es anticipo, y tenía igual un recibo de Vacaciones por 24,2 M además de la
Regular por 26,2 M.

**Los tramos de cobertura ya estaban bien**: en el 00291 la de Vacaciones tomaba 5-15 y 30-31 y la
Regular 1-4 y 16-29, sin solaparse. El problema nunca fue el reparto de días sino que el segundo
recibo no debía existir. Ver [[cobertura-en-tramos]].

**Sacar esa línea NO alcanza, y lo que queda ahora pesa más.** `DiaEnLaVentana` (Cod50016) hace:

```al
if FTramosDesde.Count() = 0 then
    exit((Dia >= FPeriodoFechaDesde) and (Dia <= FFechaRef));
```

o sea **cero tramos = el período entero**. Las 63 anticipadas que quedan no tienen ningún tramo en el
mes que se liquida —sus vacaciones empiezan al mes siguiente—, así que caen todas en ese camino y el
recibo del anticipo se calcula como si cubriera el mes completo. Cambiar el fallback a "cero días" en
seco tampoco sirve: hay tipos que legítimamente no usan cobertura.

El informe de revisión de enero (`artifacts/revision-enero-2026-20260927/Informe.md`, §2) lista las
otras causas del doble mensual, que siguen abiertas: `1003` devuelve el básico sin proporcional por
cobertura, VACACIONES tiene `Sólo Conceptos Declarados = false`, y `ResolverNetoGarantizado` resuelve
el objetivo de grossing-up completo por documento sin descontar lo que ya cubrió el otro.

## El reparto de los conceptos

Las vacaciones se pagan en **una** liquidación: la de Vacaciones si existe, la Regular si no.
Los dos modos son reales — en Meta4, enero 2026: **64 empleados por corrida separada** (TP_IMPUT
3) y **18 dentro de la mensual** (TP_IMPUT 1). Lo que no existe es cobrarlas en las dos.

Por eso **no alcanza con sacarle REGULAR a 3553**: dejaría sin cobrar a los 18. La regla es
dinámica y la contesta la Fuente de Datos **`HAY_LIQ_VACACIONES`** (tabla 60011, COUNT, filtros
`{EMP_NO}` + `{PERIODO}` + tipo VACACIONES + `No. <> {LIQ_NO}`), y los conceptos 3553, 3573 y
4743 la piden en su condición.

**El `<>{LIQ_NO}` es lo que hace que funcione en los dos lados**: calculando la de Vacaciones no
se cuenta a sí misma —da 0 y paga—, y calculando la Regular ve a la de Vacaciones —da 1 y no
paga—. Sin eso, la de Vacaciones se bloquearía a sí misma.

**El orden ya estaba garantizado** por el `Orden` del tipo: Vacaciones 30, Regular 100, y el lote
crea y calcula tipo por tipo en ese orden. Si la de Vacaciones se descartó por vacía, no existe y
la Regular paga — que es lo que corresponde.

**Por qué:** `Sólo Conceptos Declarados` resuelve el problema inverso —que la de Vacaciones no pague
todo el recibo, y funcionó: pasó de 19 conceptos a 5—, pero no impide que la Regular pague las
vacaciones. Son dos problemas distintos y es fácil creer que uno resuelve el otro.

Ver [[vacio-en-tipos-liq-aplicables-es-comodin]] y [[cobertura-en-tramos]].

## Relacionado

- [[cobertura-en-tramos]]
- [[vacio-en-tipos-liq-aplicables-es-comodin]]
- [[accidente-empleador-y-art]]
- [[enfermedad-sin-convenio-paga-cero]]
