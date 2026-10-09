---
tipo: referencia
tags: [dominio, cct, convenios, somu, parametros]
fuente: [CARGA_VALORES_TANGONEROS_2026.md, "Conceptos Liquidación.xlsx (snapshot 17/8/2026)", src/Tables/Tab60004.ConvenioColectivo.al, src/Codeunits/Cod50053.GestionFrancos.al]
actualizado: 2026-10-04
---

# Convenios del sector (CCT 729/15, 768/19, 175/75, 372/04, SOMU)

Qué **dicen** los convenios del sector y qué parte de eso **está implementada** como parámetros y fórmulas. La mecánica del par `(convenio, categoría)` y cómo se resuelve está en [[Convenios, categorías y par CCT]]; acá va el contenido de negocio. Los textos de los CCT no están en el repo (hay PDFs en la raíz: `CCT 768-2019 AACPyPP 2016.pdf`, `Marítimos…CCT 729_2015…pdf`, escalas SOMU 07-26).

| Código BC | CCT | Quién | Categorías | Familia |
|---|---|---|---|---|
| `729/15` | **SOMU** (marítimos, armadores pesqueros congeladores) | **marinería** embarcada | `MR00`…`MR09` | tripulante |
| `768/19` | AACPyPP (capitanes, pilotos, patrones de pesca) | oficiales **de cubierta** | `OF01` capitán, `OF03` 1er oficial de cubierta | tripulante |
| `175/75` | Centro de Jefes y Oficiales Maquinistas Navales, SICONARA | oficiales **de máquinas** | `OF02` jefe de máquinas, `OF04` 1er oficial de máquinas | tripulante |
| `372/04` | tierra (alimentación/STIA, `JO` y `CA` de Meta4) | personal de tierra | `CA##`, `JO##` | mensualizado / jornalizado |
| fuera de convenio | `FA` (tierra) y `FE` (embarcados españoles) | negociado por persona | `FE01`, `FA55`… | según el convenio |

> [!warning] `OF` no es un convenio: son dos
> En Meta4 "OF" agrupa a todos los oficiales; en BC se parte por **categoría**: `OF01`/`OF03` → 768/19 y `OF02`/`OF04` → 175/75. Al 23/9/2026 había 22 de 46 oficiales de enero en el convenio equivocado. No se unifican: difieren en cuota sindical (3,00% vs 2,50%), dólar producción (60% vs 90%) y 29 parámetros que sólo existen en 175/75. Ver [[convenio-of-depende-de-la-categoria]].

## CCT 729/15 — marinería SOMU

Artículos que el modelo ya refleja ([[cct-729-15-articulos]]):

- **Art. 30, remuneración asegurada en navegación**: base *marinero de planta* — **USD 1.600 flota potera, USD 1.500 flota congeladora arrastrera** —, escala convencional, **pagada en pesos al comprador BCRA**. Es el `NTO_GARANTIZADO` de Meta4 y el parámetro `SALARIO_ASEG_CAL/LAN`. Es un **piso sobre el paquete completo** (todos los ítems del Art. 29 salvo ropa de trabajo): por eso el concepto que lo materializa es *garantizado prorrateado − lo ya liquidado* ([[Producción y premios]]).
- **Art. 31, escala de básicos**: 100 / 85 / 80 / **75** / **70** sobre el primer pescador. Ver índice abajo.
- **Francos = básico × 2,4**; **órdenes = básico × 1,5**.
- **Art. 19 (pesca de calamar)** y **Art. 48 párr. 11 (vedas)**: el pago de las paradas biológicas. En poteros es el art. 19 (concepto **1075**, `DIAS_ART_19 × básico / 30`, sin coeficiente); en tangoneros el art. 48 (**1076**). El **sueldo a órdenes (1073)** descuenta `#DIAS_ART48`. La veda se carga como vigencia del atributo `ART48` del **buque**; el art. 48 sólo existe en 729/15 (ningún oficial lo cobró en la historia de Meta4). Ver [[sueldo-ordenes-por-convenio]], [[veda-como-atributo-del-buque]], [[art19-calamar-cuenta-corriente]].
- **Art. 23 vs 33**: el adicional es 60% del sueldo de navegación; oficiales cobran **1533** (art. 23) y marinería **1543** (art. 33) — [[adicional-art-23-vs-art-33]].
- **Art. 34, incentivo a la producción**: en **pesos** (1.500 marinero de planta tangonero, 1.400 potero, 2.000 arrastrero merlucero), no en USD. Presumiblemente el concepto **1547** *Incentivo a la producción* (`PRECIO_INCENT × DIAS_PROYECTO × COEF_TANGONERO` en el snapshot).
- **Art. 36, absorción** (horas extras absorbidas): 4415/4416.
- **Art. 32, antigüedad al 30/6**: `PCT_ANTIG_SOMU` usa `AÑOS_ANTIG_30JUN`; Meta4 no aplica el corte — ver [[antiguedad-suma-de-fases]].

### El índice SOMU (control sin fuente externa)

Todo SOMU sale de **un solo número base** (el básico del Marinero de Planta `MR08`) por el índice:

```text
MR00 100 · MR01 MR02 85 · MR03 MR06 MR07 MR09 80 · MR04 MR05 75 · MR08 70
puerto ×2,891 · francos ×2,4 · órdenes ×1,5 · adic. art. 23/33 ×0,6
```

Un valor cuyo cociente con `MR08` no dé 100/85/80/75/70 **está mal por dentro**. Ese control encontró el 17/9/2026 cinco `PRECIO_PUERTO_LAN` fuera de escala (corregidos con `scripts/CorregirEscalaPrecioPuertoLAN.sql`) y 18 `VALOR_CAL_*` con el cociente redondeado (`scripts/CorregirValoresCalamar2026.sql`). **Sólo vale para parámetros que derivan del básico**: los `PCT_*` no (18 celdas marcadas, 13 falsos positivos). Fuente autoritativa por categoría: `M4T_VAL_COEF_CAPECA_CATEGORIA`. Ver [[escala-somu-indice-70]].

### Parámetros SOMU

- Se **parten por pesquería**: `_LAN` (langostino, tangoneros) y `_CAL` (calamar, poteros) para `PRECIO_PUERTO`, `VALOR_FRANCO`, `PRECIO_ORDENES`, `PRECIO_NAV`. **No existe `PRECIO_PUERTO` a secas** (hay 45 valores huérfanos).
- **`PCT_DOLAR_PROD` no se parte**: uno por convenio — **60 (175/75), 78 (729/15), 90 (768/19)**.
- Los `PCT_*` conviven en **dos unidades** (porcentaje entero vs fracción): la fórmula debe dividir por 100 en unos y no en otros. 6 fórmulas de descuentos SAC/Vacaciones estaban mal por esto ([[parametros-somu-por-pesqueria]]).
- **Vigencias 2026**: 1/1, 1/2, 1/3, 1/5 y 1/6 (paritarias). Cargar sólo la de mayo deja atrás a las demás. Los valores de enero a mayo salen de `Valores Liquidación TANGONEROS 08-2025.xlsx`.

### Estado de la carga langostino/calamar (según `CARGA_VALORES_TANGONEROS_2026.md`, 17/9/2026)

- **Calamar completo y verificado** (30 celdas con vigencia 2026-01-01).
- **Langostino 729/15**: faltaban 32 de 40 valores (`BASICO`, `VALOR_FRANCO_LAN`, `PRECIO_ORDENES_LAN`, `PRECIO_INCENT`); base mayo 2026 `MR08 = 747.844`.
- **Oficiales 768/19 en langostino**: se parametrizan en 768/19; tablas de `BASICO` / puerto / franco / órdenes en el documento.
- **Una decisión abierta**: el valor base de puerto de mayo 2026 tiene tres números (Excel tangoneros 2.162.017; `PRECIO_PUERTO` pelado 2.162.552; `PRECIO_PUERTO_LAN` 2.265.375) y el `×2,891` del Excel está redondeado (2,8916). La carga del bloque SOMU langostino y el borrado de los 45 huérfanos **dependen de nómina**.
- **Pendiente tras la corrección de calamar**: 29 liquidaciones *Calculada* del 29/1/2026 usaron los valores viejos y hay que recalcularlas (las 74 Aprobadas son anteriores a la vigencia; ninguna Contabilizada). Estado a la fecha del documento: verificar contra la base.

> [!note] Producción fuera de convenio
> `VALOR_PLUS_PROD_ESP_FE01 = 41,91` (banda 6000-8000) es lo único verificado del bloque *fuera de convenio*; cierra con `105 × 0,77 × 0,9 × 0,8 × 0,72`. Factores de banda: **0,78 / 0,82 / 1,00** general y **0,73 / 0,77 / 1,00** patrón de pesca (tabla escalonada `<6000` / `6000-8000` / `>=8000`). La diferencia español/argentino es un **atributo del empleado** (reducción 2016: 0,23 vs 0,28 y si cobra adicional por producción).

## CCT 768/19 — oficiales de cubierta

([[cct-768-19-anexos]]) **Art. 20 y Anexo II**: la remuneración asegurada en navegación es **del convenio, por categoría** (Capitán índice 115 → 5.500 USD; 1er oficial 90 → 4.207,50; 2.º 72 → 3.443), idéntica en tangoneros y poteros; la empresa usa la **proporción exacta** (4.304 para OF03). **Art. 17 y Anexo V**: en puerto el oficial está de **guardia permanente**; el valor de puerto en tangoneros lo fija cada empresa (por eso no se audita contra el CCT); en poteros el CCT fija 3.500/2.500/2.500 y Arbumasa paga la tarifa de navegación (5.500/4.304). Producción: ver [[produccion-oficiales-poteros]] (coeficiente 0,90 = `PCT_DOLAR_PROD`).

## CCT 175/75 — oficiales de máquinas

([[cct-175-75-remuneracion-navegacion]]) Acuerdo vigente desde 1/2/2011: *Remuneración en Navegación* del jefe de máquinas (USD 3.300 en el acuerdo original) al **100% del tipo comprador**, proporcional a los días; **cláusula tercera**: absorbe todo lo devengado durante la marea **hasta su concurrencia**; **cláusulas quinta y sexta**: devengo de francos **0,4 + 0,12 = 0,52** por día navegado (= `PORC_FRANCO_DEV`). Valor de franco empresa vs convenio: USD 3.500/3.000 (jefe) y 2.975/2.550 (1er oficial) — concepto 2083. Lista de precios de oficiales: [[lista-precios-oficiales]].

## CCT 372/04 y tierra

Personal **mensualizado** (372/04 y `FA`) y **jornalizado** (`JO`): el **básico es por empleado**, no por categoría ([[basico-de-tierra-por-empleado]]) y cuatro de FA cobran en divisa por grossing-up ([[grossing-up-tapa-errores]]). Conceptos del convenio presentes en el catálogo: **3473** gastos de sepelio (art. 84), **3474** subsidio jubilación (art. 82), **3573** adicional vacaciones (art. 76, 10%); antigüedad de alimentación `entero(años)` ×1,5 de 10 a 19 y ×2 desde 20 (concepto **1055**, según [[escala-antiguedad-meta4]]). Sindicato y obra social **no** salen del par convenio+categoría: son atributos del empleado ([[sindicato-obra-social-atributos]]).

## Pendientes y discrepancias

- **Falta migrar el historial de puestos** (`M4T_HIST_PUESTOS`, según lecciones): el asegurado de marinería por categoría acierta sólo en 6 de 13 grupos ([[puesto-vs-categoria-cct]], [[a-cuenta-futuros-aumentos-puerto]]).
- Las 10 columnas "sin destino" (`ASEG MAREA CCT`, `ASEG PUERTO EMPRESA`, `FRANCOS EMPRESA`, `% REDUC 2008/2016`, …) se crean vacías (decisión 1.4) hasta que exista el concepto que las consuma.

Relacionadas: [[Valor del franco]], [[Rubros típicos de una liquidación embarcada]], [[Índice Dominio - marea y pagos]].
