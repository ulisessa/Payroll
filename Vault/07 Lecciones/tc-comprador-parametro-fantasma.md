---
aliases: ["TC_COMPRADOR: parámetro fantasma"]
tipo: leccion
tema: parametros-atributos
tags: [leccion, parametros-atributos, feedback]
actualizado: 2026-10-04
---

# TC_COMPRADOR: parámetro fantasma

> [!warning] Falla en silencio
> un parámetro con el mismo nombre que una Fuente de Datos la pisa, pero sólo después de que el motor cambia el par CCT

Un **parámetro** y una **Fuente de Datos** con el mismo Nombre Variable conviven sin dar error,
y el resultado depende de *cuándo* se lo lea:

- `BuildContext` carga primero los parámetros y después las fuentes, y la fuente **pisa**. Al
  arranque el valor es el bueno.
- `UsarParCCT` —lo que el motor llama cuando un concepto se liquida con otro par
  convenio/categoría, por ejemplo al evaluar un `@OTRO_CONCEPTO` o cuando el concepto tiene
  `Par CCT a Usar`— recarga **sólo los parámetros** y deliberadamente no vuelve a correr las
  fuentes. Desde ahí gana el parámetro y no hay quien lo restaure.

Caso real: `TC_COMPRADOR` existía como Fuente de Datos (cotización compradora) **y** como
Parámetro con una sola vigencia de 2023 y valor 0. En las mismas 449 liquidaciones:

```
línea de ADIC_PROD_PESCA   TC_COMPRADOR  449 veces,   0 en cero
línea de PROD_EMPRESA      TC_COMPRADOR  449 veces, 125 en cero
línea de PROD_EMPRESA      TC_VENDEDOR   449 veces,   0 en cero
```

`PROD_EMPRESA` tiene `Par CCT a Usar` = 2. `TC_VENDEDOR` sale de la misma tabla con los mismos
filtros y no falla nunca — la única diferencia es que no tiene parámetro homónimo.

**Por qué:** el síntoma es intermitente dentro de la misma liquidación, que es lo que lo hace tan
difícil de leer: la variable "anda" en una línea y da cero en la de al lado.

**Cómo aplicarlo:** ante una variable que resuelve bien en un concepto y cero en otro, buscar el
nombre en las cuatro fuentes (parámetro, variable de sistema, fuente de datos, atributo) antes
de mirar la fórmula, y cruzar contra `Par CCT a Usar`. Es la misma trampa que
[[parametro-y-atributo-mismo-nombre]], con otro par de contrincantes.

## Relacionado

- [[parametro-y-atributo-mismo-nombre]]
- [[sindicato-obra-social-atributos]]
- [[tipo-atributo-tres-campos-silenciosos]]
- [[un-valor-una-fuente]]
- [[veda-como-atributo-del-buque]]
- Tema: `parametros-atributos` (ver [[_Convenciones del vault]])
