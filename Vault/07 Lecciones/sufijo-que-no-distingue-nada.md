---
aliases: ["Un sufijo que no distingue nada"]
tipo: leccion
tema: parametros-atributos
tags: [leccion, parametros-atributos, project]
actualizado: 2026-10-09
---

# Un sufijo que no distingue nada

Dos parámetros partidos por pesquería tenían el **mismo valor en las 104 filas comparables**

El sufijo de pesquería partía 8 troncos / 16 parámetros y **484 de las 902 filas vigentes** (54%). La pregunta que nadie había hecho es cuántas de esas filas el eje realmente *distingue*:

| tronco | pares comparables | con el **mismo** valor + moneda + TC |
|---|---|---|
| **PRECIO_NAV** | 55 | **55** |
| **PRECIO_ORDENES** | 49 | **49** |
| PRECIO_PUERTO | 51 | 4 |
| VALOR_FRANCO | 51 | 6 |
| VALOR_NAV_EMP | 13 | 4 |
| VALOR_PUERTO_EMP | 4 | 4 |
| PRECIO_INCENT | 9 | 0 |

**104 filas que eran el mismo número escrito dos veces**, y siete fórmulas que cargaban un `IF(TIPOACTIVIDAD = 1, X_CAL, X_LAN)` para elegir entre dos valores idénticos. Fusionados el 9/10/2026.

> [!tip] El control que lo encuentra
> No alcanza con contar los parámetros: hay que **aparear las filas y comparar el valor**. Y comparar las tres cosas, no sólo el número: `Valor`, `Moneda` y `Cód. Variable TC`. Una fila en USD y otra en pesos con el mismo número no son el mismo precio, y el eje ahí sí distingue.
>
> ```sql
> -- apareo por tronco + convenio + categoría + empleado + vigencia
> SELECT l.tr, COUNT(*) pares,
>        SUM(CASE WHEN l.val=c.val AND l.mon=c.mon AND l.tc=c.tc THEN 1 ELSE 0 END) iguales
> FROM #V l JOIN #V c ON c.tr=l.tr AND c.suf='CAL' AND c.cv=l.cv
>                     AND c.ct=l.ct AND c.em=l.em AND c.vd=l.vd
> WHERE l.suf='LAN' GROUP BY l.tr;
> ```

## La asimetría es el hallazgo, no el ruido

`PRECIO_ORDENES_LAN` tenía 53 filas y `_CAL` 49. Las 4 de más eran 768/19 OF01..OF04, y **`_CAL` no tenía ninguna fila de 768/19**. O sea: un oficial de ese convenio embarcado en un potero resolvía un parámetro inexistente y el 1073 le daba **cero sin error**. En enero de 2026 nadie de 768/19 tuvo días a órdenes —los 13 renglones en cero tenían `Cantidad = 0`—, así que no había diferencia que lo delatara. **El cero estaba esperando.**

Antes de fusionar hay que preguntar en las dos direcciones. Una fila que existe sólo en un lado es siempre una de dos cosas: una diferencia real, o un hueco de carga. Y una fila **sólo-CAL** sería peor todavía, porque copiar desde `_LAN` la perdería y ninguna invariante la extrañaría — por eso va una guarda explícita.

## No borrar los sufijados en el mismo paso

Las fórmulas se reescriben; los parámetros sufijados **quedan**. Borrarlos deja sin resolver a cualquier fórmula que los nombre —una vigencia vieja, una condición, un filtro de fuente de datos— y en este motor un parámetro que no resuelve **devuelve cero sin aviso**. Se borran recién con el período recalculado y cuadrado.

Y hay que buscar quién los nombra en **los tres lugares**, no sólo en la fórmula: `Fórmula`, `Condición` y el `Filtro Valor` de las fuentes de datos.

## Reescribir una fórmula: REPLACE sobre el texto que ya está

No un texto nuevo escrito a mano. Así los espacios y los saltos de línea quedan exactos y el único cambio posible es el que se nombra. Dos cuidados:

- **el orden del anidado importa.** El `IF` de una línea va *primero*: si se reemplaza antes el nombre del parámetro, el `IF` ya no coincide con el texto buscado y queda en pie con las dos ramas iguales;
- **un `REPLACE` que no encuentra nada no falla**, deja la fórmula igual. Hace falta una invariante que exija que las N fórmulas hayan cambiado *de verdad*, comparando contra una foto previa.

> [!important] El historial hay que escribirlo a mano
> Un `UPDATE` por SQL **no dispara el `OnModify`** que llena `Historial Fórmula Concepto`. Sin eso el cambio de fórmula no queda trazado en ningún lado. Va antes del `UPDATE`, porque después la fórmula anterior ya no está, y con dos invariantes: que la anterior difiera de la nueva, y que la nueva coincida **letra por letra** con la que quedó en el concepto.
>
> El tipo es `Modificación`, no `Formato`: `Formato` es para cuando cambian sólo los espacios.

## Pisar la vigencia, cuando corresponde

La regla del proyecto es que una fórmula nueva es una vigencia nueva. Acá se pisó, y el motivo es que **una vigencia nueva no habría llegado a donde tenía que probarse**: arrancaría hoy, y el período que se está conciliando seguiría calculando con la fórmula vieja, que nombra los parámetros sufijados. Además los 7 conceptos tenían **una sola vigencia** —2023-01-12, abierta, la de arranque del proyecto—: no había versión anterior que proteger.

Las dos condiciones juntas son lo que lo justifica. Con una vigencia histórica real de por medio, la respuesta es otra.

## 1013: el `IF` que quedaba era un criterio divergente

De las 7, seis perdieron el `IF` por equivalencia textual. En **1013** las ramas diferían de verdad: `COEF_POTERO` contra `COEF_TANGONERO`. Se reemplazó por `#COEF_PESQUERIA` —el concepto de orden 5 que ya usan 1053, 1073 y 1076—, cuya fórmula es `IF(TIPOACTIVIDAD = 0, IFZERO(COEF_TANGONERO, 1), 1)`.

| TIPOACTIVIDAD | 1013 antes | `#COEF_PESQUERIA` |
|---|---|---|
| 1 potero | `COEF_POTERO` | 1 — **idéntico**, está cargado en 1,000000 en los seis convenios |
| 0 tangonero | `COEF_TANGONERO` | `IFZERO(COEF_TANGONERO, 1)` — idéntico, ninguno está en cero |
| 2 FA / 3 PA / **4 ML** | `COEF_TANGONERO` (cae en el `else`) | **1** |

Medido: las **180 líneas del 1013 de enero usan coeficiente efectivo 1,0000** (61,19 M), así que el cambio no movió un peso. Y arregló dos cosas:

1. **la inconsistencia del Puente Mayor.** 1053, 1073 y 1076 ya le daban 1 a un ML; el 1013 le habría dado 0,30, porque ML cae en el `else` y `COEF_TANGONERO_729/15` es 0,30. Dos conceptos del mismo recibo con dos criterios para el mismo tripulante;
2. **el cero silencioso de un convenio nuevo.** El 1013 multiplicaba por `COEF_TANGONERO` **crudo**: si para un convenio nadie carga el coeficiente, el sueldo de navegación sale cero sin error. Hay un candidato ya en la base —**130/75 tiene liquidaciones y no tiene `COEF_TANGONERO`**—. `#COEF_PESQUERIA` trae el `IFZERO(..., 1)` adentro.

**Un coeficiente elegido con un `IF` a mano es una decisión duplicada.** Cuando existe un concepto que ya la toma, usarlo no es sólo prolijidad: es que las dos copias no se puedan desincronizar.

## El paso 1: el eje como atributo tipado

Implementado en AL el 9/10/2026, **sin publicar todavía**. La dimensión deja de vivir en el nombre del parámetro y pasa a ser configuración:

- **`Parámetro`** declara hasta tres ejes: `Cód. Tipo Atributo 1/2/3`;
- **`Parámetro Vigente`** lleva, por fila, el `Sufijo Atributo 1/2/3`.

> [!important] El eje guarda el SUFIJO, no el código del valor
> `TA` Tangonero y `ML` Arrastrero/Merlucero tienen los dos `Sufijo Parámetro = LAN`, así que **una sola fila `_LAN` sirve a los dos**. Guardando el código del valor habría que cargar una fila por valor, y la que faltara daría cero sin aviso — es exactamente lo que dejó al Puente Mayor sin precio de franco el 6/10/2026.
>
### La `TableRelation` sí se puede, y el lookup nativo igual no alcanza

Mi primera conclusión fue que no se podía, y era falsa. El obstáculo aparente es que el **tipo** del eje vive en la cabecera y el `where` de una `TableRelation` sólo ve campos de la propia tabla. Lo resuelve un FlowField de lookup:

```al
field(18; "Tipo Atr. Eje 1"; Code[20])
{
    FieldClass = FlowField;
    CalcFormula = lookup("Parámetro"."Cód. Tipo Atributo 1" where(Código = field("Cód. Parámetro Base")));
}
field(15; "Sufijo Atributo 1"; Code[10])
{
    TableRelation = "Valor Atributo Liq."."Sufijo Parámetro"
        WHERE("Cód. Tipo Atributo" = FIELD("Tipo Atr. Eje 1"), "Sufijo Parámetro" = FILTER(<> ''));
}
```

Compila y está puesta. Dos cosas que **no** resuelve, y por las que el código de validación se queda igual:

- **el lookup nativo muestra `LAN` dos veces**, una por `TA` y otra por `ML`, porque el sufijo no es único. El `OnLookup` de la página ofrece en cambio los tres valores con su descripción y guarda el sufijo del elegido: el usuario elige un concepto del negocio, no una convención interna;
- **no sabe nada de la densidad** de la lista —el eje 2 cargado con el 1 vacío—, que es el modo de falla silencioso y el único que de verdad importa.

La relación es la red; `ValidarSufijoEje` es el control. Que un campo lleve `TableRelation` no significa que la validación propia sobre.

**La clave derivada no cambia.** `ArmarConEjes('VALOR_FRANCO', ['CAL'], '729/15', 'MR08')` da `VALOR_FRANCO_CAL_729/15_MR08`, que es lo que ya está escrito. Verificado sobre las 272 filas de los 6 troncos. Dos consecuencias grandes: la migración **no reescribe ninguna clave** —sólo cambia de qué base cuelga la fila y agrega el sufijo—, y **`Cod50053` no necesita un solo cambio**, porque arma la clave a mano igual que la cascada y `ValorParametro` filtra por `Cód. Parámetro`, no por la base.

### La cascada: el alcance afuera, los ejes adentro

```
COD_<eje>_<empleado>    →  COD_<empleado>
COD_<eje>_<conv>_<cat>  →  COD_<conv>_<cat>
COD_<eje>_<conv>        →  COD_<conv>
COD_<eje>               →  COD
```

Para cada **nivel de alcance** se sueltan los ejes de atrás para adelante, y sólo después se baja un nivel. Con un eje son 8 candidatas y con tres 16, todas contra un `Dictionary`. Los ejes se sueltan por prefijos y no en los 2³ subconjuntos porque van ordenados por declaración, y probar todos obligaría a decidir si "eje 1 sin eje 2" gana a "eje 2 sin eje 1", que no tiene respuesta obvia. Un parámetro **sin** ejes recorre exactamente las cuatro claves de siempre.

> [!warning] Lo escribí al revés primero, y la flexibilidad de abajo es lo que lo destapó
> La primera versión puso **los ejes afuera**: probaba todas las claves con eje antes de cualquiera sin eje. Eso hace que *"el valor de potero para todo el convenio"* le gane a *"el de MR08 en cualquier pesquería"* — una fila por convenio tapando una por categoría, al revés de lo que el resto del sistema hace.
>
> No cambiaba ningún importe mientras las filas de cada tronco estuvieran todas al mismo nivel, pero **25 parámetros de la tabla ya mezclan niveles**, y cargar el valor general sin eje con sólo las excepciones por pesquería es justamente la forma que crea la combinación.
>
> Y el orden correcto es el que `Cod50053` ya usaba: prueba el precio con sufijo y sin sufijo **sin bajar de nivel de alcance**. Era el único lugar del código donde el sufijo se resolvía, así que la cascada tenía que generalizar eso, no contradecirlo. **El precedente que existe vale más que la simetría del código que uno escribe.**

### El eje es opcional POR FILA: cargar el general una vez y sólo las excepciones

Como la cascada prueba la clave con sufijo y después la misma sin sufijo, un parámetro **con** eje puede cargar el valor general una sola vez —sin sufijo— y sólo las excepciones por pesquería. No hay que cargar dos veces lo que no difiere.

Aplicado a `PRECIO_PUERTO`, que necesita el eje porque 47 de sus 51 pares difieren: los 4 que no difieren —175/75 OF02 y OF04 en pesos, 768/19 OF01 y OF03 en dólares— pasaron a una sola fila. De 106 filas a 102, y quien mantiene los valores deja de tener que acordarse de tocar dos filas cuando ese precio cambie.

> [!important] Un alcance no puede tener fila con sufijo **y** sin sufijo
> Si las dos existen, la de sufijo gana siempre y la general nunca se usa. Hoy el valor sería el mismo, pero el día que alguien edite la fila general no pasaría nada y no habría error que lo explique. Por eso al consolidar la fila redundante se **va** del parámetro —vuelve al sufijado de legado con su clave original— en vez de quedarse muda adentro. Va como invariante del script.

### Dónde se resuelve el valor del eje, y por qué en una pasada aparte

`LoadAtributos` corre **al final** de `BuildContext`, después de los parámetros, y está así a propósito: para no pisar un nombre de variable que ya ocupó un parámetro o una fuente ([[parametro-y-atributo-mismo-nombre]]). Adelantarlo invertiría esa precedencia.

La salida es `CargarSufijosDeEje`: una pasada propia que **no escribe en el contexto** —sólo llena `FSufijoEje`, de tipo de atributo a sufijo—, así que no puede pisar nada ni ser pisada, y mira únicamente los tipos que algún parámetro declara como eje. Se cachea **por liquidación y no por pasada**, porque `UsarParCCT` vuelve a llamar a `LoadParametros` con otro par y los ejes no dependen del par ([[usarparcct-deshace-pasadas-posteriores]]).

La lista que se le pasa a la cascada tiene que quedar **densa**: si el eje 1 no resuelve se corta y no se siguen agregando, porque con el 1 vacío y el 2 cargado el sufijo del 2 iría a la primera posición y resolvería contra las filas del 1. Que salga corta no es error —la cascada prueba los prefijos más cortos y termina en la clave base—; lo que no puede hacer es desordenarse.

### Las fórmulas de los 6 troncos NO son todas equivalentes

Acá está el trabajo fino, y es el punto del paso 1: el `IF(TIPOACTIVIDAD = 1, X_CAL, X_LAN)` lo reemplaza **la cascada**, no una equivalencia textual. Hay que ir concepto por concepto:

| Concepto | Orden | Tronco | Qué pasa al migrar |
|---|---|---|---|
| **1083** Sueldo de puerto | 80 | PRECIO_PUERTO | **MIGRADO 9/10/2026.** Ramas idénticas → el `IF` se colapsa |
| **1547** Incentivo | 153 | PRECIO_INCENT | **MIGRADO 9/10/2026.** Como el 1013: `#COEF_PESQUERIA` |
| **1534** Premio adicional | 159 | VALOR_NAV_EMP | ramas **estructuralmente distintas** (potero va por producción, tangonero por `#2498`) → el `IF` SE QUEDA, sólo cambia el nombre |
| **2083** A cuenta francos | 197 | VALOR_FRANCO_EMP | **MIGRADO 9/10/2026, y el `IF` SE QUEDÓ**: filtra quién cobra, no el precio |
| **2013** A cuenta puerto | 551 | VALOR_PUERTO_EMP | **MIGRADO 9/10/2026, y SIN EJE**: los 4 pares eran idénticos |
| **2003** A cuenta 175/75 | 650 | VALOR_NAV_EMP | ramas distintas → sólo el nombre |
| **FRANCO_DEVENG** | 942 | VALOR_FRANCO | **MIGRADO 9/10/2026.** El `IF` sólo elige el precio → se colapsó |
| **1534** / **2003** | 159 / 650 | VALOR_NAV_EMP | **MIGRADOS 9/10/2026**, con el `IF` intacto: sólo cambió el nombre |

### El mismo `IF(TIPOACTIVIDAD…)` puede estar haciendo dos cosas distintas

Es la distinción que decide si el `IF` se colapsa o se queda, y no se ve sin leer la última rama:

- **elige el precio** → el eje lo releva y el `IF` se va. `FRANCO_DEVENG` es el caso limpio: `IF(TIPOACTIVIDAD = 'PO', VALOR_FRANCO_CAL, VALOR_FRANCO_LAN)`, dos ramas, nada más que el nombre del parámetro;
- **elige quién cobra** → el eje no lo releva y el `IF` se queda. El **2083** tiene tres ramas y la última devuelve **cero**: hoy sólo un tangonero o un potero cobran ese concepto, y el Puente Mayor, Administración y Planta quedan en nada. Colapsarlo abriría el concepto a cualquier pesquería, que es cambiar la regla de negocio.

En el 2083 se renombró el parámetro y la estructura quedó intacta, con las dos ramas idénticas y el `IF` filtrando el alcance. Queda feo y es correcto: **la fealdad está en que el `IF` tenía dos responsabilidades, no en haberle dejado una**.

El 2083 es el caso que hay que decidir con el negocio, no por código: hoy el Puente Mayor no entra en ninguna de sus dos ramas nombradas y con el eje entraría por LAN — que es la regla confirmada para los francos, pero es un cambio de importe, no una refactorización.

### Lo que enseñó el primer tronco (PRECIO_PUERTO, 9/10/2026)

**106 filas movidas, ninguna clave reescrita.** Antes de migrar hay que preguntar **quién usa el concepto y con qué sufijo resolvería**, porque el `else` del `IF` viejo es más ancho que el eje nuevo: mandaba a `_LAN` a cualquiera que no fuera potero, incluidos `FA` y `PA`, que **no tienen sufijo** y con el eje caerían a una clave sin eje que no existe — cero. Medido: de las 439 liquidaciones con línea de 1083 en enero, todas son `PO` (270), `TA` (164) o `ML` (5), y las tres tienen sufijo. Ninguna FA ni PA. El cambio salió neutro, pero eso **se mide, no se supone**.

> [!warning] Un `FULL JOIN` con el filtro en el `ON` no acota el lado derecho
> La invariante central —"ninguna clave cambió"— la escribí como un `FULL JOIN` con `d.[Cód. Parámetro Base]='PRECIO_PUERTO'` dentro del `ON`. Eso no filtra: trae las **796 filas del resto de la tabla** y las cuenta como faltantes. La invariante acusó un cambio que no existía y el ensayo hizo rollback de una migración correcta.
>
> La forma que sirve son **dos `NOT EXISTS` separados**: cada fila de antes tiene que encontrarse igual después, y ninguna fila de después puede no haber estado antes. El segundo es el que delataría una copia en vez de un movimiento. Es el mismo error que [[join-por-menos-campos-que-la-pk]], en otra forma.

**El parámetro es mixto y la migración lo preserva.** `PRECIO_PUERTO` tiene filas en **ARS** para marinería (1,4 a 3,2 M) y en **USD** para oficiales (3.060 a 6.000, el garantizado del 175/75 y el 768/19). Valores de cuatro cifras al lado de valores de siete parecen un error de carga y no lo son. La invariante compara `Moneda` y `Cód. Variable TC` fila por fila, así que `ConvertirParametrosEnDivisa` sigue haciendo lo mismo.

### La regla: el eje se declara cuando DISTINGUE algo

No alcanza con que la dimensión exista; tiene que cambiar el valor. Declarar un eje que no distingue nada no es neutral: hace que la cascada pruebe el doble de claves, obliga a cargar cada valor dos veces, y —lo que más cuesta— **le dice a quien lo lee que la pesquería importa ahí, cuando no importa**. La decisión se toma midiendo, tronco por tronco:

| tronco | pares comparables | con el mismo valor | decisión |
|---|---|---|---|
| PRECIO_NAV | 55 | **55** | sin eje (fusionado en el paso 0) |
| PRECIO_ORDENES | 49 | **49** | sin eje (paso 0) |
| **VALOR_PUERTO_EMP** | 4 | **4** | **sin eje** |
| PRECIO_PUERTO | 51 | 4 | eje |
| VALOR_FRANCO | 51 | 6 | eje |
| VALOR_NAV_EMP | 13 | 4 | eje |
| VALOR_FRANCO_EMP | 2 | 1 | eje |
| PRECIO_INCENT | 9 | 0 | eje |

`VALOR_PUERTO_EMP` se migró con eje y hubo que revertirlo: doce filas donde alcanzaban ocho. **Medir antes de migrar sale más barato que revertir después**, aunque revertir sea posible.

> [!tip] Quitar un eje sin tocar las filas que ya se usaron
> De cada par hay que conservar **una** fila, y la elección no es indiferente: las tres filas con `En Uso = 1` eran todas `LAN`. Conservando las `CAL` y devolviendo las cuatro `LAN` a su parámetro sufijado de origen —con su clave original intacta—, **ninguna fila usada en una liquidación registrada cambió de clave**, y no se borró nada.
>
> Y las cuatro tienen que **irse** del parámetro, no quedarse mudas adentro: filas con sufijo colgando de un parámetro sin eje dejan un estado que `ValidarEje` rechazaría la próxima vez que alguien toque el eje desde la ficha.

Las cuatro filas asimétricas son lo único que hay que medir al fusionar, porque pasan a aplicar en las dos pesquerías. Acá: `04455` y `04649` son valores **por empleado** y los dos están en potero —`04455` cobra el 2013 y resuelve 5.500 antes y después—, y del convenio `ESP` no hay ninguna liquidación en enero.

### El segundo tronco: cómo se PRUEBA que un colapso multilínea es equivalente

`VALOR_PUERTO_EMP` / 2013 trajo tres cosas nuevas. **Filas por empleado** —04455 y 04649—, que usan la otra rama de `ArmarDeFila` (base + ejes + empleado, sin par) y cuya clave tampoco cambia: 12 de 12 reconstruibles. **Tres filas con `En Uso = 1`**, que se mueven igual: mover no le cambia la clave, el valor ni la moneda, así que la liquidación registrada que las usó sigue reproduciéndose al centavo; lo que cambia es de qué parámetro cuelgan, que es organización y no dato. Y una **fórmula multilínea**, donde el `REPLACE` no sirve: un `IF` que abre en varias líneas no se borra sin adivinar los saltos (son **CRLF**, en 64 de los 299 conceptos).

La fórmula nueva se escribe a mano, y la equivalencia **no se afirma: se verifica antes de tocar nada**. Normalizar las dos —fuera espacios y CRLF—, unificar el nombre del parámetro en la vieja, y exigir:

```sql
@ViejaNorm = 'IF(TIPOACTIVIDAD=1,' + @NuevaNorm + ',' + @NuevaNorm + ')'
```

Eso prueba en un solo paso las **dos** cosas: que las ramas eran realmente idénticas, y que la fórmula tipeada a mano no perdió ni agregó un término. Un paréntesis de más no da igual y nada se guarda.

### Al migrar, el sufijado tiene que CALLARSE

No alcanza con que ninguna fórmula lo nombre. `LoadParametros` recorre **todos** los parámetros con `Nombre Variable` cargado, así que un parámetro vacío sigue escribiendo `PRECIO_PUERTO_CAL = 0` en el contexto de cada liquidación, con su aviso de "sin valor cargado". Se le vacía el `Nombre Variable` —que es por donde `LoadParametros` filtra— y recién después se borra, cuando el período cierre.

### Y los datos se migran MOVIENDO, no copiando

`BuildParametroCache` indexa por `Cód. Parámetro`, y la clave no cambia: copiar dejaría **dos filas con la misma clave** y distinta base, y el `Dictionary` se quedaría con una sola sin avisar. El `UPDATE` cambia `Cód. Parámetro Base` —que es parte de la PK, y SQL lo resuelve— y agrega el sufijo. Los parámetros sufijados quedan vacíos en el catálogo y **se les saca el `Nombre Variable`**, que es lo que hace que `LoadParametros` los saltee en vez de escribir cuatro variables en cero con sus avisos.

## El paso 1, terminado: los 8 parámetros

| parámetro | eje | filas | de ellas sin eje |
|---|---|---|---|
| PRECIO_NAV | — | 55 | 55 |
| PRECIO_ORDENES | — | 53 | 53 |
| VALOR_PUERTO_EMP | — | 8 | 8 |
| PRECIO_PUERTO | TIPOACTIVIDAD | 102 | 4 |
| PRECIO_INCENT | TIPOACTIVIDAD | 18 | 0 |
| **VALOR_FRANCO** | TIPOACTIVIDAD | 96 | 6 |
| VALOR_FRANCO_EMP | TIPOACTIVIDAD | 3 | 1 |
| VALOR_NAV_EMP | TIPOACTIVIDAD | 26 | 8 |

De 16 parámetros sufijados a 8, con la dimensión en configuración. **`Cod50053` no necesitó un solo cambio**: el ledger toma `Cód. Parámetro Valor` del concepto 1063 —que ya decía `VALOR_FRANCO`— y arma a mano la misma clave que la cascada, probando con sufijo y sin sufijo *sin bajar de nivel de alcance*. Esta cascada generaliza eso.

> [!danger] Devolver una fila "al legado" NO la saca del cálculo
> `BuildParametroCache` recorre la tabla entera, indexa por **`Cód. Parámetro`** y **no mira el parámetro base**. Y el parámetro sufijado de legado se llama exactamente igual al prefijo que `ArmarConEjes` genera:
>
> ```
> fila guardada en:  PRECIO_PUERTO_LAN   con clave  PRECIO_PUERTO_LAN_175/75_OF02
> la cascada pide:   ArmarConEjes('PRECIO_PUERTO', ['LAN'], '175/75', 'OF02')
>                    = PRECIO_PUERTO_LAN_175/75_OF02      ← LA MISMA CADENA
> ```
>
> Así que la fila "al legado" seguía respondiendo y la general sin sufijo nunca se usaba. Fue inocuo porque siempre se devolvió la gemela idéntica —medido fila por fila—, pero **la invariante que usé en los cuatro primeros scripts no lo detectaba**: *"ningún alcance con fila con sufijo y sin sufijo"* mira dentro del parámetro, y esas filas están en otro.
>
> La redundante hay que **borrarla**, no mudarla. Mientras el parámetro sufijado exista con filas, sus claves son alcanzables.

> [!warning] Un alcance MIXTO entre vigencias no se puede consolidar
> `BuildParametroCache` filtra por `Vigencia Desde <= fecha` y se queda con la última **por clave**. Si un alcance coincide en una vigencia y difiere en otra, consolidar la **posterior** deja la clave con sufijo de la vigencia vieja en la caché, tapando la general nueva — y el importe sale mal sin aviso.
>
> `PRECIO_PUERTO` tiene dos así: 175/75 OF02 y OF04 coinciden en enero (1.800.000 ARS) y difieren en mayo (6.000 / 3.600 **USD**, cambia la moneda). Consolidé enero y quedó bien **por el orden**: la clave con sufijo sólo existe desde mayo. La regla segura es la simple: **un alcance mixto no se consolida**. Va como guarda.

## Lo que queda abierto

> [!success] El control pasó: **16 de 16 renglones exactos, diferencia 0,00**
> Enero recalculado el 9/10/2026 con el paso 1 completo. Los ocho conceptos dan el mismo importe y la misma cantidad de liquidaciones que cobran, hasta el centavo, incluido el **ML del 1063** — el 04495 del Puente Mayor, que ahora resuelve por LAN gracias al `Sufijo Parámetro` del valor `ML` sin que ninguna fórmula lo nombre.
>
> Dos controles complementarios, que son los que de verdad prueban el diseño:
> - **cero líneas con cantidad > 0 e importe 0** en los ocho conceptos: ningún parámetro dejó de resolver;
> - y las filas **sin eje** resolvieron de verdad —`En Uso` marcado en 4 de 4 en `PRECIO_PUERTO`, 5 de 6 en `VALOR_FRANCO`, 6 de 8 en `VALOR_NAV_EMP`, 5 de 8 en `VALOR_PUERTO_EMP`, 1 de 1 en `VALOR_FRANCO_EMP`—. O sea que **el fallback sin eje se está usando**, no sólo que no rompió nada. Es la diferencia entre "no falla" y "funciona".

**El control que lo validó:** recalcular enero y exigir, concepto por concepto:

| Concepto | Esperado |
|---|---|
| 1083 | PO 19.741.569,73 · TA 8.859.454,69 · ML 6.162.265,00 |
| 2013 | TA 7.630.960,43 · PO 2.900.009,33 |
| 1547 | PO 156/246 = 103.216,66 · TA y ML en cero |
| 2083 | TA 1.491.783,33 · PO 48.345,83 |
| 1534 | 12/12 = 64.916.957,16 |
| 2003 | 22/24 = 251.863.867,49 |
| 1063 | TA 21.737.929,24 · PO 1.308.663,67 · **ML 494.375,60** |
| FRANCO_DEVENG | PO 2.149.043.182,00 (90 liquidaciones) |

El renglón del **ML en el 1063** es el que cierra el círculo: es el 04495 del Puente Mayor, el caso que arrancó todo esto, y ahora resuelve por LAN gracias al `Sufijo Parámetro` del valor `ML`, sin que ninguna fórmula lo nombre.

Y después:

- **borrar los 12 parámetros sufijados vacíos** y las **212 filas** de `PRECIO_NAV_*` y `PRECIO_ORDENES_*`, que son las originales del paso 0 y no son alcanzables (sus parámetros no declaran eje). Con enero cuadrado;
- colapsar a mano el `IF` de ramas iguales que quedó en **1053, 4423 y 4433** (cosmética, se ve en la página lo que se borra);
- las 4 filas de `PRECIO_ORDENES` de 768/19: ¿diferencia real o hueco de carga en potero?
- las **13 filas de `VALOR_NAV_EMP` con sufijo LAN que el cálculo no lee**: el 1534 y el 2003 consultan ese parámetro sólo dentro de la rama de potero. ¿Falta una rama de tangonero, o el valor de navegación por empresa es sólo de poteros? Es pregunta para RRHH, no para el código.

## Relacionado

- [[parametros-somu-por-pesqueria]]
- [[dos-parametros-mismo-nombre]]
- [[un-valor-una-fuente]]
- [[puente-mayor-no-es-la-planta]]
- [[franco-porcentaje-por-pesqueria]]
- [[control-precedencia-formulas]]
- [[previsualizar-antes-de-migrar]]
- [[sql-directo-deja-cache-rancia]]
- Tema: `parametros-atributos` (ver [[_Convenciones del vault]])
