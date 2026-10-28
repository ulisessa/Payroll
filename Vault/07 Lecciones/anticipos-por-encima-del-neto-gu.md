---
aliases: ["Los anticipos se descuentan por encima del neto garantizado"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-08
---

# Los anticipos se descuentan por encima del neto garantizado

En una liquidación con grossing-up el tapón absorbe cualquier descuento; un anticipo absorbido es plata entregada que nunca se recupera

> [!warning] Todo descuento que sea **plata ya entregada** tiene que aportar a `EXCL_NETO_GU`. Si no, el complemento lo compensa, el neto no se mueve y el anticipo se regala.

En una liquidación con neto garantizado el motor itera `COMPLEMENTO_GU` hasta que el neto alcanza el objetivo, así que un descuento de más sólo hace que suba el complemento. Para un aporte de ley eso es correcto. Para un anticipo **no**: el tripulante ya cobró esa plata, y compensarla con más bruto es pagarla dos veces.

Por eso existe el acumulador `EXCL_NETO_GU`, que `Cod50014.CalcNetoDesdeBD` devuelve al neto durante la convergencia:

```al
exit(TotalHaberes - TotalDesc + Excluido);
```

El acumulador se configura en `Config. Recursos Humanos` → **Cód. Acum. Excl. Neto GU**, y lo alimenta la `Fracción Acumulador` de cada concepto. **Aportaba uno solo**, el 8840 (anticipo de llegada). El 8830 (poder), el 8850 (haberes), el 8810 (vacaciones) y el 8870 (haberes ADM) no, así que el que pidió un anticipo de poder lo cobró y nunca se lo descontaron.

**La familia no se adivina: la define Meta4.** Meta4 tiene su propio acumulador de anticipos, `R_ANTICIPOS` (columna 1727), y da exactamente el total a excluir:

| | 04921 cierre | 04826 cierre |
|---|---|---|
| 8830 poder | 3.000.000 | 2.000.000 |
| 8840 llegada | 250.000 | 250.000 |
| 8850 haberes | — | 1.000.000 |
| **R_ANTICIPOS** | **3.250.000** | **3.250.000** |
| `NETO_GARANT` − R_ANTICIPOS | **11.904.650** | 8.060.250 |
| `LIQUIDO` de Meta4 | **11.904.650** ✔ | 7.568.500 |

Sobre las 88.616 corridas con `R_ANTICIPOS`, el total coincide con la suma de los siete `DESC_*` mapeados en 87.787, con diferencia 0,00.

**Cómo decidir concepto por concepto:** buscar las corridas donde ese `DESC_*` es el **único** con importe y compararlo contra `R_ANTICIPOS`. Así cada uno responde por sí mismo y la suma de los otros no tapa su aporte:

| Concepto | Aislado en | = R_ANTICIPOS | ≠ | Veredicto |
|---|---|---|---|---|
| 8810 ant. vacaciones | 570 | 547 | 0 | entra |
| 8830 ant. poder | 7.541 | 4.648 | 6 | entra |
| 8840 ant. llegada | 47.452 | 40.560 | 223 | ya estaba |
| 8850 ant. haberes | 26.868 | 23.585 | 7 | entra |
| 8860 desc. adelanto | 315 | **0** | 0 | **fuera** |
| 8870 ant. haberes ADM | 5.250 | 4.575 | 0 | entra |

> [!note] El 8860 y el 8835 quedan afuera
> El 8860 aparece en 315 corridas aisladas y en **ninguna** hay `R_ANTICIPOS`: Meta4 no lo cuenta como anticipo aunque se llame "adelanto". El 8835 tiene **una** fila en 31 años y nunca apareció aislado, así que no hay con qué decidirlo. Los dos van en una invariante del script, para que nadie meta la familia entera de un saque.

**La vigencia va en la misma fecha que el 8840** (12/1/2023) y no en enero de 2026: no es una tasa que cambie en el tiempo sino una propiedad estructural del concepto —un anticipo siempre fue plata entregada—, y partir la familia en dos fechas haría que una liquidación vieja recalculada tratara distinto al 8830 que al 8840.

## La trampa de orden: hay que mover la novedad en la misma pasada

El 8850 de 1.000.000 del 04826 estaba cargado sin proyecto y con fecha 31/1, así que caía en su DEVENGADOS; Meta4 lo descuenta en el cierre. Su devengado daba 3.466.749,01 contra 3.466.750 de Meta4 y **parecía bien**, pero cuadraba porque el tapón se comía el millón ([[grossing-up-tapa-errores]]). Sumar el 8850 al acumulador sin mover la novedad lo hubiera mandado a 2.466.750: un tramo que estaba exacto se rompe.

Los dos cambios van juntos. En enero de 2026 son las **únicas tres** liquidaciones con grossing-up y un anticipo de la familia; las otras 108 con 8830/8850/8870 no tienen grossing-up, así que ahí el acumulador es informativo y el neto no se mueve.

## Relacionado

- [[grossing-up-tapa-errores]]
- [[anticipos-como-novedades]]
- [[anticipo-no-es-haber-del-recibo]]
- [[anticipos-cta-cte-meta4]]
- [[novedad-con-proyecto-queda-huerfana]]
- [[comparar-columna-contra-total]]
- [[acuerdo-escalonado-por-mes-calendario]]
