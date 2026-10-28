---
tipo: referencia
tags: [desarrollo, licencia, ids, objetos]
fuente: [app.json, "Objetos Custom - Numeración y Disponibilidad.xlsx"]
actualizado: 2026-10-04
---

# Rangos de IDs y licencia

Antes de elegir el ID de un objeto nuevo hay que respetar lo que la **licencia** habilita, que es menos que el `idRanges` de `app.json` (50000–149999). Origen: [[rangos-licencia-objetos]].

## Dónde está el detalle

`Objetos Custom - Numeración y Disponibilidad.xlsx` (raíz del repo; ignorado por git, está sólo en disco):

- Pestaña **«Rangos permitidos»**: lo que la licencia habilita por tipo.
- Pestaña **«Disponibilidad»**: lo que además está libre.

## Reglas que muerden

| Tipo | Rango habilitado (según la lección) |
|---|---|
| **Table** | **sólo hasta 60029** en el rango 5xxxx–6xxxx, más el rango cómodo 110000–149999 |
| Codeunit | 50000–50099 y 50500–50585, y 110000–149999 |
| Page | 50000–50842, varios bloques en 60000–70000, y 110000–149999 |
| Report | 50000–50101 y 110000–149999 |
| Enum, TableExtension, PageExtension, PermissionSet | **no los controla la licencia** — el ID es indiferente |

> [!danger] Síntoma engañoso
> Una tabla por encima de 60029 (fuera del 110000+) falla en runtime con *«los permisos actuales impidieron la acción. (Table NNNNN … Execute)»*. Parece un permission set y no lo es: el set puede incluir la tabla y el error aparece igual.

**Rango cómodo: 110000–149999**, habilitado y libre para Table, Page, Codeunit, Report, XMLport y Query. Todo objeto nuevo va ahí.

## Uso real al 2026-10-04 (medido sobre `src/` y `test/`)

| Tipo | Objetos | Mín | Máx | Observación |
|---|---|---|---|---|
| table | 72 | 50578 | 110061 | 3 en 5xxxx, 27 en 60000–60029, 42 en 110000+ |
| codeunit | 67 | 50014 | 110056 | 40 en 50000–50099 (incluye test 50021), 27 en 110000+ (incluye 6 tests) |
| page | 129 | 50013 | 110058 | 70 en 5xxxx, 59 en 110000+ |
| report | 7 | 50041 | 50047 | |
| enum | 32 | 50300 | 50333 | |
| tableextension | 7 | 52000 | 110033 | |
| pageextension | 10 | 50350 | 110032 | |
| permissionset | 3 | 50300 | 50302 | |

## El nombre del archivo NO manda: el ID declarado sí

Desfasajes hoy en el repo (archivo → ID declarado en el objeto):

| Archivo | ID declarado |
|---|---|
| `Cod50018.ProcesoLiqPorLotes.al` | 50050 |
| `Cod50060.CatalogoVariablesLiq.al` | 50064 |
| `Cod50061.GestionNovedadesLiq.al` | 50066 |
| `Cod50062.EstadoFechaFinUpgrade.al` | 50065 |
| `Pag50148.AlimentadoresAcumuladorSub.al` | 50157 |
| `PageExtensions/Pag-Ext50356.EmpFamilyExt.al` (pageextension) | 50357 |
| `Tab50575.PrestamoEmpleado.al` | 50579 |
| `Tab50576.CuotaPrestamo.al` | 50580 |

(El resto concuerda. Cuando el nombre de archivo y el ID difieren, **el ID del código es el que BC usa**; la lección de Tipo Liquidación —archivo `Tab60031` con `table 50578`— ya se renombró a `Tab50578.TipoLiquidacion.al`.) Para citar un objeto en otras notas, usar el **nombre** (`"Gestión Novedades Liq."`), no el número del archivo.

## Renumerar = riesgo de pérdida de datos

- Un cambio de ID dropea la tabla vieja con sus datos y crea la nueva vacía. Ver [[rad.json - peligro]].
- Los buffers **declarados `temporary`** no tienen tabla física con datos y se renumeran sin riesgo.
- Una tabla con datos: **exportar antes, reimportar después**.
- Ejemplo real: `Filtro Fuente Datos Liq.` figuraba en `Removed` como 60028 mientras el código declaraba 60029; la 60028 se fue con todo adentro. **Hoy el ID 60028 lo ocupa otra tabla** (`Detalle Acumulador Liq.`, `Tab60028.DetalleAcumuladorLiq.al`): reutilizar un ID previamente dado de baja es posible pero conviene confirmar que no queda una tabla vieja con otro contenido en la base (`scripts/BuscarTablasDuplicadas.sql`, [[Scripts SQL y PowerShell del repo]]).

## Cómo elegir el próximo ID

1. Buscar el máximo en uso del tipo: `grep -rhoE "^table [0-9]+" src | sort -k2 -n | tail -1` (idem `codeunit`, `page`).
2. Tomar el siguiente en 110000+ (hay saltos: no existen, p. ej., las tablas 110015–110033).
3. Para tablas sólo-buffer, declarar `TableType = Temporary` / `SourceTableTemporary`; el ID da igual.
4. Confirmar que no colisiona con `Removed` de un `rad.json` viejo ([[rad.json - peligro]]).
