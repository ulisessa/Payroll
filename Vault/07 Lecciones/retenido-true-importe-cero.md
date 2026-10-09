---
aliases: ["Retenido = TRUE con importe cero"]
tipo: leccion
tema: descuentos-ganancias-sipa
tags: [leccion, descuentos-ganancias-sipa, project]
actualizado: 2026-10-04
---

# Retenido = TRUE con importe cero

> [!warning] Falla en silencio
> En el buffer de retenciones 50022, Retenido = TRUE no implica que se haya retenido algo

En Codeunit 50501 "Registro diarios" (Retenciones.txt), el orden en los cuatro
regímenes es: `fntTopeRetencion` primero —que puede devolver 0 cuando no hay
disponible en el pago— y `Retenido := TRUE` después, sin condicionar. Una fila
del buffer 50022 puede quedar con `Retenido = TRUE` e `Importe retencion = 0`.

**Por qué:** cualquier lógica que use `Retenido` como "acá ya se retuvo" se equivoca en
silencio. Pasó con la guarda de pagos parciales de Ganancias: excluía la factura
del cálculo siguiente por un antecedente que nunca retuvo nada.

**Cómo aplicarlo:** al leer antecedentes del buffer, filtrar siempre
`SETRANGE(Retenido,TRUE)` **y** `SETFILTER("Importe retencion",'>%1',0)`.
`Retenido` tampoco distingue un cálculo de diario de una retención registrada: no
hay marca de registrado, y `"Importe retencion total"` es un FlowField, así que no
queda guardado el importe previo al tope. Distinguir una retención topeada de una
completa exige un campo nuevo en la tabla 50022.

## Relacionado

- [[sindical-sac-base-equivocada]]
- [[tope-sac-por-liquidacion]]
- [[tot-remun-27617-es-acumulador]]
- Tema: `descuentos-ganancias-sipa` (ver [[_Convenciones del vault]])
