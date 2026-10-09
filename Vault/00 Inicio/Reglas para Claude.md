---
tipo: guia
tags: [inicio, claude, reglas]
actualizado: 2026-10-04
---

# Reglas para Claude

Este es el contenido operativo del `CLAUDE.md` de la raíz del repo. Es corto a propósito: cada regla enlaza a la nota que la explica. **Si vas a tocar una zona, leé las lecciones de su tema** ([[Índice de lecciones]]).

## 1. Contexto en 5 líneas

- Extensión AL "Liquidación Sueldos Pesca" para BC 25.2 OnPrem; namespace `UAS.Payroll`; ver [[Portada]].
- Motor paramétrico: conceptos con fórmula, parámetros con vigencia, acumuladores, fuentes de datos. Ver [[Visión general de la arquitectura]].
- Dominio: tripulantes de buques pesqueros (mareas, francos, CCT 729/15, 768/19, 175/75, 372/04, SOMU) y personal de tierra. Ver [[Vision del dominio pesquero]].
- Sistema anterior: Meta4 (Oracle). BC migra de ahí y se compara contra él. Ver [[Índice Integraciones]].
- El usuario escribe en **español**; respondé en español. Nombres de objetos y campos exactamente como en el código.

## 2. Al cerrar cualquier cambio en `src/`

1. **Compilar** con `alc.exe` ([[Compilar con alc.exe]], [[al-compile-command]]). Cero errores; ignorar AL0432, AL1029, AL1025. Borrar el `.app` de prueba.
2. **Borrar `.vscode/rad.json`** sin preguntar; mirar antes qué trae en `Removed` y avisar si hay objetos vivos ([[borrar-rad-json-tras-cada-cambio]], [[rad.json - peligro]]).
3. **No tocar `version` de `app.json`**: la sube el usuario al publicar ([[version-app-json-manual]]). Si el cambio necesita republicar (add-in, esquema), decirlo.
4. **Actualizar el vault** en el mismo cambio (nota afectada; lección si costó tiempo) y correr `pwsh scripts/GenerarIndiceVault.ps1`.
5. Sumar objetos nuevos a los tres permission sets ([[Permission sets de la extensión]]).
6. Checklist completo: [[Runbook - tareas frecuentes]].

## 3. Diseño

- **No crear tablas si se puede evitar.** Orden de intentos: Parámetro → Fuente de Datos → Condición → variable de sistema → campo en tabla de configuración ([[avoid-tables-principle]]). Un valor, una fuente ([[un-valor-una-fuente]]).
- **Vigencias:** una fórmula, una distribución o un convenio nuevo se agrega como **vigencia nueva**, nunca pisando la vigente ([[conceptos-tres-vigencias]]).
- **IDs nuevos:** Table/Page/Codeunit/Report en **110000–149999**. Table sólo llega a 60029 en el rango bajo; por encima de eso falla con un error de permisos engañoso ([[Rangos de IDs y licencia]], [[rangos-licencia-objetos]]). **El ID declarado dentro del archivo manda sobre el del nombre de archivo** (hay 7 desfasados; ver [[Objetos AL]]).
- **Nunca renumerar una tabla con datos** sin exportarla: BC la dropea con sus datos ([[rad-json-removed-peligroso]]). **Nunca publicar con RAD** ([[Publicar en BC (no usar RAD)]]).
- **`Commit` en AL: no tocarlo sin aprobación explícita del usuario.** No agregar, quitar ni mover llamadas a `Commit`. Si un cambio parece requerirlo (p. ej. antes de `Codeunit.Run`, ver [[codeunit-run-necesita-commit]]), detenerse, explicar el motivo y preguntar. Los `Commit` existentes se dejan como están. Ver [[Transaccionalidad y errores del cálculo]].
- Una variable de sistema nueva hay que **sembrarla** además de codificarla ([[variable-sistema-hay-que-sembrarla]], [[system-variables-conventions]]).

## 4. Trampas de AL que compilan y fallan en silencio

| Trampa | Lección |
|---|---|
| `AL` no cortocircuita: `ContainsKey` y `Get` en la misma expresión ejecuta el `Get` igual | [[al-sin-cortocircuito]] |
| `Get` con menos argumentos que la PK compila y asigna al campo equivocado | [[get-con-menos-argumentos]] |
| `xRec` en `OnModify` llega con el valor nuevo si el `Modify` vino de un add-in | [[xrec-no-confiable-con-addin]] |
| Bucle que modifica el campo que filtra: se detiene tras el primer registro; juntar las claves antes | [[bucle-modifica-campo-filtrado]] |
| `Format` no se valida al compilar (`'<Char>'` no existe) | [[format-no-se-valida-al-compilar]] |
| `Codeunit.Run()` exige `Commit` antes; si no, el patrón "una fila mala no frena el lote" es un bug latente | [[codeunit-run-necesita-commit]] |
| `CLEAR` no vacía un Record `TEMPORARY` | [[clear-no-vacia-temporary]] |
| `SetSelectionFilter` sobre una página temporal devuelve vacío | [[setselectionfilter-tabla-temporal]] |
| `CopyFilters` copia sólo el grupo 0; no arrastra el `SubPageLink` | [[copyfilters-solo-grupo-actual]] |
| Un `Report` sin layout compila; falla al abrirlo | [[report-sin-layout-compila]] |
| Recorrer un estado abierto día por día desborda (`31/12/9999`) | [[recorrer-estado-abierto-dia-por-dia]] |
| Excel Buffer: una variable por hoja | [[excel-buffer-writer-en-la-variable]] |
| `SingleInstance` de progreso conserva contadores de un lote cortado | [[progreso-singleinstance-sucio]] |

## 5. Trampas del motor y la configuración

- Un importe bajo **sin error** suele ser un acumulador leído antes de recibir todos sus aportes, o un `#`/`@` a un concepto de orden mayor ([[acumuladores-orden-calculo]], [[control-precedencia-formulas]], [[Orden de cálculo y precedencia]]).
- Un concepto que produce un valor negativo debe correr **antes** de sus consumidores ([[concepto-negativo-despues-de-sus-consumidores]]).
- `@` ignora el par del concepto y re-evalúa con el de quien llama; para respetarlo leer con `#` ([[arroba-ignora-el-par-del-concepto]]).
- Parámetro y atributo con el mismo nombre: gana el parámetro y el atributo queda mudo; dos parámetros con el mismo nombre: gana el último por código y pisa con cero ([[parametro-y-atributo-mismo-nombre]], [[dos-parametros-mismo-nombre]]).
- Fuente de Datos apunta a la tabla **por número**: borrar un campo la rompe en runtime sin que el compilador lo vea ([[fuente-datos-apunta-por-numero]]).
- Variables que valen cero sin error: [[variables-rotas-valen-cero]]. Vacío en *Tipos Liq. Aplicables* es comodín ([[vacio-en-tipos-liq-aplicables-es-comodin]]).
- **Grossing-up:** el neto siempre sale bien; comparar el bruto y la base, nunca el neto ([[grossing-up-tapa-errores]]).
- Estados de empleado: historial contiguo con `Fecha Fin` mantenida; leer siempre `FechaFinEfectiva()` ([[estado-empleado-effective-dated]]). Tres capas fase → estado → asignación: limpiar de arriba hacia abajo ([[tres-capas-fase-estado-asignacion]]).
- Novedades: sólo entran en la liquidación del proyecto que indican ([[novedad-con-proyecto-queda-huerfana]], [[novedad-tipo-liq-y-fecha-se-pelean]]).

## 6. Datos y SQL

- **SQL directo deja la caché del service tier rancia**: tras un `UPDATE` por fuera hay que reiniciar el servicio ([[sql-directo-deja-cache-rancia]]).
- SQL dinámico se trunca a 4000 si falta `CAST(... AS nvarchar(max))` ([[sql-dinamico-truncado-4000]]). Una subconsulta correlacionada con columna mal escrita no falla: deja de filtrar ([[subconsulta-correlacionada-silenciosa]]).
- Conexión a la base de BC: [[conexion-sql-bc]] (`sqlcmd` necesita `-C`; SqlClient necesita el FQDN). Campos de extensión viven en la tabla `$ext` con el id de la extensión como sufijo ([[campos-extension-tabla-ext]]).
- **Meta4 es Oracle**: no hay linked server; se consulta por ODP.NET desde PowerShell ([[meta4-es-oracle]], [[meta4-conectar-desde-powershell]]). Un `NUMBER` castea a cero y un `DATE` lleva hora ([[meta4-number-castea-a-cero]], [[oracle-date-lleva-hora]]). `Export-Csv` escribe decimales con coma ([[export-csv-decimal-con-coma]]).
- Antes de migrar: previsualizar con controles de invariante y de dirección ([[previsualizar-antes-de-migrar]]).
- La licencia **no permite** firmar PAdES desde AL ni hay habilitación que tramitar ([[firma-recibos-digitales]]).

## 7. Cómo trabajar con el usuario

- Respuestas en español, directas, sin relleno; decir qué se compiló, qué quedó sin verificar y qué requiere publicar.
- Cuando algo "da bien" sin error, desconfiar: el sistema falla en silencio ([[Índice de lecciones]]).
- Los datos de empleados (recibos PDF, CUIL, importes) son sensibles: no copiarlos a notas del vault ni a respuestas.
- Si el código y una nota divergen, manda el código; corregí la nota y dejá constancia en [[Divergencias entre documentación vieja y código]].
- Estado conocido de lo que falta resolver: [[Hallazgos abiertos]].
