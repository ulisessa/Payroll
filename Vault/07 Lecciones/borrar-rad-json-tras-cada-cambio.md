---
aliases: ["Borrar rad.json tras cada cambio"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, feedback]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-21
---

# Borrar rad.json tras cada cambio

Borrar .vscode/rad.json después de cada modificación al proyecto AL, sin esperar a que lo pidan

Después de cada modificación al proyecto AL hay que **borrar `.vscode/rad.json`**. No es una limpieza opcional ni algo a consultar: es parte de terminar el cambio, igual que compilar.

**Por qué:** VS Code lo regenera solo al publicar en RAD y deja adentro una lista de objetos en `"Removed"`. En la próxima publicación RAD los da de baja de verdad. El 20/9/2026 el archivo había vuelto con `Cliente NAV WS` (110040), `Interfaz Meta4` (50506) y `Fase Alta Buffer` (110039) marcados para borrar — objetos vivos del proyecto. Está en `.gitignore` y borrado del repo, así que git no lo muestra ni lo trae de vuelta: hay que mirar el disco.

**Cómo aplicarlo:** al cerrar cualquier tanda de cambios en `src/`, `rm -f .vscode/rad.json`. Conviene mirar antes qué tiene en `"Removed"` y avisar si hay algo que no debería estar ahí, pero el borrado va igual. Ver [[rad-json-removed-peligroso]].

## Relacionado

- [[rad-json-removed-peligroso]]
- [[al-compile-command]]
- [[al-sin-cortocircuito]]
- [[avoid-tables-principle]]
