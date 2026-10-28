---
tipo: guia
tags: [configuracion, fuentes-de-datos, formulas, tokens]
fuente: [src/Pages/Pag50134.FuenteDatosLiquidacion.al, src/Pages/Pag50141.FuenteDatosCard.al, src/Pages/Pag50178.FiltroFuenteDatosLiqSub.al, src/Tables/Tab60015.FuenteDatosLiquidacion.al, src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Enums/Enum50302.FuncionAgregadoLiq.al]
actualizado: 2026-10-04
---

# Configurar fuentes de datos

Una **Fuente de Datos** hace que **cualquier campo de cualquier tabla de BC** (kilos descargados, días de un estado, importes de otra liquidación…) llegue a las fórmulas **como una variable**, sin desarrollo. Cada fuente define: de qué tabla y campo se lee, con qué filtros y cómo se agrega. El valor queda disponible con el **Nombre Variable** que se le dé. Principio de diseño: [[avoid-tables-principle]].

> [!warning] Divergencia con la guía vieja
> `GUIA-LIQUIDACION.md` describía **"hasta 3 pares" de filtro** y las funciones `First`/`Sum`. Hoy los filtros viven en una **tabla aparte** (`Filtro Fuente Datos Liq.`, sin límite; los campos *No. Filtro 1-3* / *Filtro Valor 1-3* son **obsoletos**) y las funciones son *Suma, Cantidad, Máximo, Mínimo, Búsqueda directa, Días solapados, Duración desde inicio, Duración en el año*.

## Pantallas

*Fuentes de Datos* (Pag50134, lista: nombre, descripción, tabla, función, campo, activo) → ficha **Fuente de Datos de Liquidación** (Pag50141).

## Campos de la ficha

| Grupo | Caption | Qué es |
|---|---|---|
| General | **Nombre Variable** | El nombre en la fórmula. Único frente a parámetros, variables de sistema y atributos |
| | **Activo** | Una fuente inactiva no se carga |
| | **Mostrar en Recibo** / **Etiqueta Recibo** | Imprime el valor en el recibo; sin etiqueta usa la descripción. La ficha de liquidación (*Contexto del Cálculo*) muestra igual toda variable con valor ≠ 0 |
| Origen | **Tabla (ID)** / **Nombre Tabla** | Número de tabla (lookup *Seleccionar Tabla*) |
| | **Campo Valor (No.)** / **Nombre Campo** | Número del campo a leer (lookup *Seleccionar Campo*) |
| | **Tipo Dato** | *Decimal / Texto / Fecha*: la fórmula ve **siempre un número** (texto → 1/0, fecha → días hasta la fecha de referencia); el valor original se conserva para auditar e imprimir ("126205 - OSECAC" y no un 1) |
| | **Función Agregado** | Ver tabla |
| Rango de fechas | **Campo Fecha Inicio (No.)**, **Campo Fecha Fin (No.)** | Para las funciones de días. Fin en 0 = fecha abierta (= fecha de referencia) |
| | **Fin Efectivo (Estado Siguiente)** | Para tablas con vigencia sin campo fin (Estado Empleado): el fin de cada intervalo = inicio del siguiente de la misma entidad − 1. La entidad la definen los filtros con token; los filtros constantes se ignoran |
| Filtros | Subpágina **Filtros** | Una fila por filtro: **Campo (No.)** y **Filtro / Valor** |

### Funciones de agregado

| Función | Devuelve |
|---|---|
| **Suma** | Suma del campo sobre las filas filtradas |
| **Cantidad** | Cantidad de filas |
| **Máximo / Mínimo** | Mayor / menor valor del campo |
| **Búsqueda directa** | El valor de la **última** fila filtrada (`FindLast`) |
| **Días solapados** | Días de cada intervalo [inicio, fin] que caen dentro de la ventana de la liquidación |
| **Duración desde inicio** | Duración **completa** de todo intervalo cuyo inicio cae dentro del período (p. ej. vacaciones: art. 155 LCT) |
| **Duración en el año** | Como *Días solapados* pero recortado al año calendario |

> [!warning] Sólo las de fecha respetan vigencia por sí solas
> *Suma*, *Máximo*, *Mínimo*, *Búsqueda directa* aplican **únicamente los filtros que configuraste**: no agregan vigencia por su cuenta. Una fuente sobre atributos (o cualquier tabla con vigencia) necesita sus dos filtros de fecha a mano, y el de `Vigencia Hasta` tiene que aceptar el blanco ([[atributos-tipados]]).

### Filtros y tokens

El valor de filtro es una **expresión de filtro de BC** (rangos `..`, alternativas `|`, comodines `*`) y admite **tokens** que el motor reemplaza al calcular:

| Token | Se reemplaza por |
|---|---|
| `{EMP_NO}` | No. de empleado |
| `{JOB_NO}` | No. de proyecto (marea) |
| `{BUQUE}` | Buque del proyecto (dimensión 1 del Job). Sin proyecto queda **vacío** |
| `{PERIODO}` | Código del período |
| `{PERIODO_DESDE}` / `{FECHA_REF}` | Inicio del período / fecha de referencia. Juntos acotan por las dos puntas: `{PERIODO_DESDE}..{FECHA_REF}` |
| `{AÑO_DESDE}` | 1/1 del año de la liquidación (cuentas corrientes anuales) |
| `{ASIG_DESDE}` / `{ASIG_HASTA}` | Alta y baja **de ese tripulante en esa marea** (baja en blanco = fecha de referencia) |
| `{MAREA_DESDE}` / `{MAREA_HASTA}` | Zarpada y arribo del proyecto, sin recortar por período |
| `{LIQ_NO}` | No. de liquidación |
| `{MONEDA}` | Moneda del contexto |
| `{SEM_DESDE}` / `{SEM_HASTA}` | Semestre calendario de la fecha de referencia (1/1–30/6 o 1/7–31/12) |
| `{PROM_DESDE}` / `{PROM_HASTA}` | Los 6 meses calendario **anteriores** al mes en que empieza la licencia (art. 34 del CCT; pago anticipado incluido) |
| `{AUS_PROM_HASTA}`, `{AUS_PROM6_DESDE}`, `{AUS_PROM12_DESDE}` | Ventana del promedio de ausencia (6 o 12 meses según convenio) |

> [!danger] Token vacío = la fuente devuelve 0
> Si un token se resuelve a **vacío** (p. ej. `{BUQUE}` en una liquidación sin proyecto, `{LIQ_NO}` sin liquidación) la fuente devuelve **0** en lugar de leer sin ese filtro, "que es la peor forma de fallar porque da un número grande y creíble".

> [!warning] Fuente sin filtros
> Una fuente **activa sin ningún filtro** agrega la tabla entera. Casi siempre es que los filtros se perdieron, y el síntoma engaña: varias fuentes que sólo se distinguían por el filtro empiezan a devolver el **mismo número**. El cálculo avisa "La Fuente de Datos X no tiene ningún filtro cargado" ([[Controles y avisos del cálculo]]).

## Ejemplo (de la guía original, sin re-verificar números de campo)

Kilos brutos de una especie en la marea de la liquidación, desde `Lín. descarga` (tabla 50562 de la personalización de descargas):

| Dato | Valor |
|---|---|
| Nombre Variable | `PROD_KB_L1` |
| Tabla (ID) / Campo Valor (No.) | `50562` / `9` (peso bruto) |
| Función Agregado | Suma |
| Filtro 1 | campo `1` (No. proyecto) = `{JOB_NO}` |
| Filtro 2 | campo `4` (No. de ítem) = el código de la clasificación |

Y la fórmula del concepto de producción: `PROD_KB_L1`, con condición `PROD_KB_L1 > 0`. Siempre filtrar por `{EMP_NO}` o `{JOB_NO}` como mínimo: cada fuente activa hace una consulta **por liquidación**.

## Trampas

- **Se referencia por número**: borrar o renumerar un campo en AL **no da error de compilación**, y el cálculo revienta recién en la primera liquidación real ("El número de campo proporcionado '4' no se encuentra en la tabla …"), **aunque ninguna fórmula use esa variable**, porque el contexto carga todas las fuentes activas ([[fuente-datos-apunta-por-numero]]).
- **Un valor, una fuente**; no duplicar lo que ya es un parámetro o un atributo ([[un-valor-una-fuente]]).
- Un atributo con **Nombre Variable** ya llega solo a la fórmula: no hace falta una fuente por atributo.
- Nombres duplicados entre parámetro/atributo/fuente: ver [[parametro-y-atributo-mismo-nombre]].

## Verificación

*Asistente de Fórmulas* → **Cargar contexto completo** con un empleado y período reales → buscar la variable en la lista: si vale 0, revisar filtros y tokens. En la línea de la liquidación, *Variables del cálculo* muestra el valor usado. [[Asistente de fórmulas y detalle del cálculo]]

## Ver también

[[Fuentes de datos]] · [[Tokens de filtro de fuentes de datos]] · [[Tabla - Fuente Datos Liquidación]] · [[Tabla - Filtro Fuente Datos Liq]]
