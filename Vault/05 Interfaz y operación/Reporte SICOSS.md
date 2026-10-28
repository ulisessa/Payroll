---
aliases: ["Reporte SICOSS", "SICOSS"]
tipo: guia
tags: [interfaz, sicoss, declaraciones, excel]
fuente: [src/Pages/Pag110063.ReporteSicoss.al, src/Codeunits/Cod110064.ReporteSicossLiq.al, src/Enums/Enum50334.ColumnaSicossLiq.al]
actualizado: 2026-10-12
---

# Reporte SICOSS

**Dónde**: búsqueda → *Reporte SICOSS* (`Pag110063`, categoría Tareas). Genera `Cod110064`.

Emite en Excel la declaración mensual de la seguridad social, con **una fila por empleado y mes** y
las cuatro hojas de la planilla que se venía armando a mano desde antes de BC, más una quinta de
avisos. Reemplaza el armado manual de los `SI.COSS MM-AAAA.xlsx` de la raíz del repo.

## Por qué tiene ESTAS hojas y no otras

Los archivos `SI.COSS 01-2026` a `06-2026` son la planilla que se armaba con la salida de Meta4:
hojas **TOTALES**, **CNT**, **FSR** y **Dto 814**. Los de `07-2026` y `08-2026` son otra cosa —la
nómina que se **baja** de AFIP después de declarar, `Nomina_30632072917_AAAAMM_000`, con las 85
columnas del registro de SICOSS—, y ésa no la produce la liquidación: sirve para conciliar contra lo
declarado. El reporte reproduce las cuatro primeras, con sus nombres de hoja y de columna, para que
un mes de BC se pueda poner al lado de un mes de Meta4 sin traducir nada.

## Las cinco hojas

| Hoja | Qué lleva |
|---|---|
| **TOTALES** | Una fila por empleado: legajo, nombre, CUIL, ingreso, egreso, total devengado, con y sin aportes, las cinco bases imponibles, los seis descuentos que SICOSS declara, total retenido, líquido, obra social, zona, convenio, crédito del decreto 814 y el bloque de detracción |
| **CNT** | Contribuciones patronales: las tres bases, las siete alícuotas y los montos, con el total que liquidó BC al lado y la diferencia |
| **FSR** | Fondo Solidario de Redistribución: el aporte y la contribución de obra social partidos entre la obra social y el fondo |
| **Dto 814** | Base, porcentaje y crédito por zona, con la base sumada con `SUMIF` sobre TOTALES |
| **Avisos** | Filtros usados, conteos, parámetros sin valor, conceptos sin columna, empleados sin zona o sin CUIL, y cómo leer las planillas |

## De dónde sale cada número

**La unidad es el empleado y el mes, no la liquidación.** Un tripulante puede tener en el mismo mes
una regular, un cierre de marea y una de vacaciones; SICOSS declara una línea por CUIL. Los
acumuladores se suman entre liquidaciones y **los topes se aplican una sola vez sobre la suma**, que
es como los aplica la ley y como los trabaja el motor con sus `MES_`/`PERIODO_`.

- **Bases**: de los acumuladores `REMUNERATIVO_BRUTO`, `NO_REMUNERATIVO`, `BASE_SS_TRAB`/`_VAC`,
  `BASE_OS_TRAB`/`_VAC`, `BASE_LRT` y `BASE_IG4` + `BASE_EXT_IG4`.
- **Topes**: `TOPE_SIPA` y `TOPE_SIPA_OS`, leídos al último día del período y al nivel genérico (sin
  convenio, sin categoría, sin empleado). Un tope en cero **corta con error**: sin tope todas las
  bases saldrían en cero y la declaración quedaría vacía sin una sola celda en rojo.
- **Importes de aportes y contribuciones**: de los conceptos, agrupados por el campo nuevo
  **`Columna SICOSS`** (ver abajo).
- **Zona, obra social y días**: de `Resumen Variable Liq.` —`COD_ZONA`, `OBRA_SOCIAL` y
  `DIAS_ALTA_30`—, o sea de lo que el motor dejó calculado. Los días son del **mes** y se toma el
  máximo entre liquidaciones, no la suma: cada liquidación del mes publica el mismo `DIAS_ALTA_30` y
  sumarlos daría 60 o 90 días de alta.
- **CUIL**: de `CIF/NIF` y, si está vacío, de `Nº seguridad social`. Ver [[cuil-vive-en-cif-nif]].
- **Ingreso**: la `Fecha Alta` de la primera fase por fecha. **Egreso**: la `Fecha Baja` de la última
  fase, sólo si cae dentro del período.

**Nada se recalcula.** Si el reporte recalculara podría decir una cosa y el recibo otra, y no habría
manera de saber cuál tiene razón. Lo único que se recalcula son las contribuciones de CNT y FSR, y es
a propósito: la planilla original existe para eso —tomar la base, volver a aplicar la alícuota y
comparar—. Por eso esas columnas salen como **fórmulas de Excel** y al lado va lo que BC liquidó con
la diferencia. Una diferencia distinta de cero es un dato, no un error de la planilla.

**Los devengos no se declaran.** El reporte saltea toda línea con `Es Devengo`, así que la familia
`475x` (jubilación, ley 19032, obra social y cuota sindical sobre el SAC devengado) queda afuera sin
tener que excluir el tipo `DEVENGADOS` a mano: es una provisión y se aporta cuando el SAC se paga.

## El campo `Columna SICOSS`

Campo 36 de `Concepto Liquidación`, enum `Columna SICOSS Liq.` (50334). Dice **en qué casillero de la
declaración** entra el importe del concepto.

**Existe porque `Grupo Costo Laboral` no alcanza**, y eso se ve en los datos: el `6000` (jubilación
del empleado) y el `6010` (ley 19032 del empleado) están los dos en el grupo *Seguridad Social* con
tipo 5; y el `7000`, el `7060` y el `7070` están los tres en *Seguridad Social* con tipo 3. SICOSS los
declara en columnas separadas. El grupo dice de qué **rubro** es el costo; esto dice en qué
**columna** se informa, y son dos ejes distintos.

**El blanco y «No se declara» no son lo mismo**, y la diferencia es la que hace útil a la hoja de
Avisos: el blanco significa «nadie decidió todavía» y el reporte lo lista; «No se declara» significa
«alguien lo miró y no va», y el reporte lo saltea. Sin los dos valores la lista de avisos queda
dominada por los anticipos (83 M), los embargos y los gastos —que nunca van a tener columna porque
SICOSS no tiene dónde ponerlos— y los que sí faltan se vuelven invisibles entre ellos.

### Cómo se carga la primera vez

1. En *Conceptos Liquidación*, **Asignar Grupo Costo Laboral** (si quedan conceptos sin grupo). Los
   siete conceptos de la familia sindical —`8542` caja compensadora, `8543` fondo de desempleo,
   `8553` centro de capacitación, `8563`, `8573`, `8593`, `8603`— tenían el grupo en blanco y por eso
   la propuesta de columna no los reconocía como sindicales.
2. **Proponer Columna SICOSS**: completa lo que esté en blanco deduciéndolo del grupo, el tipo y la
   descripción. No pisa nada ya asignado ni toca los devengos.
3. Generar el reporte y **vaciar la hoja Avisos**: lo que corresponda declarar se mapea; a lo que no
   va se le pone *No se declara*. La lista viene **ordenada por importe descendente**, así que se
   arranca por lo grande.

En enero de 2026 la propuesta acierta los 29 conceptos de aportes y contribuciones y deja 27 en la
cola de triage, casi todos anticipos, gastos y descuentos de terceros.

> [!warning] El paso 2 no es opcional y el reporte lo exige
> Sin ningún concepto mapeado, la planilla saldría completa y prolija con las seis columnas de
> descuentos y las siete de contribuciones en **cero** y las bases bien: la clase de planilla que se
> archiva sin mirar porque parece correcta. Por eso el reporte **corta con error** si no hay un solo
> concepto con columna. Que falte el mapeo de *algunos* no corta: avisa.

## Parámetros que lee

Al último día del período y al nivel genérico. Los que no tengan valor salen en la hoja Avisos con su
nombre completo.

| Parámetro | Para qué | ¿Cargado? |
|---|---|---|
| `TOPE_SIPA`, `TOPE_SIPA_OS` | topes de las bases de aportes | sí |
| `DED_CONT_PATR` | detracción del art. 4 de la ley 27.541 | sí |
| `VALOR_ART_FIJO`, `VALOR_SVO` | ART fijo y SCVO por empleado | sí |
| `PCT_CONT_JUB`, `PCT_CONT_19032`, `PCT_ASIG_FAMI`, `PCT_FNE`, `PCT_CONT_23660`, `PCT_ART`, `PCT_TAR_DIF` | alícuotas patronales | sí |
| `PCT_OS` | aporte de obra social, base del reparto del FSR | sí |
| **`BASE_MIN_SIPA`** | piso de la base de contribuciones (la planilla de enero usaba 117.643,93) | **falta** |
| **`PCT_FSR`** | % del aporte y de la contribución de obra social que va al fondo (la planilla usaba 15: 0,45 de 3 y 0,90 de 6) | **falta** |
| **`PCT_DTO_814_<zona>`** | crédito del decreto 814 por zona: `_7` 1,45, `_29` 6,5, `_69` 7,3 | **falta** |

Los tres que faltan salen en cero y su columna sale en cero. No se siembran con un valor inventado:
un número inventado en una declaración fiscal es peor que un cero visible.

> [!warning] Los `PCT_` conviven en dos unidades y no está documentado en ningún otro lugar que las
> fórmulas
> `PCT_CONT_JUB` vale 0,1077 porque el `7000` lo multiplica directo; `PCT_JUB` vale 11 porque el
> `6000` hace `* PCT_JUB / 100`. `Cod110064.Puntos()` lleva la lista de los que son factor, sacada de
> leer esas fórmulas. Si una fórmula cambia de unidad hay que cambiarla también ahí, y el control que
> lo delata es la columna de diferencia contra lo liquidado, que se iría por un factor de cien. Ver
> [[parametros-somu-por-pesqueria]].

## Validado contra Meta4 (enero de 2026)

Se reprodujo la agregación del reporte en SQL y se comparó cada total contra el valor cacheado de la
fila de totales de `SI.COSS 01-2026.xlsx`. **Las columnas que los dos sistemas calculan cierran:**

| Columna | BC / Meta4 |
|---|---|
| `TOT_DEV` | 100,00 % |
| `IMPO_RET`, `IMPO_RET_OS` | 100,03 % y 100,02 % |
| `JUBILACION`, `LEY_19032`, `OBRA_SOCIAL`, `ADIC_OBS` | 100,00 % |
| `IMPUESTO` | 99,79 % |

Las que no cierran son **hallazgos del motor, no del reporte**, y por eso el reporte existe: la base
de ART al 58 %, la de contribuciones al 121 %, la de contribución de obra social al 81 %, la
detracción al 178 % y la zona cargada en 41 de 329. Ver [[Hallazgos abiertos]], ítems 17 a 20.

Dos diferencias más, de clasificación y no de base: **16,7 M están como remunerativos en BC y como no
remunerativos en Meta4** (`TOT_C_AP` 101 % contra `TOT_S_AP` 95 %, de signo opuesto y casi el mismo
monto), y el sindical queda al 94 %.

## Trampas que ya se pisaron

- **El Excel Buffer guarda el writer de .NET en la variable, no en la sesión.** Cada hoja se arma en
  su propio buffer; vaciar el primero con `DeleteAll` para reusarlo deja el writer sin instanciar y
  `SelectOrAddSheet` muere con «No se pudo crear el libro de Excel», con la primera hoja ya escrita.
  Ver [[excel-buffer-writer-en-la-variable]].
- **Las fórmulas van sin el `=` adelante y con punto decimal.** El writer pasa la cadena tal cual a
  Excel: un `Format` local escribe coma y rompe la fórmula en silencio. Los números se arman con
  `Num()`, que usa el formato XML.
- **Una celda de texto son 250 caracteres y `AddColumn` no trunca: tira error.** Y lo tira al escribir
  la celda, o sea con las cuatro hojas ya armadas y el libro perdido. Pasó con una nota de la hoja de
  Avisos de 251 caracteres. Hoy `Texto()` corta a `MaxStrLen("Cell Value as Text")` para que ninguna
  etiqueta nueva —ni una traducción más larga que el original— pueda repetirlo, y `EscribirNota()`
  parte las notas en celdas contiguas en vez de recortarlas.
- **`Valor Atributo Liq.` tiene tres campos en la PK**, con el valor padre en el medio. Un `Get` de
  dos argumentos compila y asigna el código al campo del padre. Ver [[get-con-menos-argumentos]].
- **El ID 110061 estaba ocupado por un codeunit de `test/`**, que viaja dentro de la misma app. Al
  buscar un ID libre hay que mirar `src/` **y** `test/`.

## Relacionado

- [[Comparador BC vs Meta4]] — la otra mitad de la corrida en paralelo, por empleado y concepto
- [[Acumuladores y fracciones]] — qué acumula cada base
- [[Parámetros y vigencias]]
- [[Atributos tipados]] — de dónde salen la zona y la obra social
- [[Hallazgos abiertos]]
