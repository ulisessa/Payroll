---
tipo: concepto
tags: [motor, fuentes-de-datos, contexto]
fuente: [src/Tables/Tab60015.FuenteDatosLiquidacion.al, src/Tables/Tab60029.FiltroFuenteDatosLiq.al, src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Enums/Enum50302.FuncionAgregadoLiq.al, src/Enums/Enum50324.TipoDatoFuenteLiq.al]
actualizado: 2026-10-04
---

# Fuentes de datos

Una **fuente de datos** (`Fuente Datos Liquidación`, 60015, clave `Nombre Variable`) pone en el contexto
un valor leído de **cualquier tabla de BC** vía `RecordRef`, **sin tocar código**: la tabla, el campo
valor y los filtros se guardan como **números de objeto y de campo**. Es la forma de traer producción
(kilos descargados), estados, familiares, cotizaciones, etc. Ver [[avoid-tables-principle]].

> [!warning] La fuente apunta por número
> Borrar o renumerar un campo rompe la fuente en runtime aunque ninguna fórmula la nombre y el
> compilador no ve nada. Ver [[fuente-datos-apunta-por-numero]].

## Campos de la definición

| Campo | Para qué |
|---|---|
| `Nombre Variable` | token de fórmula (único en el espacio de nombres, `ExigirLibre`) |
| `Id. Tabla` | tabla origen (valida contra `AllObjWithCaption`); **cambiarlo limpia** campo valor, fechas, filtros y `Fin Efectivo` |
| `No. Campo Valor` | campo a agregar/leer |
| `Tipo Dato` | `Decimal` (0), `Texto` (1), `Fecha` (2): qué es el valor en origen. Valida el tipo del campo contra el declarado |
| `Función Agregado` | cómo se reduce el conjunto filtrado (tabla abajo) |
| `No. Campo Fecha Inicio` / `No. Campo Fecha Fin` | para las funciones de intervalo y para la vigencia de las no numéricas |
| `Fin Efectivo` | el fin del intervalo de cada fila es el inicio de la siguiente −1 (tablas con historial sin `Fecha Fin`, como `Estado Empleado`) |
| `Activo` | sólo las activas entran al contexto |
| `Mostrar en Recibo` / `Etiqueta Recibo` | publican la variable en el resumen del recibo |
| Filtros | filas de `Filtro Fuente Datos Liq.` (60029): `(Nombre Variable, No. Línea, No. Campo, Filtro Valor)` |

Los tres pares `No. Filtro N` / `Filtro Valor N` de la cabecera están **obsoletos**. Con **al menos un filtro** en la tabla auxiliar los tres viejos **no se aplican** (un `SetFilter` sobre un campo reemplaza el filtro previo, y una fuente creada con *Copiar como…* heredaba el filtro del original: así `PROD_KN_L4/L5/L6` devolvían los kilos de `L3`). Una fuente **sin filtros** agrega la tabla entera y emite un **aviso** (`AvisarSiFuenteSinFiltros`). Ver [[Avisos y advertencias del cálculo]].

## Funciones de agregado (`Función Agregado Liq.`)

| Valor | Resultado (`ResolveFuente`) |
|---|---|
| `SUM` | suma de `No. Campo Valor` sobre las filas filtradas |
| `COUNT` | cantidad de filas |
| `MAX` / `MIN` | máximo / mínimo del campo |
| `LOOKUP` | valor de la **última fila** (`FindLast`) según la clave primaria |

> `LOOKUP` ordena por **clave primaria, no por fecha**. Sobre `Currency Exchange Rate` acierta porque la clave termina en `Starting Date`; sobre una tabla de historial con clave por número de entrada —`Estado Empleado`, cuya PK es `No. Mov.` sola— devuelve la fila **insertada** última, que no es la más nueva. Para eso están `FILA_MAS_RECIENTE` y `FILA_MAS_ANTIGUA`, que no dependen de la forma de la clave.
| `DIAS_OVERLAP` | suma de días de cada intervalo `[Fecha Inicio, Fin]` **que caen en la ventana de la liquidación** (tramos o `[FPeriodoFechaDesde, FFechaRef]`) |
| `DURACION_INICIO` | **duración completa** de cada intervalo cuyo **inicio** cae en el período (Art. 155 LCT: las vacaciones que arrancan en el mes se pagan enteras) |
| `DURACION_AÑO` | como `DIAS_OVERLAP` pero recortado al **año calendario** (`[1/1, 31/12]`), p. ej. días de vacaciones tomadas en el año |
| `FILA_MAS_RECIENTE` | valor de la fila de **`Fecha Inicio` mayor** entre las que ya empezaron a `FechaRef`, **aunque ya hayan cerrado** |
| `FILA_MAS_ANTIGUA` | ídem, pero la de `Fecha Inicio` menor |

Intervalo abierto (sin fin) se recorta a `FFechaRef`. Los campos de `Employee Relative` tienen **equivalencias de campos legacy** (`CampoFuenteCanonico`: las fechas de alta legacy 50008/50010/50211 → 50000; las de baja 50009/50011/50212 → 50001).

Sólo los campos `Decimal`, `Integer` y `BigInteger` son numéricos (`FieldRefToDecimal`): cualquier otro tipo daba **0 en silencio** antes de la validación `ValidarTipoCampo`.

### Fuentes no numéricas (`Tipo Dato` Texto/Fecha)

Con `FILA_MAS_RECIENTE` o `FILA_MAS_ANTIGUA` la regla de elegibilidad cambia: **alcanza con que la fila haya empezado**, no se exige que siga abierta (`FilaElegibleNoNumerica`). Las demás lecturas del motor preguntan "qué rige hoy"; éstas preguntan "cuál fue la última", que no es lo mismo — el caso que las motivó es en qué marea estuvo embarcado por última vez alguien que **ya no lo está**. Lo que sí se respeta es que no hay red hacia adelante: una fila que empieza después de `FechaRef` no cuenta. Sin `No. Campo Fecha Inicio` declarado no resuelven y **avisan**, en vez de caer de vuelta en `FindLast`.

`ResolverFuenteNoNumerica` lee con semántica de `LOOKUP` pero respetando la **vigencia**: recorre las filas filtradas, descarta las que no estén vigentes a `FechaRef` (`FilaVigenteAFechaRef`: inicio ≤ `FechaRef` y fin en blanco o ≥ `FechaRef`) y se queda con la de **inicio más reciente**. Guarda el valor original en `FValoresTexto` (para auditoría y recibo) y proyecta a número:

- `Texto` → `1` si hay valor, `0` si no (bandera de presencia). Para preguntar por un texto **puntual** desde una fórmula, la vía es una fuente `COUNT` con el texto en el filtro (compara en SQL) o un atributo de lista comparado por código.
- `Fecha` → **días transcurridos** hasta `FechaRef` (`FFechaRef − fecha`; positivo = pasado, negativo = futuro). Fecha en blanco → 0.

## Fin efectivo

Para `Estado Empleado` (que no guarda `Fecha Fin`), el fin de cada estado es **la siguiente fecha de inicio distinta − 1** del mismo empleado, ignorando los filtros constantes (como `Cód. Estado`): sólo los filtros con token (`{EMP_NO}`…) acotan la entidad. `0D` = abierto.

Implementación y su historia de performance (ver [[Rendimiento y caché del cálculo]]):

1. `GetFechasInicioFuente` lee **una vez por fuente** las fechas de inicio (con `SetLoadFields` de un solo campo) y las cachea.
2. `FinEfectivoDeLista` intenta primero el **mapa inicio → fin** (`ConstruirMapaFinEfectivo`, que ordena una copia con merge-sort, deduplica y arma el diccionario) y, si la fecha consultada no está, cae a `FinEfectivoPorRecorrido`, que **es la definición** de la regla. Las dos tienen que dar siempre lo mismo (hay una prueba, `Test Fin Efectivo Liq.`).
3. **No** acotar la lista al mes: se perdería el estado posterior que cierra un intervalo.

> [!warning] Estado abierto = 31/12/9999
> `FechaFinEfectiva` de un estado abierto devuelve 31/12/9999. Recorrerlo día por día desborda el `Date`
> ("La fecha no es válida"): hay que recortar contra la ventana antes. Ver [[recorrer-estado-abierto-dia-por-dia]].

## Cómo se arman los filtros

`AplicarFiltrosFuente` recorre las filas de `Filtro Fuente Datos Liq.`; para cada una `ApplyTokens` reemplaza los [[Tokens de filtro de fuentes de datos|tokens]] y `FieldRef.SetFilter(valor)` aplica el filtro (admite la sintaxis de filtros de BC: rangos `a..b`, `|`, `<>`…). Reglas:

- Si un valor **tenía** `{TOKEN}` y quedó **vacío** tras resolverlo (`TokenResolvedToEmpty`, p. ej. `{LIQ_NO}` sin liquidación, `{BUQUE}` sin proyecto), la fuente **devuelve 0 en vez de leer sin ese filtro**: el modo de fallar que da un número grande y creíble.
- Valor vacío o campo 0 → el filtro se ignora.
- En `SoloTokens` (fin efectivo) sólo se aplican los filtros que contienen `{`.
- `CopyFilters` copia sólo el grupo actual y no los del `SubPageLink`: ver [[copyfilters-solo-grupo-actual]].

## Dónde se ven

- `Fuente Parámetros` de cada línea lleva `FDS:<tabla>/<nombre>` por cada fuente resuelta.
- `Resumen Variable Liq.` guarda las fuentes con `Mostrar en Recibo` (valor y texto).
- El catálogo del editor las lista con tipo `Fuente Datos` y valor 0.

## Divergencia con la documentación vieja

`GUIA-LIQUIDACION.md` describe `Función Agregado` como `First`/`Sum` y filtros `No. Filtro 1/2/3`: **ya no es así** (ver [[Divergencias entre documentación vieja y código]]).

## Relacionado

[[Contexto de liquidación y variables]] · [[Tokens de filtro de fuentes de datos]] · [[Tabla - Fuente Datos Liquidación]] · [[cobertura-en-tramos]]

**Tablas relacionadas:** [[Tabla - Filtro Fuente Datos Liq]] · [[Tabla - Estado Empleado]]

## Orden de recorrido: `Ordenar por Campo` y `Orden descendente`

Dos campos en la cabecera de la fuente (`Tab60015`, ids 19 y 20). **En blanco la fuente recorre por clave primaria**, que es como se comportó siempre, y ninguna fuente existente los declara: agregarlos no movió ningún importe.

Importan cuando la función toma **una sola fila** —`LOOKUP`, `FILA_MAS_RECIENTE`, `FILA_MAS_ANTIGUA`—, porque ahí el orden decide cuál, y la clave primaria rara vez es la que uno tiene en la cabeza.

**Se declara el CAMPO, no el número de clave.** En AL sólo se puede ordenar por una clave declarada en la tabla, así que la pregunta real es qué clave usar; pero los índices de clave son posicionales y agregar una clave arriba correría todos los números, y la fuente pasaría a ordenar por otra cosa sin que nadie la toque. El motor busca una clave que contenga el campo, prefiriendo aquella donde sea el **último** —la que ordena por él dentro del grupo que los filtros ya acotaron—. Sin clave utilizable **avisa** y deja el orden como estaba.

El caso de referencia es `Estado Empleado`: su clave `K2` es `(Tipo Entidad, No. Empleado, Fecha Inicio)`, así que con las dos primeras fijadas por los filtros, recorrerla ordena por fecha. Su clave primaria es `No. Mov.` sola, el orden de alta.

> Con `LOOKUP` (que es `FindLast`) el orden descendente devuelve el **menor**, no el mayor. Es consistente —siempre es "la última en el orden pedido"— pero se lee al revés.

### Cuál usar

`LOOKUP` + clave declarada hace, en el camino numérico, lo mismo que `FILA_MAS_RECIENTE`. Las dos formas conviven a propósito:

- **`FILA_MAS_RECIENTE` / `FILA_MAS_ANTIGUA`**: cuando la pregunta es por fecha. Dicen lo que hacen, no dependen de que exista la clave adecuada, avisan si les falta el campo de fecha, y son las únicas que cambian la elegibilidad en el camino no numérico (aceptan filas cerradas).
- **`LOOKUP` + clave**: cuando hay que ordenar por algo que no es una fecha, o cuando ya se usaba `LOOKUP` y sólo falta hacer predecible el orden.
