---
tipo: guia
tags: [desarrollo, tests, calidad]
fuente: [test/Codeunits/Cod50021.TestEvaluadorFormula.al, test/Codeunits/Cod110034.TestFormateadorFormula.al, test/Codeunits/Cod110045.TestFinEfectivoLiq.al, test/Codeunits/Cod110046.TestCorreccionesRendLiq.al, test/Codeunits/Cod110047.TestCacheLiquidacion.al, test/Codeunits/Cod110048.TestEscrituraAuditoria.al, test/Codeunits/Cod110056.TestDetalleCalculo.al, test/editorFormula.atributos.test.cjs, .altestrunner/config.json]
actualizado: 2026-10-04
---

# Tests automatizados

Hay **dos suites chicas** y ningún test de integración del motor. Cubren lo que es lógica pura (evaluador, formateador, fechas, cachés, lectura de detalle) y el comportamiento del editor de fórmulas en el navegador.

## 1. Tests AL (`test/Codeunits/`, 70 `[Test]`)

| Codeunit (archivo) | Pruebas | Qué cubre |
|---|---|---|
| `Test Evaluador Fórmula` (`Cod50021`) | 35 | Aritmética, precedencia, `IF`/`CASE` perezosos (evitan división por cero), comparadores, `AND/OR/NOT`, variables, decimal con coma/punto, atributos comparados por código (`AtributoComparaCodigoAunqueNumeroSeRepita`, `AtributoValidaCodigosSinEmpleado`) |
| `Test Formateador Fórmula` (`Cod110034`) | 11 | Normalización de espacios, menos unario, literales de texto, corte de líneas largas |
| `Test Fin Efectivo Liq.` (`Cod110045`) | 10 | Equivalencia entre resolver el fin efectivo recorriendo la lista (definición) y con mapa (rápido): desordenadas, repetidas, historial largo |
| `Test Detalle Calculo` (`Cod110056`) | 7 | Reconstrucción del detalle: referencias históricas, escalas, retenciones, Ganancias sin etiqueta |
| `Test Correcciones Rend. Liq.` (`Cod110046`) | 3 | Tolerancia de un peso y 20 iteraciones del grossing-up, filtro con apóstrofes |
| `Test Cache Liquidacion` (`Cod110047`) | 2 | Incidencias y CCT cacheadas por categoría/fecha/reinicio |
| `Test Escritura Auditoria` (`Cod110048`) | 2 | Detalle y resumen conservan lo importante al truncar |

Características comunes:
- `Subtype = Test; TestPermissions = Disabled;`
- **Sin librerías de test**: cada codeunit define su propio `Assert`/`AssertEq`/`AssertFecha` local. `app.json` **no** declara dependencia con *Test Runner* ni *Library Assert*.
- Los tests trabajan con **tablas temporales** y no tocan la base. Cada uno instancia su propio `Contexto Liquidación` (la caché es por nombre de variable y compartir la instancia contaminaría).
- **Viajan dentro de la misma app**: `alc` compila `test/` junto con `src/` (≈1,4 MB). IDs: `50021` y `110034`–`110056` ([[Rangos de IDs y licencia]]).

### Cómo correrlos
1. Tener instalado en el servidor el *AL Test Tool* de BC (página de herramienta de pruebas) y publicar la app completa ([[Publicar en BC (no usar RAD)]]).
2. Abrir la herramienta, agregar los codeunits de test por ID y ejecutar.
3. Alternativa: la extensión *AL Test Runner*. Su `.altestrunner/config.json` existe pero está **vacío** (sin `launchConfigName`, `userName`, `testSuiteName`): habría que completarlo ([[Setup del entorno de desarrollo]]).

> [!warning] Sin verificar
> No se corrió la suite AL en esta revisión (el compilador la valida, la ejecución exige el servidor). Tampoco se confirmó que el *Test Tool* esté instalado en `mimir`.

## 2. Test JS del editor (`test/editorFormula.atributos.test.cjs`)

Prueba las sugerencias de valores de atributo del control add-in `EditorFormula` (`src/ControlAddIns/EditorFormula/editorFormula.js`). No usa framework: `node:assert`, `node:vm`. Carga el JS en un sandbox y le inyecta un detector expuesto sólo para el test (`_valores`), sin alterar la API del add-in.

```bash
node test/editorFormula.atributos.test.cjs
# 14 comprobaciones de sugerencias de atributos correctas.
```

Corrido el 2026-10-04 con Node v24.19.0: pasa. No hay `package.json` ni dependencias.

Verifica: `CONVENIO = ` y `<>` proponen los 3 valores, filtro por código/descripción, inserción con comillas, comillas duplicadas (`D''ANGELO`), ausencia de sugerencia con `>`/`TRAMO('`/otra variable, y que el rango reemplazado reconstruye la fórmula idéntica. Contexto funcional: [[atributo-comparar-por-codigo]].

## Lo que no está cubierto

- El **motor completo** (`Motor Liquidación`): ninguna prueba compara liquidaciones enteras. La revisión de rendimiento lo marca como condición previa a optimizar ([[Diagnóstico de rendimiento]]).
- Franco FIFO, estados, sincronización NAV, SIRADIG, informes.
- La comparación real es **contra Meta4** con consultas y scripts (`scripts/CompararEneroMotor.ps1`, `artifacts/revision-enero-2026-*`), no automatizada.

## Cómo agregar un test

1. Un codeunit `Subtype = Test` en `test/Codeunits/` con ID en 110000+ y nombre `Test <Tema>`.
2. `[Test] procedure` por caso, con `Assert` local; evitar tocar tablas reales (usar `temporary`).
3. Para lógica pura de un codeunit sin estado, hacerla `Access = Public` o exponer un procedimiento `…DeLista` como `FinEfectivoDeLista` ([[Convenciones de código AL del proyecto]]).
4. Compilar ([[Compilar con alc.exe]]) y sumar la fila en esta tabla.
5. Si se agrega JS al add-in, un `.test.cjs` análogo; recordar que publicar cambios del add-in exige subir versión ([[Versionado de app.json]]).
