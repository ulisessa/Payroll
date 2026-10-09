---
aliases: ["Un valor, una fuente"]
tipo: leccion
tema: parametros-atributos
tags: [leccion, parametros-atributos, feedback]
actualizado: 2026-10-04
---

# Un valor, una fuente

**En una frase:** no duplicar un valor en dos parámetros; si una fórmula necesita el básico del tripulante, que lea PRECIO_NAV

**Un valor, un parámetro.** Si una fórmula necesita el básico de un tripulante, se le agrega
`PRECIO_NAV` a la fórmula — no se crea un `BASICO` que repita el mismo número. Mantener dos
listados del mismo valor significa que el día que cambie uno hay que acordarse del otro, y nada
avisa cuando eso no pasa.

**Por qué:** copié los 45 `PRECIO_NAV_729/15_*` a `BASICO_729/15_*` y estuvo mal por tres motivos, de
menor a mayor:

1. **No hacía falta.** Lo que iba a arreglar eran las horas extras, y **las horas extras no son de
   tripulantes**: las cobran JO, 372/04 y FA, todos de tierra. Lo había medido en la misma corrida
   y apliqué igual — el dato estaba delante y no lo usé para frenar.
2. **Era peligroso.** `1003 Sueldo` **no tiene condición** y sí aplica a 729/15. Sin el parámetro
   daba cero, que es lo correcto: en Meta4 ningún tripulante cobra ese concepto — cobran
   navegación, órdenes, franco. Con el básico cargado les habría pagado el básico entero a los 295
   tripulantes.
3. **Duplicaba el dato**, que es la regla de arriba.

**Cómo aplicarlo:** antes de cargar un parámetro que "falta", preguntarse qué concepto lo lee y si
ese concepto **debería** pagar a esa población. Un parámetro en cero no siempre es un error: a
veces es lo que apaga un concepto que no corresponde — ver [[get-con-menos-argumentos]], donde el
cero silencioso es el problema, y éste, donde es la solución.

## Relacionado

- [[parametro-y-atributo-mismo-nombre]]
- [[sindicato-obra-social-atributos]]
- [[tc-comprador-parametro-fantasma]]
- [[tipo-atributo-tres-campos-silenciosos]]
- [[veda-como-atributo-del-buque]]
- Tema: `parametros-atributos` (ver [[_Convenciones del vault]])
