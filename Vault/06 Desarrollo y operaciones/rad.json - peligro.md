---
tipo: guia
tags: [desarrollo, rad, riesgo, perdida-de-datos]
fuente: [.gitignore, .vscode/rad.json, scripts/DiagnosticoTablasExtension.sql]
actualizado: 2026-10-04
---

# rad.json - peligro

> [!danger] El archivo que dropea tablas con datos
> `.vscode/rad.json` es una caché del modo RAD. Su lista **`Removed`** enumera objetos que existieron en un build publicado y ya no están en el código. En la siguiente publicación RAD, BC los da de baja **de verdad**. Para una **tabla**, bajar significa `DROP TABLE` con sus datos; si el ID vuelve, se recrea vacía. No hay diff en el código ni aviso.

Lecciones de origen: [[rad-json-removed-peligroso]] (el incidente y el historial) y [[borrar-rad-json-tras-cada-cambio]] (la regla operativa).

## Regla operativa

1. **Después de cada modificación al proyecto AL, borrar `.vscode/rad.json`.** Es parte de terminar el cambio, igual que compilar. No se pregunta.
2. Antes de borrarlo, mirar su `Removed` y avisar si trae algo que no debería (objetos vivos del proyecto).
3. **Nunca publicar en RAD.** Publicar completo ([[Publicar en BC (no usar RAD)]]).
4. Verificar **en cada sesión** si volvió: `ls .vscode/rad.json`. Está en `.gitignore` y fuera del repo, así que **git no lo muestra**: hay que mirar el disco.

## Chequeo de la alarma

Que el archivo exista no es la alarma; la alarma es que `Removed` traiga algo.

```bash
grep -o '"Removed":\[[^]]*\]' .vscode/rad.json | grep -o '"Kind":' | wc -l
```

## Historial (para dimensionar)

| Fecha | Estado |
|---|---|
| 2026-08-14 | 36 tablas en `Removed` (Estado Empleado 60000, Concepto 60007, Línea Liquidación 60012…) |
| 2026-08-22 | Se saca del repo (`git rm --cached` + `.gitignore`) |
| 2026-09-07 | Reaparece con **103 objetos** (128 contando repetidos). Se borra el 09-08 |
| 2026-09-08 | Reaparece **vacío** (0 objetos): inocuo |
| 2026-09-20 | Reaparece con `Cliente NAV WS` (110040), `Interfaz Meta4` (50506) y `Fase Alta Buffer` (110039) marcados para borrar: objetos **vivos** |
| 2026-10-03 23:15 | **Existe de nuevo** en disco (3.534 bytes). Al 2026-10-04 su `Removed` tiene 2 entradas (`Kind` 12): `Id` 0 sin nombre y `Id` 110055 «Control Liquidación Período» (esa página hoy es la 110056 y el 110055 lo ocupa otra página: renumeración, no borrado real). Sin tablas. **Pendiente borrarlo** |

> [!warning] Estado al escribir esta nota
> El archivo está en disco y no se borró (esta documentación no modifica nada fuera del vault). Aplicar la regla: borrarlo.

## Por qué la pérdida de agosto parecía inconexa

Lo restaurado desde el ConfigPackage volvió **incompleto** ([[configpackage-campos-faltantes]]); lo que no estaba en el paquete no volvió (Filtro Fuente Datos entero, variables de sistema más allá de 5 filas); lo recargado a mano quedó sin lo que nadie tipeó. Ver [[ConfigPackage y RapidStart - qué lleva y qué no]] y [[Backup y restauración - cómo reaplicar]].

La pérdida de los **76 filtros de septiembre** *no* la explica este archivo (la tabla 60028 ya se había ido en agosto); la hipótesis viva es el flag *«Eliminar los registros de tablas antes del procesamiento»* del ConfigPackage sobre la 60029.

## Cómo detectar un drop

`sys.tables.create_date` reciente en las tablas de la extensión delata un DROP + CREATE. Está en `scripts/DiagnosticoTablasExtension.sql` (pasos 2 a 5) — ver [[Scripts SQL y PowerShell del repo]].

## Renumerar es lo mismo que borrar

Renumerar una tabla equivale a un `Removed` del ID viejo. Ejemplos vivos de archivo con nombre viejo y ID nuevo: `Tab50575.PrestamoEmpleado.al` declara 50579; `Tab50576.CuotaPrestamo.al` declara 50580. Ver [[Rangos de IDs y licencia]].
