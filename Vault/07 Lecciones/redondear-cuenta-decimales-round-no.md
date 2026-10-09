---
aliases: ["REDONDEAR cuenta decimales, ROUND toma precisión"]
tipo: leccion
tema: motor-formulas
tags: [leccion, motor-formulas, redondeo, francos]
actualizado: 2026-10-06
---

# REDONDEAR cuenta decimales, ROUND toma precisión

Pasarle `PRECISION_REDONDEO` a `REDONDEAR` redondea a 0,1 y no da error

> [!warning] Las dos funciones del evaluador tienen contratos **opuestos** y el mismo parámetro sirve para una sola. Cruzarlas no da error: da un redondeo mucho más grueso del que se pidió.

- `ROUND(valor, precisión)` → `Round(Arg2, Arg3)`. Toma la precisión tal cual: `ROUND(x, 0.0001)`.
- `REDONDEAR(valor, n)` → **`n` es una cantidad de decimales**, que el evaluador convierte a
  precisión descontando de a uno:

```al
Result := 1;                  // 1/10^n
while Arg3 > 0 do begin
    Result := Result / 10;
    Arg3 -= 1;
end;
exit(Round(Arg2, Result));
```

El bucle no distingue 4 de 0,0001. **Cualquier valor entre 0 y 1 entra exactamente una vez**
—con 0,0001 sale con `Arg3` en −0,9999— y el resultado es `Round(valor, 0.1)`. Siempre a un
decimal, cualquiera sea la precisión que se haya querido pedir.

## Cómo se vio

`PRECISION_REDONDEO` vale **0,0001**, que es una precisión, y el concepto `1062` (Francos
devengados) la pasaba a `REDONDEAR`. El síntoma es que la `Fórmula Evaluada` de la línea y la
`Cantidad` guardada **no coinciden**, sin ningún aviso:

| Empleado | Fórmula Evaluada | Guardado |
|---|---|---|
| 04649 | `REDONDEAR(0,52 * 27 + 1; 0,0001)` = 15,04 | 15,00 |
| 04724 | `REDONDEAR(0,52 * 22 + 1; 0,0001)` = 12,44 | 12,40 |
| 04791 | `REDONDEAR(0,52 * 26 + 1; 0,0001)` = 14,52 | 14,50 |

Se escondió **tres años** porque el único convenio con coeficiente de dos decimales es el 768/19
(0,52). Con el 0,5 del 729/15 todos los resultados caen en un múltiplo de 0,1 y el bug es
invisible: `0,5 × 27 + 1` = 14,5 redondee como redondee.

## Qué hacer

- **Para una precisión, `ROUND`.** `REDONDEAR` sólo con un entero literal: `REDONDEAR(x, 2)`.
- Desde el 6/10/2026 `REDONDEAR` **corta el cálculo** si recibe algo que no sea un entero no
  negativo (`ErrRedondearDecimales`, `Cod50015`), y nombra `ROUND` en el mensaje. Las tres únicas
  fórmulas que lo usaban —`1062`, `VAC_DEVENG`, `FRANCO_DEVENG`— pasaron a `ROUND`.
- Se **pisó la vigencia vigente** del `1062` en vez de abrir una nueva (contra la regla 6): no
  cambió ninguna regla de negocio, era el nombre equivocado de una función, y una vigencia nueva
  habría dejado enero redondeado a 0,1 para siempre.

El control que lo encuentra sin leer código: comparar la `Fórmula Evaluada` de una línea contra su
`Cantidad`/`Importe`. Si difieren, algo entre el parser y el campo las separó.

## Relacionado

[[Grossing-up y tipo de cambio]] · [[Valor del franco]] · [[francos-fifo-ledger]] · [[valor-franco-por-terna]] · [[format-no-se-valida-al-compilar]]
