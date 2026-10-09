---
aliases: ["Equivalencia ID_PUESTO de Meta4"]
tipo: leccion
tema: migracion-meta4
tags: [leccion, migracion-meta4, project]
actualizado: 2026-10-04
---

# Equivalencia ID_PUESTO de Meta4

Tabla ID_PUESTO de Meta4 contra PUESTO de BC, deducida por co-ocurrencia; los embarcados salen con 90-100% y los de planta no salen

**Las dos codificaciones son distintas.** `ID_PUESTO` de Meta4 usa `CB01`, `MQ05`, `PT02`, `ME01`…
y **ninguno existe** entre los valores admitidos del atributo `PUESTO` de BC, que son `MR00`–`MR09`,
`OF01`–`OF05`, `FE01`/`FE02`, `FA01`–`FA36`, `CA02`–`CA15`, `EC01`. El `PUESTO` de BC **ya está
migrado con historial** —1.392 empleados con 1 vigencia, 452 con 2, hasta 53 en un caso— pero desde
otra fuente, no desde `ID_PUESTO`.

`ID_PUESTO` cubre **1995 a 2026, 5.031 empleados**, y en el **98,2%** de los empleado-mes hay un solo
puesto (176.103 de 179.370), así que la granularidad mensual alcanza para reconstruir vigencias.

## Deducida por co-ocurrencia (el puesto vigente en BC a la fecha de cada liquidación)

    CB01 -> OF01  98,2%      ME01 -> MR02  98,9%      CB02 -> FE01  100%
    CB03 -> OF03  95,2%      ME02 -> MR03  97,7%      MQ02 -> FE02  100%
    CB04 -> MR00  90,3%      ME03 -> MR06  (pocos)    CB10 -> OF05  (pocos)
    CB06 -> MR01  95,5%      MQ01 -> OF02  98,8%
    CB07 -> MR05  97,9%      MQ03 -> OF04  96,7%
    PT02 -> MR08  94,9%      MQ05 -> MR04  99,5%
    PT04 -> MR07  90,8%

El ruido del 2-10% es **coherente**: son los empleados cuyo `PUESTO` en BC está mal, que son
justamente los que la migración tiene que corregir. Los prefijos tienen sentido: **CB** cubierta,
**MQ** máquinas, **ME** mecánica, **PT** planta a bordo, **FE** especiales.

## Confirmada con el maestro de puestos (28/9/2026)

El usuario pasó `M4SYS_PUESTOS`. La tabla queda así, y **cada nombre cae en el índice del CCT 729/15
que ya habíamos medido** — una validación independiente de la co-ocurrencia:

    CB01 Capitán                        -> OF01
    CB02 Patrón de Pesca                -> FE01
    CB03 Primer Oficial de Cubierta     -> OF03
    CB04 Primer Pescador                -> MR00   índice 100  ✓ "Primer Pescador" del acta
    CB06 Contramaestre Argentino        -> MR01   índice  85
    CB07 Marinero de Cubierta           -> MR05   índice  75  ✓ "Marinero de Cubierta"
    CB10 Segundo Oficial de Cubierta    -> OF05
    MQ01 Jefe de Máquinas               -> OF02
    MQ02 Garantía de Máquinas           -> FE02
    MQ03 Primer Oficial de Máquinas     -> OF04
    MQ05 Engrasador                     -> MR04   índice  75  ✓ "Engrasador"
    PT02 Marinero de Planta             -> MR08   índice  70  ✓ "Marinero de Planta"
    PT04 Contramaestre de Frío          -> MR07   índice  80  ✓ "Contramaestre Frío"
    ME01 Cocinero                       -> MR02   índice  85  ✓ "Cocinero"
    ME02 Mozo                           -> MR03   índice  80
    ME03 Enfermero                      -> MR06   índice  80  ✓ "Enfermero"

Seis de los índices coinciden con el nombre que el acta le pone a ese porcentaje. Dos no están en el
acta —Contramaestre Argentino 85 y Mozo 80— y son plausibles.

**`FE` es personal español/de garantía**: FE01 sale de "Patrón de Pesca" y FE02 de "Garantía de
Máquinas", los dos puestos que el armador cubre con dotación propia.

## La tabla completa: es una TRADUCCIÓN, no una deducción

Al mirar los nombres de los dos lados el mapeo sale uno a uno — los nombres de BC son los de Meta4
traducidos. Los 22 puestos embarcados:

    CB01 Capitán                       -> OF01 Capitan
    CB02 Patrón de Pesca               -> FE01 Patron de Pesca
    CB03 Primer Oficial de Cubierta    -> OF03 Primer Oficial de Cubierta
    CB04 Primer Pescador               -> MR00 Primer Pescador
    CB05 Contramaestre Cubierta Esp.   -> FE03 Contramaestre Espanol
    CB06 Contramaestre Argentino       -> MR01 Contramaestre
    CB07 Marinero de Cubierta          -> MR05 Marinero de Cubierta
    CB08 Marinero Español              -> FE04   (creado el 28/9/2026)
    CB09 Segundo Contramaestre Arg.    -> MR09 Segundo Contramaestre Argentino
    CB10 Segundo Oficial de Cubierta   -> OF05 Segundo Oficial de Cubierta
    ME01 Cocinero                      -> MR02 Primer Cocinero
    ME02 Mozo                          -> MR03 Mozo
    ME03 Enfermero                     -> MR06 Enfermero
    MQ01 Jefe de Máquinas              -> OF02 Jefe de Maquinas
    MQ02 Garantía de Máquinas          -> FE02 Garantia de Maquinas
    MQ03 Primer Oficial de Máquinas    -> OF04 Primer Maquinista
    MQ04 Segundo Oficial de Máquinas   -> OF06 Segundo Oficial de Maquinas
    MQ05 Engrasador                    -> MR04 Engrasador
    PT01 Contramaestre Planta Esp.     -> FE05   (creado)
    PT02 Marinero de Planta            -> MR08 Marinero de Planta
    PT03 Control de Calidad Español    -> FE06   (creado)
    PT04 Contramaestre de Frío         -> MR07 Contramaestre de Frio

**Tres de los seis "sin equivalente" ya existían con el nombre traducido** —FE03, MR09, OF06—; sólo
hubo que crear los tres de dotación española, bajo el convenio `ESP` (`crear_puestos_esp.sql`).

## El PUESTO cuelga del CONVENIO

`Valor Atributo` tiene `Cód. Valor Padre` = el convenio, y el tipo `PUESTO` declara `CONVENIO` como
atributo padre. Por eso **OF01..OF05 aparecen dos veces**, una bajo `175/75` y otra bajo `768/19`: no
son duplicados. Las familias son `729/15` -> MR, `175/75` y `768/19` -> OF, `ESP` -> FE.

**Consecuencia para la migración**: el puesto asignado tiene que ser coherente con el convenio
vigente del empleado a esa fecha, o queda colgando de un padre que no le corresponde.

## Las tres dudas, resueltas


## Las tres dudas, resueltas

- **`DES` = "Desconocido"**, familia ADM. No es un puesto: es el relleno. **No se migra**, con sus
  31.322 apariciones.
- **Los `P??` que no son `PT` son familia `PP` = planta EN TIERRA**: PN peón, PE envasado, PF
  fileteado, PP placas, PL limpieza, PZ maestranza, PV varios, PC camarista, PD depósito, PM
  mantenimiento, PG generales. No son tripulantes, así que el índice del asegurado no los toca.
- **`CB05` Contramaestre de Cubierta Español**, y con él `CB08` Marinero Español, `PT01`
  Contramaestre de Planta Español y `PT03` Control de Calidad Español: **dotación española**. Más
  `CB09` Segundo Contramaestre Arg. y `MQ04` Segundo Oficial de Máquinas. **BC no tiene equivalente**
  para ninguno de los seis: `FE` sólo llega hasta FE02.


## Migrado el 28/9/2026 (`migrar_puesto.sql`, commiteado)

Una vigencia por **tramo de meses consecutivos con el mismo puesto** —el truco de la isla:
`(año*12+mes) − ROW_NUMBER()` es constante mientras no cambie el puesto ni se corte la secuencia—.
El último tramo de cada empleado queda **abierto**, como el resto de los atributos.

    11.612 tramos, 2.974 empleados
     9.806 vigencias anteriores borradas   ->   10.630 nuevas
       975 tramos sin convenio a esa fecha        no se escriben
         7 tramos con un par puesto+convenio inexistente   no se escriben

Los tres invariantes en cero: ningún par puesto+convenio inexistente, ningún solapamiento, ninguna
vigencia al revés.

**Control de dirección — el índice que resulta contra el `NTO_GARANTIZADO` de Meta4:**

    el índice del puesto coincide   952 entradas / 260 empleados
    NO coincide                       3 entradas /   3 empleados

**Antes eran 52 empleados con el índice equivocado; quedaron 3.**

Con dos puestos en el mismo mes —1,8% de los casos— gana el más frecuente y a igual frecuencia el
código menor: es arbitrario pero **estable**, el mismo dato da siempre lo mismo.

Sólo se borró el `PUESTO` de los empleados que se reescriben; tierra, cámaras y administrativos
quedaron intactos. Los 7 pares imposibles son inconsistencias del dato —`MR04` bajo `175/75`,
`OF03` bajo `729/15`, `MR08` bajo `JO`— donde el convenio y el puesto no se corresponden.

## Relacionado

- [[anticipos-cta-cte-meta4]]
- [[export-csv-decimal-con-coma]]
- [[historia-remuneraciones-migrada]]
