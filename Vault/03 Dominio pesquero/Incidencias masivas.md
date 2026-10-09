---
tipo: proceso
tags: [dominio, incidencias, carga-masiva]
fuente: [src/Reports/Rep50044.InsertarIncidenciaMasiva.al, src/Codeunits/Cod50052.GestionIncidenciaMasiva.al, src/Pages/Pag50149.PayrollRoleCenter.al]
actualizado: 2026-10-04
---

# Incidencias masivas

El informe **`Insertar Incidencia Masiva`** (Rep50044, sólo proceso, accesible desde el Role Center) carga **la misma incidencia** —concepto + importe, o cantidad × valor unitario— en **varias liquidaciones existentes a la vez**. Es la contrapartida de las [[Novedades pre-liquidación|novedades]]: éstas se cargan *antes* de que exista la liquidación y entran solas al calcular; la incidencia masiva opera sobre liquidaciones **ya creadas**.

## Cómo se usa

1. Abrir *Insertar Incidencia Masiva*.
2. En la pestaña de filtros elegir las liquidaciones: `No.`, `Cód. Período`, `Cód. Tipo Liq.`, `No. Empleado`, `Cód. Convenio`, `Estado`.
3. En las opciones: `Cód. Concepto` (obligatorio), `Cantidad`, `Unidad Cantidad`, `Valor Unitario`, `Importe`, `Observaciones`, `Sobrescribir si ya existe`.
4. Al terminar muestra "Se insertó en N liquidación(es). M omitida(s)".

## Reglas (`Gestión Incidencia Masiva.InsertarIncidencia`)

| Situación | Resultado |
|---|---|
| Liquidación **no Borrador** | se omite (no se puede tocar) |
| Ya tiene incidencia del concepto y `Sobrescribir = No` | se omite |
| Ya la tiene y `Sobrescribir = Sí` | se **modifica** (`Modify(true)`: **pasa a ser manual**, se pierde `Desde Novedad`) |
| No la tiene | se inserta (`Insert(true)`) |

Las omitidas se cuentan juntas: el mensaje final no distingue *por qué*.

> [!warning] No sirve para el cero explícito ni para "sólo cantidad"
> `OnPreDataItem` exige **`Importe ≠ 0`** (directo o por `Cantidad × Valor Unitario`; si no, error "El Importe debe ser distinto de cero"). Por eso este informe no puede cargar una incidencia de sólo cantidad (horas extras valorizadas por fórmula) ni un cero que apague un concepto: para eso usar una [[Novedades pre-liquidación|novedad]] (ver los tres modos de carga) o cargar la incidencia a mano.

> [!note] Por qué hay un codeunit aparte
> La plataforma no permite escribir en la base dentro de un `TryFunction` definido en un objeto Report, así que la escritura vive en `Cod50052`. En el código **no hay** `Codeunit.Run` ni `TryFunction` alrededor: es una llamada directa, y un error en una liquidación corta el informe entero. La lección [[novedades-pre-liquidacion]] cita este codeunit como precedente del patrón `Codeunit.Run`; el código actual no lo aplica (ver [[codeunit-run-necesita-commit]] si se quisiera que "una fila mala no frene el lote").

## Cuándo preferirlo a una novedad

- Ajuste de una sola vez sobre liquidaciones ya creadas en Borrador, con filtros por convenio/tipo.
- Se necesita que **no** se regenere ni se sume con otras novedades (la incidencia manual la respeta el recálculo).

Para todo lo recurrente, migrado desde Meta4 o que deba sobrevivir a recrear liquidaciones, usar novedades.

Relacionadas: [[Incidencias]], [[Índice Dominio - marea y pagos]].
