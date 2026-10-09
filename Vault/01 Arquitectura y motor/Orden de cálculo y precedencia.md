---
tipo: concepto
tags: [motor, orden-calculo, acumuladores, controles]
fuente: [src/Codeunits/Cod50014.MotorLiquidacion.al, src/Codeunits/Cod50067.ControlOrdenAcumuladores.al, src/Tables/Tab60007.ConceptoLiquidacion.al, src/Codeunits/Cod50015.EvaluadorFormula.al]
actualizado: 2026-10-04
---

# Orden de cálculo y precedencia

El motor recorre los conceptos **uno por uno** en el orden `(Orden Cálculo, Código)` (clave `K2` de
`Concepto Liquidación`). No hay grafo de dependencias: **el orden lo decide quien configura**. Lo que un
concepto lee tiene que estar ya calculado, y si no lo está, **lee cero o un subtotal, sin error**. Es el
error de configuración más silencioso del motor.

## Reglas del recorrido

- **Empates**: con el mismo `Orden Cálculo` corren por `Código` (orden de texto). Un empate sólo es problema si el código del que aporta cae **después** del que lee.
- Sólo se procesa la **fila ganadora** de cada código (la última `Vigencia Desde <= FechaRef`, no cerrada); su `Orden Cálculo` es el que vale. Si dos versiones tienen órdenes distintos, rige el de la versión en uso.
- Una **incidencia manual** hace que un concepto se recorra **en su orden** aunque no le aplique al empleado o al convenio (`SelectConceptosParaCalculo` no filtra por `Aplica A`). Antes se filtraba de entrada y la incidencia caía en `WriteIncidenciasRestantes`, que aporta al acumulador *al final*: mirando la liquidación el orden parecía correcto, pero el aporte llegaba tarde. Ver [[Incidencias en el motor]].
- Los acumuladores **no** se evalúan: sólo reciben.

## Las tres formas de leer un resultado ajeno

| Forma | Qué lee | ¿Depende del orden? |
|---|---|---|
| nombre de acumulador (`BASE_SS_TRAB`) | subtotal acumulado **hasta ese punto** | **Sí**: los aportes de orden mayor faltan |
| `#CÓDIGO` | `Ctx[CÓDIGO]` = importe ya calculado (con la incidencia que lo sobrescribió) | **Sí**: si no corrió aún, o su condición dio falso, vale 0 |
| `@CÓDIGO` | re-evalúa condición + fórmula del concepto en el contexto actual | **No** (pero ignora el par del concepto: [[arroba-ignora-el-par-del-concepto]]) |

Un `@` que a su vez lee un acumulador **hereda** el problema de orden del acumulador, y el análisis estático por texto no lo ve: para eso existe el control en runtime.

## Controles que existen

### 1. Estático: `Control Orden Acumuladores` (Cod50067, página 50014)

`Analizar(FechaRef, Buffer)` no liquida a nadie. Por **cada acumulador vigente**:

- **Aportes**: filas de `Fracción Acumulador` vigentes hacia ese acumulador; toma el **mayor** `Orden Cálculo` entre los conceptos aportantes en versión en uso (`BuscarAportes`).
- **Lecturas**: conceptos vigentes cuya **Fórmula o Condición** nombra al acumulador como token completo (`MencionaVariable`); toma el **menor** orden (`BuscarLecturas`).
- **Conflicto** (`LlegaTarde`): `orden aporte > orden lectura`, o igual con `código aporte > código lector`.
- Sin lecturas o sin aportes no hay conflicto. `Orden Sugerido = último aporte + 1`. Lista los aportes en conflicto (`Códigos en Conflicto`).

Corre cuando se toca `Orden Cálculo`, fórmulas o `Fracción Acumulador`. Límites: no ve `@` indirectos, y `MencionaVariable` sólo considera `A-Z`, `0-9`, `_` como caracteres de identificador (no `Ñ` ni acentos, a diferencia del evaluador).

### 2. En runtime: `RegistrarLecturasAcumuladores` / `VerificarOrdenAporte` (Cod50014)

- Después de cada concepto, del log `VAR:` se anota la **primera lectura** de cada acumulador (`FAcumLeidoEnOrden`, con el concepto lector). Se normaliza `@X`/`#X` a `X`.
- Al terminar de procesar cada **aportante**, si alguno de sus acumuladores ya fue leído en un orden menor (o igual con código posterior), se registra un **aporte tardío** (se acumula por acumulador, no por aporte, para no sepultar el aviso).
- Las incidencias escritas fuera del bucle se registran con orden `999999999`.
- Se **reinicia por pasada** y se ignora en las vueltas de grossing-up (`FIteracionGU`); queda vigente el aviso de la **pasada final**.
- Salida: `FAvisosOrden` (va al mensaje consolidado con `AcumularAdvertencias`) y entradas filtrables en el registro (`Categoría Registro Liq."::"Orden Cálculo"`). Ver [[Avisos y advertencias del cálculo]].

### 3. Precedencia de `#` y `@` (control por script)

La lección [[control-precedencia-formulas]] cuenta el script `precedencia.sql`, que extrae las referencias `#`/`@` de todas las fórmulas y compara `Orden Cálculo` (al 28/9/2026: 90 referencias, 4 mal ordenadas). **No está en `scripts/` del repo** (no encontrado el 4/10/2026): hoy no hay control en AL para `#`/`@` entre conceptos.

> [!warning] Un `MIN(base, TOPE)` puede tapar el error
> Una base incompleta pero muy por encima del tope no mueve el resultado; con un sueldo más bajo sí.
> No tomar como "validado" un concepto porque dio bien en un caso. Ver [[concepto-negativo-despues-de-sus-consumidores]].

## Cómo corregir un orden

1. **Mover el productor hacia atrás, no el consumidor hacia adelante**: mover al lector arrastra sus propios consumidores, y puede cruzarse con conceptos que alimentan los mismos acumuladores (aguinaldo sobre aguinaldo).
2. El **primer orden válido** del productor lo fija **su propia fórmula**: lo que él lee tiene que estar antes.
3. Antes de mover, listar (a) qué acumuladores alimenta, (b) qué conceptos los leen y en qué orden, (c) qué lee el concepto que se mueve. Las tres salen de `Fracción Acumulador` cruzada con `Concepto Liquidación`.
4. Mover **mirando los dos lados**: acercar un concepto a lo que lee lo acerca a sus consumidores.
5. Correr el control estático y recalcular un caso conocido.

## Guía histórica de rangos (sin verificar)

`GUIA-LIQUIDACION.md` propone rangos (`1–99` haberes base, `100–199` adicionales, …, `900–929` aportes, `999` redondeo). Es una **recomendación de la guía**; los órdenes reales viven en datos y varios conceptos están fuera de esos rangos (por ejemplo la absorción del art. 36 en 412 y el SAC devengado en 460-462, según las lecciones). No usarla como contrato.

## Relacionado

[[Acumuladores y fracciones]] · [[Ciclo de cálculo de una liquidación]] · [[acumuladores-orden-calculo]] · [[orden-calculo-del-lote]] (otro "orden": el de las **liquidaciones** dentro de un lote) · [[Tabla - Concepto Liquidación]]
