---
tipo: tabla
tags: [modelo-de-datos, atributos, parametrizacion]
fuente: [src/Tables/Tab110003.TipoAtributoLiq.al, src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Codeunits/Cod50078.EspejoAtributosLiq.al, src/Codeunits/Cod110051.NombresVariablesLiq.al]
actualizado: 2026-10-04
---

# Tabla - Tipo Atributo Liq

**Tabla 110003 `Tipo Atributo Liq.`** (caption *Tipo de Atributo*). **Datos persistentes** (catálogo de configuración).

**Propósito.** El equivalente a una *Dimensión* de BC: define **qué** se puede cargar sobre una entidad (zona desfavorable, obra social, convenio, categoría, veda...), no el valor. Existe para que un dato que importa al cálculo se agregue como configuración y no como campo nuevo. Con un `Nombre Variable` cargado, el contexto de cálculo lo inyecta como variable y la fórmula lo escribe como a cualquier otra, sin Fuente de Datos. Ver [[atributos-tipados]] y [[avoid-tables-principle]].

## Clave primaria
`Código` (Code[20]). Secundaria: `("Tipo Entidad", Código)`.

## Campos relevantes
| Campo | Tipo | Propósito |
|---|---|---|
| `Descripción` | Text[100] | |
| `Tipo Dato` | Enum `Tipo Dato Atributo Liq.` | Decimal, Entero, Lista, Texto, Fecha. No se puede cambiar si ya hay asignaciones. |
| `Tipo Entidad` ("Se carga en") | Enum `Tipo Entidad Estado` | Empleado, Buque o Proyecto (marea). Decide a qué entidad de la liquidación se le pregunta el atributo. |
| `Obligatorio` | Boolean | Lo materializa la plantilla de la clase ([[Tabla - Clase Entidad Liq]]). **No** bloquea la liquidación: un atributo faltante avisa, no impide pagar. |
| `Cód. Clase` | Code[20] → `Clase Entidad Liq.` | Acota el tipo a una clase de entidad (sólo atributos de buque/planta). Vacío = todas. |
| `Nombre Variable` | Code[30] | Nombre con el que entra al contexto. Se pasa a **mayúsculas** en `OnValidate`. Vacío = el atributo no se inyecta. |
| `Cód. Tipo Atributo Padre` ("Depende de") | Code[20] → este mismo tipo, sólo `Tipo Dato = Lista` | Encadena listas: CATEGORIA depende de CONVENIO. |
| `Padre Según el Valor` | Boolean | Quién aporta el padre: apagado = lo deriva la entidad del atributo padre vigente; encendido = lo trae el valor elegido (PUESTO). Exige tener padre. |
| `Espejo De` | Enum `Espejo Atributo Liq.` | Ninguno, Convenio Colectivo, Categoría CCT, Puesto. Los valores se copian de la tabla maestra. |
| `Mostrar en Recibo`, `Etiqueta Recibo` | Boolean/Text[50] | El recibo imprime la **descripción** del valor de listas. Requiere `Nombre Variable`. |

## Relaciones
- Padre/hijo con [[Tabla - Valor Atributo Liq]] (valores permitidos) y [[Tabla - Atributo Entidad Liq]] (asignaciones con historial).
- `Cód. Clase` → [[Tabla - Clase Entidad Liq]].
- Auto-referencia por `Cód. Tipo Atributo Padre`.

## Lógica en triggers
- `OnValidate Tipo Dato`: error si ya hay asignaciones (`Atributo Entidad Liq.` con ese tipo).
- `OnValidate Nombre Variable`: `UpperCase` y `ValidarNombreLibre()` → `Cod110051 Nombres Variables Liq.`.`ExigirLibre`, que rechaza un nombre ya usado por **cualquiera de las cuatro tablas** que alimentan el espacio de nombres (Parámetro, Fuente de Datos, Variable de Sistema, este).
- `OnValidate Cód. Tipo Atributo Padre`: no a sí mismo, sólo listas, sin ciclos (recorre hasta 50 saltos), y **no se puede encadenar si ya tiene valores cargados**.
- `OnValidate Espejo De`: sólo listas, sin valores cargados a mano; Convenio Colectivo no puede tener padre; Categoría CCT exige un padre que sea espejo de Convenio Colectivo. Al activarlo hace `Modify()` y llama a `Espejo Atributos Liq.`.`Resincronizar`.
- `OnDelete`: error si hay asignaciones; si no, borra los valores.

## Quién la lee y la escribe
- **Lee:** `Cod50016 Contexto Liquidación` (`LoadAtributos`: un valor por cada tipo con `Nombre Variable`), `Cod50015 Evaluador Fórmula`, `Cod50060 Catálogo Variables Liq.`, `Cod50053 Gestión Francos`, `Cod50080 Convenio Categoría Liq.`, `Cod50073 Plantilla Atributos Liq.`, `Cod110035 Atributos Entidad UI`, reporte `Asignar Atributo Masivo`; `Concepto Liquidación` la referencia.
- **Escribe:** páginas `Tipos de Atributo` (110007) / `Ficha Tipo Atributo` (110008); `Cod50078 Espejo Atributos Liq.` toca sus valores, no el tipo.

## Trampas
> [!warning] Tres campos silenciosos
> `Cód. Clase` lo esconde de la página de la entidad, `Nombre Variable` vacío lo borra del recibo y `Obligatorio` crea vigencias a toda la clase. Ver [[tipo-atributo-tres-campos-silenciosos]].

> [!warning] Un parámetro con el mismo nombre gana y el atributo queda mudo
> El contexto es un diccionario por nombre. `LoadAtributos` hace `if not Ctx.ContainsKey(...)` antes de agregar: un parámetro/fuente/variable de sistema ya cargado con ese nombre tapa al atributo sin error. De ahí el control de nombre libre. Ver [[parametro-y-atributo-mismo-nombre]] y [[dos-parametros-mismo-nombre]].

- El código de la lista debe **coincidir** con el del maestro (Convenio/Categoría): si no, no hay error sino importe cero ([[Tabla - Valor Atributo Liq]]).
- Código muerto: `DesufijarESFCY` y el label `ErrNombreTomado` ya no se usan (el control se movió a `Nombres Variables Liq.`). No tocar sin ver el codeunit.
- El valor `Puesto` de `Espejo Atributo Liq.` existe en el enum, pero `ValidarEspejo` sólo contempla explícitamente Convenio Colectivo y Categoría CCT.

## Relacionado
[[Tabla - Valor Atributo Liq]] · [[Tabla - Atributo Entidad Liq]] · [[Tabla - Entidad Liq]] · [[atributos-tipados]] · [[atributo-comparar-por-codigo]] · [[sindicato-obra-social-atributos]] · [[veda-como-atributo-del-buque]] · [[Mapa del modelo de datos - atributos, novedades, francos y sincronización]]
