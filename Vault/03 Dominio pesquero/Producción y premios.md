---
tipo: concepto
tags: [dominio, produccion, premios, garantizado, poteros, tangoneros]
fuente: [CARGA_VALORES_TANGONEROS_2026.md, scripts/RestaurarFiltrosFuenteDatos.sql, src/Tables/Tab60015.FuenteDatosLiquidacion.al, src/Codeunits/Cod50016.ContextoLiquidacion.al, "Conceptos Liquidación.xlsx (snapshot 17/8/2026)"]
actualizado: 2026-10-28
---

# Producción y premios

## Precio por tonelada pactado: aplicado (2026-10-13)

Para el acuerdo bruto con fijo de oficiales poteros se incorporó el parámetro vigente
`USD_TON_PACTADO`, cargado en USD por tonelada por convenio/categoría o empleado,
según el alcance y fecha del acuerdo. El virtual `PCT_PROD_CALC` obtiene
`100 * USD_TON_PACTADO / USD_TON_PROD`; ambos precios llevan USD y `TC_COMPRADOR`,
por lo que el tipo de cambio se cancela en el cociente. La referencia no se escribe como
un número fijo en la fórmula.

`PROD_EMPRESA` lee `@PCT_PROD_CALC` desde el 01/01/2026 sólo en su rama de cierre
potero con fijo, sin neto garantizado ni grossing-up. `PCT_PROD` sigue disponible para
las ramas anteriores y SOMU. El auxiliar replica el par de puesto y la condición del
consumidor; no imprime ni aporta a acumuladores y detecta precio faltante o referencia
no positiva mediante `ERROR('mensaje')`.

Los adicionales conservan su representación actual: un precio que ya contiene un plus
se identifica como total en su nota y no recibe el mismo plus nuevamente. Las versiones
nuevas se aplicaron inicialmente desde el 03/02/2026. Se verificaron los ocho acuerdos y pasaron
27 controles con el evaluador publicado, sin recalcular recibos.

Se aplicó mediante `scripts/AplicarPrecioTonPactado.ps1` después de actualizar el
respaldo con las ediciones/cálculos detenidos, ensayar con rollback y comprobar la firma
del plan/respaldo. Se reinició `MicrosoftDynamicsNavServer$BC252` y quedó en ejecución.
La verificación posterior confirmó que los recibos guardados, sus variables, líneas y
el control global de las seis tablas financieras permanecen intactos; también se
conservaron los valores y fórmulas anteriores, salvo el cierre de la versión reemplazada.
No se recalcularon recibos ni se requirieron cambios AL, publicación, campos o tablas.

### Extensión equivalente al 01/01/2026

Por pedido explícito se extendió la conversión a enero mediante
`scripts/AplicarPrecioTonHistorico.ps1`: diecinueve precios mantienen los alcances y
fechas de los porcentajes originales, incluidas las clases posteriores de mayo.
Las ocho filas personales del 03/02 permanecen intactas. No se copia el precio de
febrero a enero ni se reemplaza un precio de clase por uno personal artificial.

El auxiliar tiene una versión 01/01–02/02. Las tres expresiones anteriores de
`PROD_EMPRESA` se actualizaron con auditoría, conservando fechas, condiciones y demás
operaciones. En las ramas generales la referencia usa
`IF(alcance, @PCT_PROD_CALC, PCT_PROD)`; fuera del alcance conserva el porcentaje previo.
La expresión del 02/02 coincide con la conversión ya aplicada el 03/02 y conserva su
ELSE. Esta actualización retroactiva de configuración fue solicitada expresamente;
las fórmulas anteriores quedan en el historial y el respaldo.

Pasaron las comprobaciones independientes de resolución por fecha/especificidad y nueve
pruebas de expresiones con el evaluador de BC. El ensayo revertido y la comprobación
posterior verificaron cabeceras, líneas, variables y control global financiero intactos.
No se recalcularon recibos: su explicación histórica sigue usando `Fórmula Aplicada`
y los valores del detalle guardado. BC252 quedó en ejecución con un proceso iniciado
después de aplicar el cambio, confirmando la renovación de caché.

## Acuerdo bruto con fijo mensual de oficiales poteros (2026-10-13)

La generalización de febrero distingue tres valores: la garantía normativa de convenio
(`GARANT_POT_CCT`, sin filas personales), el fijo mensual de empresa (`VALOR_NAV_EMP`) y el
porcentaje de producción (`PCT_PROD`). Las condiciones individuales se verifican en
`CONDICIONES OFICIALES POTEROS CAMPAÑA 26.xlsx`; las planillas de producción permiten
comprobar el cierre. No inferir el acuerdo personal desde la categoría ni desde un total
de recibo compensado por otro concepto.

`APLICA_PROD_FIJO` es una fuente de cabecera por convenio y tipo de liquidación, sin
empleados ni proyectos escritos en las fórmulas. Las ramas nuevas exigen actividad potera,
ausencia de neto garantizado y ausencia de grossing-up. Las otras modalidades conservan
la expresión anterior. Las versiones nuevas se aplican desde febrero; los devengados
de enero conservan sus importes y fórmulas guardados.

En el cierre, empresa suma producción de la marea completa, fijo de empresa proporcional
a `DIAS_ENROLAMIENTO` y adicional de pesca; descuenta nominalmente los devengados ya
pagados. El convenio compara producción normativa con garantía proporcional a ese mismo
enrolamiento. Su descuento anterior se reconstruye con
`ACUM_PARAM_CCT('DEV_PREV_MAREA', 'GARANT_POT_CCT', 'DIAS_MAREA', 30)`: tarifa normativa
a la fecha de cada cabecera, categoría sellada, cantidad y tipo de cambio históricos.
Esto evita trasladar al cierre un reparto equivocado entre premio y complemento de un
devengado cuyo total era correcto, sin modificar ese devengado.

El premio `1534` absorbe los básicos y el feriado `1023` del recibo actual. Su orden
condicional permite leer ese feriado ya calculado. `2003` completa hasta el objetivo de
empresa y respeta el piso del convenio. No se amplía la aplicabilidad de `1534` al convenio
de máquinas. Los adicionales pactados se conservan según su parametrización existente;
no se asigna el adicional de pesca de un contrato a todos los oficiales.

El calendario del convenio también forma parte de la conciliación: un precio diario
correcto con una cantidad errónea puede quedar escondido por el complemento. Revisar
calendario y cantidad antes de compensar una diferencia en `2003`.

En esta modalidad, `1023` usa `DIAS_FERIADOS` de la cobertura del recibo. Los días de
puerto de salida anteriores a la zarpada pertenecen al enrolamiento: `PS` está marcado
como estado de marea, pero queda antes de la fecha inicial del proyecto. Por eso podía
quedar fuera tanto de `DIAS_FERIADOS_MAREA` como de `DIAS_FERIADOS_GUARDIA`, mientras
el premio absorbía el importe y el bruto parecía correcto. La rama nueva de feriado
conserva el precio diario y el orden, y se limita al mismo alcance de fuentes/modalidad;
la expresión anterior permanece en las otras ramas.

La configuración y el código publicados en 1.0.0.654 separan empresa y convenio sin
campos ni tablas nuevos. La comprobación de enero y de los recibos fuera del alcance
compara cabeceras, líneas, resúmenes, detalles y cuenta corriente de francos. El pago
de empresa anterior se descuenta nominalmente; el precio normativo histórico conserva
su propio tipo de cambio, no el del cierre.

La plata que distingue a una liquidación embarcada de una de tierra es lo que **depende de lo pescado**: la producción de la marea paga un porcentaje a cada tripulante, y los CCT fijan un **garantizado** (piso) que la producción debe superar. Esta nota explica cómo entra el dato al motor y cómo se arman los premios. Las cifras y fórmulas concretas están en [[Rubros típicos de una liquidación embarcada]].

> [!note] Alcance de lo verificado
> La **entrada del dato** (Fuentes de Datos, variables) está verificada en el repo. Las **fórmulas de los conceptos** viven en la base: se citan del snapshot `Conceptos Liquidación.xlsx` (17/8/2026) y de las lecciones, y pueden haber cambiado después. Lo que no está en el repo se marca "según lecciones".

## Cómo entra la producción: Fuentes de Datos, sin código

Los kilos no son una tabla propia: son **Fuentes de Datos** (`Fuente Datos Liquidación`, ver [[Tabla - Parámetro Vigente]] para el otro lado) que consultan *cualquier tabla de BC* por `RecordRef`, con filtros guardados por número de campo y **tokens** (`{JOB_NO}` = proyecto de la liquidación, `{EMP_NO}`, `{FECHA_REF}`, `{LIQ_NO}`…). Según `scripts/RestaurarFiltrosFuenteDatos.sql`:

| Variable | Filtros | Significa |
|---|---|---|
| `PROD_KN_L1`…`L6`, `PROD_KN_C1`…`C3`, `PROD_KN_CR` | campo 1 = `{JOB_NO}` y campo 4 = código de artículo `LTBP-AA21-L1-12 K`, `LTBP-AB21-C1-12 K`, `LTBP-AC21-CR-12 K`… | **kilos netos** de la marea por clasificación de langostino: entero 1-6 (L), cola 1-3 (C), cola rota (CR) |
| `PROD_KB_*` | idem | kilos brutos |
| `PROD_KN_MAREA` | `{JOB_NO}` y fecha `<={FECHA_REF}` | kilos de la **marea entera** (no sólo de la liquidación) |
| `TC_CERCANO` | moneda y fecha `<={FECHA_REF}` | cotización (ver trampa abajo) |

Es una agregación sobre una tabla de BC filtrada por proyecto y por código de artículo, presumiblemente los movimientos de proyecto (la tabla exacta, `Id. Tabla`, no está en el repo: vive en la base; **sin verificar**). Para sumar **ligado a una marea** el filtro es siempre `{JOB_NO}`. Las fuentes `*_PERIODO` no filtran por proyecto.

> [!danger] Los 76 filtros desaparecieron una vez de la base
> `scripts/RestaurarFiltrosFuenteDatos.sql` existe porque los 76 filtros de `Filtro Fuente Datos Liq.` se perdieron y sin filtros cada Fuente suma **toda la tabla** (65 s de `ResolveFuente`). Ver [[fuente-datos-apunta-por-numero]] — el compilador no ve nada y se rompe en runtime.

La convención de nombres da el alcance: `PROD_*` y `*_MAREA` miran la marea ([[Mareas y ciclo de la marea]]); un `PROD_KN_*` copiado de otro (L4/L5/L6 de L3) arrastra sus filtros y se paga igual sin avisar.

## Cuatro familias, cuatro lógicas

```mermaid
flowchart TD
  K[Kilos de la marea<br/>Fuente de Datos PROD_KN_*] --> A
  K --> B
  K --> C
  A[Marinería SOMU 729/15<br/>tangonero langostino<br/>conceptos 2403-2493 por clasificación] 
  B[Marinería SOMU potero calamar<br/>valores por clasificación VALOR_CAL_*]
  C[Oficiales poteros 768/19<br/>USD de producción + TC por marea]
  C --> G[Garantizado SALARIO_ASEG_*<br/>y premio = convenio - básicos]
  D[Oficiales 175/75 máquinas<br/>valor USD por tonelada + garantizado] --> G
```

### 1. Marinería de tangoneros (langostino)

Un concepto **por clasificación** (2403…2483 enteros/colas, 2493 cola rota). Forma, según el snapshot:

```text
(PROD_KN_L1/1000 * VALOR_L1_SOMU * PCT_NORM_TANG * IF(PCT_PROD<>0,PCT_PROD,1)/100 * 0.9 * TC_CERCANO) * COEF_TANGONERO
```

`VALOR_*_SOMU` son USD/tonelada por clasificación; `PCT_PROD` el porcentaje de la categoría (**guardado ×100**: `PCT_PROD_768/19_OF01 = 2,20`, no 0,022 — ver [[parametros-somu-por-pesqueria]]); `COEF_TANGONERO` el 30% del Dto 633/18 que se aplica a toda la base remunerativa. Cargas pendientes del lado langostino y la decisión sobre el valor base de puerto: ver [[Convenios del sector (CCT 729-15, 768-19, 175-75, 372-04, SOMU)]].

### 2. Marinería de poteros (calamar)

Se paga por kilo con **valores en pesos por clasificación**: `VALOR_CAL_ENT` (entero, base 10.000), `VALOR_CAL_REJ` (rejo sucio, 6.400), `VALOR_CAL_VAI` (vaina, 18.303), y de ahí **el índice SOMU** por categoría (100/85/80/75/70 sobre el básico de Marinero de Planta) — 30 celdas cargadas con vigencia 2026-01-01 y verificadas. Ver [[escala-somu-indice-70]]. Un error de redondeo del cociente (`1,4286` en lugar de la fracción exacta) movió 18 valores en −0,17 a +0,67 por tonelada: usar siempre la **fracción exacta** y redondear al final.

### 3. Oficiales de poteros (768/19)

Decodificado con `A28 59 CLC producción.xlsx` ([[produccion-oficiales-poteros]]). Insumos **por marea**: **USD de producción** y **TC acordado** (no es una cotización: [[tc-de-marea-no-es-cotizacion]]).

```text
bruto            = USD de producción × TC
total convenio   = bruto × COEF (0,90 = PCT_DOLAR_PROD 768/19)        base de PCT_PROD_CAPECA
total empresa    = producción empresa (USD/ton × puesto) + ASEGURADO   (sin coeficiente)
asegurado        = USD_MAREA × TC / 30 × DÍAS                           (prorrateo por días, no coeficiente)

PREMIO ADIC. ESP. DE PRODUCCIÓN (1534) = total convenio − (sueldo navegación + sueldo puerto + antigüedad + adicional art. 23)
A CUENTA FUTUROS AUMENTOS (2003)       = total empresa − total convenio
```

La producción de empresa es **USD por tonelada por puesto** (Pesca 32 · Capitán 16 · Jefe 16 · Garantía 20); parece un porcentaje sólo porque `USD_TON_PROD = 800` (32/800 = 4%). Por eso `PCT_PROD = (TON ENTERO + adicional)/8`. Condiciones individuales 2026 en [[condiciones-oficiales-poteros-2026]]: dos esquemas — **por tonelada con "compara con CCT, paga el mayor"** y **valores netos al 70%** (grossing-up a mano; BC no distingue los dos grupos, ver [[oficiales-netos-al-70]] y [[grossing-up-tapa-errores]]). El adicional de 10 USD/ton del Patrón de Pesca lo paga `ADIC_PROD_PESCA`, no el parámetro.

> [!warning] El 1534 y el tapón se mueven juntos
> El 1534 lee el garantizado del **CCT** (`SALARIO_ASEG_CAL`), no el acordado (`USD_MAREA`); corregirlo solo empeora el bruto porque el 2003 es el **tapón** del grossing-up. Cambiar los dos en el mismo cambio ([[cuatro-conceptos-sin-disparar]]).

### 4. Oficiales de máquinas (175/75) y el 2073

El garantizado (cláusula primera: "Remuneración en Navegación", USD al **comprador**, proporcional a los días) **absorbe todo lo devengado en la marea hasta su concurrencia** (cláusula tercera), de modo que el 2003 de 175/75 es el resto de una absorción, no un adicional ([[cct-175-75-remuneracion-navegacion]]). El **2073** *Adicional tareas mecánicas* es el 15% del garantizado prorrateado ([[adicional-tareas-mecanicas]]).

## A cuenta de futuros aumentos: una familia, tres variantes

El nombre del concepto es el mismo patrón: **garantizado prorrateado − lo ya liquidado**, con guarda sobre el *driver* (días) y no sobre el precio, porque si no con precio cargado y cero días paga **negativo**.

| Concepto | Contexto | Fórmula | Fuente |
|---|---|---|---|
| **2013** (puerto) | guardia en puerto, marinería y oficiales | `SALARIO_ASEG_* /30 × DIAS_GP_PERIODO × COEF_GUARDIA_PUERTO(1,4) × TC_COMPRADOR − (#1083 + #1023 + #1053)`; 27 vigencias al 1/1/2026 | [[a-cuenta-futuros-aumentos-puerto]] |
| **2083** (francos) | jefe y primer oficial de máquinas de tangoneros | `VALOR_FRANCO_EMP/30 × DIAS_FRANCOS_PERIODO × TC_COMPRADOR − (#1063 + #1053)`; empresa 3.500/2.975 USD vs convenio 3.000/2.550 | [[a-cuenta-futuros-aumentos-francos]] |
| **2003** (marea) | oficiales: el tapón del neto pactado | ver arriba | [[produccion-oficiales-poteros]] |

## Trampas conocidas

- **La producción no se prorratea**: `PROD_KN_MAREA` es la marea entera; el garantizado sí está prorrateado por días. En un Cierre coinciden; en un **Devengado** a mitad de marea no, y un `MAX()` entre ambos pagó 12 M de premio a un tripulante con 3 días ([[produccion-no-se-prorratea]]). Se discrimina con `TIPO_LIQ`, y desde el 11/10/2026 **por código**: el 1534 y el 2003 dicen `IF(TIPO_LIQ = 'CIERRE_MAREA', …)` y ya no `= 1`, que era un número que había que ir a buscar a la tabla ([[tipo-liq-no-implementada]]).
- **TC_CERCANO no es lo que dice**: es un `LOOKUP` sin fecha que devuelve la última cotización cargada, no la más cercana; la rama langostino de 2498 lo usa y puede valorizar con un TC equivocado.
- Un precio en **USD cargado como pesos** no da error: da un importe congelado ([[que-tc-usa-cada-concepto]]).
- Un concepto que **lee un acumulador** de la producción debe ordenarse **después** de quienes aportan ([[acumuladores-orden-calculo]], [[control-precedencia-formulas]]).

Tablas: [[Tabla - Fuente Datos Liquidación]], [[Tabla - Filtro Fuente Datos Liq]]. Relacionadas: [[Valor del franco]], [[Índice Dominio - marea y pagos]].
