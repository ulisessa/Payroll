---
aliases: ["Símbolos de Final Version traen el AL"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, reference]
actualizado: 2026-10-04
---

# Símbolos de Final Version traen el AL

**En una frase:** El .app de "Final Version Customization - Tables Only" trae el AL completo; cómo extraerlo y por qué los nombres de archivo engañan

Los símbolos de `Final Version Customization Extension - Tables Only` (`.alpackages/*.app`) no son sólo metadata: traen el **código AL completo** de la personalización convertida de NAV. Es la única forma de ver los nombres exactos de campo de Descargas, Job y Employee sin abrir SQL ni NAV.

Para extraerlo: el `.app` es un ZIP con 40 bytes de cabecera. Saltar hasta el primer `PK\x03\x04` y descomprimir. Ojo con las rutas largas: extraer entradas sueltas a un directorio plano en vez de `ExtractToDirectory` sobre todo el paquete, que revienta a mitad de camino y deja un árbol incompleto que parece vacío.

**El gotcha:** los archivos se llaman por el **ID del objeto de extensión**, no por la tabla que extienden. `UAS.167.TableExt.al` no existe; el tableextension de Job es `UAS.50245.al` ("Job Ext.") y el de Employee es `UAS.50668.al`. Buscar por número de tabla base no encuentra nada y da la impresión falsa de que la extensión no toca esas tablas. Lo que sí funciona es leer la primera línea de cada archivo y filtrar por `extends <Tabla>`.

Dónde está lo que suele hacer falta:
- `Cab. descarga` (50561) y `Lín. descarga` (50562) → `src/projects/Producción/Descargas/tables/`. La PK de la cabecera es **sólo** `No. proyecto`: hay una descarga por marea.
- Campos de marea en Job (`Hora de zarpada`, `Hora ingreso a puerto`, `Tipo`, `Patron`, `Year tide`) → tableextension 50245.
- `CIF/NIF`, `Categoría`, `pat_Fecha ingreso laboral` en Employee → tableextension 50668.

Muchos campos de esos tableextensions son FlowFields y FlowFilters (kilos descargados, totales DCL, todos los `Filtro *`): no existen como columna en SQL. Para separarlos, filtrar los bloques `field(...)` que no declaran `FieldClass`.

Relacionado: [[al-compile-command]], [[rangos-licencia-objetos]]

## Relacionado

- [[progreso-singleinstance-sucio]]
- [[rad-json-removed-peligroso]]
- [[rangos-licencia-objetos]]
- [[report-sin-layout-compila]]
- [[setselectionfilter-tabla-temporal]]
- [[version-app-json-manual]]
- Tema: `desarrollo-al` (ver [[_Convenciones del vault]])
