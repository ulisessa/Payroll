---
tipo: tabla
tags: [modelo-de-datos, parametros, calculo, rendimiento]
fuente: [src/Tables/Tab110009.UsoParametroLiq.al, src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Codeunits/Cod50019.GestionLiquidacion.al, src/Codeunits/Cod50081.ControlMareaLiq.al]
actualizado: 2026-10-19
---

# Tabla - Uso Parámetro Liq

**Tabla 110009 `Uso Parámetro Liq.`** (caption *Uso de Parámetro por Liquidación*). **Datos persistentes** (índice).

**Propósito.** Qué versión de qué parámetro usó cada liquidación: una fila por *(liquidación, variable)*. Existe para responder la pregunta inversa —"¿alguna otra liquidación activa sigue usando esta versión del parámetro?"— con una consulta indexada. Ese dato ya existía como tokens `VAR:` dentro del texto `Fuente Parámetros` de cada línea, y reabrir una liquidación terminaba siendo más lento que calcularla.

`Fuente Parámetros` sigue existiendo: es la auditoría legible de *una* línea. Esta tabla es el índice para la pregunta a escala.

## Clave primaria
`("No. Liquidación", "Nombre Variable")`. Clave `Version`: `("Cód. Parámetro","Vigencia Desde","No. Liquidación")` — la razón de ser de la tabla.

## Campos relevantes
| Campo | Tipo | Propósito |
|---|---|---|
| `No. Liquidación` | Code[20] → [[Tabla - Liquidación]] | |
| `Nombre Variable` | Code[30] | La variable tal como la vio la fórmula. |
| `Cód. Parámetro Base` | Code[20] | Base del [[Tabla - Parámetro Vigente]] (primer campo de su PK). |
| `Cód. Parámetro` (caption *Clave Derivada*) | Code[50] | Clave efectiva que resolvió la cascada de sufijos. |
| `Vigencia Desde` | Date | La versión concreta que se usó; la que hay que dejar bloqueada (`En Uso`) mientras la liquidación siga viva. |

## Lógica en triggers
Ninguno.

## Quién la lee y la escribe
- **Escribe:** `Cod50016 Contexto Liquidación`: `RegistrarUsoParametro` (`Insert` tolerando duplicado, sólo si hay `FLiqNo`) y `BorrarUsoParametros(LiqNo)` (público: lo llaman reabrir y borrar).
- **Lee:** `Cod50019 Gestión Liquidación` (`LiberarEnUsoPorRegistro`: por cada versión que usó la liquidación, `IsEmpty` sobre la clave `Version` excluyéndose a sí misma y filtrando liquidaciones **activas**: Calculada, Aprobada, Contabilizada) y `Cod50081 Control Marea Liq.` (qué monedas efectivamente usaron los parámetros).

## Vigencias
Referencia puntual a una vigencia de [[Tabla - Parámetro Vigente]]; no tiene vigencia propia.

## Reconciliación y recibos testigo

La optimización del 19/10, instalada y con 30/30 pruebas aisladas aprobadas, conserva la tabla sin cambios. La query
exacta de conciliación encuentra un recibo activo por versión; Gestión Liquidación aprovecha
ese testigo para leer una sola vez sus usos por PK de documento y confirmar otras versiones
en un temporal local. Usa `SetLoadFields` de base/clave/vigencia y `UpdLock`; la cabecera activa
ya está protegida por la query. Sólo se reutilizan positivos y la ausencia conserva la consulta
exacta y el respaldo histórico. No cambia `RegistrarUsoParametro`, `BorrarUsoParametros`,
los registros persistentes ni `Fuente Parámetros`. Ver [[Parámetros y vigencias]].

El ajuste posterior del mismo día, publicado y validado con 35/35 pruebas aisladas, limita la memoria de testigos a
triples de candidatas todavía pendientes. Si una carga no confirma ninguna pendiente adicional,
se omiten las próximas precargas disparadas por esa base en la llamada; TOP1 e histórico siguen
comprobando cada candidata desconocida. No se modifica esta tabla ni se eliminan registros de
uso: los `Delete(false)` nuevos actúan exclusivamente sobre `Parámetro Vigente` temporal.

## Trampas
> [!warning] Liquidaciones calculadas antes de que existiera la tabla
> `LiberarEnUsoPorRegistro` devuelve `false` si la liquidación no tiene filas de uso; en ese caso se usa el camino viejo (leer líneas y partir tokens), más lento. Una liquidación sin registro de uso no es un error.

- Una fila de uso huérfana (liquidación borrada sin pasar por `BorrarUsoParametros`) no bloquea nada: el filtro por estado activo lo cubre.
- Si el parámetro se resuelve dos veces con el mismo `Nombre Variable` en una liquidación, gana la primera fila (el `Insert` falla en silencio).

## Relacionado
[[Tabla - Parámetro Vigente]] · [[Tabla - Liquidación]] · [[Tabla - Línea Liquidación]] · [[un-valor-una-fuente]] · [[sql-directo-deja-cache-rancia]]
