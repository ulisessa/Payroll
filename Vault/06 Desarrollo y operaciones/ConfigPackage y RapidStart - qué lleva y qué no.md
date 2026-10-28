---
tipo: referencia
tags: [desarrollo, configpackage, rapidstart, configuracion]
fuente: [gen_config.ps1, gen_config.py, gen_rapidstart.ps1, ConfigPackage_Payroll.xml, ConfigPackage_Payroll.rapidstart, ConfigPackage_Payroll.xlsx, PackageLIQUIDACION.rapidstart, src/Tables/Tab60007.ConceptoLiquidacion.al]
actualizado: 2026-10-04
---

# ConfigPackage y RapidStart - qué lleva y qué no

> [!danger] El paquete NO es un backup
> Aplicar un paquete de configuración sobre una base **no restaura** la configuración completa: cubre pocas tablas y sólo un subconjunto de sus campos. Toda fila que el *apply* **crea** (en vez de modificar) queda en el valor cero de cada campo que el paquete no lleva. Para restaurar de verdad hace falta además la lista de [[Backup y restauración - cómo reaplicar]]. Lección: [[configpackage-campos-faltantes]].

## Los tres generadores (raíz del repo)

| Archivo | Qué genera | Última modificación | Estado |
|---|---|---|---|
| `gen_config.ps1` (670 líneas) | `ConfigPackage_Payroll.xlsx`, vía **Excel COM** (hay que tener Excel). Hojas: INSTRUCCIONES + una por tabla | 2026-09-07 | **Vigente.** Escribe `Tipos Liq. Aplicables` (códigos, campo 22) e `Imprime en Recibo` (19) |
| `gen_rapidstart.ps1` (570 líneas) | `ConfigPackage_Payroll.xml` y `ConfigPackage_Payroll.rapidstart` (un ZIP con `PAYROLL-25.xml` adentro) escritos directo sin Excel | 2026-05-22 | **Atrasado.** Sigue escribiendo el campo 14 `Aplica Tipo Liq.` (obsoleto) con enteros de enum (`$TIPO_LIQ_INT`) |
| `gen_config.py` (461 líneas) | Lo mismo que el `.ps1` con openpyxl; vigencia base `01/01/2025` | 2026-05-17 | **Obsoleto**: sin tipo `IN` (Informativo), sin mapa de códigos de tipo de liquidación. No usar (además no hay Python instalado) |

Los artefactos `ConfigPackage_Payroll.xml` (845 KB), `.rapidstart` (25 KB) y `.xlsx` están **versionados** y fechados 2026-05-22; son anteriores a las correcciones del 14/8 y 7/9 en `gen_config.ps1`. El `.xlsx` del repo (2026-05-22 11:59) no incorpora el campo 22. **Regenerarlos antes de usarlos.**

### Cómo se usa
- `.xlsx`: Paquetes de configuración → crear (p. ej. `PAYROLL-25`) → *Importar desde Excel* → validar cada tabla → aplicar. Orden recomendado (hoja INSTRUCCIONES): Convenio Colectivo → Categoría CCT → Parámetro + Parámetro Vigente → Variable Sistema Liq. → Concepto Liquidación (incluye acumuladores) → Concepto CCT Vigente → Fracción Acumulador.
- `.rapidstart` / `.xml`: *Importar paquete*; si falla el `.rapidstart`, probar el `.xml`.
- `gen_config.ps1` ya **corta** la generación si un tipo de liquidación de la tabla de conceptos no está en `$TIPO_LIQ_MAP` (antes se escribía tal cual y el concepto se colaba en todas las liquidaciones sin avisar).

## Qué tablas cubre el generador

10 tablas (ids 60004, 60006, 60007, 60008, 60013, 60014, 60016, 60017, 60018, 60019): Convenio Colectivo, Categoría CCT, Concepto Liquidación, Parámetro Vigente, Tabla Escalonada (+ Det.), Parámetro, Fracción Acumulador, Variable Sistema Liq., Concepto CCT Vigente.

**No cubre en absoluto:** Cód. Estado Empleado (60003), Estado Empleado (60000), **Filtro Fuente Datos Liq. (60029)**, **Fuente Datos Liquidación (60015)**, Tipo Liquidación, Estado Tipo Liq., Novedades, Préstamos, Tipos/Valores/Atributos de entidad, Períodos, Config. RRHH. Todo eso hay que recargarlo por otras vías (SQL en `scripts/`, ver [[Scripts SQL y PowerShell del repo]]).

## Campos que NO viajan

Auditoría original (2026-08-14, cruzando `configpackagefield` del XML contra los `field()` no-FlowField):

| Tabla | Campos que NO viajan |
|---|---|
| 60007 Concepto Liquidación | 9 Grupo Costo Laboral · 12 Vigencia Hasta · 16 Variable Cantidad · 17 Unidad Cantidad · 18 Etiqueta Det. Ganancias · 19 Imprime en Recibo · 20 Es Devengo · 21 Variable Base · 22 Tipos Liq. Aplicables · 23 Rol Franco |
| 60008 Parámetro Vigente | 8 No. Empleado · 10 Cód. Parámetro Base · 11 Cód. Convenio · 12 Cód. Categoría · 13 Nivel |
| 60018 Variable Sistema Liq. | 5 Mostrar en Recibo · 6 Etiqueta Recibo · 7 Etiqueta Det. Ganancias · 8 Orden Det. Ganancias · 9 Cód. Acumulador · 10 Tipo Concepto |
| 60017 Fracción Acumulador | **6 Invertir Signo** |
| 60019 Concepto CCT Vigente | 4 Cód. Categoría |
| 60016 Parámetro | 7 Antigüedad Máxima Vigencia |
| 60004 Convenio Colectivo | 5 Cámara |

Los que más duelen:

1. **Invertir Signo** — una fracción que restaba pasa a sumar y la base de Ganancias sale inflada.
2. Los cinco de **Parámetro Vigente** — el mecanismo de sufijos `BASICO_<CONVENIO>_<CATEGORÍA>` no viaja.
3. **Cód. Acumulador / Tipo Concepto** de Variable Sistema — sin ellos `YTD_ACUM`/`YTD_LINEAS` no se restauran.

### Actualización del 2026-10-04 sobre Concepto Liquidación

Hoy la tabla tiene **28 campos** (no 22). El `gen_config.ps1` vigente escribe 13 columnas (campos 1–8, 10, 11, 13, 19 y 22). **Siguen sin viajar:** 9 Grupo Costo Laboral, 12 Vigencia Hasta, 15 Vigencia CCT Más Reciente, 16 Variable Cantidad, 17 Unidad Cantidad, 18 Etiqueta Det. Ganancias, 20 Es Devengo, 21 Variable Base, 23 Rol Franco, **24 Par CCT a Usar**, **25 Cód. Tipo Atributo Detalle**, **26 Cód. Parámetro Valor**, **27 Cód. Tipo Atributo Precio**, **28 Divisor Valor**. Los últimos cinco son posteriores a la auditoría y mueven el valor de un concepto (par de puesto, precio por atributo): una fila recreada por el paquete **pierde cómo se valúa**. Ver [[conceptos-tres-vigencias]] y [[arroba-ignora-el-par-del-concepto]].

> [!warning] Sin verificar
> No se re-auditaron las otras seis tablas contra el código de hoy; la tabla de arriba es la del 14/8. Repetir el cruce antes de confiar en el paquete.

## `PackageLIQUIDACION.rapidstart`

Es otra cosa: un **export completo desde BC** del paquete `LIQUIDACION` (no generado por script), fechado 2026-08-14 23:17. Pesa ~10 MB comprimido (gzip) y **177 MB descomprimido** (XML UTF-16). Lleva tablas base (entre ellas Job 167, Dimension Value 349 y Employee 5200; ids 13, 91, 167, 349, 1501–1541, 5200, 5205, 5218, 5714, 8610–8631) y casi toda la configuración propia: ids 50578–50580, 60000–60035 (con huecos) y 110000–110006. Contiene **datos de empleados y proyectos**: no pertenece a un repo.

> [!warning] Ojo con el commit
> Está en el índice de git como archivo agregado (`A`, todavía sin commit) junto con `Oracle.ManagedDataAccess.dll`, `PerformanceProfile_Session9.alcpuprofile`, `recibos_2026-01_extraidos.tsv` y un `.msg`. Ver [[Mapa de la raíz del repo]].

## El flag que borra datos

En la ficha del paquete, la columna **«Eliminar los registros de tablas antes del procesamiento»**: si está tildada para una tabla, cada importación la **vacía antes de aplicar**; si el apply no llega a esa tabla, las filas quedan borradas **sin error**. Es la hipótesis viva de por qué desaparecieron los 76 filtros de `Filtro Fuente Datos Liq.` (60029) en septiembre de 2026. Regla: **no reimportar el paquete completo sobre tablas que ya están bien; importar sólo la que falte.**

## Checklist después de cualquier apply

1. Fracciones: re-marcar **Invertir Signo** (el paso 4 de `scripts/CargarFraccionesMeta4.sql` lista candidatos).
2. Parámetro Vigente: reponer los cinco campos de sufijos.
3. Variable Sistema Liq.: reponer `Cód. Acumulador`, `Tipo Concepto`, etiquetas ([[variable-sistema-hay-que-sembrarla]]).
4. Concepto: Vigencia Hasta, Grupo Costo Laboral, `Par CCT a Usar`, `Cód. Parámetro Valor`, `Divisor Valor`, `Rol Franco`.
5. Convenio Colectivo: Cámara.
6. Correr `scripts/EstadoConfiguracion.sql` ([[Scripts SQL y PowerShell del repo]]).
7. Reiniciar el service tier ([[sql-directo-deja-cache-rancia]]).

Ver también [[rad.json - peligro]] (por qué hubo que restaurar) y [[avoid-tables-principle]].
