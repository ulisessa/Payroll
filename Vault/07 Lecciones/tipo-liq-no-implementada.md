---
aliases: ["TIPO_LIQ no está implementada", "TIPO_LIQ se compara por código"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-11
---

# TIPO_LIQ se compara por código, no por número

**En una frase:** `TIPO_LIQ` devolvía el `Orden` del tipo y una fórmula con `IF(TIPO_LIQ = 40, …)` no se podía leer ni verificar; desde el 11/10/2026 se escribe `TIPO_LIQ = 'LIQ_FINAL'` y el editor ofrece la lista.

> [!warning] Esta nota decía lo contrario
> Hasta el 4/10/2026 afirmaba que `TIPO_LIQ` **no estaba implementada**. Era cierto al 28/9 y dejó de serlo sin que la nota se corrigiera. Hoy está resuelta en `Cod50016`, sembrada en `Cod50077` y se compara de las dos formas. Queda el alias viejo para no romper enlaces.

## El problema no era que faltara: era que no se podía leer

La variable devuelve el **`Orden`** del tipo de liquidación de la corrida, y `Tab50578` fuerza que el
Orden sea único justamente para eso. Funcionaba. Pero:

- `IF(TIPO_LIQ = 40, …)` no dice nada. Para saber qué es 40 hay que entrar a la tabla a mirar.
- **En ningún lado de la interfaz decía qué número era cada tipo.** El caption del campo era "Orden"
  y la descripción sembrada se cortaba en `"(CIERRE_MAREA 1, DEVENGADOS 60…)"`.
- `TIPO_LIQ = 41` compila, no coincide con nada y no da ningún error. Un dígito mal tipeado apaga
  una rama entera en silencio, que es la familia de fallas que más cuesta en este motor.
- El número depende de un campo editable. Cambiarle el Orden a un tipo reescribe el significado de
  todas las fórmulas que lo comparan, sin tocarlas.

## La solución reusó el mecanismo de los atributos

El evaluador **ya sabía** comparar por código: un literal entre comillas a la derecha de `=` cambia
la comparación, y así funcionan los atributos de lista ([[atributo-comparar-por-codigo]]). Enganchar
`TIPO_LIQ` fueron tres toques:

| Dónde | Qué |
|---|---|
| `Cod50016.LoadVariablesSistema` | Publica el código en `FCodigosAtributos`, además del número |
| `Cod50015.ValidarCodigoAtributo` | Valida el literal contra `Tipo Liquidación` en vez de exigir un atributo |
| `Cod50060.BuildValoresAtributoJson` | Emite los códigos, y el editor los autocompleta sin tocar el JS |

**Las dos formas conviven.** El número sigue funcionando: no hay migración forzada.

> [!important] El enganche va por `Cód. Cálculo`, no por el nombre
> `Nombre Variable` es configurable a propósito —una instalación puede renombrar la variable para que
> las fórmulas se lean mejor, y `Cod50077` lo documenta—. Comparar contra el literal `'TIPO_LIQ'`
> dejaría de funcionar justo en la instalación que se tomó el trabajo de ponerle un nombre claro.

## Por qué: el cero es ambiguo y el número no se audita

Una liquidación **sin** `Cód. Tipo Liq.` también devuelve cero, y cero es el Orden de
`SALDO_INICIAL` ([[migracion-tipo-liq-incompleta]]). Comparar contra 0 no distingue "es un saldo
inicial" de "no tiene tipo cargado"; con el código, `TIPO_LIQ = 'SALDO_INICIAL'` sólo matchea el
primero, porque el código de una liquidación sin tipo es el vacío.

## Cómo aplicarlo

- En una fórmula nueva, **siempre el código**: `IF(TIPO_LIQ = 'CIERRE_MAREA', …)`. El editor ofrece la
  lista al escribir la comilla, con la descripción del tipo y su Orden al lado.
- Para saber **quién compara TIPO_LIQ** antes de tocar un tipo: [[Dónde se usa un símbolo]].
- Las tres fórmulas que lo usaban —1023, 1534 y 2003— se migraron el 11/10/2026 por SQL, con entrada
  en el historial de fórmulas y la invariante de que ningún importe se mueva.

## Relacionado

- [[atributo-comparar-por-codigo]] — el mecanismo que se reusó
- [[produccion-no-se-prorratea]] — el caso que pedía distinguir el cierre del devengado
- [[variable-sistema-hay-que-sembrarla]]
- [[lote-tipo-liq-en-blanco]]
- [[migracion-tipo-liq-incompleta]]
- [[vacio-en-tipos-liq-aplicables-es-comodin]]
