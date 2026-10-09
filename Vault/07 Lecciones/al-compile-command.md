---
aliases: ["Compilar la extensión AL desde la CLI"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, reference]
origen: c60bb641-6f64-4ab1-9d8b-eabba2faf874
actualizado: 2026-08-07
---

# Compilar la extensión AL desde la CLI

El compilador `alc.exe` viene con la extensión AL de VS Code y permite validar cambios sin abrir VS Code.

## Cómo aplicarlo

Desde la raíz del proyecto (Git Bash):

```bash
ALC="/c/Users/ulises.sasovsky/.vscode/extensions/ms-dynamics-smb.al-17.0.2273547/bin/win32/alc.exe"
"$ALC" /project:"$(pwd -W)" /packagecachepath:"$(pwd -W)/.alpackages" /out:"$(pwd -W)/_compile_test.app"
```

- Filtrar errores reales con `grep -iE "error AL|: error"`.
- Éxito = se produce el archivo `_compile_test.app` (borrarlo después).
- Warnings preexistentes a ignorar: AL0432 (campos marcados para remoción en Fuente Datos), AL1029 (idioma destino del xlf), AL1025 (archivos no AL como `ConfigPackage_Payroll.xml`).
- La versión de la extensión puede cambiar el nombre de la carpeta `ms-dynamics-smb.al-17.0.2273547`: si la ruta falla, usar un glob `~/.vscode/extensions/ms-dynamics-smb.al-*`.

> [!warning] Worktrees viejos rompen la compilación
> `alc` compila todo `.al` bajo `/project:`, incluidos los git worktrees sobrantes en `.claude/worktrees/`. Esos llevan copias viejas o rotas de los mismos objetos y producen una pared de errores de sintaxis que **no** están en el árbol de trabajo. Revisar `git worktree list` cuando los errores citen rutas con `worktrees`. Workaround que no toca los worktrees del usuario: copiar `app.json` + `src/` al scratchpad, compilar ahí con `/packagecachepath:` apuntando todavía al `.alpackages` real, y borrar la copia después.

## Relacionado

- [[format-no-se-valida-al-compilar]]
- [[borrar-rad-json-tras-cada-cambio]]
- [[al-sin-cortocircuito]]
- [[avoid-tables-principle]]
