---
aliases: ["Format no se valida al compilar"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, reference]
actualizado: 2026-10-04
---

# Format no se valida al compilar

Las expresiones de Format son runtime; para un carácter por código hay que asignarlo a un Char

> [!warning] Las expresiones de Format se resuelven en runtime: un formato inválido compila y falla recién al ejecutarse.

El compilador de AL **no valida la cadena de formato** de `Format(Valor, Largo, Expr)`:
una expresión inventada compila y falla recién al ejecutarse, con *"Se ha especificado
un campo o atributo no válido para la propiedad Format"*.

`Format(9, 0, '<Char>')` **no existe**. AL no tiene `Chr()`. Para obtener un carácter
por su código hay que pasar por una variable `Char`:

```al
local procedure TabChar(): Text
var
    C: Char;
begin
    C := 9;          // 9 TAB · 10 LF · 13 CR
    exit(Format(C));
end;
```

**Por qué:** el 18/9/2026 la página de detalle de cálculo compiló limpia y reventó al
abrirla, en `AnotarTermino`. Compilar no alcanza para dar por buena una llamada a
`Format` con expresión.

**Cómo aplicarlo:** toda expresión de `Format` hay que ejecutarla una vez antes de darla
por buena — y si sólo se necesita un separador, conviene una función con nombre
(`TabChar`, `LfChar`) que se prueba una vez y se reusa. Ver [[al-compile-command]] y
[[al-sin-cortocircuito]].

## Relacionado

- [[al-compile-command]]
- [[al-sin-cortocircuito]]
- [[avoid-tables-principle]]
- [[borrar-rad-json-tras-cada-cambio]]
- [[bucle-modifica-campo-filtrado]]
