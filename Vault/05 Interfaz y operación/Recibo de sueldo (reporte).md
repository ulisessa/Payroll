---
tipo: pagina
tags: [reporte, recibo, rdlc, impresion]
fuente: [src/Reports/Rep50041.ReciboDeSueldo.al, src/Reports/Rep50041.ReciboDeSueldoV2.rdl, src/Reports/Rep50041.ReciboDeSueldo.rdl, src/Pages/Pag50117.FichaLiquidacion.al, src/Pages/Pag50100.ListaLiquidaciones.al, src/Pages/Pag110017.ArbolLiquidaciones.al]
actualizado: 2026-10-04
---

# Recibo de sueldo (reporte)

**Caption:** *Recibo de Sueldo* · **Informe 50041** · `UsageCategory = ReportsAndAnalysis` · `EnableExternalImages = true` (logo de la empresa).

## Cómo imprimirlo

| Desde | Acción | Alcance |
|---|---|---|
| **Ficha Liquidación** | *Imprimir Recibo* | La liquidación abierta |
| **Lista Liquidaciones** | *Imprimir Recibo* / *Imprimir Recibo (Selección)* | La fila actual / las marcadas |
| **Árbol de Liquidaciones** | *Imprimir Recibos* | Lo marcado: una liquidación o **todas las de un nodo** (mes, tipo, proyecto) |
| Role Center → Informes | *Recibo de Sueldo* | Lo que se filtre en la ventana |

Todas abren la **ventana de solicitud** (`RunModal` con diálogo), donde se puede cambiar el filtro por **No.**, **Cód. Período**, **No. Empleado** y **Estado**, el diseño y el destino (vista previa, PDF, impresora).

### Opción de la ventana

| Opción | Efecto |
|---|---|
| **Solo liquidaciones aprobadas/contabilizadas** | Filtra por estado Aprobada o Contabilizada |

> [!warning] Por defecto imprime también Borradores y Calculadas
> La opción **no viene tildada**: un recibo de una liquidación en *Borrador* sale igual, con los importes que tenga en ese momento. Para entregar recibos, **tildarla** o filtrar `Estado`.

## Diseños (layouts)

| Diseño | Archivo | Estado |
|---|---|---|
| **Recibo de Sueldo (Decreto)** | `Rep50041.ReciboDeSueldoV2.rdl` | **Predeterminado** (`DefaultRenderingLayout = RDLCLayoutDecretoV2`) |
| **Recibo de Sueldo** (clásico) | `Rep50041.ReciboDeSueldo.rdl` | Alternativo (hay además un `.rdlc` suelto en la carpeta que ningún layout referencia) |

Se cambia desde la ventana de solicitud o en *Selección de diseño de informe*. Un cambio de columnas del dataset exige tocar los dos RDL; ver [[report-sin-layout-compila]] por la trampa de los informes sin layout.

## Qué contiene cada diseño

El dataset es el mismo (cabecera, líneas, variables *Mostrar en Recibo*, detalle de Ganancias, composición de costo laboral); **cada diseño imprime una parte** (verificado contra los campos que usa cada `.rdl`):

| Bloque | **Decreto** (predeterminado) | **Clásico** |
|---|:-:|:-:|
| Empresa, domicilio, **C.U.I.T.** | Sí | Sí (+ logo) |
| Período (mes y año) | Sí | Sí (descripción y fechas desde/hasta) |
| N° legajo, apellido y nombre, **C.U.I.L**, fecha de ingreso, categoría | Sí | Sí |
| **Antigüedad** (años) | Sí | No |
| Convenio, tipo de liquidación, proyecto, fecha de liquidación, domicilio del empleado | **No** | Sí |
| **Composición salarial**: concepto (*Nombre Impresión*), cantidad y unidad (*Plural Liq.*: "9 DIAS", no "9 DIA"), base, importe; Remunerativo / No Remunerativo; descuentos; **Sueldo bruto / Sueldo neto** | Sí | Sí (HABERES / DESCUENTOS / SUBTOTALES / NETO A PAGAR) |
| **Variables "Mostrar en Recibo"** (*Parámetros utilizados en el cálculo*; p. ej. obra social) | **No se imprimen** | Sí |
| **Detalle Impuesto a las Ganancias** (deducciones familiares y pasos de las líneas con *Etiqueta Det. Ganancias*) | Sí | Sí (*Impuesto a las Ganancias 4ta. categoría*) |
| **Costo laboral**: *Detalle de la composición del costo laboral* y *Distribución de costos* por rubro (Sindical, Seg. Social, Obra Social, INSSJP, ART, SCVO), empleador vs. trabajador | Sí | No (sólo *Aportes patronales (informativo)*) |
| Lugar de pago, F. pago aportes, firma del empleador y del empleado | Sí | Firmas |

> [!warning] "Mostrar en Recibo" no imprime nada en el diseño predeterminado
> Marcar una Fuente de Datos con *Mostrar en Recibo* sólo se ve en el recibo **clásico**. El diseño *Decreto* no usa esas variables (el dataset las expone pero el RDL no las dibuja). Si se necesita imprimir la obra social o la veda en el Decreto, hay que agregar el bloque al RDL V2.

> [!note] Divergencia con la guía vieja
> La guía decía que la *Contribución Patronal* "no aparece en el recibo del empleado". En ambos diseños **sí aparece** (como *costo laboral* en el Decreto y como *aportes patronales (informativo)* en el clásico).

## Qué líneas se imprimen

- Sólo líneas con **Importe ≠ 0** **y** concepto con **Imprime en Recibo** activado. Un concepto en cero no sale, aunque exista la línea.
- Los acumuladores (tipo *Informativo*) no se imprimen aparte; sus importes se ven en la ficha.
- Cada línea suma a la columna según su **Tipo Concepto**: haberes (Remunerativo y No Remunerativo), descuentos (Descuento Empleado, Retención y Seguridad Social) y contribuciones (Contribución Patronal). El importe lleva su **signo**: un haber que corrige hacia abajo sale **negativo** en la columna de haberes.
- Los rubros de costo laboral se calculan sobre líneas con *Grupo Costo Laboral* distinto de blanco.

## Cosas para saber

> [!warning] CUIL posiblemente vacío
> El informe toma el CUIL de `Employee."Social Security No."`. Según [[cuil-vive-en-cif-nif]], en la base de producción ese campo está **vacío en los 4.810 empleados** y el CUIL vive en `CIF/NIF` (extensión Final Version). **Sin verificar** que el recibo salga con el CUIL en blanco; si lo hace, hay que apuntar el informe a ese campo o cargar el dato.

> [!warning] Antigüedad del recibo ≠ antigüedad del cálculo
> El recibo imprime `(Fecha Liquidación − Fecha de ingreso) div 365` años desde `Employment Date`. El cálculo usa la **suma de fases de alta** más la antigüedad reconocida ([[antiguedad-suma-de-fases]]). Pueden diferir (reingresos, tramos); es un dato impreso, no interviene en importes.

- El recibo **no está firmado digitalmente**: la firma es en papel. El diseño de firma digital es una propuesta ([[firma-recibos-digitales]]).
- Un recibo de **vacaciones** sólo lleva lo de vacaciones (no sueldo ni antigüedad) según el tipo de liquidación ([[recibo-vacaciones-paga-solo-vacaciones]]).
- **El anticipo no es un haber del recibo** ([[anticipo-no-es-haber-del-recibo]]).
- El PDF sale por el diálogo estándar de BC; no hay envío por mail ni portal del empleado (previsto en el ADR de firma, no construido).

## Relacionado

[[Crear, calcular, aprobar y reabrir liquidaciones]] · [[Árbol de liquidaciones]] · [[Reportes y procesos masivos]] · [[Tabla - Línea Liquidación]]

## Ver también

[[Tipos de concepto y su efecto en el recibo]] · [[Firma digital de recibos - decisión]] · [[Deducciones de Ganancias y familiares]]
