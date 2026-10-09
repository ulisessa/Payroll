---
tipo: guia
tags: [desarrollo, compilacion, alc]
fuente: [app.json, .claude/worktrees]
actualizado: 2026-10-04
---

# Compilar con alc.exe

Cómo validar un cambio sin abrir VS Code. Es la **primera** verificación de cualquier cambio (ver [[Runbook - tareas frecuentes]]). Origen: lección [[al-compile-command]].

## Comando (Git Bash, desde la raíz del repo)

```bash
ALC=$(ls -d /c/Users/ulises.sasovsky/.vscode/extensions/ms-dynamics-smb.al-*/bin/win32/alc.exe | tail -1)
"$ALC" /project:"$(pwd -W)" /packagecachepath:"$(pwd -W)/.alpackages" /out:"$(pwd -W)/_compile_test.app"
```

La lección original fija la versión (`ms-dynamics-smb.al-17.0.2273547`); el glob evita romperse cuando VS Code actualice la extensión.

- **Éxito** = se produce `_compile_test.app` (≈1,4 MB). Borrarlo después. (`*.app` está en `.gitignore`, pero ensucia la raíz; ver [[Mapa de la raíz del repo]].)
- **Filtrar errores reales**: `... 2>&1 | grep -iE "error AL|: error"`.
- `alc` compila **todos los `.al` bajo `/project:`**, incluida la carpeta `test/` (los tests viajan dentro de la misma app, ver [[Tests automatizados]]).

## Advertencias esperadas (ignorar)

Medido el 2026-10-04 en una compilación limpia (cero errores, exit 0, ~10 s):

| Código | Cantidad | Qué es |
|---|---|---|
| `AL0432` | 11 | Campos marcados para eliminación (obsoletos) de Fuente Datos, referenciados todavía |
| `AL1029` | 1 | Idioma de destino del xlf |
| `AL1025` | (aparece compilando el repo entero) | Archivos que no son AL en el proyecto, p. ej. `ConfigPackage_Payroll.xml` |

Cualquier otro código nuevo hay que mirarlo; en particular `AL0468` y `AL0275` (objeto duplicado) han bloqueado publicaciones antes (ver [[Backup y restauración - cómo reaplicar]]).

## Gotcha: worktrees de git

`alc` compila también los `.al` de `.claude/worktrees/` si existen. Esas copias son versiones viejas o rotas de los mismos objetos y producen un muro de errores de sintaxis **que no están en el árbol de trabajo**. Señal: los errores citan rutas con `worktrees`. Chequear `git worktree list`.

**Workaround sin tocar los worktrees del usuario** — compilar una copia en el scratchpad y seguir apuntando a los símbolos reales:

```bash
SP=<scratchpad>
mkdir -p "$SP/cmp" && cp app.json "$SP/cmp/" && cp -r src test Translations "$SP/cmp/"
"$ALC" /project:"$(cd "$SP/cmp" && pwd -W)" \
       /packagecachepath:"$(pwd -W)/.alpackages" \
       /out:"$(cd "$SP/cmp" && pwd -W)/_compile_test.app" > "$SP/cmp.log" 2>&1
grep -iE "error AL|: error" "$SP/cmp.log"
```

Hoy `.claude/worktrees/` está vacía, así que compilar directo funciona; el workaround queda como respaldo y es el que usan los agentes.

## Lo que compilar NO prueba

- **`Format` con expresión**: el compilador no valida la cadena de formato. Ver [[format-no-se-valida-al-compilar]].
- **Reports**: un `report` sin layout compila y falla al abrirlo. Ver [[report-sin-layout-compila]].
- **`Get` con menos argumentos que la PK**: compila y asigna al campo equivocado ([[get-con-menos-argumentos]]).
- **`ContainsKey` y `Get` en la misma expresión**: AL no cortocircuita ([[al-sin-cortocircuito]]).
- **Variables de sistema**: agregar un `Cód. Cálculo` en AL compila pero hace falta la fila ([[variable-sistema-hay-que-sembrarla]]).
- **Equivalencia de cálculo**: compilar no demuestra que una optimización dé los mismos importes ([[Diagnóstico de rendimiento]]).

## Después de compilar

1. Borrar `_compile_test.app` si quedó en la raíz.
2. Borrar `.vscode/rad.json` ([[rad.json - peligro]]).
3. **No** tocar `version` de `app.json` ([[Versionado de app.json]]).
