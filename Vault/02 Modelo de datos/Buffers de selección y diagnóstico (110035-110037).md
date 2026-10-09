---
tipo: referencia
tags: [modelo-de-datos, buffers, diagnostico, seleccion]
fuente: [src/Tables/Tab110035.TipoLiqSeleccionBuffer.al, src/Tables/Tab110036.DiagFuenteDatosBuffer.al, src/Tables/Tab110037.DiagOrdenAcumBuffer.al, src/Codeunits/Cod50067.ControlOrdenAcumuladores.al]
actualizado: 2026-10-04
---

# Buffers de selección y diagnóstico (110035-110037)

> [!warning] Declaradas persistentes, usadas como temporales
> A diferencia de los otros buffers, estas **tres tablas no declaran `TableType = Temporary`**: existen como tablas reales vacías, y su uso como buffer depende de que la página las abra con `SourceTableTemporary = true` o el código las declare `temporary`. Si alguien escribe en ellas sin `temporary`, las filas quedan **en la base** (con `DataClassification = SystemMetadata`). Se anotan acá y no como notas "Tabla - ..." porque no guardan datos de negocio.

## Tipo Liq. Selección Buffer (110035)
- **Para qué:** buffer genérico de selección con tilde. Lo usan las herramientas masivas de conceptos: *Conceptos por Tipo Liq.* (con Tipo Liquidación como lista) y *Conceptos por Convenio* (con Convenio Colectivo), para marcar varias filas sin persistir la selección. Páginas: `Conceptos Selección Sub` (50075), `Conceptos por Convenio` (50076), `Selector Tipos Liq.` (50176), `Tipo Liq. Selección Sub` (50196), `Convenio Selección Sub` (50198).
- **PK:** `Código` (Code[20]). **Campos:** `Descripción` (Text[100], para que entren las de Concepto), `Marcado` (Boolean).
- **Permisos:** sólo `LiqPescaAdmin` (RIMD). Las páginas se abren con `Record ... temporary`, por lo que no los necesitarían.

## Diag. Fuente Datos Buffer (110036)
- **Para qué (según su comentario):** herramienta de diagnóstico de Fuentes de Datos rotas (campo apuntado que ya no existe).
- **PK:** `("Nombre Variable","No. Línea")`. **Campos:** `Descripción`, `Id. Tabla`, `Nombre Tabla`, `Origen` (caption *Campo Roto*), `No. Campo` (*inexistente*).

> [!warning] Tabla sin uso
> Una búsqueda de `"Diag. Fuente Datos Buffer"` en `src/` sólo la encuentra en su propia definición y en un comentario de `Tab110037`: **ningún codeunit ni página la referencia**. Candidata a retirar, o a conectar si se retoma la herramienta (ver [[fuente-datos-apunta-por-numero]]: borrar un campo rompe la Fuente de Datos en runtime y el compilador no ve nada).

## Diag. Orden Acum. Buffer (110037)
- **Para qué:** control de orden de cálculo de acumuladores: `Cod50067 Control Orden Acumuladores` y página `Control Orden Acumuladores` (50014). Detecta acumuladores cuya primera lectura ocurre **antes** del último aporte (el importe sale bajo sin error). Ver [[acumuladores-orden-calculo]] y [[control-precedencia-formulas]].
- **PK:** `"Cód. Acumulador"` (Code[20]); clave `(Conflicto, Cód. Acumulador)`.
- **Campos:** `Orden Máx. Aporte` / `Concepto Máx. Aporte` (el aporte más tardío), `Orden Mín. Lectura` / `Concepto Mín. Lectura` (la primera lectura), `Aportes en Conflicto`, `Códigos en Conflicto` (*Conceptos a Reordenar*), `Conflicto`, `Orden Sugerido` (primer Orden Cálculo en que una lectura ve el acumulador completo: mover las lecturas acá **o** adelantar los aportes), `Cant. Aportes`, `Cant. Lecturas`.

## Relacionado
[[Buffers temporales - control y consulta de liquidaciones]] · [[Índice Modelo de datos (110xxx)]]
