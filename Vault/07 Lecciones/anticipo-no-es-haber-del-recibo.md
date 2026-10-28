---
aliases: ["El anticipo no es un haber del recibo"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
actualizado: 2026-10-04
---

# El anticipo no es un haber del recibo

Los anticipos 4803/4813/4823 viven sólo en el Tipo Imputación 4 de Meta4, que es el pago por fuera; el recibo sólo lleva el descuento

> [!warning] Convertir el Tipo Imputación 4 de Meta4 en novedad de haber inflaba el recibo mensual: el anticipo es un pago por fuera del recibo mensual.

**El anticipo no es un haber del recibo.** En Meta4 el corte es perfecto y sin una sola excepción en
todo 2026:

    4803 ANTICIPO_PODER    163 apariciones en Tipo Imputación 4    0 en recibos
    4813 ANTICIPO_LLEGAD   494                                     0
    4823 ANTICIPO_HABERE   240                                     0
    8830 DESC_ANT_PODER      0                                   263 en recibos
    8850 DESC_ANT_HABE       0                                   413
    8870 DESC_ANT_HAB_AD     0                                    32

**`Tipo Imputación = 4` es el movimiento de PAGO del anticipo**, no un recibo de sueldo: es la plata
entregada por fuera de la liquidación. El recibo sólo **recupera** el adelanto, y por eso los
descuentos viven en los tipos de recibo y los anticipos en ninguno.

El testigo es el **00794 en enero de 2026**, con dos entradas del mismo mes:

    entrada 3764   ti=1  el recibo mensual   DESC_ANT_HABE 700.000, TOT_HAB_SIN_AP 0,07
    entrada 15302  ti=4  el pago             ANTICIPO_HABERE 140.000, TOT_HAB_SIN_AP 140.000

El 140.000 vive sólo en el movimiento. BC se lo pagaba como haber porque la migración convirtió el
`ti=4` en una novedad de haber.

## Corregido el 28/9/2026: 897 novedades anuladas

`anular_anticipos.sql`. **Anuladas, no borradas**: `Anulada` es un estado de la tabla, se revierte
desde la página con `ReactivarNovedad`, y deja el rastro contra Meta4 que permite auditar la
decisión. El efecto son **23.340.000 de haberes de menos sólo en enero** y 33.185.000 en febrero.

**La guarda pagó sola**: detectó **3 novedades cargadas a mano** —julio de 2026, concepto 4813,
colectivas, con proyecto `PP-114-0003xx`— que no vienen de la migración y **no se tocaron**. Son el
uso real del concepto hacia adelante; la migración cubre enero a junio.

**El `Tipo Imputación = 4` emite su propio recibo.** El usuario primero dijo que era una orden de
pago y **se retractó el mismo día: sí se emite recibo para los anticipos**. O sea que el anticipo se
muestra, pero **en SU documento, no en el recibo mensual**.

Eso no cambia la anulación: el recibo mensual de Meta4 no lo lleva, y meterlo ahí infla el mensual y
no reproduce ninguno de los dos documentos. Lo que abre es una pregunta de alcance: **BC no tiene
tipo de liquidación para el anticipo** y hoy no lo representa en ningún lado. Para conciliar el
mensual está bien; emitir el comprobante del anticipo desde BC sería un tipo de liquidación nuevo, no
reactivar estas novedades.

**Queda una inconsistencia menor**: las 3 novedades de julio cargadas a mano —4813, colectivas,
250.000 cada una— harían aparecer el anticipo como haber en el recibo **mensual** de julio, que es
justamente donde no va.

## Relacionado

- [[a-cuenta-futuros-aumentos-puerto]]
- [[adicional-art-23-vs-art-33]]
- [[adicional-tareas-mecanicas]]
