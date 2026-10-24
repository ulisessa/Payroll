---
aliases: ["Un atributo cargado que nadie lee", "COD_ZONA sale del atributo"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, atributos, zona-desfavorable]
actualizado: 2026-10-11
---

# Un atributo cargado que nadie lee

**En una frase:** el dato puede estar perfecto y no servir de nada, porque lo que el motor lee es el **Nombre Variable**, no el atributo; y antes de hacer que lo lea hay que contar a cuántos se lo va a dar.

## El caso

A 90448 le faltaba la zona desfavorable. El valor **estaba cargado**: atributo `ZONA_DESFAVORABLE`, código 69 (Santa Cruz), vigente desde el 9/1/2026. Y sin embargo el concepto `2703` no generaba ni la línea en cero, porque su condición es `COD_ZONA > 0`.

`InjectZonaDesfavorable` (Cod50014) resuelve `COD_ZONA` en este orden:

1. una **Fuente de Datos o parámetro llamado `COD_ZONA`**, que ya dejó su valor en el contexto;
2. el `Zona Desfavorable` del **proyecto**;
3. el de la **ficha** del empleado.

El atributo se publicaba como `ZONA_DESF`. Ningún eslabón lo miraba, así que la zona caía a la ficha, que estaba en 0. El comentario del propio código dice que el atributo **es** el camino previsto —"para que la zona salga del atributo con historial, vigente a la fecha de la liquidación, en vez del entero sin fecha de la ficha"— y sólo faltaba que se llamara igual.

> [!tip] El contrato es el nombre, no la tabla
> Un atributo, un parámetro y una fuente de datos entran al contexto por su `Nombre Variable`. Si no
> coincide con lo que la fórmula pide, el dato existe y el cálculo no lo ve. Y si coincide con el de
> otro objeto, gana uno solo y el otro queda mudo: [[parametro-y-atributo-mismo-nombre]].

## Lo que no se puede hacer es renombrarlo y listo

El atributo estaba cargado en **287 entidades** y la zona la cobran **41**. Es el **domicilio**, no el derecho al adicional. Renombrarlo a secas le habría dado zona a mucha gente:

| | |
|---|---|
| Atributo cargado y Meta4 paga zona | 41 |
| Atributo cargado y Meta4 **no** paga | 197 |
| Meta4 paga y falta el atributo | **0** |

De los 197, la mayoría eran inocuos —no existe `PCT_ZONA_DESF` para 729/15, 175/75 ni 768/19, así que el `2703` pagaba 0— pero **7 de FA sí tienen el porcentaje cargado** y habrían empezado a cobrar el 20 %. Siete recibos que empiezan a pagar un adicional no es un detalle.

## Y el código importa, aunque parezca que no

El `2703` usa `COD_ZONA` **sólo en la condición**: el importe sale de `PCT_ZONA_DESF` por convenio. Pero el **`2704`** hace `BASICO * TRAMO('ZONA_DESFAV', COD_ZONA) / 100`, y la tabla da **1,45 % para 7 · 6,50 % para 29 · 7,30 % para 69**. Son 7,3 M en enero de 2026.

Para 32 de los 41, el atributo decía **29** (Chubut) y la ficha **69** (Santa Cruz). Geográficamente el 29 parecía el correcto —liquidan con `PN-ADM-PTOMDY`, Puerto Madryn, que es Chubut— **pero la plata dijo lo contrario**: con el 69 de la ficha el bruto de los 40 cierra contra Meta4 (141.916.597,86 contra 141.905.748,87, y el único que se aparta es uno por 10.848,83, que no es el salto de tramo). Con 29 el `2704` bajaría ~325.000 y dejarían de cerrar 39.

> [!important] Meta4 no podía arbitrar y el bruto sí
> Meta4 guarda el **porcentaje** (`PORC_ZONA_DESF`, 20 o 30 para el `ASIG_ZONA_DESF`) y **no el código
> de provincia**. Ninguna columna está mapeada al `2704`. Lo que decidió fue el bruto agregado, que es
> el único juez disponible cuando el dato maestro no tiene fuente de verdad.

## Cómo se hizo, en tres pasos y en ese orden

1. **Borrar** el atributo de los 197 que liquidaron enero y no cobran zona en Meta4. Acotado a enero a propósito: de los otros 49 no hay recibo contra el cual decidir, y "no cobró zona en enero" no significa nada si no trabajó.
2. **Corregir** a 69 los 32 que decían 29, para que el renombre no mueva a nadie que ya cierra.
3. **Renombrar** `ZONA_DESF` → `COD_ZONA`. La previsualización listó **un solo** empleado afectado: 90448.

Los dos primeros son inocuos mientras el atributo se llame `ZONA_DESF`, y por eso van antes. Cada script lo verifica con una guarda explícita: si ya estuviera renombrado, el borrado mueve plata y no puede correr a ciegas.

## Y después del renombre seguía sin cobrar: la vigencia cerrada el día de la baja

Renombrado el atributo y recalculado, 90448 **seguía en cero**. La fórmula evaluada de su `2704` lo
mostró sin intermediarios:

```
90448:  IF(0 > 0,  1.009.193,22 * TRAMO('ZONA_DESFAV', 0) / 100, 0)
80002:  IF(69 > 0, 1271184      * TRAMO('ZONA_DESFAV', 69) / 100, 0)
```

Su fila del atributo iba del **9/1 al 24/1** —exactamente su fase— pero la liquidación final tiene
`Fecha Liquidación` = **31/1**, y ésa es la fecha con la que `AtributoVigente` resuelve. Al 31/1 no
hay fila vigente, `COD_ZONA` da 0 y la condición del `2703` queda en falso. Era **el único de los 90**
con la vigencia cerrada; los otros 89 están abiertas, y por eso cobran.

> [!danger] Un atributo cerrado el día de la baja es invisible para la liquidación final del egresado
> La final se referencia al **fin del mes**, no a la baja ([[ventana-liquidacion-es-cobertura]] es
> sobre la cobertura; la `Fecha Liquidación` es otra cosa y sigue siendo fin de mes). Así que cerrar
> un atributo "bien" —el último día de la relación laboral— lo saca de la liquidación que justamente
> tiene que pagarlo.
>
> Hoy sólo muerde en la zona, porque los demás atributos de 90448 (`CATEGORIA`, `CONVENIO`,
> `SINDICATO`, `OBRA_SOCIAL`) están abiertos. Pero cualquier carga prolija de un egreso va a cerrarlos
> todos, y entonces el convenio y la categoría del egresado también desaparecen. **Es un agujero del
> motor, no del dato**, y la salida de fondo es que los atributos se resuelvan a la fecha de cobertura
> y no a la de liquidación. Arreglado el caso abriendo su vigencia; el criterio queda pendiente.

## Lo que queda abierto

Los **49** que tienen el atributo (44 con 29, 5 con 7) y no liquidaron enero. Si liquidan en febrero van a cobrar zona, y recién ahí hay recibo para compararlo.

## Relacionado

- [[parametro-y-atributo-mismo-nombre]] · [[atributos-tipados]] · [[tipo-atributo-tres-campos-silenciosos]]
- [[previsualizar-antes-de-migrar]] — controles de dirección antes de escribir
- [[cobertura-parcial-no-es-ausencia]] — el otro arreglo del mismo empleado

## Resolución por cobertura implementada el 12/10/2026

La final usa el último día de cobertura para atributos del empleado y su encuadre, conservando
la fecha habitual de los otros cálculos. Implementado y compilado, pendiente de publicar y
recalcular. Ver [[final-vacaciones-sac-descuentos-coordinados]].

