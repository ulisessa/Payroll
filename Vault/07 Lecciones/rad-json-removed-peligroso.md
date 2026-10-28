---
aliases: ["rad.json tiene media app en Removed"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, project]
origen: 6fef786a-9ac7-4101-a78d-2cb1c395ef37
actualizado: 2026-09-08
---

# rad.json tiene media app en Removed

> [!danger] Riesgo de pérdida de datos
> La lista Removed de .vscode/rad.json es el cementerio de IDs publicados; para una tabla significa que BC la dropeó con sus datos. Sacado del repo el 2026-08-22 — verificar en cada sesión si volvió a aparecer

`.vscode/rad.json` lleva la lista `Removed` de objetos que existían en un build publicado y ya no existen en el código. Al 2026-08-14 tenía **36 tablas**, entre ellas 60000 Estado Empleado, 60003 Cód. Estado Empleado, 60007 Concepto, 60011 Liquidación, 60012 Línea Liquidación, 60016 Parámetro, 60018 Variable Sistema Liq. y 60028 Filtro Fuente Datos Liq.

**El 2026-08-22 se borró del repo** (`git rm --cached` + `.gitignore:21`) y quedó un respaldo del contenido en el scratchpad de esa sesión. El archivo es caché del modo RAD: **VS Code lo regenera solo** la próxima vez que alguien publique en ese modo, con lo cual la mina se rearma sin aviso.

**Por qué:** para una tabla, desaparecer de la app significa que BC la dropea **con sus datos**, y si el ID vuelve después se recrea vacía — sin ningún diff en el código que lo delate. La prueba está en Filtro Fuente Datos Liq.: figura en `Removed` como **60028** y el código declara **60029** (archivo Tab60029). Se renumeró, la 60028 se fue con todo adentro y la 60029 nació vacía. Otras renumeraciones vivas, con nombre de archivo viejo: Tab50575 declara 50579 (Préstamo Empleado), Tab50576 declara 50580 (Cuota Préstamo), Tab60031 declara 50578 (Tipo Liquidación, que pasó antes por 50577). Tipo Liquidación no se notó porque Cod50056/50057 la resiembran en cada install/upgrade; Préstamo y Cuota Préstamo no tienen sembrador.

Eso explica el patrón de pérdidas de agosto 2026, que parecía inconexo: lo que se restauró desde `ConfigPackage_Payroll.xml` volvió **incompleto** (el paquete lleva 12 de las 22 columnas de Concepto), lo que no estaba en el paquete no volvió (Filtro Fuente Datos entero, las variables de sistema más allá de 5 filas) y lo que se recargó a mano quedó sin lo que nadie tipeó (`Tipo Estado` de los Cód. Estado, que dejó DIAS_VAC_PERIODO en 0 y el autocompletado de vacaciones muerto).

**2026-09-07 22:59: volvió a aparecer.** Regenerado, con **103 objetos en `Removed`** (128 contando los `Kind` repetidos), entre ellos otra vez `Filtro Fuente Datos Liq.` **60028**, `Fuente Datos Liquidación` 60015, `Parámetro Vigente` 60008, `Variable Sistema Liq.` 60018, `Detalle Variable Línea Liq.` 60023 y `Tabla Escalonada Det.` 60014. Se borró el 2026-09-08. La versión del 22/08 sigue recuperable con `git show HEAD:.vscode/rad.json` — sirve para ver qué IDs estaban marcados sin depender del archivo vivo.

**2026-09-08 12:43: volvió otra vez, pero VACÍO** — 0 objetos en `Removed`. Se regenera al publicar, así que va a seguir apareciendo; lo que importa es que el código ya no arrastra las eliminaciones viejas (la renumeración al rango 110000 quedó consistente). O sea: que el archivo exista no es la alarma — la alarma es que `Removed` traiga algo. El chequeo de cada sesión es `grep -o '"Removed":\[[^]]*\]' .vscode/rad.json | grep -o '"Kind":' | wc -l`.

Ojo con atribuirle de más: la pérdida de los 76 filtros de **septiembre** NO la explica este archivo. Esas filas estaban en la 60029 y se exportaron completas el 07/09 23:24; `Removed` nombra la 60028, que ya se había ido en agosto. Para esa pérdida la hipótesis viva es el flag «Eliminar los registros de tablas antes del procesamiento» del ConfigPackage sobre la 60029.

**Cómo aplicarlo:** el usuario pidió expresamente **verificar en cada sesión si el archivo volvió a existir** — un `ls .vscode/rad.json` alcanza. Si reapareció: avisarle, mirar qué tablas quedaron en `Removed` y confirmar que no se publicó en RAD desde entonces (`sys.tables.create_date` en la base de BC delata cualquier tabla dropeada y recreada; la consulta está en `scripts/DiagnosticoTablasExtension.sql`, pasos 5 y 6). Antes de renumerar una tabla, exportar sus datos — el renombre de archivo no basta, el ID es el que manda. Publicar siempre completo (Ctrl+F5, *AL: Publish*), nunca con RAD. Ver [[configpackage-campos-faltantes]] para qué campos NO viajan en el paquete, y [[system-variables-conventions]].

## Relacionado

- [[progreso-singleinstance-sucio]]
- [[rangos-licencia-objetos]]
- [[report-sin-layout-compila]]
- [[setselectionfilter-tabla-temporal]]
- [[symbolos-final-version-tienen-fuente]]
- [[version-app-json-manual]]
- Tema: `desarrollo-al` (ver [[_Convenciones del vault]])
