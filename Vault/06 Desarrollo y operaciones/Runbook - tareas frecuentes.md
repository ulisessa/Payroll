---
tipo: proceso
tags: [desarrollo, runbook, checklist]
fuente: [app.json, .gitignore, .vscode/rad.json, scripts/GenerarIndiceVault.ps1]
actualizado: 2026-10-04
---

# Runbook - tareas frecuentes

Checklists cortos para lo que se repite. Los detalles están en las notas enlazadas.

## 1. Al cerrar un cambio en el proyecto AL

1. **Compilar** ([[Compilar con alc.exe]]): cero errores; sólo advertencias `AL0432`/`AL1029`/`AL1025`. Borrar `_compile_test.app`.
2. **Ejecutar lo que el compilador no valida**: expresiones `Format`, informes nuevos (abrirlos), `Get` con claves parciales, guardas con `ContainsKey`+`Get` ([[format-no-se-valida-al-compilar]], [[report-sin-layout-compila]], [[get-con-menos-argumentos]], [[al-sin-cortocircuito]]).
3. **Borrar `.vscode/rad.json`** sin preguntar; antes, mirar su `Removed` y avisar si trae objetos vivos ([[borrar-rad-json-tras-cada-cambio]], [[rad.json - peligro]]).
4. **No tocar `version` de `app.json`**. Si el cambio necesita republicarse para verse (control add-in, esquema), decirlo ([[Versionado de app.json]]).
5. **Permisos**: si se agregó una tabla/codeunit/página, sumarla a los tres permission sets ([[Permission sets de la extensión]]).
6. **Instalación**: si el cambio agrega una variable de sistema, un tipo de liquidación o un puntero de configuración, revisar que lo siembre Install/Upgrade ([[Install y Upgrade - qué siembra cada uno]], [[variable-sistema-hay-que-sembrarla]]).
7. **IDs**: objeto nuevo en 110000–149999 ([[Rangos de IDs y licencia]]).
8. **Actualizar el vault** en el mismo cambio: la nota del motor/tabla/proceso afectada; si costó tiempo, una lección en `07 Lecciones`. Regenerar índices: `pwsh scripts/GenerarIndiceVault.ps1`.
9. En la respuesta final: qué cambió, qué se compiló, qué requiere publicar y subir versión, qué quedó sin verificar.

## 2. Publicar una versión

1. Cambios cerrados (punto 1). 2. El usuario sube `version`. 3. *Publish & debug (mimir)* — **nunca RAD** ([[Publicar en BC (no usar RAD)]]). 4. Si el esquema cambió, `Sync-NAVApp -Mode ForceSync` + `Start-NAVAppDataUpgrade`. 5. Reiniciar el service tier si hubo SQL directo ([[sql-directo-deja-cache-rancia]]). 6. `scripts/EstaPublicadoElBuildNuevo.sql` para confirmar que corre lo nuevo.

## 3. Al comenzar una sesión

- `ls .vscode/rad.json` — ¿volvió? ([[rad.json - peligro]]).
- `git worktree list` — sin worktrees sobrantes ([[Compilar con alc.exe]]).
- `git status` — hay **mucho trabajo sin commit** (a 2026-10-04: último commit del 20/9/2026 y 76 archivos modificados, ~38 sin seguimiento y archivos agregados al índice que no deberían ir, ver [[Mapa de la raíz del repo]]).
- Leer `Vault/00 Inicio` y las lecciones del tema.

## 4. Una liquidación no cierra contra el recibo

1. `scripts/DiagnosticoLiquidacion.sql` (cabecera vs líneas vs detalle de variables). 2. Comparar `Fórmula Aplicada` contra `Fórmula` del concepto: separa «mal configurado» de «caché rancia» ([[sql-directo-deja-cache-rancia]]). 3. Mirar acumuladores y orden de cálculo ([[acumuladores-orden-calculo]], [[control-precedencia-formulas]]). 4. Si hay grossing-up, comparar bruto y base, **nunca el neto** ([[grossing-up-tapa-errores]]). 5. Método de comparación contra Meta4: `METODO_COMPARACION_META4_BC.md` (raíz).

## 5. El cálculo se volvió lento

1. ¿Filtros de Fuente Datos presentes? (`EstadoConfiguracion.sql`, bloque 3). 2. ¿Índices de más en `Línea Liquidación`? (`Indices_Linea_Liquidacion.sql`). 3. ¿Vista `VSIFT$PK`? ([[sift-sobre-clave-unica]]). 4. Perfilar. Ver [[Diagnóstico de rendimiento]].

## 6. Restauraron la base o se perdieron datos

[[Backup y restauración - cómo reaplicar]]: medir primero (`EstadoConfiguracion.sql`), reaplicar sólo lo que falte. `DiagnosticoTablasExtension.sql` para saber si hubo DROP.

## 7. Agregar una variable de sistema nueva

1. Agregar el `case` en `ComputeVariableSistema` (`Cod50016.ContextoLiquidacion.al`). 2. Agregar el `Agregar(...)` en `Gestión Variables Sistema.Sembrar()` (`Cod50077`). 3. Compilar, publicar completo; en desarrollo/RAD, acción **Sembrar**. 4. Probar una fórmula que la use. Ver [[variable-sistema-hay-que-sembrarla]], [[system-variables-conventions]].

## 8. Cambiar una fórmula de concepto

Con **vigencia nueva**, no editando la vigente (las liquidaciones ya calculadas deben reproducirse; [[conceptos-tres-vigencias]]). El editor de fórmulas valida sintaxis y existencia de variables. Verificar el orden de cálculo contra sus consumidores ([[concepto-negativo-despues-de-sus-consumidores]]).

## 9. Correr una migración o corrección por SQL

Mostrar antes lo que se va a escribir ([[previsualizar-antes-de-migrar]]); reversa guardada; reiniciar el service tier después; verificar con el diagnóstico correspondiente ([[Scripts SQL y PowerShell del repo]]).

## 10. Antes de renumerar o borrar una tabla

Exportar sus datos. Confirmar con `BuscarTablasDuplicadas.sql` que no queda huérfana ([[Rangos de IDs y licencia]]).

## 11. Si algo toca el editor de fórmulas (JS/CSS)

`node test/editorFormula.atributos.test.cjs` ([[Tests automatizados]]); republicar con versión nueva para que el navegador no use la caché.

## Anti-checklist (lo que NO hay que hacer)

- Publicar en RAD. - Subir la versión. - Editar `.g.xlf` a mano. - Reimportar el ConfigPackage completo. - Correr `UPDATE` por SQL sin reiniciar el service tier. - Borrar `Cod50082` (migración vacía con tag). - Confiar en que compilar prueba que el cálculo es igual.
