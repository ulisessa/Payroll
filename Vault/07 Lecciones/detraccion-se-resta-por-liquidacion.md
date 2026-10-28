---
aliases: ["La detracción se resta una vez por liquidación"]
tipo: leccion
tema: contribuciones-patronales
tags: [leccion, contribuciones-patronales, sicoss]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-10-12
---

# La detracción se resta una vez por liquidación y es mensual

Las fórmulas del `7000`, `7010`, `7060` y `7070` arrancan todas igual:

```
MAX(0, BASE_IG4 + BASE_EXT_IG4 - DED_CONT_PATR) * PCT_CONT_JUB
```

`DED_CONT_PATR` es la detracción del artículo 4 de la ley 27.541: un monto **por empleado y por mes**.
La fórmula lo resta **por liquidación**, y en esta nómina un empleado tiene varias liquidaciones en el
mismo mes —una regular, un cierre de marea, una de vacaciones—.

Enero de 2026: **157 de 329 empleados tuvieron más de una liquidación**, 84 tuvieron tres. La
detracción del mes sumó **3.992.097,60** donde correspondían **2.239.815,77**: el 178 %. Cada peso de
detracción de más es contribución patronal de menos, repartida entre jubilación, INSSJP, asignaciones
familiares y fondo nacional de empleo.

## Por qué no se vio antes

**No hay error, no hay aviso y el importe no es absurdo.** La contribución sale algo baja y nada más;
un 1,7 M de base sobre 1.946 M es medio punto, invisible mirando un recibo.

Y hay un contraste que lo disfraza: en la **misma** familia de fórmulas, el tope sí está protegido. El
`6000` hace `MIN(..., TOPE_SIPA - MES_BASE_SS_TRAB - MES_BASE_SS_VAC)`, descontando lo ya consumido en
el mes con una variable `MES_`. La maquinaria para no contar dos veces una magnitud mensual **ya
existe y se usa al lado**; a la detracción nadie se la aplicó. Ver
[[tope-sac-por-liquidacion]], que es el mismo problema con el tope del SAC.

## Cómo se arregla

En la fórmula, no en el reporte: restar `DED_CONT_PATR - MES_DED_CONT_PATR`, con una variable de
sistema de clase `PERIODO_PARAM` que devuelva lo ya detraído en el mes —hoy no existe: hay
`PERIODO_ACUM` y `PERIODO_CONCEPTO`, no una para parámetros—. Y una vigencia nueva de las cuatro
fórmulas, no un cambio sobre la vigente ([[Parámetros y vigencias]]).

## Cómo se detecta

El [[Reporte SICOSS]] lo expone: la hoja TOTALES lleva la columna **`DET APLICADA BC`** —lo que el
motor restó de verdad, sumado entre liquidaciones— al lado de **`DET TOTAL`** —lo que corresponde al
mes según los días— y la diferencia en `DIF DETRACCION`. Se eligió sumar lo realmente aplicado y no lo
correcto justamente para que la diferencia quede a la vista en vez de taparse con el valor que
debería ser.

Por SQL, la lectura directa es `Resumen Variable Liq.` con `Nombre Variable = 'DED_CONT_PATR'`: una
fila por liquidación, todas con el valor completo.

## Relacionado

- [[Reporte SICOSS]]
- [[tope-sac-por-liquidacion]]
- [[Variables de sistema]]
- [[Hallazgos abiertos]]
