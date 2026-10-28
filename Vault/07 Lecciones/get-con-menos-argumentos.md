---
aliases: ["Get con menos argumentos que la PK"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, feedback]
origen: 6fef786a-9ac7-4101-a78d-2cb1c395ef37
actualizado: 2026-08-16
---

# Get con menos argumentos que la PK

Record.Get() compila con menos argumentos que la PK y asigna al campo equivocado; el caso que explotó fue Parámetro Vigente

> [!warning] Compila sin aviso y asigna los argumentos a los campos equivocados de la clave primaria.

`Record.Get()` en AL compila aunque le pases menos argumentos que campos tiene la clave primaria: los asigna **en orden desde el primero**. Si la PK es `(A, B, C)` y escribís `Get(valorDeB, valorDeC)`, valorDeB va a parar a A — sin error de compilación, y en runtime falla por longitud o simplemente no encuentra nada.

**Dónde muerde en este proyecto:** `Parámetro Vigente` tiene `key(PK; "Cód. Parámetro Base", "Cód. Parámetro", "Vigencia Desde")`. `Get(ClaveDerivada, Vigencia)` metió la clave derivada (`Code[50]`, ej. `PCT_CUOTA_SIND_ESP_FE02`, 23 caracteres) en `Cód. Parámetro Base`, que es `Code[20]` → *"The length of the string is 23, but it must be less than or equal to 20"*, y la página se cerró.

**Cómo aplicarlo:** para buscar un Parámetro Vigente por su clave derivada, usar la clave secundaria y no `Get`:

```al
ParVig.SetCurrentKey("Cód. Parámetro", "Vigencia Desde");
ParVig.SetRange("Cód. Parámetro", ClaveDerivada);
ParVig.SetRange("Vigencia Desde", Vigencia);
if ParVig.FindFirst() then ...
```

Doblemente necesario porque `Cód. Parámetro Base` puede estar vacío en filas viejas, así que ni siquiera un `Get` con los tres argumentos las encontraría.

Regla general antes de escribir cualquier `Get`: mirar la PK completa de la tabla. Si el primer campo no es el que tenés a mano, no es un `Get` — es un `SetRange` + `FindFirst` sobre una clave secundaria. Ver también [[al-sin-cortocircuito]] y [[bucle-modifica-campo-filtrado]], que son el mismo tipo de trampa: compila, corre, y hace otra cosa.

## Relacionado

- [[al-sin-cortocircuito]]
- [[bucle-modifica-campo-filtrado]]
- [[al-compile-command]]
- [[avoid-tables-principle]]
- [[borrar-rad-json-tras-cada-cambio]]
