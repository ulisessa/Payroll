# Liquidación Sueldos Pesca (BC 25.2, AL)

Extensión AL OnPrem de Grupo Arbumasa: motor **paramétrico** de liquidación de sueldos para la industria pesquera argentina (namespace `UAS.Payroll`). Reemplaza a Meta4. Responder siempre en **español**.

## El conocimiento vive en el vault de Obsidian: `Vault/`

Es el manual integral y la memoria del proyecto (~330 notas). **Antes de tocar una zona, leé su nota y las lecciones de su tema.**

- Entrada: `Vault/00 Inicio/Portada.md` (mapa por tarea) y `Vault/00 Inicio/Reglas para Claude.md` (reglas completas con enlaces).
- Trampas aprendidas (151): `Vault/07 Lecciones/Índice de lecciones.md`.
- Qué está roto o sin verificar: `Vault/00 Inicio/Hallazgos abiertos.md`.
- Si el código y una nota divergen, **manda el código**: corregí la nota.

## Reglas que no se negocian

1. **Al cerrar un cambio en `src/`:** compilar con `alc.exe` (ver `Vault/06 Desarrollo y operaciones/Compilar con alc.exe.md`; copiar el proyecto al scratchpad si hay worktrees en `.claude/worktrees/`), **borrar `.vscode/rad.json`** sin preguntar (antes mirar su `Removed` y avisar si trae objetos vivos), y actualizar la nota del vault afectada.
2. **No tocar `version` en `app.json`**: la sube el usuario al publicar. Si el cambio exige republicar (control add-in, esquema), decirlo.
3. **Nunca publicar con RAD** ni renumerar una tabla con datos sin exportarla: BC la dropea con sus datos.
4. **IDs nuevos** de Table/Page/Codeunit/Report en **110000–149999** (la licencia corta Table en 60029). El ID declarado dentro del archivo manda sobre el del nombre de archivo.
5. **Evitar tablas nuevas**: probar antes Parámetro → Fuente de Datos → Condición → variable de sistema → campo en tabla de configuración. El motor se configura, no se codifica.
6. **Vigencias:** una fórmula, distribución o convenio nuevo es una vigencia nueva; nunca se pisa la vigente.
7. Una variable de sistema nueva se codifica en `Cod50016` **y se siembra** en `Cod50077`.
8. Objetos nuevos → sumarlos a los tres permission sets (`PermSet50300/50301/50302`).
9. **SQL directo deja la caché del service tier rancia**: reiniciar el servicio tras un `UPDATE` por fuera.
10. **No agregar, quitar ni mover llamadas a `Commit` en el código AL sin aprobación explícita del usuario.** Si un cambio parece necesitarlo (p. ej. antes de `Codeunit.Run`), pararse, explicar por qué y preguntar. Los `Commit` que ya existen se dejan como están.
11. Los datos de empleados (recibos, CUIL, importes) son sensibles: no copiarlos al vault ni a respuestas.

## Trampas de AL que compilan y fallan en silencio

`ContainsKey` + `Get` en la misma expresión (AL no cortocircuita) · `Get` con menos argumentos que la PK · `xRec` en `OnModify` tras un `Modify` de add-in · bucle que modifica el campo que filtra · `Format` con literales inválidos · `Codeunit.Run` sin `Commit` previo · `CLEAR` sobre `TEMPORARY` · `SetSelectionFilter` en página temporal · `CopyFilters` (sólo grupo 0) · `Report` sin layout. Detalle y enlaces en `Reglas para Claude.md`.

## Orientación rápida

- Motor: `Cod50014` MotorLiquidacion, `Cod50015` EvaluadorFormula, `Cod50016` ContextoLiquidacion, `Cod50019` GestionLiquidacion, `Cod50018` ProcesoLiqPorLotes (declara el 50050).
- Datos: `Tab60007` Concepto, `Tab60008` Parámetro Vigente, `Tab60011/12` Liquidación/Línea, `Tab60017` Fracción Acumulador, `Tab60018` Variable Sistema.
- Importe bajo **sin error** = casi siempre un acumulador leído antes de recibir todos sus aportes o un `#`/`@` a un concepto de orden mayor.
- Meta4 es **Oracle** (sin linked server). La base de BC se consulta con `sqlcmd -C`. Raíz del repo = mucho archivo suelto: ver `Vault/06 Desarrollo y operaciones/Mapa de la raíz del repo.md`.
- Inventario completo de objetos: `Vault/08 Referencia/Objetos AL.md` (regenerar con `pwsh scripts/GenerarIndiceVault.ps1`).
