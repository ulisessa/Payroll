---
tipo: referencia
tags: [desarrollo, permisos, seguridad]
fuente: [src/PermissionSets/PermSet50300.LiqPescaAdmin.al, src/PermissionSets/PermSet50301.LiqPescaLiquidador.al, src/PermissionSets/PermSet50302.LiqPescaLectura.al, src/Profiles/Prof50300.PayrollManager.al, src/Profiles/Prof50301.DirectorTI.al]
actualizado: 2026-10-04
---

# Permission sets de la extensión

Tres permission sets asignables, cada uno en un archivo. El detalle de uso por rol (manual de usuario) va en `05 Interfaz y operación`; acá está lo que importa a quien agrega objetos.

| ID | Nombre del objeto | Caption | Qué puede |
|---|---|---|---|
| 50300 | `Liq. Pesca - Admin` | Liq. Pesca - Admin | Todo: configuración maestra (CCT, conceptos, parámetros, escalas, fuentes, variables, Ganancias) + operación. Único que puede ejecutar `Gestión Variables Sistema`, `Espejo Atributos Liq.` y `Migracion Fechas ImpFam` |
| 50301 | `Liq.Pesca-Liquidador` (sin espacio tras el punto) | Liq. Pesca - Liquidador | Calcula y gestiona liquidaciones de un período; **no** modifica configuración maestra (la lee) |
| 50302 | `Liq. Pesca - Lectura` | Liq. Pesca - Lectura | Sólo lectura de todo, más `RIMD` sobre tablas temporales (el rol de lectura no podría ni abrir las vistas si no) |

Todos son `Assignable = true` y cubren **tabledata**, **table = X**, **codeunit/page/report = X**.

## Dependencias de roles estándar

Cada archivo repite el aviso: el set cubre sólo el módulo Payroll; para acceso completo hay que asignar además un rol estándar de BC:

- Employee / HR Setup → `D365 HUMAN RES, FULL` o equivalente.
- Job (Marea) → `D365 PROJECT MGMT` o equivalente.

`Human Resources Setup` va con `RM` en Admin y `R` en los otros dos.

## Profiles

`Prof50300.PayrollManager.al` define el perfil `PAYROLL-MANAGER` (Role Center `Payroll Role Center`, página 50149; `Promoted = true`). `Prof50301.DirectorTI.al` define `DIRECTOR-TI` sobre `Administrator Role Center`; su propio comentario dice que sólo hace falta si «Director de TI» no existe en otra extensión (la navegación de payroll ya la agrega `PagExt50352.ITManagerRCPayrollExt.al`) y que, si existe, hay que borrarlo. **Sin verificar** si hoy existe ese perfil en otra extensión del grupo.

## Regla para objetos nuevos

Todo objeto nuevo que lleve datos o se invoque desde la UI se suma **a los tres sets** (con el nivel que corresponda: `RIMD` en Admin, `R` en configuración para Liquidador/Lectura). Un objeto que falta produce errores de permisos «(Table NNNNN … Execute)» que **se confunden con el límite de licencia** ([[Rangos de IDs y licencia]]); descartar primero la licencia mirando el ID.

## Tablas que hoy NO están en ningún set (al 2026-10-04)

Cruce de `table NNNNN "X"` en `src/Tables/` contra `tabledata "X"` en los tres archivos. Faltan (con datos persistentes):

| Tabla | Archivo |
|---|---|
| `Filtro Fuente Datos Liq.` | `Tab60029.FiltroFuenteDatosLiq.al` |
| `Estado Tipo Liq.` | `Tab110059.EstadoTipoLiq.al` |
| `Tramo Cobertura Liq.` | `Tab110061.TramoCoberturaLiq.al` |
| `Préstamo Empleado` / `Cuota Préstamo` | `Tab50575`/`Tab50576` |
| `Importación SIRADIG` / `Cue SIRADIG` | `Tab60026`/`Tab60027` |
| `Hist. Liq. Meta4` / `Valor Hist. Meta4` / `Columna Hist. Meta4` | `Tab110054`/`110056`/`110055` |
| `Stg Valor Dim NAV` | `Tab110047` |
| `Diag. Fuente Datos Buffer` / `Diag. Orden Acum. Buffer` | `Tab110036`/`110037` (no son temporales) |

Además `Tipo Liq. Selección Buffer` falta en Liquidador y Lectura (sí está en Admin). Las tablas `temporary` que faltan (`Comp. Meta4 Buffer`, `Paso Cálculo Línea`, `Mes Filtro Liq.`, `Lote Franco Buffer Liq.`, `Variable Liq. Test`…) pueden no necesitar permiso explícito, pero Lectura da `RIMD` a otras por la misma razón: **sin verificar** si el cliente falla sin ellas.

> [!warning] Probable deuda de permisos
> Un usuario sin `SUPER` (Liquidador o Lectura) probablemente no pueda abrir `Filtro Fuente Datos Liq.`, los préstamos, SIRADIG ni el comparador Meta4. No se probó con un usuario real; el cruce es estático. Revisar al incorporar usuarios no administradores.

## Cómo repetir el cruce

```bash
grep -h "^table " src/Tables/*.al | sed -E 's/^table [0-9]+ //' | sort -u > t.txt
grep -oE 'tabledata "[^"]+"' src/PermissionSets/PermSet50300.LiqPescaAdmin.al | sed 's/tabledata //' | sort -u > p.txt
comm -23 t.txt p.txt
```

## Ver también

[[Convenciones de código AL del proyecto]] · [[Install y Upgrade - qué siembra cada uno]] · [[Setup del entorno de desarrollo]]
