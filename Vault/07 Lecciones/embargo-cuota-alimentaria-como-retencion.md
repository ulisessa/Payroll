---
aliases: ["Embargo y cuota alimentaria como Retención"]
tipo: leccion
tema: descuentos-ganancias-sipa
tags: [leccion, descuentos-ganancias-sipa, project]
actualizado: 2026-10-04
---

# Embargo y cuota alimentaria como Retención

8883 y 8893 son Tipo 4, y YTD_RETENIDO_ANUAL suma TODO el Tipo 4: la cuota alimentaria se descuenta del impuesto

`YTD_RETENIDO_ANUAL` —el término `- YTD_RETENIDO_ANUAL` del 5010, que descuenta el impuesto ya
retenido en el año— no sale de un acumulador con fracciones. Es una fila de `Variable Sistema Liq.`
con **`Cód. Cálculo = YTD_LINEAS` y `Tipo Concepto = 4`**, así que suma **todas** las líneas de tipo
Retención del año, cualesquiera sean.

Y en Tipo 4 no están sólo los conceptos de Ganancias: **8883 Embargo judicial** (323 empleados,
356.477,80) y **8893 Cuota alimentaria** (85 empleados, 24.889.547,70) también. Un embargo o una
cuota alimentaria se computan entonces como impuesto ya retenido y **anulan la retención de
Ganancias**. En enero de 2026 afecta a **32 empleados**: a 19 les deja el 5010 en cero y a 13 se lo
baja, por 25,2 M en total. El 00291 es el caso puro: BC le liquida dos liquidaciones completas y el
5010 sale 0,00 en las dos contra 136.915,36 de Meta4, porque su 8893 de 1.580.012 le tapa los
178.434,77 que le correspondían.

**Buscar RETENIDO_ANUAL en el dispatcher de Cod50016 no lo encuentra**, y eso hace perder tiempo: los
códigos de la ayuda de Pag50146 (`HAB_GRAV_ANUAL`, `HAB_EXTORD_ANUAL`, `RETENIDO_ANUAL`) existen como
códigos propios pero las filas reales usan los genéricos `YTD_LINEAS` y `YTD_ACUM`. Hay que mirar la
fila, no el código AL. Ver [[variable-sistema-hay-que-sembrarla]] y [[system-variables-conventions]].
**Las dos cosas quedaron aplicadas el 2/10/2026:**

1. **8883 y 8893 pasaron a Tipo 2 (Descuento Empleado)**, como el 8830. No mueve ningún total:
   `Total Descuentos` suma los tipos 2, 4 y 5 (Cod50014:1591-1601). Misma familia de error que el
   4813 en [[diferencias-descuentos-enero]].
2. **`YTD_RETENIDO_ANUAL` pasó a `YTD_ACUM` sobre el acumulador nuevo `RETENIDO_IG`**, que contiene
   sólo el 5010 y el 5020. Sin esto el problema volvía con el próximo concepto de retención, y
   seguía latente el **5310 Impuesto a las ganancias año anterior**: es Tipo 4 legítimo pero de OTRO
   ejercicio, hoy está en cero y el día que tenga importe se habría restado del año en curso.

**Por qué hizo falta un acumulador y no bastó restringir la variable**: `YTD_LINEAS` pasa `''` como
código de concepto (`CalcImporteAnualLiq(VarSis."Tipo Concepto", '')` en Cod50016:816), así que
**ignora el `Cód. Concepto` que la tabla `Variable Sistema Liq.` ofrece** — el campo está, se puede
cargar y no hace nada. La función ya acepta el parámetro; el día que convenga, pasarle
`VarSis."Cód. Concepto"` deja a `YTD_LINEAS` restringible por concepto sin tocar nada más.

Un acumulador se crea como un **Concepto Liquidación con `Es Acumulador` = 1, Tipo 0 y Orden 0**
(así son BASE_IG4, SS_LIQUIDADO y los demás), y `YTD_ACUM` suma las líneas de los conceptos que lo
alimentan, no la línea del acumulador, así que el Orden 0 no lo deja corto.

## Relacionado

- [[variable-sistema-hay-que-sembrarla]]
- [[system-variables-conventions]]
- [[diferencias-descuentos-enero]]
- [[cuatro-conceptos-sin-disparar]]
- [[cuota-sindical-deducida-dos-veces]]
- [[familiar-alta-impuesto]]
