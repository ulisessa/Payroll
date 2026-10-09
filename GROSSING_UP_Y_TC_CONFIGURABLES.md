# Grossing-up y tipo de cambio: sacar del código lo que debería ser dato

Diseño del cambio, para revisar **antes** de tocar una línea. Escrito el 4/10/2026.

Son dos cosas que se tocan en el mismo lugar y conviene hacer juntas: el tipo de cambio de los
parámetros en divisa, y la configuración del grossing-up. Las dos sacan decisiones de `Cod50014` y
`Cod50016` para ponerlas en datos que alguien pueda ver y cambiar sin compilar.

---

## 1. Qué está cableado hoy

### El tipo de cambio

`ConvergerGrossingUp` convierte el neto objetivo con una sola línea:

```al
TipoCambio := TipoCambioVendedor(MonedaGU, FechaRef);   // Cod50014:2289
```

**Siempre el vendedor.** Para los cuatro empleados de tierra que hoy usan grossing-up eso es
correcto —el comentario de la línea 2281 documenta el bug que corrigió: un neto de USD 11.100 salía
15.706.500 en vez de 16.261.500— pero no es universal. La planilla de los oficiales poteros convierte
al comprador, y la convención del proyecto es *producción al comprador, sueldos en divisa al
vendedor*.

Y la moneda sale de `FMoneda`, que `Cod50016:430` fija con **el primer parámetro en divisa que
aparece en el recorrido**:

```al
if FMoneda = '' then
    FMoneda := Moneda;
```

Hoy no molesta porque los 156 parámetros con moneda son todos USD o EUR y nadie mezcla dentro de una
misma liquidación. Pero la moneda sale bien **por casualidad**, no por diseño.

### Las variables del grossing-up

Tres nombres cableados en **16 lugares** de `Cod50014`, más tres en el catálogo de `Cod50060`:

| Variable | Qué es |
|---|---|
| `ES_GROSSING_UP` | la liquidación converge (1) o no (0) |
| `NETO_GARANTIZADO` | el objetivo, en pesos |
| `COMPLEMENTO_GU` | el ajuste que el bucle mueve |

Y dos constantes: el máximo de iteraciones (`MaxIteracionesGrossingUp`, 20) y la tolerancia
(`NetoGarantizadoSatisfecho`).

### Lo que YA es configurable, y conviene no rehacer

- **Qué concepto define el objetivo**: `Config. RRHH."Cód. Concepto Neto Garantizado"`, hoy
  `NETO_GARANT`. Su fórmula es un concepto común y se edita como cualquiera.
- **Qué concepto paga el complemento**: cualquiera cuya fórmula nombre `COMPLEMENTO_GU`. Hoy son el
  1003, el 2003, el 3553 y el 4743. No hace falta tocar nada para agregar otro.

---

## 2. Lo que NO vamos a hacer, y por qué

**El bucle de convergencia no pasa a ser un concepto.** No es una fórmula: es una búsqueda de punto
fijo sobre la liquidación entera —recalcula todos los conceptos, lee el neto resultante, ajusta el
complemento y repite hasta veinte veces—. El evaluador no tiene bucles ni forma de reinvocar al motor
desde dentro de una fórmula, y dárselos abriría la puerta a que una fórmula mal escrita cuelgue el
cálculo.

Además no es una regla de nómina: es plomería numérica. Lo que hay que poder decidir es **cuál es el
objetivo** y **dónde cae el ajuste**, y las dos cosas ya salen de datos.

Si algún día hace falta otro algoritmo de convergencia, eso es una interfaz en AL con dos
implementaciones, no una fórmula.

---

## 3. El cambio

### 3.1 Columna de tipo de cambio en `Parámetro Vigente`

Campo nuevo **`Cód. Variable TC`** (Code[60]) al lado de `Moneda`, en la **fila de valor** y no en la
cabecera del parámetro. Esa es la decisión correcta por tres motivos:

- `Moneda` ya vive en la fila; tener la moneda en un lado y su TC en otro es justo lo que después
  nadie entiende.
- Queda **por alcance**: `USD_MAREA_04724` puede ir al vendedor y `USD_MAREA_768/19_OF03` al
  comprador, porque son filas distintas.
- Queda **por vigencia**: si cambia la convención, se expresa con una fila nueva en vez de reescribir
  la anterior.

Contenido: el nombre de una variable que resuelva el TC — hoy `TC_COMPRADOR` o `TC_VENDEDOR`, que
son Fuentes de Datos. Nada impide que mañana sea una distinta: el TC de una marea **no es una
cotización sino un valor acordado**, y ese caso ya existe.

**Validación**: con `Moneda` cargada y `Cód. Variable TC` vacía, el motor corta. Pero la validación
se enciende **al final**, cuando las 156 filas estén completas — si se enciende antes, no liquida
nadie.

### 3.2 El orden de carga, que es el único riesgo real

`TC_COMPRADOR` y `TC_VENDEDOR` son **Fuentes de Datos**, y el contexto se arma así
(`Cod50016:153-155`):

```
153  LoadScalars        → LoadParametros (375), LoadVariablesSistema (376)
154  LoadDynamicSources  ← acá recién aparecen los TC
155  LoadAtributos
```

Los parámetros se cargan **antes** que las fuentes. Si el motor convierte cada parámetro al cargarlo,
el TC que la columna le indica todavía no existe.

**Solución: diferir la conversión a una segunda pasada**, después de `LoadDynamicSources`. Los
parámetros entran al contexto en divisa como hoy, y un paso nuevo los convierte leyendo su
`Cód. Variable TC`.

**Lo que NO hay que hacer**: mover `LoadDynamicSources` arriba de `LoadParametros`. `LoadAtributos`
está escrito para no pisar lo que ya ocupó un parámetro o una fuente —"NO pisa lo que ya esté
definido", `Cod50016:2153`— y reordenar invierte esa precedencia. Es la misma trampa que frenó el eje
de sindicato en `Claves Parámetro Liq.`

### 3.3 Las fórmulas que hoy convierten: son 16, no 4

**Corregido el 4/10/2026.** La primera versión de este documento decía 4, contando sólo las que usan
`_ESFCY`. Estaba mal: `_ESFCY` es el mecanismo **opcional**, y la mayoría de las fórmulas convierte
sin preguntar nada.

Encender la conversión sin migrarlas **multiplica por el TC dos veces**, y en la cadena de producción
entera.

**Con `_ESFCY` (4)** — el `IF` decide si convierte:

| Concepto | Parámetro |
|---|---|
| 1003 | `BASICO` |
| 1083 | `PRECIO_PUERTO_CAL`, `PRECIO_PUERTO_LAN` |
| 3553 | `BASICO` |
| 4743 | `BASICO` |

**Sin bandera (12)** — multiplican y listo:

| Concepto | Parámetros |
|---|---|
| 1534 | `SALARIO_ASEG_CAL`, `USD_MAREA`, `USD_TON_PROD`, `NETO_GU_MAREA` |
| 2003 | `SALARIO_ASEG_CAL`, `USD_TON_PROD` |
| 2013 | `SALARIO_ASEG_CAL`, `SALARIO_ASEG_LAN` |
| PROD_EMPRESA | `USD_TON_PROD`, `USD_MAREA` |
| ADIC_PROD_PESCA | `USD_TON_PROD` |
| 1393, 2083 | `VALOR_CR_SOMU`, `VALOR_FRANCO_ACDO` |
| 2403, 2413, 2423, 2463, 2473 | `VALOR_L1/L2/L3_SOMU`, `VALOR_C1/C2_SOMU` |

**Y en dos de las cuatro con `_ESFCY` el `IF` no se puede borrar.** En 3553 y 4743 la bandera no
sólo decide si convierte: elige entre **dos valores distintos**.

```
IF(BASICO_EsFCY, BASICO * TC_VENDEDOR, #1003 + #1053 + #1054 + ...)
```

Si el empleado tiene básico en divisa se usa ése; si no, la suma de conceptos. Ahí hay que sacar el
`* TC_VENDEDOR` y **dejar el `IF`**, que pasa a ser una prueba de presencia. Borrarlo entero dejaría
en cero a todo el que no tenga `BASICO`.

En 1003 y 1083, en cambio, las dos ramas quedan iguales y el `IF` se colapsa.

**Corregido de nuevo el 4/10/2026**: en 3553 y 4743 el `IF` **sí** se borra entero. La rama verdadera
usaba *sólo* el básico; la falsa suma `#1003 + #1053 + ...`, y `#1003` **ya es el básico**. Las dos
ramas dan el mismo número —verificado en 90251, el único empleado que alcanza esa rama: de los siete
conceptos de la suma sólo `#1003` es distinto de cero—. Borrarlo además arregla un defecto: la rama
verdadera dejaba la antigüedad afuera de la base de vacaciones.

### 3.4 Las fórmulas NO son el único inventario

Buscar `TC_COMPRADOR` en las fórmulas encuentra las que convierten de más. Falta el espejo: las que
después de encender van a convertir **de menos o de más sin nombrar ningún TC**. Son tres categorías
y ninguna aparece en el listado de 3.3.

**(A) Filas sin `Moneda` que la fórmula convierte igual.** El control "ninguna fila con `Moneda` y
sin `Cód. Variable TC`" las deja pasar, porque el problema es justamente que **no tienen** `Moneda`.

| Parámetro | Filas en blanco | Valores | Qué pasa al encender |
|---|---|---|---|
| `USD_MAREA` | 8 de 16 | 5.500 a 24.000 | dejan de convertirse: **226 M menos** en 1534 y 2003 |
| `VALOR_PLUS_PROD` | 1 de 1 | 41,91 | deja de convertirse en la rama tangonera de 2003 |

Los ocho `USD_MAREA` son dólares sin discusión: el nombre lo dice, la magnitud coincide con los
que sí están marcados (5.500, 6.900, 12.750) y la fórmula los convierte hoy sin preguntar. Es una
omisión del paso 2, no una diferencia de moneda. **`VALOR_PLUS_PROD` en cambio no está claro**: 41,91
contra 800 de `USD_TON_PROD` y 5.800 de `VALOR_L1_SOMU` es un orden de magnitud menos, y la fila está
con `En Uso = 0`.

**(B) Parámetros con `Moneda` en fórmulas que no convierten.** Al encender empiezan a convertirse, y
eso multiplica por ~1.100 algo que hoy se usa crudo.

| Variable | Conceptos | Enero | Veredicto |
|---|---|---|---|
| `NETO_GU`, `NETO_GU_MAREA` | `NETO_GARANT` | 5 líneas | **bloquea**: ver abajo |
| `USD_TON_PROD` | `BASE_PROD_CAL` | 180 líneas, 80,7 M | inocuo: Tipo 6 y **sin consumidores** |
| `VALOR_L1_SOMU`, `VALOR_C1_SOMU` | 1093 | 0 líneas | inocuo: no se usa |
| `BASICO` | 1054, 1055, 1803, 1813, 1893, 2103, 2704 | 584 pesos | inocuo, y es un arreglo |

El grupo de `BASICO` sólo alcanza a 90212, 90251 y 90302 —los únicos con básico en divisa— y en
enero sólo mueven el 2704, que es informativo. Hoy esas fórmulas usan un 6.000 en euros **como si
fueran pesos**; que empiecen a convertir es la corrección, no el daño.

**`NETO_GARANT` es el bloqueo.** Es el concepto objetivo del grossing-up: su fórmula lee `NETO_GU` y
`NETO_GU_MAREA` sin convertir **a propósito**, porque el que convierte es el motor, con
`TipoCambioVendedor` (`Cod50014:2289`). Si el parámetro llega ya en pesos, **se convierte dos veces**.
Así que 3.5 no es independiente como decía la primera versión de este documento: es requisito.

### 3.5 Configuración del grossing-up

Campos nuevos en `Config. Recursos Humanos`, al lado del que ya existe:

| Campo | Reemplaza | Default |
|---|---|---|
| `Cód. Var. Es Grossing-Up` | el literal `'ES_GROSSING_UP'` | `ES_GROSSING_UP` |
| `Cód. Var. Neto Garantizado` | `'NETO_GARANTIZADO'` | `NETO_GARANTIZADO` |
| `Cód. Var. Complemento GU` | `'COMPLEMENTO_GU'` | `COMPLEMENTO_GU` |
| `Máx. Iter. Grossing-Up` | `MaxIteracionesGrossingUp()` | 20 |
| `Tolerancia Grossing-Up` | la constante de `NetoGarantizadoSatisfecho` | **1 peso** |

Los defaults son los valores actuales, así que **sin tocar la configuración nada cambia**.

**Corregido el 4/10/2026**: la tolerancia es de **un peso**, no de 0,01 como decía la primera versión
de este documento. Bajarla a centavos puede dejar liquidaciones sin converger por los redondeos de
los conceptos intermedios, que no tienen por qué cerrar al centavo.

Los nombres de campo van abreviados —`Cód. Var.` y no `Cód. Variable`— porque pasar de 30 caracteres
dispara el AL0468, que está anunciado como error futuro. Las captions quedan completas.

Ninguno usa `InitValue`: la fila de `Config. RRHH` ya existe, así que un `InitValue` no la tocaría y
haría falta un Upgrade para algo que el fallback de `CargarConfigGU` resuelve sin riesgo. **En blanco
significa el valor de siempre**, y un cero en los numéricos se trata como blanco: cero iteraciones no
convergería nunca y tolerancia cero no cerraría jamás, así que no son configuraciones válidas sino el
campo sin cargar.

El TC del objetivo deja de ser `TipoCambioVendedor` y pasa a resolverse por 3.1, leyendo la columna
del parámetro que el concepto objetivo usa.

---

## 4. Orden de trabajo

Pensado para que enero no se mueva hasta el final, y para que cada paso se pueda verificar solo.

**Paso 1 — La columna, vacía.** Agregar `Cód. Variable TC` a `Parámetro Vigente`, sin validación y
sin que el motor la lea. No cambia ningún importe. *Verificación: recalcular enero y comparar contra
el estado actual; tiene que dar idéntico.*

**Paso 2 — Completar las 156 filas.** Por lote agrupando por parámetro base, con el criterio
convenido para cada uno. Sigue sin leerse. *Verificación: ninguna fila con `Moneda` y sin
`Cód. Variable TC`.*

**Paso 3 — La segunda pasada de conversión, apagada.** Escribir el paso que convierte, detrás de una
bandera. *Verificación: con la bandera apagada, enero idéntico.*

**Paso 3b — Marcar la moneda que falta. HECHO el 4/10/2026.** Nueve filas a `USD` + `TC_COMPRADOR`:
las 8 de `USD_MAREA` y la de `VALOR_PLUS_PROD` —41,91 USD por tonelada, confirmado por el usuario; es
un plus y no un precio, así que la magnitud chica no se puede controlar por rango—. Sólo dato: con la
bandera apagada nadie lee `Moneda`, así que no hizo falta recalcular. Quedan mixtas las tres
legítimas, `BASICO` y los dos `PRECIO_PUERTO_*`, que son las que preguntan `_ESFCY` por fila.

**Paso 3c — El TC del objetivo del grossing-up. HECHO el 4/10/2026** (pendiente de publicar)**.** Con la bandera encendida, `ConvergerGrossingUp`
tiene que dejar de convertir: el parámetro ya llega en pesos. Es un cambio en AL, y sin él
`NETO_GARANT` convierte dos veces. *Verificación: con la bandera apagada, enero idéntico.*

**Paso 4 — Encender y migrar las fórmulas, en el mismo movimiento.** Es el único paso que mueve
importes, y el riesgo creció dos veces: primero con la corrección de 3.3 —toca la cadena de
producción completa, no cuatro casos de borde— y después con 3.4, que agregó lo que no se ve
buscando `TC_COMPRADOR`.

La foto de referencia está en **`dbo.SnapEnero_Paso3`** (51.322 filas, 324 empleados, suma de control
26.904.945.155,71), tomada el 4/10/2026 con la bandera apagada y las 568 liquidaciones de enero
recalculadas.

*Verificación: enero concepto por concepto contra esa foto.* **Tiene que dar idéntico salvo en una
lista cerrada de cuatro cosas**, todas de 3.4(B) y todas inocuas: `BASE_PROD_CAL` (informativo, sin
consumidores), el 2704 de 90212 y 90302 (584 pesos), el 1093 (en cero) y `NETO_GARANT` si 3c quedó a
medias. Cualquier otra diferencia es un error de migración, no un efecto del cambio.

**Paso 5 — La validación. HECHO el 4/10/2026** (pendiente de publicar)**.** Dos piezas:

- `ConvertirParametrosEnDivisa` **corta** en los tres casos que no puede convertir, donde antes
  avisaba y seguía. Avisar era la peor opción: el importe quedaba en divisa, mil cuatrocientas veces
  más chico, y ningún control de importe lo ve porque el número es válido.
- Pantalla **`Moneda de Parámetro a Revisar`** (`Pag110059`), colgada del Árbol de Parámetros, con
  los dos diagnósticos. El segundo es el que importa y es el que se escapó en 3.4(A): una fila **sin**
  moneda dentro de un parámetro cuyas demás filas sí la declaran. No corrige ni ordena corregir
  —mezclar es legítimo en `BASICO` y los dos `PRECIO_PUERTO_*`—: muestra las dos cuentas y deja la
  lectura a quien sabe qué se pactó.

**Paso 6 — El resto de la configuración del grossing-up. HECHO el 4/10/2026** (pendiente de
publicar)**.** Los cinco campos de 3.5, con `CargarConfigGU` resolviendo el default. En el motor
quedan **exactamente tres literales** de los tres nombres, los de `CargarConfigGU`, y ninguno en el
resto del proyecto; el catálogo de `Cod50060` también los lee de la configuración, porque si alguien
los renombra el editor de fórmulas tiene que ofrecer el nombre nuevo.

De paso se expuso en la página de `Config. RRHH` la bandera **`Convertir Param. por TC`**, que
estaba en la tabla desde el paso 3 pero no en ninguna pantalla: la llave de paso se había encendido
por SQL y no había forma de apagarla sin SQL.

*Verificación: con los cinco en blanco, enero idéntico.*

---

## 5. Lo que queda abierto

**Qué TC corresponde a cada parámetro.** Es una definición de negocio, no técnica, y es la que hay
que cerrar antes del paso 2. La convención conocida —producción al comprador, sueldos en divisa al
vendedor— cubre la mayoría, pero el paquete neto pactado de los oficiales al 70% no cae claramente de
ningún lado: la planilla usa el comprador, el motor hoy usa el vendedor, y los dos tienen argumento.

**La misma fila con dos TC.** El diseño fija un TC por fila de valor. Si alguna vez el mismo valor
resuelto necesita convertirse distinto en dos conceptos, no se puede expresar. Hay que confirmar que
eso no pasa hoy; si pasa, el TC tendría que ir en el consumo y no en el dato, que es un diseño
distinto y bastante peor.

**La línea de `NETO_GARANT`.** Es un concepto Tipo 6 que además se evalúa como concepto común, así
que su línea muestra el objetivo. Conviene decidir si se muestra en divisa o en pesos, porque el
cambio lo altera.
