---
tipo: tabla
tags: [modelo-de-datos, atributos, parametrizacion]
fuente: [src/Tables/Tab110004.ValorAtributoLiq.al, src/Codeunits/Cod50078.EspejoAtributosLiq.al, src/Pages/Pag110010.ValoresDeAtributo.al]
actualizado: 2026-10-04
---

# Tabla - Valor Atributo Liq

**Tabla 110004 `Valor Atributo Liq.`** (caption *Valor de Atributo*). **Datos persistentes** (catálogo).

**Propósito.** El equivalente a un *Valor de Dimensión*: la lista cerrada contra la que se valida un atributo de tipo Lista. Su `Valor Numérico` es lo que hace que el atributo llegue a una fórmula: la fórmula no ve el código `PATAGONIA`, ve el 1,20 que éste le asigna.

## Clave primaria
`("Cód. Tipo Atributo", "Cód. Valor Padre", Código)`.

> [!note] El padre entra en la clave
> Permite que el mismo código exista bajo dos padres: `OF01` es Capitán en 175/75 y también en 768/19, y son dos categorías distintas con el mismo código. Con la clave vieja (tipo + código) la segunda no entraba. Por eso **todo `Get` sobre esta tabla lleva tres argumentos** (ver [[get-con-menos-argumentos]]).

## Campos relevantes
| Campo | Tipo | Propósito |
|---|---|---|
| `Cód. Tipo Atributo` | Code[20] → [[Tabla - Tipo Atributo Liq]] | |
| `Código`, `Descripción` | Code/Text | |
| `Valor Numérico` | Decimal | Lo que ve la fórmula. |
| `Sufijo Parámetro` | Code[10] | Texto que el valor aporta al código de un parámetro resuelto por él. Ej.: el valor `PO` de TIPOACTIVIDAD lleva `CAL`, y el motor busca `VALOR_FRANCO_CAL_<convenio>_<categoría>`. Vacío = no participa. Ver [[valor-franco-por-terna]]. |
| `Cód. Valor Padre` | Code[20] | Valor del atributo padre del que cuelga. Sin `TableRelation` (apunta a otro tipo, que sólo se sabe en ejecución); se valida a mano y se elige con `OnLookup`. |

## Lógica en triggers
- `OnInsert`: `BloquearSiEsEspejo()` y `ValidarPadre()`. Un valor sin padre en un tipo que lo declara quedaría inalcanzable; un valor con padre en un tipo plano también falla.
- `OnModify`: si cambia `Valor Numérico` y hay asignaciones, muestra un `Message` aclarando que **no se reescriben**: las asignaciones conservan el número anterior.
- `OnDelete` / `OnRename`: bloqueados si el tipo es espejo.
- `PermitirEscrituraEspejo()`: habilita **una** escritura sobre esa instancia (la bandera `FEscrituraEspejo` vive en la variable de registro y se apaga sola); es lo que usa `Cod50078`.

## Quién la lee y la escribe
- **Escribe:** páginas `Valores Atributo Sub` (110009) y `Valores de Atributo` (110010), reporte `Asignar Atributo Masivo`; `Cod50078 Espejo Atributos Liq.` (con `PermitirEscrituraEspejo`) cuando el tipo es espejo.
- **Lee:** `Atributo Entidad Liq.` (`RecalcularValorNumerico`, `ValorParaMostrar`), `Cod110035`, `Cod50015`, `Cod50053`, `Cod50060`, `Cod50078`, páginas de atributos.

## Vigencias
Sin vigencia: es un catálogo. El historial vive en [[Tabla - Atributo Entidad Liq]], que **copia** el `Valor Numérico` al asignar.

## Trampas
> [!warning] Cambiar el Valor Numérico no actualiza lo ya asignado
> Es deliberado: una liquidación vieja debe recalcularse con el número usado. Para cambiar lo vigente hay que cargar una **vigencia nueva** en cada entidad.

> [!warning] Los códigos del espejo tienen que ser los del maestro
> El motor busca `Categoría CCT`.`Get(convenio, categoría)` y arma parámetros con sufijo `CONVENIO_CATEGORÍA`. Un código distinto no da error: da importe cero. Por eso los espejos son sólo-lectura.

- Un valor de padre inexistente falla recién al insertar (`No existe el valor ... en el atributo ...`).

## Relacionado
[[Tabla - Tipo Atributo Liq]] · [[Tabla - Atributo Entidad Liq]] · [[Tabla - Categoría CCT]] · [[Tabla - Convenio Colectivo]] · [[atributos-tipados]] · [[puesto-vs-categoria-cct]]
