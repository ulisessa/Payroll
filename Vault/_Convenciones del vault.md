---
tipo: guia
tags: [meta, convenciones]
actualizado: 2026-10-04
---

# Convenciones del vault

Este vault es **el manual integral y la memoria operativa** de la extensión *Liquidación Sueldos Pesca* (Business Central 25.2, Grupo Arbumasa). Lo leen personas **y** Claude Code (ver `CLAUDE.md` en la raíz del repo, que apunta acá). Por eso cada nota tiene que ser **verificable contra el código** y **autosuficiente**.

## Reglas de redacción

1. **Idioma:** español rioplatense, técnico y directo. Nombres de objetos y campos AL **tal cual están en el código** (con tildes y espacios: `Línea Liquidación`, `Cód. Concepto`).
2. **Verificar antes de afirmar.** Nada de describir lo que "debería" hacer el código. Si algo no se pudo confirmar: callout `> [!warning] Sin verificar`. Si el código y la documentación vieja divergen, manda el código y se marca la divergencia.
3. **Una idea por nota.** Notas de 30–150 líneas. Si crece, partir y enlazar.
4. **Enlazar mucho** con `[[Nombre de nota]]` (nombre de archivo sin extensión). No usar rutas. Un enlace a una nota que todavía no existe es aceptable sólo si es una nota que claramente falta escribir; preferir enlazar a lo que existe.
5. **Frontmatter obligatorio:**

```yaml
---
tipo: concepto | tabla | codeunit | pagina | proceso | guia | leccion | referencia | decision
tags: [motor, ...]
fuente: [src/Codeunits/Cod50014.MotorLiquidacion.al]   # archivos que respaldan la nota
actualizado: 2026-10-04
---
```

6. **Código y rutas:** rutas del repo en backticks (`src/Tables/Tab60012.LineaLiquidacion.al`). Fórmulas y AL en bloques de código.
7. **Callouts** de Obsidian para lo que no se puede perder: `> [!danger]` (pierde datos / rompe producción), `> [!warning]` (trampa silenciosa), `> [!tip]`, `> [!note]`, `> [!example]`.
8. **Diagramas** con ```` ```mermaid ```` cuando aclaran un flujo o una relación.
9. **Nombres de archivo:** sin `: / \ ? * " < > | # ^ [ ]`. Únicos en todo el vault (Obsidian resuelve `[[...]]` por nombre). Antes de crear una nota, comprobar que no exista ya una con ese nombre.
10. **No duplicar.** Si algo ya está explicado en otra nota, enlazarla y agregar sólo lo nuevo.
11. **Lecciones:** las notas de `07 Lecciones` usan como nombre de archivo el *slug* original de la memoria de Claude (p. ej. `avoid-tables-principle`) y un `aliases:` con título legible. Se enlazan desde las notas de dominio con `[[slug]]`.

## Estructura

| Carpeta | Contenido |
|---|---|
| `00 Inicio` | Portada, mapa del vault, reglas para Claude |
| `01 Arquitectura y motor` | Cómo calcula el motor, evaluador de fórmulas, contexto, acumuladores |
| `02 Modelo de datos` | Una nota por tabla + diagramas por dominio |
| `03 Dominio pesquero` | Estados, fases, entidades, atributos, mareas, francos, convenios, tipos de liquidación |
| `04 Integraciones` | Sincronización NAV, Meta4, SIRADIG/AFIP, firma de recibos |
| `05 Interfaz y operación` | Páginas, Role Center, reportes, permisos, flujo operativo (manual de usuario) |
| `06 Desarrollo y operaciones` | Compilar, publicar, IDs, scripts SQL, ConfigPackage, rendimiento, runbooks |
| `07 Lecciones` | Trampas y decisiones aprendidas (una nota por lección) |
| `08 Referencia` | Índices generados: objetos AL, enums, glosario |

## Etiquetas de tema (campo `tema` en las lecciones)

`motor-calculo` · `formulas-evaluador` · `parametros-atributos` · `estados-fases` · `francos` · `convenios-cct` · `conceptos-haberes` · `descuentos-ganancias-sipa` · `vacaciones-sac-licencias` · `migracion-meta4` · `integracion-nav` · `sql-bc-infra` · `desarrollo-al` · `ui-controles` · `rendimiento` · `controles-auditoria` · `firma-recibos`

## Cómo mantenerlo

- Al cambiar el comportamiento del motor, actualizar la nota correspondiente **en el mismo cambio**.
- Una trampa nueva que costó tiempo → una nota en `07 Lecciones` con *Por qué* y *Cómo aplicarlo*.
- Los índices de `08 Referencia` se regeneran con `scripts/GenerarIndiceVault.ps1`.
