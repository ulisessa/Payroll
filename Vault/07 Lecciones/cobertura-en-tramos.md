---
aliases: ["Cobertura en tramos"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-04
---

# Cobertura en tramos

un día se liquida una vez; el reparto vive en Tramo Cobertura Liq. porque un desde/hasta no puede decir "del 1 al 4 y del 26 al 31"

**La regla: un día de estado se liquida UNA vez.** El reparto del mes entre las liquidaciones de
un empleado vive en `Tramo Cobertura Liq.`, tabla hija de Liquidación.

`Cobertura Desde/Hasta` de la cabecera ya expresaba la idea y el motor ya la usaba como piso de
toda variable de período — el comentario que la justifica dice literalmente *"ya los paga la
liquidación REGULAR de la nómina: se contaban dos veces"*. Pero es **un solo intervalo**, y sólo
la usaba el tipo con disparador de arribo. En enero de 2026: Cierre de marea 25 días, y
**Regular, Vacaciones y Devengados los 31**, pisándose entre sí.

**Por qué no alcanza un intervalo:** la Regular cubre "todo lo demás", y si las vacaciones caen
en el medio del mes lo que le queda son dos tramos. Con un desde/hasta sólo se puede decir "del
1 al 31", que vuelve a pisar.

**Cómo se reparte:** cada tipo declara en `Estado Tipo Liq.` qué estados lo justifican, y esos
mismos estados definen qué días cubre. El tipo que no declara ninguno se queda con lo que sobra
— el papel de la Regular. **El orden lo decide el `Orden` del tipo**, que ya existía y ya es
único: Vacaciones (30) reclama antes que la Regular (100).

En el motor la bifurcación está en un solo lugar, `DiasEnLaVentana`: con tramos suma contra cada
uno, sin tramos contra la ventana única de siempre. `Recalcular` corre **antes** de armar el
contexto, porque el contexto los lee.

**Los tramos se borran con la liquidación.** Si sobrevivieran, la próxima que pregunte "qué días
quedan libres" los vería tomados por una que ya no existe y se quedaría sin días sin que nada lo
explique.

Ver [[ventana-liquidacion-es-cobertura]] y [[vacio-en-tipos-liq-aplicables-es-comodin]].

**Declarar un estado dice CUÁLES días te interesan, no que sean tuyos.** La primera versión hacía
que sólo el tipo que recoge "lo que sobra" consultara lo ya reclamado, y los tipos con estados
declarados tomaran los suyos a ciegas: 196 solapamientos en enero de 2026. El Cierre de Marea se
quedaba con el viaje del 3 al 29 y Devengados volvía a tomar esos mismos días de navegación;
Vacaciones y la Regular se peleaban los días de AU9. Ahora todos los caminos consultan el mismo
conjunto de días tomados.

**La excepción es el disparador de arribo**: los días del viaje los define el proyecto y no se
negocian, así que ese tramo se escribe sin consultar. Funciona porque el Cierre de Marea tiene el
`Orden` más bajo y corre primero.

**Que un concepto aparezca en dos liquidaciones no es por sí mismo un error.** El SAC devengado y
sus cargas se calculan sobre el bruto de cada una, así que si el mes está repartido entre tres
liquidaciones hay tres provisiones y la SUMA es lo que tiene que dar. Lo que se compara contra
Meta4 es el total del empleado-mes, no la presencia en un tipo.

## Relacionado

- [[ventana-liquidacion-es-cobertura]]
- [[vacio-en-tipos-liq-aplicables-es-comodin]]
- [[acumuladores-orden-calculo]]
- [[cobertura-devengado-tapa-dias]]
- [[concepto-negativo-despues-de-sus-consumidores]]
