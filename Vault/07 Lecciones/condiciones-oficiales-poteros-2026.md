---
aliases: ["Condiciones oficiales poteros 2026"]
tipo: leccion
tema: convenios-cct
tags: [leccion, convenios-cct, reference]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-30
---

# Condiciones oficiales poteros 2026

la planilla de condiciones da USD por tonelada; PCT_PROD = (TON + ADICIONAL)/8, y dos esquemas de pago distintos

`CONDICIONES OFICIALES POTEROS CAMPAÑA 26.xlsx`, en la raíz del repo, es la fuente de las
condiciones pactadas con cada oficial de los tres poteros (A28, HF801, HF802) para la campaña 2026.

**La planilla da el precio en USD por TONELADA ENTERA. BC lo guarda como porcentaje sobre
`USD_TON_PROD`, que vale 800:**

    PCT_PROD = (TON ENTERO + ADICIONAL POR TON) / 8

Probado al centavo en tres casos que ya estaban bien: 04791 (32+10 → 5,25), 04766 y 04455 (16 →
2,00). Cargados el 30/9/2026: 04924 (7,5 → 0,9375), 04649 (32 → 4,00), 01477 (32 → 4,00) y 02452
(3,75 → 0,46875), todos **por empleado**, porque dentro de un mismo par conviven tres tarifas
distintas (768/19 OF03 tiene 04924 a 7,5, 02452 a 3,75 y 04724 sin ninguna).

El **ADICIONAL PRODUCCIÓN X TON de 10 USD** del Patrón de Pesca lo paga el concepto
`ADIC_PROD_PESCA`, no el parámetro: en 04649 sale 633,639 t × 10 × 1415 = 8.965.991,85 exacto. Por
eso va 4,00 y no 5,25. En 04791 está al revés —5,25 con el adicional plegado adentro— y también
cierra; son dos modelados del mismo trato.

**Hay dos esquemas de pago, y la planilla los separa:**

1. **Por tonelada**, con "compara con CCT, paga el mayor" (01477, 02452, 03664, 04455, 04649,
   04766, 04791, 04924). Es lo que BC ya sabe hacer.
2. **"Valores netos por todo concepto, pago al 70% para prever SAC, vacaciones y francos - a
   revisar"** (04921, 04836, 04868, 04724, 04837, 04826, 04163). Grossing-up sobre un NETO pactado
   en USD, con una retención del 30%. No cobran por tonelada: no llevan `PCT_PROD`. BC no lo
   modela; al 30/9/2026 esos seis van de 78% a 140% del neto de Meta4 en enero. Ver
   [[grossing-up-tapa-errores]] y [[basico-de-tierra-por-empleado]].

**Contradicción de la planilla**: lista a 04649 bajo CAPITAN (16 USD/ton, fijo 5.500), pero la plata
dice Patrón de Pesca — cobra el adicional de 10 USD/ton y sólo con `USD_MAREA` = 7.000 y
`PCT_PROD` = 4,00 su 2003 de enero da los 32.369.534,68 de Meta4. Se dejó como Patrón de Pesca.

Algunos valores cambian **dentro de la campaña**: 04921 y 04836 tienen un fijo para enero y otro
para febrero; 04163 empieza en febrero. Eso obliga a una vigencia por tramo, no una sola del 1/1.

## Relacionado

- [[grossing-up-tapa-errores]]
- [[basico-de-tierra-por-empleado]]
- [[art19-calamar-cuenta-corriente]]
- [[cct-175-75-remuneracion-navegacion]]
- [[cct-729-15-articulos]]
