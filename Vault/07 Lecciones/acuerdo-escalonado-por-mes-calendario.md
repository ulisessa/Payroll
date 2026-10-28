---
aliases: ["El acuerdo escalonado cambia por mes calendario"]
tipo: leccion
tema: parametros-atributos
tags: [leccion, parametros-atributos, project]
actualizado: 2026-10-08
---

# El acuerdo escalonado cambia por mes calendario

Un acuerdo que dice "fijo mensual marea febrero" se aplica desde el 1 de febrero, no desde el día que sale la marea de febrero

> [!warning] La vigencia de un neto acordado va el día 1 del mes. Anclarla en la salida de la marea adelanta el escalón y paga de más los últimos días del mes anterior.

Los netos acordados con los oficiales de poteros vienen escalonados en la planilla de condiciones como *"fijo mensual marea enero"*, *"marea febrero"*, *"marea marzo"*. La lectura natural —y la que se cargó primero— es que cada escalón arranca cuando el buque **sale** a esa marea. Es la equivocada.

**Por qué:** la salida casi nunca cae el 1. La marea 07 del HF801 salió el **30 de enero**, así que con la vigencia ahí los tres últimos días de enero ya cobraban el valor de febrero. Parecía lo correcto: poner el 1/2 "dejaba la marea dos días corta".

Los devengados del 29 al 31 de enero de 2026 lo resuelven, porque son tres días sueltos después de la salida:

| | BC con la vigencia al 30/1 | Meta4 |
|---|---|---|
| 04836 | `16.000 × 3/30 × 0,70 × 1415` = 1.584.799,15 | **1.188.600,00** = `12.000 × …` |
| 04921 | `20.000 × 3/30 × 0,70 × 1415` = 1.980.999,56 | **1.683.850,00** = `17.000 × …` |

Los dos usan el valor de **enero** para esos tres días, aunque la marea de febrero ya estuviera navegando. Moviendo las dos vigencias al 1/2 los dos dan exacto.

**Cómo aplicarlo:** cargar `USD_MAREA` y `NETO_GU_MAREA` con `Vigencia Desde` el día 1 del mes que nombra el acuerdo, y de paso corregir al 04163, que no tiene liquidaciones con qué verificarse: sus escalones pasaron del 26/1 y el 13/2 —salidas del HF802— al 1/2 y el 1/3. Su acuerdo no lista enero, así que queda sin valor antes de febrero, y eso es lo que corresponde.

> [!note] Las vigencias que ya cuadran no se tocan
> Las primeras de 04836 y 04921 quedaron en el **3/1**, salida de la marea 06, y ahí se dejan: con esa fecha su Regular y su Cierre de enero dan exactos contra Meta4, y el escalón de enero no tiene con qué compararse más atrás. Mover lo que ya cuadra no compra nada y puede romperlo.

El error se detecta sólo en un tramo que caiga **entre la salida y el fin de mes**. En el cierre de marea no se ve: cubre la marea anterior y resuelve el escalón viejo igual de las dos maneras.

## Relacionado

- [[oficiales-netos-al-70]]
- [[condiciones-oficiales-poteros-2026]]
- [[grossing-up-tapa-errores]]
- [[anticipos-por-encima-del-neto-gu]]

## Excepción: un ascenso a mitad de mes (04826, 15/10/2026)

La planilla de condiciones lista a 04826 **dos veces**: Primer Oficial de Máquinas (15.000 / 6.600) y Jefe de Máquinas junto con 04837 (22.000 / 9.000). Se ascendió con la marea 8 del HF802: el cierre del 1 al 12/2 cierra con 15.000, y el devengado del 13 al 28/2 de Meta4 (neto 11,25 M contra 7,67 M de BC, 6 M de diferencia en el tapón 2003) corresponde a 22.000 / 9.000 (BC con esos valores da 11,1 M). La vigencia va **el 13/2, día de la salida**, no el 1/2: un cambio de puesto no es un escalón por mes. Script: `scripts/Escalon04826Jefe.sql`. El atributo PUESTO de 04826 sigue en OF04 hasta el 28/2 y pasa a OF02 el 1/3; hoy no afecta el neto pactado, pero conviene alinear la fecha.

## Corrección de 04163 con datos de marzo (20/10/2026)

La nota de arriba movió los escalones de 04163 al día 1 «sin liquidaciones con qué verificarse». Con marzo se pudo verificar y **el 1/3 estaba mal**: Meta4 liquidó el cierre del 13/3 (cobertura 1 al 22/3, 22 días) con 12.000 USD —`12.000 × 1.360 × 70 % × 22/30 − 250.000` de anticipo = 8.127.600— y la devengada del 23 al 31/3 con 15.000. El escalón de marzo arranca con la **salida de la marea nueva (23/3)**, como en 04826 (13/2) y 04921 (17/2), que ya estaban en la fecha de salida y cuadran. `scripts/EscalonGU04163Marzo.sql`: la fila del 1/3 pasa a 12.000 y se agrega la del 23/3 con 15.000, en `USD_MAREA_04163` y `NETO_GU_MAREA_04163`. Antes de mover un escalón al día 1 hay que verificarlo contra un tramo que caiga entre el 1 y la salida; el caso de 04836/04921 (devengados del 29 al 31/1) no alcanza para generalizar.
