---
aliases: ["El precio del franco tiene tres niveles"]
tipo: leccion
tema: francos
tags: [leccion, francos, project]
actualizado: 2026-10-08
---

# El precio del franco tiene tres niveles

Convenio, acuerdo de empresa y pesquería son tres ejes distintos, y el nombre del parámetro no los distingue

> [!warning] `VALOR_FRANCO_LAN` no es "langostino" contra "calamar": es el **convenio**. El acuerdo de empresa vive en `VALOR_FRANCO_EMP_*`, y confundirlos paga el franco al precio equivocado sin error.

La familia tiene **cuatro** parámetros y el sufijo engaña, porque mezcla dos ejes:

| Parámetro | Qué es | OF02 | OF04 |
|---|---|---|---|
| `VALOR_FRANCO_LAN` | convenio, langostino | 3.000 | 2.550 |
| `VALOR_FRANCO_EMP_LAN` | acuerdo de empresa, langostino | 3.500 | 2.975 |
| `VALOR_FRANCO_CAL` | convenio, calamar | 3.000 | 2.550 |
| `VALOR_FRANCO_EMP_CAL` | acuerdo de empresa, calamar | 3.600 | 2.975 |

Todos en USD mensuales, al `TC_COMPRADOR`, con el divisor 30 del concepto llevándolos a día.

**El convenio no se parte por pesquería; el acuerdo de empresa sí.** La lista de precios del CCT 175/75 es por categoría ([[lista-precios-oficiales]]), así que `VALOR_FRANCO_CAL` y `VALOR_FRANCO_LAN` llevan **los mismos valores**, y es lo que paga Meta4 como `PR_FRANCO` en los dos oficiales medidos. Lo que varía entre poteros y tangoneros es el acuerdo de empresa.

**El reparto son dos conceptos, no uno:**

- **1063** paga el **convenio**. No tiene fórmula de precio —vale `DIAS_FRANCOS_PERIODO`— y lo valoriza el ledger con la terna del lote ([[valor-franco-por-terna]]), tomando `VALOR_FRANCO_<suf>` del `Parámetro del valor` del concepto.
- **2083** paga la **diferencia** con `VALOR_FRANCO_EMP_<suf>`, restando `#1063 + #1053`.

Medido en enero de 2026, contra la corrida TI=13 de Meta4:

| | 1063 | 2083 |
|---|---|---|
| 04826 (OF04) | 120.275 ✔ | 20.045,83 ✔ |
| 04921 (OF02) | 141.500 ✔ | 28.300 contra 23.583,33 |

> [!warning] Cargar el total en `VALOR_FRANCO_CAL` anula el 2083
> Es el error que costó el rodeo: con `VALOR_FRANCO_CAL` igual a `VALOR_FRANCO_EMP_CAL`, el 1063 paga el acuerdo entero y la resta del 2083 da **cero**, sin ningún aviso. El total del recibo sale bien y el reparto queda mal, que es justo lo que un control por importe no ve. Si el 2083 da cero en un potero, lo primero a mirar es si el convenio y la empresa tienen el mismo valor.

> [!note] El 2083 ramifica por el **código** del atributo
> `IF(TIPOACTIVIDAD = 'TA', <LAN>, IF(TIPOACTIVIDAD = 'PO', <CAL>, 0))`. Los valores son `TA` Tangonero (sufijo LAN, número 0) y `PO` Potero (sufijo CAL, número 1); el 1053 y el 1083 ramifican el mismo eje con `= 1`, que es la proyección numérica de `PO` ([[atributo-comparar-por-codigo]]). El atributo cuelga del **buque**, cuyas entidades son `801`, `802`, `126` y `128` —el número, no `HF801`—.

> [!note] OF02 queda a propósito con `EMP_CAL` en 3.600
> Meta4 le paga el equivalente a 3.500, el valor de langostino. El 2083 del 04921 queda 4.716,67 arriba por eso: es una diferencia **conocida**, no un error.

## La estacionalidad explica por qué la mayoría va al valor de langostino

En enero los tangoneros están parados fuera de campaña y los poteros arrancan la suya, así que casi todos los francos que se pagan se devengaron antes, en tangonero. Medido: de los 85 días de franco OF02 de enero, **84 se valorizan al convenio de langostino** y uno solo al de calamar; en OF04, 4 de 5. Un franco se valúa con el par y el buque **de su lote**, no con los de hoy, así que esa mezcla es lo esperado y no un síntoma.

> [!warning] Un saldo inicial puede traer un convenio que la categoría contradice
> El saldo inicial de francos del 04826 (OF04) viene sellado con convenio **768/19**, contra la regla de que OF02/OF04 son 175/75 ([[convenio-of-depende-de-la-categoria]]). Su propio `Valor Franco Estimado` —121.550— se calculó con 2.550, el valor de convenio. Sin verificar cuántos saldos iniciales más tienen el par cruzado.

## Relacionado

- [[valor-franco-por-terna]]
- [[franco-porcentaje-por-pesqueria]]
- [[a-cuenta-futuros-aumentos-francos]]
- [[francos-fifo-ledger]]
- [[convenio-of-depende-de-la-categoria]]
- [[parametros-somu-por-pesqueria]]
- [[un-valor-una-fuente]]
