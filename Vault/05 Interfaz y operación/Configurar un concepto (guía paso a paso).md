---
tipo: guia
tags: [configuracion, conceptos, formulas, acumuladores, vigencias]
fuente: [src/Pages/Pag50145.ConceptoLiqCard.al, src/Pages/Pag50107.ConceptosLiquidacion.al, src/Pages/Pag50144.FraccionAcumuladorSub.al, src/Pages/Pag50147.ConceptoCCTSub.al, src/Tables/Tab60007.ConceptoLiquidacion.al, src/Codeunits/Cod50014.MotorLiquidacion.al, src/ControlAddIns/EditorFormula/editorFormula.js]
actualizado: 2026-10-04
---

# Configurar un concepto (guía paso a paso)

Un **concepto** es un renglón del recibo: qué es (tipo), cómo se calcula (fórmula + condición), cuándo corre (orden, tipo de liquidación, convenio) y a qué bases aporta (acumuladores). Se configura **desde la ficha** (*Conceptos* → abrir uno o *Nuevo*, Pag50145). Tabla: [[Tabla - Concepto Liquidación]].

> [!important] Tres líneas de tiempo independientes
> Un concepto no se versiona como una unidad: **la fórmula/flags**, la **distribución en acumuladores** y los **convenios aplicables** tienen cada uno su `Vigencia Desde` y el motor resuelve cada uno por separado ([[conceptos-tres-vigencias]]). Crear una *Nueva Vigencia* del concepto **no** arrastra las otras dos (y eso es correcto: el motor sigue usando la anterior). Las subpáginas de la ficha listan **todas** las vigencias.

## Pasos

### 1. Alta

*Conceptos* → **Nuevo**, o partir de otro con **Copiar como...** (copia fórmula, distribución de **todas** las vigencias y convenios aplicables). El **código no se puede renombrar** ("las fórmulas que lo nombran pasarían a resolver CERO sin dar error"): para cambiarlo, copiar como el nuevo código, corregir las fórmulas que nombran el viejo y dar de baja el viejo.

### 2. Grupo *General*

| Campo (caption) | Qué cargar |
|---|---|
| **Código** + **Vigencia Desde** | Clave. Una versión por fecha |
| **Vigencia Hasta** | Vacío = abierta. Cargarla **da de baja** el concepto desde ese día sin tocar lo liquidado |
| **Descripción**, **Nombre Impresión** | Nombre interno y texto del recibo |
| **Variable Cantidad**, **Unidad Cantidad** | Lo que se imprime como cantidad (nombre de variable —`DIAS_VAC`— o expresión). *No cambia lo que se paga* |
| **Variable Base** | Lo que se imprime como "base de cálculo". *No cambia lo que se paga* |
| **Tipo Concepto** | Ver tabla de tipos abajo |
| **Grupo Costo Laboral** | Para SS y contribuciones: rubro (Sindical, SS, Obra Social, INSSJP, ART, SCVO) del bloque de costo laboral del recibo |
| **Aplica A** | *Todos / Tripulante / Mensualizado / Jornalizado* (sale del convenio del empleado) |
| **Convenio/Categoría a usar** | Dos opciones: **El del empleado (atributos)** (predeterminado: su encuadre) o **El puesto del empleado (atributos)** (el par del *puesto*: la categoría paga el sueldo y el puesto paga la producción, [[puesto-vs-categoria-cct]]). El tooltip de la página todavía habla de "la asignación al proyecto": ese valor ya no existe, `Personal Proyecto` no guarda convenio ni categoría |
| **Aplica a Tipo Liq.** | Se edita con el botón `…`: abre *Selector Tipos Liq.* **Vacío = todos los tipos** |
| **Orden Cálculo** | De menor a mayor. Ver paso 6 |
| **Es Acumulador** | El concepto no tiene fórmula: recibe aportes de otros |
| **Etiqueta Det. Ganancias** | Si se completa, el resultado aparece como un paso en el detalle de Ganancias del recibo |
| **Imprime en Recibo** | Desactivado = no sale en el recibo aunque tenga importe |
| **Es Devengo** | Se calcula pero **no suma a los totales ni al neto** |
| **Rol Franco**, **Parámetro del valor**, **Atributo que afina el precio**, **Divisor del valor** | Sólo para devengo/consumo de francos ([[francos-fifo-ledger]], [[valor-franco-por-terna]]) |
| **Detalle de atributo** | Muestra al lado del importe el valor de un atributo (el gremio, la obra social). No interviene en el cálculo |

> [!warning] "Activo" ya no existe
> El campo `Activo` figura como *"Activo (sin efecto)"* y **la ficha no lo muestra**. Un concepto se da de baja con **Vigencia Hasta**. Las versiones viejas que quedaron en `Activo = false` **ahora calculan**: revisarlas en *Versiones Inactivas a Revisar* antes de recalcular.

**Cómo suma cada tipo** (verificado en `UpdateTotals`): *Haber Remunerativo* y *No Remunerativo* → **Total Haberes**; *Descuento Empleado*, *Retención* y *Seguridad Social* → **Total Descuentos**; *Contribución Patronal* → **Total Contribuciones** (no entra al neto); *Informativo* (acumuladores y conceptos de control) → no suma a nada. **Neto = Haberes − Descuentos.**

### 3. Fórmula y condición

El editor (add-in con resaltado e IntelliSense) tiene dos cajas. Al salir de cada una, el sistema **formatea** el texto (sangría y saltos de línea) y valida: error de sintaxis → no deja guardar; **variable desconocida** → mensaje. Reglas del evaluador que muerden:

- **Decimales con punto** (`0.11`); la **coma separa argumentos**: `IF(cond, 0, otro)`. La guía vieja escribía `0,11`: eso hoy se parte en dos argumentos y falla.
- Las **funciones no distinguen mayúsculas; las variables sí**: `BASICO` ≠ `basico`. Funciones: `ABS, ROUND, MIN, MAX, REDONDEAR, PISO, TECHO, IF, IFZERO, DIV, TRAMO, CASE`; operadores `AND OR NOT = <> < > <= >=`.
- **Referenciar otro concepto:** `@1003` re-evalúa su fórmula **con el par convenio/categoría del que llama**; `#1003` lee el importe **ya calculado** de la línea (su orden tiene que ser menor). Un código pelado (`1003 * 0,5`, como decía la guía vieja) ya no es una referencia. → [[arroba-ignora-el-par-del-concepto]], [[control-precedencia-formulas]]
- **Condición**: expresión booleana; **vacía = el concepto siempre aplica**. Falsa = no genera línea.
- Atributos de lista se comparan por código: `CONVENIO = '729/15'` ([[atributo-comparar-por-codigo]]).

Probar antes de guardar: **Asistente de Formulación** → [[Asistente de fórmulas y detalle del cálculo]]. *Aplicar y Cerrar* en el asistente vuelca los cambios a la ficha; cerrarlo de otra forma no modifica nada.

### 4. Distribución en acumuladores

Subpágina **Distribución en acumuladores**: por cada acumulador destino, **Vigencia Desde**, **Cód. Acumulador**, **% Importe** e **Invertir Signo**. La columna **Vigente** marca la fila que el motor usaría hoy. Reglas: un 100% remunerativo va a `REMUNERATIVO_BRUTO`, `BASE_SS`, `BASE_OS`, `BASE_SINDICAL`, `BASE_LRT`, `BASE_IG4`, `BASE_SAC` (+ las específicas); un no remunerativo **no** va a `BASE_SS` ni `BASE_IG4`. Para **restar** de una base, tildar *Invertir Signo* **en esa fila** (el importe se guarda siempre en valor absoluto: el signo vive en la fracción, por acumulador).

### 5. Convenios aplicables

Subpágina **Convenios Aplicables**: **Vigencia Desde**, **Cód. Convenio**, **Cód. Categoría** (opcional), **Excluye**. **Sin filas = aplica a todos los convenios.** *Excluye* da vuelta la fila ("a todos menos a este") y **una exclusión gana sobre cualquier inclusión**. Para muchos conceptos a la vez: *Convenios por Concepto* o *Conceptos por Convenio*; para tipos: *Conceptos por Tipo Liq.* ([[Mapa de páginas por menú]]).

> [!danger] Vacío es comodín
> Un concepto sin tipos de liquidación o sin convenios **no es "ninguno": es "todos"**. 185 conceptos sin tipo duplicaron liquidaciones enteras ([[vacio-en-tipos-liq-aplicables-es-comodin]]). Un `Tipos Liq. Aplicables` en blanco más un tipo con "Sólo conceptos declarados" tildado es lo que evita que un tipo recalcule todo el recibo.

### 6. Orden de cálculo

El motor evalúa de menor a mayor `Orden Cálculo`, y un acumulador se va sumando **a medida que corren los conceptos**: quien lo lee ve el subtotal hasta su posición. Regla única: **todo concepto que aporta a un acumulador debe tener orden menor que el que lo lee**. No hay rangos impuestos por el sistema; dejar huecos (10, 20, 30…) para intercalar. Si un importe sale **bajo y sin error**, casi siempre es esto ([[acumuladores-orden-calculo]]) → **Control de Orden de Cálculo**.

### 7. Cambiar un concepto que ya se usó

| Quiero… | Hago… |
|---|---|
| Cambiar la fórmula desde una fecha | **Nueva Vigencia** (pide la fecha). La anterior se **cierra sola el día previo** y se conserva para recalcular períodos viejos |
| Dar de baja | Cargar **Vigencia Hasta** (se rechaza si una liquidación no-Borrador usó esa versión después de esa fecha) |
| Ver quién tocó qué | **Historial de Cambios** (texto anterior y nuevo; *Restaurar*) |
| Ver las versiones | **Vigencias del Concepto** (por fecha, no por quién editó) |
| Borrar | Sólo si **ninguna fórmula, variable de sistema, novedad sin liquidar, préstamo ni Config. RR.HH.** lo nombra, y si ninguna liquidación usó esa versión |

No se pueden solapar vigencias; un hueco entre versiones **sí** es válido (cerrar en marzo y reabrir en julio).

## Verificación

1. *Fórmulas con errores* no lista el concepto. 2. *Control de Orden de Cálculo* sin conflictos. 3. Calcular una liquidación de prueba y abrir la línea → *Detalle del cálculo* ([[Asistente de fórmulas y detalle del cálculo]]). 4. En la línea, **Fuente Parámetros** y **Vigencias Distribución** dicen qué versión se usó.

Ejemplos: [[Ejemplos completos de conceptos]]. Problemas típicos: [[Resolución de problemas frecuentes]].

## Ver también

[[Tipos de concepto y su efecto en el recibo]] · [[Acumuladores y fracciones]] · [[Versionado de conceptos y fórmulas]] · [[Aplicabilidad de un concepto a una liquidación]] · [[Evaluador de fórmulas - sintaxis]] · [[Evaluador de fórmulas - funciones]] · [[Orden de cálculo y precedencia]] · [[Editor de fórmulas]] · [[Par convenio-categoría por concepto]] · [[Tabla - Fracción Acumulador]] · [[Tabla - Concepto CCT Vigente]]
