---
tipo: tabla
tags: [modelo-datos, configuracion, formulas, variables]
fuente: [src/Tables/Tab60015.FuenteDatosLiquidacion.al, src/Codeunits/Cod50016.ContextoLiquidacion.al]
actualizado: 2026-10-04
---

# Tabla - Fuente Datos Liquidación (60015)

## Propósito
Define una **variable nombrada del contexto de fórmulas** que se llena al calcular consultando *cualquier tabla de BC* con `RecordRef`. La tabla, el campo valor y los filtros se guardan como **IDs de objeto/campo**, así que agregar una fuente nueva es configuración, no código ([[avoid-tables-principle]]). Es la vía por la que llegan a la fórmula los atributos tipados ([[atributos-tipados]]), las incidencias (`INCID_<concepto>`), las producciones de descarga, etc.

La fórmula siempre ve un **número** (el contexto es `Dictionary of [Text, Decimal]`); el `Tipo Dato` sólo conserva el valor original para auditar e imprimir.

## PK
`Nombre Variable` (Code[30]), clustered. Sin otros índices.

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `Nombre Variable` (1) | Code[30] | Nombre en la fórmula. OnValidate → `Nombres Variables Liq.`.`ExigirLibre` (`Cod110051`): el nombre no puede colisionar con parámetros, variables de sistema, conceptos |
| `Descripción` (2), `Etiqueta Recibo` (16), `Mostrar en Recibo` (15), `Activo` (12, InitValue true) | | Presentación / habilitación |
| `Id. Tabla` (3) | Integer | Valida que exista en `AllObjWithCaption`; **al cambiarla pone en cero** campo valor, filtros, campos de fecha y `Fin Efectivo`, y **borra** los filtros asociados |
| `No. Campo Valor` (4) | Integer | Valida que exista el campo y que su tipo coincida con `Tipo Dato` |
| `Tipo Dato` (18) | Enum [[Enums de liquidación#Tipo Dato Fuente Liq]] | Decimal / Texto / Fecha |
| `Función Agregado` (5) | Enum [[Enums de liquidación#Función Agregado Liq]] | SUM, COUNT, MAX, MIN, LOOKUP, DIAS_OVERLAP, DURACION_INICIO, DURACION_AÑO |
| `No. Campo Fecha Inicio` (13) / `No. Campo Fecha Fin` (14) | Integer | Para las funciones por intervalo |
| `Fin Efectivo` (17) | Boolean | Para tablas con vigencia sin campo fin (p. ej. Estado Empleado): el fin de cada fila se deriva como inicio del siguiente − 1 de la misma entidad, ignorando los filtros constantes (sólo los filtros con token acotan la entidad). Aplica a DIAS_OVERLAP/DURACION_INICIO/DURACION_AÑO |
| `No. Filtro 1..3` / `Filtro Valor 1..3` (6–11) | | **Obsoletos** (Pending): reemplazados por [[Tabla - Filtro Fuente Datos Liq]] |

## Triggers y lógica
- `OnDelete`: borra sus filtros.
- `CopiarEn(NuevoNombre)`: duplica la fuente y sus filtros (resetea `No. Línea`).
- `ValidarTipoCampo`: cierra un agujero viejo — `FieldRefToDecimal` sólo entiende Decimal/Integer/BigInteger; apuntar a un campo texto o fecha **devolvía cero en silencio**. Hoy: Decimal ↔ Decimal/Integer/BigInteger; Texto ↔ Text/Code/Option; Fecha ↔ Date/DateTime.

## Quién la lee
`Cod50016.ContextoLiquidacion` (carga las fuentes dinámicas; `ResolverFuenteNoNumerica`, `FilaVigenteAFechaRef`), `Cod50014.MotorLiquidacion`, `Cod50060.CatalogoVariablesLiq`, `Cod110051.NombresVariablesLiq`; `Tab110005 Atributo Entidad Liq.` y `Tab60007` la referencian; `BuildKnownVarsCtx` de [[Tabla - Concepto Liquidación]] las incluye para validar fórmulas. Páginas: `Pag50134 Fuente Datos Liquidación` (lista), `Pag50141 Fuente Datos Card`.

## Vigencias
Sin vigencia propia: es una definición. Lo que consulta puede tener vigencia (por eso `Fin Efectivo` y la fecha de referencia).

## Trampas conocidas
> [!danger] Apunta por número de campo
> Borrar un campo de la tabla origen rompe la fuente **en runtime** aunque ninguna fórmula la use, y el compilador no lo ve. Ver [[fuente-datos-apunta-por-numero]].

- Un texto o fecha mal tipado da 0 silencioso (hoy bloqueado por validación).
- Colisión de nombres con parámetros/atributos: [[parametro-y-atributo-mismo-nombre]], [[dos-parametros-mismo-nombre]].
- Comparar un atributo por código: [[atributo-comparar-por-codigo]].
- `Tabla Origen Liq.` ([[Enums de liquidación#Tabla Origen Liq]]) **no se usa** en ningún campo: es un enum huérfano; la tabla se elige por `Id. Tabla`.
