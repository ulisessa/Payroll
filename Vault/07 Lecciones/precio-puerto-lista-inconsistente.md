---
aliases: ["PRECIO_PUERTO cambia en mayo"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-28
---

# PRECIO_PUERTO cambia en mayo

**En una frase:** El precio de puerto de oficiales cambia en mayo de 2026 y se parte por pesquería; el valor de mayo estaba cargado desde enero

**El síntoma**: el legajo 00794 en enero de 2026 cobra 5.263.800 de sueldo de puerto donde Meta4 le
paga 1.860.000. `PRECIO_PUERTO_LAN_175/75_OF02` valía **3.600 USD con vigencia desde el 1/1/2026**, y
3.600 USD es el precio de **mayo**. No era la unidad: era la fecha.

## Lo que paga Meta4, medido en `PR_PUERTO` × 30 sobre los seis primeros meses de 2026

    ene-abr  175/75 OF02  1.800.000 pesos      ( = PR_SUELDO 900.000 × COEF_PUERTO 2 )
    ene-abr  175/75 OF04  1.530.000 pesos      ( =            765.000 × 2 )
    may-jun  175/75 OF02  3.600 USD tangonero  /  6.000 USD potero
    may-jun  175/75 OF04  3.060 USD tangonero  /  5.100 USD potero
    ene-jun  768/19 OF01  5.500 USD            sin cambio en mayo y sin partir por pesquería
    ene-jun  768/19 OF03  4.304 USD            ídem

**En mayo el precio se parte por pesquería y antes no.** No es una suposición: los buques A14–A19
(`TIPOACTIVIDAD = TA`) pagan 3.600 y los A28, HF801 y HF802 (`PO`) pagan 6.000, sin una excepción.
Y 3.060/3.600 = 5.100/6.000 = **0,85**, la misma escala de [[lista-precios-oficiales]].

**No se puede derivar de `PRECIO_NAV`.** En oficiales la razón es 2, pero en marinería es **2,0 en
poteros y 2,8916 en tangoneros**, así que `PRECIO_NAV × COEF_PUERTO` con un coeficiente único no
reproduce la lista. Tiene que ser lista aparte — y por eso hay que mirarla entera y no una fila.

## El mapeo de buque Meta4 → BC

    A14..A19  ->  114..119      (tangoneros, TA)
    A28       ->  128           (potero, PO)
    HF801/2   ->  801/802       (poteros, PO)

`RIGHT(buque,3)` **no sirve**: deja pasar HF801 y descarta A14 y A28 en silencio, y un control que
sólo evalúa los poteros parece completo. Me pasó el 28/9/2026 y por poco concluyo que el precio de
mayo estaba mal en los tangoneros.

## Cómo quedó la lista

Doce filas, cuatro pares × dos pesquerías, y `Nivel = 2` en todas (varias estaban en 0 porque son
anteriores al campo). Se borraron trece: los pares inexistentes `175/75_OF01`, `768/19_OF02` y
`768/19_OF04` —ver [[convenio-of-depende-de-la-categoria]]— y las vigencias de mayo de 768/19, donde
el precio no cambia.

**Control: 67 de 70 combinaciones (mes × convenio × categoría × pesquería) dan diferencia 0,00.**
Las 3 que no son tres empleados sueltos de mayo a los que Meta4 todavía liquidó al precio viejo: un
rezago de la transición, no un error de parámetro. Enero a abril y junio cierran completos.

Script `precio_puerto_of.sql`, **commiteado el 28/9/2026**. Falta reiniciar BC y recalcular:
un UPDATE por fuera no invalida la caché del service tier — ver [[sql-directo-deja-cache-rancia]].

## Relacionado

- [[oficiales-netos-al-70]]
- [[produccion-no-se-prorratea]]
- [[produccion-oficiales-poteros]]
- [[que-tc-usa-cada-concepto]]
- [[tc-de-marea-no-es-cotizacion]]
- Tema: `conceptos-haberes` (ver [[_Convenciones del vault]])
