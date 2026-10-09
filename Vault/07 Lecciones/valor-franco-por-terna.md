---
aliases: ["Valor del franco por terna"]
tipo: leccion
tema: francos
tags: [leccion, francos, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-30
---

# Valor del franco por terna

**En una frase:** la pesquería del franco sale del LOTE y la categoría de la LIQUIDACIÓN que paga; VALOR_FRANCO_<CAL|LAN>_<convenio>_<categoría> viene en pesos del mes (÷30)

El importe del 1063 no sale de su fórmula —que devuelve **días**— sino del ledger FIFO, que valúa
cada lote con `VALOR_FRANCO`. Le faltaba la pesquería: pagaba de más ~10,4 M en enero de 2026.

**El valor depende de la terna pesquería + convenio + categoría**, y sólo se ve cruzando las tres:

```
LAN (tangonero) + 175/75 oficiales   →  valor pleno   (¡en los MISMOS buques!)
LAN (tangonero) + 729/15 marinería   →  30% del pleno
CAL (potero)    + 729/15 marinería   →  valor pleno
```

Resolverlo sólo por el buque le baja el franco a los oficiales; sólo por el convenio, a la marinería
de los poteros. Las dos se probaron y las dos rompían casos que estaban bien.

`ValorFrancoDia` (Cod50053) busca en dos pasos, **y las unidades no son la misma**:

1. `VALOR_FRANCO_<CAL|LAN>_<CONVENIO>_<CATEGORÍA>` — pesos del **mes**, hay que dividir por 30
2. `VALOR_FRANCO_<CONVENIO>_<CATEGORÍA>` — pesos del **día**, se usa tal cual

`VALOR_FRANCO_CAL` y `VALOR_FRANCO_LAN` son bases propias con 5 vigencias por categoría, sólo de
729/15. Ya existían pero cargadas **idénticas** al pleno, así que no diferenciaban y el motor no las
usaba; se bajó LAN al 30%. No hay variante para los convenios de oficiales y está bien: caen al
genérico. La pesquería se deriva de `TIPOACTIVIDAD` del buque con la misma convención que las
fórmulas: `= 1` → CAL, si no → LAN.

**Dos trampas de fecha que costaron dos vueltas:**

- Los **saldos iniciales no traen proyecto** (74 lotes, 4.279 días, contra 90 y 1.143). `BuqueDelLote`
  cae al historial de estados a la fecha del lote y los recupera a los 74.
- `TIPOACTIVIDAD` de los 12 buques estaba vigente **desde el 1/1/2026** —la fecha de carga— y los
  lotes de saldo inicial son del **31/12/2025**. Ningún lote encontraba su pesquería. Se retrotrajo a
  2023-01-01; abrir hacia atrás no mueve ninguna liquidación, que se evalúan a su propia fecha.

**Cómo aplicarlo:** el desglose se mira con la acción **Lotes de franco** de la línea (Pag110054), que
reconstruye el FIFO y muestra lote, pesquería, días tomados, valor y proporción contra el pleno. Al
valuar, el importe se acumula **por lote** y no después de agrupar por categoría: dos lotes de la
misma categoría pueden venir de pesquerías distintas. **La CATEGORÍA del precio es la de la
liquidación que paga, no la del lote** —cambiado el 30/9/2026 en `ParQuePagaElFranco`, para alinearse
con Meta4: un franco no gozado se salda como las vacaciones, a la remuneración vigente cuando se
paga—. La **pesquería** sí sigue saliendo del lote. Relacionado:
[[francos-fifo-ledger]], [[franco-porcentaje-por-pesqueria]], [[parametros-somu-por-pesqueria]].

## Relacionado

- Tema: `francos` (ver [[_Convenciones del vault]])
