---
aliases: ["Comparar un atributo por código"]
tipo: leccion
tema: formulas-evaluador
tags: [leccion, formulas-evaluador, reference]
actualizado: 2026-10-04
---

# Comparar un atributo por código

comparar un atributo de lista contra su código ya está implementado en el evaluador; no hace falta una función con parámetro

Un atributo de lista se puede comparar **por código** en una fórmula, y ya funciona: basta poner
un literal entre comillas simples a la derecha de `=` o `<>`.

```
IF(PCT_SINDICATO = 'PAT', round(BASE_SINDICAL / 100, PRECISION_REDONDEO), 0)
```

`ParseCompare` (Cod50015:247) mira si el token de la derecha es `StrLit` y, si lo es, **descarta el
valor numérico de la izquierda** y llama a `CompararCodigoAtributo`, que busca el nombre en
`FCodigosAtributos` — un diccionario `Nombre Variable → Cód. Valor` que llena `LoadAtributos`
(Cod50016:2185). El mismo identificador suelto sigue dando el **Valor Numérico**. No hay que
inventar una función con parámetro: el tipo lo decide el contexto.

Sólo admite `=` y `<>`; con `<`, `>` corta con error. Valida contra la base que el atributo sea de
lista y que el código exista, así que un código mal escrito falla ruidosamente al validar la
fórmula, no en silencio.

**Por qué importa**: dos atributos pueden compartir el Valor Numérico y entonces el número no
alcanza para distinguirlos. SINDICATO tiene MAQ y PAT los dos en 3,00; CON, SBA y SEC los tres en
4,50. Comparar contra el número junta casos que la regla separa.

**Dónde se rompe**: `LoadAtributos` salta el atributo si el nombre ya está en el contexto, y con él
**no carga el código** — así que si un parámetro o una Fuente de Datos le pisa el nombre, la
comparación por código corta con "No se cargó el código vigente de X" o devuelve 0 en modo
lenient. Es la misma trampa de [[parametro-y-atributo-mismo-nombre]], pero con un segundo efecto
que ahí no está anotado.

Ver [[atributos-tipados]] y [[sindicato-obra-social-atributos]].

## Relacionado

- [[parametro-y-atributo-mismo-nombre]]
- [[atributos-tipados]]
- [[sindicato-obra-social-atributos]]
- [[arroba-ignora-el-par-del-concepto]]
