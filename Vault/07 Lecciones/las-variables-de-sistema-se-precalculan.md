---
tags: [lección, motor, variables-sistema, francos]
fecha: 2026-10-11
---

# Las variables de sistema se precalculan antes del primer concepto

`LoadVariablesSistema` recorre **todas** las variables activas y las deja como valores fijos en el
contexto. Corre dentro de `LoadScalars`, **antes del bucle de conceptos**.

Entonces **una variable de sistema no puede ver nada que generen los conceptos**. No importa que el
concepto que la produce tenga orden 55 y el que la consume orden 400: cuando la variable se evaluó,
ninguno de los dos había corrido.

## Lo que costó

Se hizo que el devengo de francos (1062) corriera también en la liquidación final, para que el que
devenga en guardia de puerto no perdiera esos francos. El lote se generaba bien, pero
`PAGO_FRANCOS_SALDO` seguía dando el saldo viejo. Se buscó el problema en:

1. el filtro `<> LiqActual` de `FiltrarLotes` —real, pero no era—;
2. la caché del service tier;
3. la publicación.

**Tres publicaciones en falso.** El código estaba bien desde el principio; lo que estaba mal era
CUÁNDO se evaluaba. El propio comentario de `LoadScalars` lo decía —"SALDO_FRANCOS valúa contra el
ledger"— y había que leerlo como "y lo valúa acá, al principio".

## La forma de verlo en un minuto

La columna **`Fórmula Evaluada`** de la línea muestra con qué valor entró cada término:

```
ROUND( 1196069 + ROUND(0,5 * 14) * 0 - 113.911,33 )
                                   ↑ VALOR_FRANCO_DIA = 0
```

Ahí se ve que los días estaban bien (7) y que el precio era cero. Mirarla **antes** de suponer habría
ahorrado las tres publicaciones; es el equivalente de un depurador para este motor.

## Cómo se resuelve

Lo que un concepto genera se suma **en la fórmula**, no desde la variable:

```
  PAGO_FRANCOS_SALDO                                   el ledger, a precio FIFO por lote
+ COEF_FRANCOS * DIAS_DEVENGA_FRANCOS_COBERTURA
    * VALOR_FRANCO_DIA                                 el tramo nuevo, a precio de hoy
- #1063                                                lo que esta liquidación ya pagó como goce
```

No duplica con el lote: `PAGO_FRANCOS_SALDO` sale de `SaldoFrancos`, que **excluye la liquidación
actual**, así que el lote que el 1062 crea acá no está en el primer término. Los dos sumandos son
disjuntos por construcción.

## El sufijo necesita una entidad

`VALOR_FRANCO_DIA` daba cero por una segunda razón, independiente: se armó una línea sintética para
preguntarle el precio, y `SufijoDelLote` necesita la **entidad** —buque o proyecto— para encontrar
el atributo de precio. Una liquidación final **no tiene proyecto**, así que el sufijo salía vacío, el
parámetro caía a un nivel inexistente y el precio era 0 — mientras el FIFO valuaba los lotes reales
bien, a 53.158,67.

Se resuelve tomando el sufijo del **último lote real**, excluyendo la liquidación actual (su propio
lote tampoco tiene proyecto). El **par** convenio+categoría, en cambio, sale de la liquidación
actual: el franco se paga al par de hoy aunque se haya devengado en otra categoría.

**Queda un borde abierto**: quien devengue francos en su primera liquidación, sin ningún lote
anterior, no tiene de dónde sacar el sufijo y el precio vuelve a dar cero.

## Resultado

Enero de 2026 cerró con los cuatro conceptos de devengados no gozados **exactos contra Meta4** —12
de 12 en francos, 13 de 14 en vacaciones— y los 90 cierres de marea intactos en 1143,50 días.
