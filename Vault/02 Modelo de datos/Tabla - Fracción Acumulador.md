---
tipo: tabla
tags: [modelo-datos, acumuladores, effective-dating, motor]
fuente: [src/Tables/Tab60017.FraccionAcumulador.al]
actualizado: 2026-10-04
---

# Tabla - Fracción Acumulador (60017)

## Propósito
Define **cómo el importe de un concepto alimenta a los acumuladores** (BASE_SS, BASE_IG4, BASE_SINDICAL…). Cada fila es independiente: 100% → BASE_SS y 100% → BASE_IG4 reciben el importe completo. Es la "distribución" de [[conceptos-tres-vigencias]], versionada por separado de la fórmula.

## PK e índices
PK `Cód. Concepto`, `Vigencia Desde`, `Cód. Acumulador` (clustered); K2 `Cód. Acumulador`, `Vigencia Desde` (para localizar alimentadores de un acumulador).

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `Cód. Concepto` (1) | → `Concepto Liquidación.Código` | El que aporta |
| `Vigencia Desde` (2) | Date | |
| `Cód. Acumulador` (3) | → `Concepto Liquidación.Código` donde `Es Acumulador = true` | El que recibe |
| `Porcentaje` (4, "% del importe") | Decimal 0–100 (0:4) | |
| `Invertir Signo` (6) | Boolean | El importe **se resta** del acumulador. Es una *inversión*, no una "resta": si la línea es negativa, invertir **suma**, que es lo correcto |
| `Descripción` (5) | Text[50] | |

## Triggers
Ninguno. La limpieza de huérfanas al borrar el último concepto la hace [[Tabla - Concepto Liquidación]] (`BorrarFraccionesHuerfanas`: filas donde el código es concepto **y** donde es acumulador); `CopiarEn` las copia **todas**.

## Quién la lee
`Cod50014.MotorLiquidacion` (`BuildFractionCache`: toma la **última `Vigencia Desde <=` fecha de liquidación**, **sin mirar qué versión del concepto corre**), `Cod50016.ContextoLiquidacion`, `Cod50067.ControlOrdenAcumuladores` (control estático del orden). Páginas: `Pag50144 Fracción Acumulador Sub`, `Pag50148 Alimentadores Acumulador Sub`.

## Vigencias
Línea de tiempo **propia**: no se corresponde una a una con las vigencias del concepto. [[Tabla - Línea Liquidación]] guarda `Vigencias Distribución` (`ACUMULADOR:AAAAMMDD`) para auditar con qué fracción se calculó.

## Trampas conocidas
> [!danger] Cargar una fracción con vigencia retroactiva cambia recálculos viejos
> Un recálculo de un período antiguo distribuye distinto. Se detecta comparando `Vigencias Distribución`.

- Un aporte que queda en un orden **posterior** a la lectura del acumulador da importe bajo sin error: [[acumuladores-orden-calculo]], [[concepto-negativo-despues-de-sus-consumidores]], [[control-precedencia-formulas]].
- Faltan en el ConfigPackage `Invertir Signo` y otros: [[configpackage-campos-faltantes]].
- Comparar una columna de Meta4 contra el total rompió el sindical por 1,78 M: [[comparar-columna-contra-total]].
- Embargos tipo Retención suman a `YTD_RETENIDO_ANUAL` y anulan Ganancias: [[embargo-cuota-alimentaria-como-retencion]].

## Filtro de convenio

Campo 7, Filtro Convenio (Text250). Vacío mantiene el aporte a todos los convenios; admite
filtros estándar. AplicaAConvenio utiliza un registro temporal para verificar el código sin
consultar la tabla física. El motor cachea el filtro con la distribución vigente.
Ver [[antiguedad-unificada-1053-por-convenio]].

