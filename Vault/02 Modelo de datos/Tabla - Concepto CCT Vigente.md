---
tipo: tabla
tags: [modelo-datos, conceptos, convenios-cct, effective-dating]
fuente: [src/Tables/Tab60019.ConceptoCCTVigente.al]
actualizado: 2026-10-04
---

# Tabla - Concepto CCT Vigente (60019)

## Propósito
Restringe **a qué convenios (y opcionalmente categorías)** aplica un concepto, con versionado por fecha. Caption: "Convenios Aplicables al Concepto". Es la tercera vigencia de [[conceptos-tres-vigencias]].

## Reglas de resolución
- **Sin ninguna fila** para el concepto → aplica a **todos** los convenios.
- Con filas de **inclusión** → aplica **sólo** a los listados.
- Fila con `Excluye` = true → "NO aplica a este convenio". **Gana sobre cualquier inclusión**, no participa del versionado por convenio (es una capa aparte) y **no tiene fecha de fin**. Si sólo hay exclusiones, el concepto sigue aplicando a todo lo demás. Para volver a incluir un convenio excluido se **borra** la fila.
- El versionado es **por convenio**: para cada convenio manda su fila con la `Vigencia Desde` más reciente `<=` la fecha de liquidación. Agregar una vigencia para un convenio no revoca las de los demás.
- Dentro de un convenio restringido, `Cód. Categoría` en blanco = todas sus categorías; con categoría = sólo esa. Para cada categoría vale la **última vigencia que la nombre** (por código o por fila en blanco), no la última a secas: una vigencia nueva agrega y actualiza, pero **no revoca lo que no menciona**. Sacarle un concepto a una categoría exige una fila `Excluye`.

El código vive en `CCTAplicaAConcepto` y `ExcluidoPorCCT` de `Cod50014.MotorLiquidacion`.

## PK e índices
PK `Cód. Concepto`, `Vigencia Desde`, `Cód. Convenio`, `Cód. Categoría` (clustered); K2 `Cód. Convenio`, `Vigencia Desde`.

## Campos
`Cód. Concepto` (→ `Concepto Liquidación.Código`), `Vigencia Desde`, `Cód. Convenio` (→ `Convenio Colectivo`, NotBlank), `Cód. Categoría` (→ `Categoría CCT` filtrada por convenio; vacío = todas), `Excluye` (Boolean).

## Triggers
Ninguno. Limpieza al borrar el último concepto (`BorrarConveniosHuerfanos`) y copia en `CopiarEn` desde [[Tabla - Concepto Liquidación]].

## Quién la lee
`Cod50014.MotorLiquidacion`. FlowField `Vigencia CCT Más Reciente` en el concepto. Páginas: `Pag50147 Concepto CCT Sub`, `Pag50197 Concepto CCT Vigente List`, `Pag50073 Conceptos Convenio Sub`.

## Vigencias
Por convenio, como arriba. La exclusión no tiene vigencia propia: si se necesita "excluida durante 2026 y de vuelta en 2027" hay que modelarla explícitamente.

## Trampas conocidas
> [!danger] Omitir una categoría de una vigencia nueva ya no la saca
> Antes sí alcanzaba, y una carga que enumeró las categorías de otro convenio dejó a los OF04 del 175/75 sin sueldo, antigüedad ni francos desde el 1/1/2026 **sin un solo aviso**. Para sacarla hay que cargar `Excluye`.

> [!warning] Copiar un concepto restringido sin copiar sus filas
> "Sin filas" significa "todos los convenios": la copia liquidaría a toda la nómina. `CopiarEn` ya copia las restricciones.

- OF01/OF03 vs OF02/OF04: [[convenio-of-depende-de-la-categoria]].
- Ver también [[Tabla - Convenio Colectivo]], [[Tabla - Categoría CCT]].
