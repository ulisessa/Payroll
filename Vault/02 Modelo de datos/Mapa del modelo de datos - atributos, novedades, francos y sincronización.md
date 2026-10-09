---
tipo: referencia
tags: [modelo-de-datos, mapa, mermaid]
fuente: [src/Tables/]
actualizado: 2026-10-04
---

# Mapa del modelo de datos - atributos, novedades, francos y sincronización

Diagramas de las tablas **110000–110061**. Para las tablas 50xxx/60xxx (`Liquidación`, `Línea Liquidación`, `Concepto Liquidación`, `Estado Empleado`...) ver su propia sección de [[Índice Modelo de datos (110xxx)]]. Notación: `||--o{` = uno a muchos; una línea punteada (`..`) = relación **sin `TableRelation` real** (se resuelve por código en ejecución).

## 1. Atributos tipados y entidades

Dimensiones con historial que llegan a la fórmula sin tocar el motor ([[atributos-tipados]]).

```mermaid
erDiagram
    CLASE_ENTIDAD ||--o{ TIPO_ATRIBUTO : "Cód. Clase (opcional)"
    CLASE_ENTIDAD ||--o{ ENTIDAD : "Cód. Clase (obligatoria)"
    DIMENSION_VALUE ||--o| ENTIDAD : "Código = valor de dim. global 1"
    TIPO_ATRIBUTO ||--o{ VALOR_ATRIBUTO : "Cód. Tipo Atributo"
    TIPO_ATRIBUTO ||--o{ TIPO_ATRIBUTO : "Cód. Tipo Atributo Padre (listas)"
    VALOR_ATRIBUTO ||--o{ VALOR_ATRIBUTO : "Cód. Valor Padre"
    TIPO_ATRIBUTO ||--o{ ATRIBUTO_ENTIDAD : "Cód. Tipo Atributo"
    VALOR_ATRIBUTO ||--o{ ATRIBUTO_ENTIDAD : "Cód. Valor (+ Valor Padre)"
    ENTIDAD ||..o{ ATRIBUTO_ENTIDAD : "Cód. Entidad (Buque)"
    EMPLOYEE ||..o{ ATRIBUTO_ENTIDAD : "Cód. Entidad (Empleado)"
    JOB ||..o{ ATRIBUTO_ENTIDAD : "Cód. Entidad (Proyecto)"
    CONVENIO_COLECTIVO ||..o{ VALOR_ATRIBUTO : "espejo (Convenio)"
    CATEGORIA_CCT ||..o{ VALOR_ATRIBUTO : "espejo (Categoría)"

    CLASE_ENTIDAD { code Codigo PK }
    ENTIDAD { code Codigo PK }
    TIPO_ATRIBUTO { code Codigo PK }
    VALOR_ATRIBUTO { code Tipo_Atributo PK
                     code Valor_Padre PK
                     code Codigo PK }
    ATRIBUTO_ENTIDAD { enum Tipo_Entidad PK
                       code Cod_Entidad PK
                       code Tipo_Atributo PK
                       date Vigencia_Desde PK }
```

| Diagrama | Tablas |
|---|---|
| CLASE_ENTIDAD | [[Tabla - Clase Entidad Liq]] |
| ENTIDAD | [[Tabla - Entidad Liq]] |
| TIPO_ATRIBUTO | [[Tabla - Tipo Atributo Liq]] |
| VALOR_ATRIBUTO | [[Tabla - Valor Atributo Liq]] |
| ATRIBUTO_ENTIDAD | [[Tabla - Atributo Entidad Liq]] |

**Cómo llega a una fórmula.** `Contexto Liquidación` recorre los `Tipo Atributo Liq.` con `Nombre Variable`, resuelve la entidad de *esta* liquidación (empleado, proyecto o buque = `Job."Global Dimension 1 Code"`), busca la vigencia a la fecha de referencia con `Atributo Entidad Liq.`.`Vigente` y mete el `Valor Numérico` congelado en el diccionario de variables. Si ya existe una variable con ese nombre (parámetro, fuente, sistema) **el atributo no entra** ([[parametro-y-atributo-mismo-nombre]]).

## 2. Novedades pre-liquidación

```mermaid
erDiagram
    PERIODO_LIQUIDACION ||--o{ NOVEDAD : "Cód. Período (no cerrado)"
    CONCEPTO_LIQUIDACION ||--o{ NOVEDAD : "Cód. Concepto"
    TIPO_LIQUIDACION ||--o{ NOVEDAD : "Cód. Tipo Liq. (selector)"
    CONVENIO_COLECTIVO ||--o{ NOVEDAD : "Convenio/Categoría (selector colectivo)"
    EMPLOYEE ||--o{ NOVEDAD : "No. Empleado (selector)"
    JOB ||--o{ NOVEDAD : "No. Proyecto (selector)"
    NOVEDAD ||--o{ NOVEDAD : "Novedad Origen (recurrencia)"
    NOVEDAD }o--o| LIQUIDACION : "No. Liquidación (dónde entró)"
    LIQUIDACION ||--o{ INCIDENCIA : "materializa al calcular"
    NOVEDAD }o..o{ INCIDENCIA : "sin FK: la incidencia lleva Desde Novedad = true"
```

Una novedad se carga **contra el período**, sin que exista la liquidación. Al calcular, `Gestión Novedades Liq.` evalúa `NovedadAplica` (tipo, empleado o convenio/categoría, proyecto, fecha contra la **cobertura** guardada), acumula por concepto y escribe una `Incidencia Liquidación` marcada `Desde Novedad`. Recalcular borra esas incidencias y devuelve las novedades a `Pendiente`. Ver [[Tabla - Novedad Liquidación]] y [[novedades-pre-liquidacion]].

## 3. Francos (ledger FIFO, carga inicial y buffers)

El ledger **no tiene tabla propia**: son líneas de [[Tabla - Línea Liquidación]] (cada lote sellado con convenio y categoría).

```mermaid
erDiagram
    SALDO_INICIAL_FRANCOS ||--o| LIQUIDACION : "Aplicar: una continente aprobada por tripulante"
    SALDO_INICIAL_FRANCOS ||--o| LINEA_LIQUIDACION : "No. Línea Generada = lote"
    LIQUIDACION ||--o{ LINEA_LIQUIDACION : "lotes de francos devengados"
    LINEA_LIQUIDACION ||..o{ FRANCOS_BUFFER : "agrupa por empleado+convenio+categoría (temporal)"
    LINEA_LIQUIDACION ||..o{ LOTE_FRANCO_BUFFER : "desglose FIFO de un pago (temporal)"
    VALOR_ATRIBUTO ||..o{ LOTE_FRANCO_BUFFER : "Sufijo Parámetro / Tipo Buque (CAL, LAN)"
    PARAMETRO_VIGENTE ||..o{ FRANCOS_BUFFER : "VALOR_FRANCO_CONV_CAT a la fecha de corte"
```

- [[Tabla - Saldo Inicial Francos Liq]] (persistente) → genera lotes y es reversible.
- [[Buffers temporales - francos y antigüedad]] (temporales) → sólo visualización.
- Reglas: francos no fungibles, consumo FIFO, valor por terna tipo de buque + convenio + categoría ([[francos-fifo-ledger]], [[valor-franco-por-terna]]).

## 4. Fases, estados, tipos de liquidación y cobertura

La selección de quién entra a un lote y qué días cubre cada liquidación.

```mermaid
erDiagram
    EMPLOYEE ||--o{ FASE_ALTA : "No. Empleado (tramos de relación laboral)"
    EMPLOYEE ||--o{ ESTADO_EMPLEADO : "qué hacía cada día (contiguo, sin altas/bajas)"
    FASE_ALTA ||..o{ ESTADO_EMPLEADO : "estado debe caer dentro de una fase; la baja cierra estados"
    COD_ESTADO_EMPLEADO ||--o{ FASE_ALTA : "Motivo Alta / Motivo Baja"
    TIPO_LIQUIDACION ||--o{ ESTADO_TIPO_LIQ : "Exige / Excluye (filtro de estados)"
    ESTADO_TIPO_LIQ ||..o{ ESTADO_EMPLEADO : "Cód. Estado es un FILTRO (BAJ*, NV|PL)"
    LIQUIDACION ||--o{ TRAMO_COBERTURA : "un día pertenece a UNA liquidación"
    ESTADO_TIPO_LIQ ||..o{ TRAMO_COBERTURA : "los mismos estados definen los días"
    LIQUIDACION ||--o{ USO_PARAMETRO : "versión de parámetro usada"
    PARAMETRO_VIGENTE ||--o{ USO_PARAMETRO : "Cód. Parámetro + Vigencia Desde"
```

Tablas: [[Tabla - Fase Alta Empleado]], [[Tabla - Estado Tipo Liq]], [[Tabla - Tramo Cobertura Liq]], [[Tabla - Uso Parámetro Liq]]. Tres preguntas del lote: asignación a proyecto, **fase de alta** y **estados** ([[tres-capas-fase-estado-asignacion]], [[cuando-corresponde-una-liquidacion]]).

## 5. Sincronización NAV

```mermaid
erDiagram
    CONFIG_SINC_NAV ||--o{ CTRL_SINC_NAV : "empresa activa → una fila por entidad"
    CTRL_SINC_NAV ||..o{ STG_VALOR_DIM : "Entidad = Valor Dimension"
    CTRL_SINC_NAV ||..o{ STG_EMPLEADO : "Entidad = Empleado"
    CTRL_SINC_NAV ||..o{ STG_PROYECTO : "Entidad = Proyecto"
    CTRL_SINC_NAV ||..o{ STG_DESCARGA_CAB : "Entidad = Descarga Cabecera"
    STG_DESCARGA_CAB ||--o{ STG_DESCARGA_LIN : "No Proyecto"
    STG_PROYECTO ||--o| STG_DESCARGA_CAB : "No Proyecto"
    STG_PROYECTO ||--o| STG_INFORME_CAP_CAB : "No Proyecto"
    STG_INFORME_CAP_CAB ||--o{ STG_INFORME_CAP_LIN : "No Proyecto"
    STG_PROYECTO ||--o| STG_DIA_ABORDO_CAB : "No Proyecto"
    STG_DIA_ABORDO_CAB ||--o{ STG_DIA_ABORDO_LIN : "No Proyecto"
    STG_VALOR_DIM ||..o{ STG_PROYECTO : "Buque, Marea, Actividad deben existir antes"
    STG_VALOR_DIM ||--o| DIMENSION_VALUE : "aplica"
    STG_EMPLEADO ||--o| EMPLOYEE : "aplica (+ abre Fase Alta)"
    STG_PROYECTO ||--o| JOB : "aplica (+ Default Dimensions)"
    STG_DESCARGA_CAB ||--o| CAB_DESCARGA : "aplica (NAV 50561)"
    STG_DESCARGA_LIN ||--o| LIN_DESCARGA : "aplica (NAV 50562)"
    STG_INFORME_CAP_CAB ||--o| CAB_INFORME_CAPITAN : "aplica (NAV 50559)"
    STG_INFORME_CAP_LIN ||--o| LIN_INFORME_CAPITAN : "aplica (NAV 50560)"
    STG_DIA_ABORDO_CAB ||--o| ON_BOARD_CAPTURE : "aplica (NAV 50501)"
    STG_DIA_ABORDO_LIN ||--o| ON_BOARD_CAPTURE_LINES : "aplica (NAV 50502)"
```

Flujo y orden de dependencia en [[Patrón de las tablas de staging NAV]]; configuración en [[Tabla - Config Sinc NAV]]; reloj en [[Tabla - Ctrl Sinc NAV]]. Los nombres entre `STG_*` son las nueve tablas `Stg ... NAV`.

```mermaid
flowchart LR
    NAV[(NAV)] -->|SQL Agent / linked server| STG[Tablas Stg ... NAV]
    NAV -->|OData V4 + Change Log| WS[Cod110041 Traer NAV WS]
    WS --> STG
    STG -->|Cod110036 Sinc NAV Liq. → Cod110037 por AL| REAL[Job, Employee, Dimension Value, descargas, informes]
    CTRL[Ctrl Sinc NAV: Marca Agua] -.reloj.- NAV
    CFG[Config Sinc NAV] -.configura.- WS
```

## 6. Archivo de historia Meta4 y comparador

```mermaid
erDiagram
    HIST_LIQ_META4 ||--o{ VALOR_HIST_META4 : "No. Entrada"
    COLUMNA_HIST_META4 ||--o{ VALOR_HIST_META4 : "No. Columna"
    COLUMNA_HIST_META4 }o..o| CONCEPTO_LIQUIDACION : "Cód. Concepto BC (ayuda, no autoridad)"
    EMPLOYEE ||..o{ HIST_LIQ_META4 : "No. Empleado (sin validar)"
    HIST_LIQ_META4 ||..o{ COMP_META4_BUFFER : "bruto, descuentos, neto (temporal)"
    LIQUIDACION ||..o{ COMP_META4_BUFFER : "REMUNERATIVO_BRUTO, Total Descuentos, Neto a Pagar"
    COMP_META4_BUFFER ||--o{ COMP_DET_META4_BUFFER : "drilldown por concepto (temporal)"
```

Archivo **literal**: el motor no lo lee. Ver [[Tabla - Hist. Liq. Meta4]], [[Tabla - Valor Hist. Meta4]], [[Tabla - Columna Hist. Meta4]] y [[Buffers temporales - comparador Meta4 y auxiliares]].

## 7. Bitácora y auditoría

```mermaid
erDiagram
    REGISTRO_PROCESO ||--o{ ENTRADA_REGISTRO : "No. Registro (OnDelete en cascada)"
    LIQUIDACION ||--o{ REGISTRO_PROCESO : "No. Liquidación"
    PERIODO_LIQUIDACION ||--o{ REGISTRO_PROCESO : "Cód. Período"
    CONCEPTO_LIQUIDACION ||--o{ ENTRADA_REGISTRO : "Cód. Concepto"
    CONCEPTO_LIQUIDACION ||--o{ HISTORIAL_FORMULA : "Cód. Concepto + Vigencia Desde"
```

[[Tabla - Registro Proceso Liq]] · [[Tabla - Entrada Registro Liq]] · [[Tabla - Historial Fórmula Concepto]].

## Relacionado
[[Índice Modelo de datos (110xxx)]] · [[Patrón de las tablas de staging NAV]] · [[avoid-tables-principle]]
