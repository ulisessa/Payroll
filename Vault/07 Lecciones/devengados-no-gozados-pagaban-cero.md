---
tags: [lección, conceptos, francos, vacaciones, liquidación-final]
fecha: 2026-10-10
---

# Los devengados no gozados existían y pagaban cero

El hueco de ~17 M del bruto de enero de 2026 no era un concepto que faltaba: eran **cuatro que ya
existían** y pagaban cero.

| Meta4 | BC | Descripción | Orden |
|---|---|---|---|
| `FCOS_NO_GOZADOS` | **2803** | Indemnización francos no gozados | 400 |
| `FCOS_NO_GOZ_SAC` | **2804** | SAC s/ francos no gozados | 405 |
| `VAC_NO_GOZADAS` | **3973** | Vacaciones no gozadas | 555 |
| `VAC_NO_GOZ_SAC` | **3974** | SAC s/ vacaciones no gozadas | 560 |

Los cuatro están activos desde 2023, con orden de cálculo, y **ya generaban línea** en enero —446,
446, 504 y 504— **todas en 0,00**: `Fórmula`, `Condición` y `Variable Cantidad` vacías. Es el patrón
deliberado de [[anticipos-como-novedades]]: un concepto sin fórmula espera un aportante.

## Cómo encontrarlo

Los cuatro suman **exactamente** el `H_INDEMNIZACION` de clase A de Meta4. Lo que Meta4 llama
indemnización *es* la suma de los devengados no gozados, no un concepto aparte. Buscar un concepto
de indemnización en BC era buscar lo que no existe.

Y hay dos más de la misma familia, también vacíos: **3975/3976**, de años anteriores.

## El franco no se puede valorizar por parámetro

Primer instinto: `SALDO_FRANCOS * VALOR_FRANCO`, todo por configuración. **No cierra**, y los datos
lo dicen solos:

| Categoría | Valor por día que pagó Meta4 |
|---|---|
| `729/15` `MR08` | 54.143,09 · 59.803,50 · 53.158,67 |
| `729/15` `MR04` | 57.904,93 · 58.010,40 · 77.939,33 |

Mismo convenio y misma categoría, tres valores distintos cada uno. Si fuera un `VALOR_FRANCO` por
terna ([[valor-franco-por-terna]]) los tres `MR08` pagarían idéntico. El saldo se valoriza **lote por
lote**, que es lo que el ledger FIFO ya modela y lo que un parámetro con vigencia no puede: daría el
valor de hoy para todos.

Por eso hace falta código, pero **una línea**, componiendo dos funciones públicas que ya existían:

```al
'PAGO_FRANCOS_SALDO':
    exit(FFrancosMgt.ValorPagoFrancosFIFO(
        FEmployeeNo, FFrancosMgt.SaldoFrancos(FEmployeeNo, FLiqNo), FFechaRef, FLiqNo));
```

`PAGO_FRANCOS_FIFO` no servía: paga los francos **consumidos del período** —los días en estado
Francos— y el que se va no los consumió, se va con el saldo sin gozar. `ValorPagoFrancosFIFO` ya
recibía los días como argumento, así que basta pasarle el saldo. `CaminarFIFO` marca los lotes, de
modo que el saldo queda en cero después de pagarlo, que es lo correcto cuando el vínculo terminó.

**El saldo predice a quién le toca**: los 6 con saldo > 0 son exactamente los 6 que Meta4 pagó, y los
2 con saldo 0 —ambos de tierra— no cobraron nada. Como control de un ledger entero, es barato.

De paso quedó validado que los **francos consumidos** coinciden exactamente entre BC y Meta4:
`DIAS_FRANCO` de Meta4 **no** son los no gozados, son los consumidos del mes, y dieron igual en los
20 casos comparados.

## Vacaciones va por novedad, y no es incoherencia

BC no arrastra saldo de vacaciones, así que el 3973 usa el **tercer modo de carga** que el motor ya
tiene: la novedad trae sólo la **cantidad** en días y la fórmula la valoriza con `CANT_INCIDENCIA`,
igual que las horas extras. La base se copia del 3553 —promedio sobre 25 por los días por el
coeficiente de pesquería, ver [[vacaciones-tripulantes-promedio]]— sin la rama de grossing-up, que
pertenece al concepto que ancla el GU.

Francos calculado y vacaciones por novedad no es una inconsistencia: el dato existe en un caso y no
en el otro.

## La fórmula de la provisión no es la de la final

La provisión de junio prorratea el devengamiento del año: la columna `K` del Excel tiene dos
variantes, `I/12*6` y `I/360*H`, que son **la misma regla** —con `H = 180` las dos dan `I/2`, y el
corte en los 180 días es donde el proporcional toca el tope—. Eso ya está implementado en BC como
`VAC_DEVENG`.

Pero en la **liquidación final** los días son el **saldo pendiente**, no un proporcional: a un
empleado con 12 años de antigüedad dado de baja el 2 de enero Meta4 le liquidó 4 días, y el
proporcional daría una fracción. Validar la fórmula de la final contra la provisión de junio mide
otra cosa.

## El comodín que ensuciaba 316 recibos

Los cuatro tenían `Tipos Liq. Aplicables` **vacío**, que es comodín
([[vacio-en-tipos-liq-aplicables-es-comodin]]), y por eso metían ~1.900 líneas en cero en *todas* las
liquidaciones de enero. Acotarlos a `LIQ_FINAL|RELIQUIDACION|SALDO_INICIAL` limpia el recibo de los
316 que no se dieron de baja.

## Las tres decisiones de forma de la novedad

Cargar los días del 3973 tiene tres trampas, y cada una ya mordió antes:

1. **Sin proyecto.** Una novedad con proyecto sólo entra en la liquidación de ESE proyecto
   ([[novedad-con-proyecto-queda-huerfana]]), y las `LIQ_FINAL` nacen sin proyecto porque agrupan por
   empleado. Con proyecto quedarían huérfanas.
2. **Tipo de liquidación y fecha coherentes.** Cargados los dos y en desacuerdo, la novedad no entra
   en ninguna ([[novedad-tipo-liq-y-fecha-se-pelean]]). Por eso la fecha es la **fecha de baja** de
   cada uno y no el 31/1: la cobertura de una final corta en la baja, y una fecha posterior caería
   fuera. Las ocho de enero de 2026 verificaron caer dentro de su propia cobertura.
3. **Sin convenio ni categoría.** Cargarlos sólo restringe, y si no coinciden con los que resuelve el
   motor la novedad no aplica.

Y `Estado` en 0 con `No. Liquidación` vacío: las aplica el cálculo, no la carga.
