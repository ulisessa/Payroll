---
aliases: ["CCT 768/19: los anexos"]
tipo: leccion
tema: convenios-cct
tags: [leccion, convenios-cct, reference]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-28
---

# CCT 768/19: los anexos

El CCT 768/19 de capitanes: el salario asegurado en navegación es del convenio por categoría, el valor de puerto en tangoneros lo deja librado a cada empresa

CCT **768/2019** (AACPyPP, capitanes/pilotos/patrones de pesca). El PDF está en los uploads de la
sesión; se lee con `pdftotext -layout` (está instalado; `pdftoppm` no, así que el Read de PDF falla).
Es el convenio de los oficiales **de cubierta** — `OF01` y `OF03` en BC, ver
[[convenio-of-depende-de-la-categoria]]. Los de **máquinas** (`OF02` jefe de máquinas, `OF04` primer
oficial de máquinas) van por **175/75**, que es otro convenio: los anexos de acá **no los cubren**.

## Art. 20 y Anexo II: el salario asegurado es del convenio

> "La remuneración bruta mensual asegurada en navegación se detalla por categoría en el ANEXO II, y
> guardarán relación con la escala jerárquica referida para los salarios básicos."

Eso confirma que `NTO_GARANTIZADO` de Meta4 **no es un acuerdo individual sino una figura del CCT por
categoría** — ver [[a-cuenta-futuros-aumentos-puerto]], donde los 18 valores de marinería salieron
todos de la columna equivalente del CCT 356/03.

Anexo II, en dólares, **idéntico para tangoneros y poteros**:

    CAPITAN      índice 115    5.500,00
    1° OFICIAL   índice  90    4.207,50
    2° OFICIAL   índice  72    3.443,00

La escala no es perfectamente proporcional: 5.500 × 72/115 = 3.443,48 ≈ 3.443, pero
5.500 × 90/115 = **4.304,35** y el anexo imprime 4.207,50.

**Y la empresa usa la proporción exacta, no la impresa.** El `PRECIO_PUERTO` que medí en Meta4 para
768/19 es 5.500 USD en OF01 y **4.304 USD en OF03** — o sea 5.500 × 90/115 al centavo. Ver
[[precio-puerto-lista-inconsistente]].

## Art. 17 y Anexo V: en puerto el oficial está de guardia permanente

> "Estando el buque en puerto, los tripulantes de puente enrolados estarán a disposición 24 horas
> diarias, considerándose que el personal de puente se encuentra en **servicio de guardia
> permanente**. El pago de la jornada en puerto se ajustará a lo indicado en el Anexo V."

Anexo V — "Valores Mensuales de Francos, Órdenes y Puertos por Categoría", en índices **115/85/72**
(distintos de los 115/90/72 del Anexo II, dentro del mismo convenio):

    tangoneros   PUERTO "conf. modalidad de cada empresa"   ORDENES $3.300 / $2.439 / $2.066
                 FRANCOS u$s 2.750 / 2.050 / 1.750
    poteros      PUERTO  u$s 3.500 / 2.500 / 2.500
                 FRANCOS u$s 2.990 / 2.600 / 2.335

**En tangoneros el CCT no fija el valor de puerto**: lo deja a cada empresa. Por eso `PRECIO_PUERTO`
de 768/19 es un valor de empresa y no se puede auditar contra el convenio.

En poteros el CCT sí lo fija en 3.500/2.500/2.500 y **Arbumasa paga 5.500/4.304**, o sea la tarifa de
navegación también en puerto. Es coherente con el Art. 17 —en puerto el oficial está de guardia
permanente, así que cobra como navegando— y es justamente el hueco que cubre "a cuenta de futuros
aumentos". Pagar por encima del convenio es legítimo; el convenio es piso.

Art. 16: **"Los días de puerto y los de accidentes laborales se considerarán como días embarcados"**
a los efectos de los francos compensatorios.

Anexo IV, % de participación en producción (buques langostineros): capitán 22, 1° oficial 18,
2° oficial 16. Ver [[produccion-oficiales-poteros]].

## Relacionado

- [[convenio-of-depende-de-la-categoria]]
- [[a-cuenta-futuros-aumentos-puerto]]
- [[precio-puerto-lista-inconsistente]]
- [[produccion-oficiales-poteros]]
- [[art19-calamar-cuenta-corriente]]
- [[basico-de-tierra-por-empleado]]
- [[cct-175-75-remuneracion-navegacion]]
