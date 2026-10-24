---
aliases: ["BASE_PROMEDIO no mezcla porciones y totales"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, sac, liquidacion-final, acumuladores, pesqueria]
fuente: [scripts/PrevisualizarBasePromedioFinal.sql, scripts/CorregirBasePromedioFinal.sql, src/Codeunits/Cod50014.MotorLiquidacion.al, src/Codeunits/Cod50016.ContextoLiquidacion.al]
actualizado: 2026-10-11
---

# BASE_PROMEDIO no mezcla porciones y totales

El SAC de egreso aplica el coeficiente de pesquería después de dividir la base del semestre por doce.
La base debe contener los valores antes del coeficiente. En enero, los haberes de puerto y su
 gratificación aportaban sus importes ya reducidos, mientras el ledger aportaba el franco completo.
El faltante coincide con la porción no remunerativa de puerto en la historia importada de Meta4.

## Corrección configurada

`AJ_PROM_PESQUERIA`, vigente desde enero 2026, orden 469, sólo `LIQ_FINAL`, tipo `Informativo`,
no acumulador y sin impresión. Corre cuando `0 < #COEF_PESQUERIA < 1`.
Aporta el 100 % únicamente a `BASE_PROMEDIO`; no paga un haber ni modifica bases contributivas.

```text
ROUND(
    (
        #1013 + #1073 + #1076 + #1083 + #1053 + #1543 + #1547 + #1023 + #2043
        + #1603 * (#1013 + #1083 + #1543 + #1053 + #1547 + #1076)
            / IFZERO(#1013 + #1083 + #1543 + #1053 + #1547 + #1076 + #1063, 1)
    ) / IFZERO(#COEF_PESQUERIA, 1) * (1 - #COEF_PESQUERIA),
    PRECISION_REDONDEO
)
```

- Directos: `1013`, `1073`, `1076`, `1083`, `1053`, `1547` multiplican el coeficiente.
- Indirecto: `1543` reevalúa el `1013`; `1023` usa la base de feriado formada por haberes reducidos.
- `2043`: su porción reducida se confirmó contra las columnas originales de Meta4 para enero.
- `1603`: deriva una diferencia de puesto sobre componentes reducidos y franco completo; se
  distribuye proporcionalmente para no volver a ampliar su parte de `1063`.
- Se excluyen el `1063` completo, las indemnizaciones y el `3554` actualmente inflado.
- No se normalizan indiscriminadamente importes manuales sin fórmula verificable ni enfermedad y
  accidente, que usan historia separada remunerativa/no remunerativa. Tampoco se amplían los tipos
  de liquidación: esta configuración corrige las finales, no todos los cierres o regulares históricos.

> [!warning] Límite de la verificación
> La previsualización de enero corrige un caso y conserva las otras siete finales. Los componentes
> adicionales en ese caso valen cero: la lógica ampliada se revisó contra las fórmulas, pero no se
> verificó en ejecución para otras combinaciones de haberes. Requiere recálculo y contraste en BC.

## Operación

Aplicado por SQL con autorización del usuario; el script permanece en previsualización por defecto.
Las dos inserciones se hacen en una transacción y rechazan un concepto preexistente.
No se modificó AL ni se requiere publicación. Ver [[Pendientes liquidación final]],
[[Acumuladores y fracciones]] y [[el-sac-es-la-doceava-parte]].

## Recálculo verificado

El 11/10/2026 se confirmó en BC la línea informativa y su única fracción, con la vigencia nueva.
La base reconstruida y el SAC del caso afectado coinciden al centavo con la previsualización y
Meta4; las vacaciones y los SAC de las otras siete finales conservaron sus importes.
La verificación en ejecución sólo cubre la combinación efectivamente pagada en enero; no amplía
la evidencia para las ramas adicionales que valieron cero en ese caso.

## Cambio del 1063 preparado el 11/10/2026

La configuración posterior incorpora también el complemento del franco, porque el 1063 pasa a
representar sólo la parte remunerativa. Mantiene el denominador completo del 1603.
Ver [[coeficiente-franco-no-cambia-dias-fifo]]: pendiente de publicación y aplicación coordinada;
la fórmula anterior documentada arriba sigue siendo la vigente hasta entonces.

