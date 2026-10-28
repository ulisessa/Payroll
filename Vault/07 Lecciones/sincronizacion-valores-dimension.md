---
aliases: ["Sincronización de valores de dimensión"]
tipo: leccion
tema: integracion-nav
tags: [leccion, integracion-nav, project]
origen: 9185b3df-1c53-44a4-a540-9174e99644c1
actualizado: 2026-09-11
---

# Sincronización de valores de dimensión

**En una frase:** Los valores de dimensión de buque y marea se traen de NAV como quinta entidad; por qué, y qué basura trae el origen

**Confirmado el 11/9/2026.** La sincronización NAV→BC tiene una **quinta entidad, "Valor Dimension" (ordinal 4)**, que trae `Dimension Value` de NAV a BC antes que los proyectos.

**Por qué existe:** una marea nueva es, por definición, un valor de dimensión que BC todavía no tiene. Sin esto, cada mes los proyectos de las mareas nuevas quedan en Error con "el valor de dimensión no existe" y hay que crearlos a mano. No es un arreglo de una vez.

Al momento de crearla faltaban en BC **51 valores de MAREA/CIUDAD** (las `26xxxx` de enero 2026 incluidas, o sea justo los 44 proyectos que necesitaba la migración de estados) y **21 de DEPARTAMENTO**. Los 10 `PN-<buque>-NOMINA` estaban limpios.

**El nombre se trae de NAV y no se inventa:** allá `V03` es "Villarino III" y `868` es "Buque Sunrise 868 (Alunamar)". Crear el valor con el código como nombre deja la dimensión llena de códigos ilegibles.

**Pero NO se actualizan los que ya existen.** NAV es el origen de los códigos *nuevos*; el nombre que se ve todos los días es el de BC, y ahí se corrigen las cosas. En NAV conviven "HAI XIANG 16" con "HAI XIANG" para el siguiente, "Vistoria II" por Victoria, y un `Buque Tae Baek"` con comilla suelta. Pisar el nombre en cada corrida devolvería esos errores sobre lo que alguien ya arregló.

**Basura del origen que hay que filtrar:**
- Filas con `[Dimension Code]` **vacío** (~8). Las excluye el `IN` de las tres dimensiones.
- Un código de buque (`TAE`) cargado **dentro de MAREA/CIUDAD**. Entra igual: no hay cómo distinguirlo de una marea legítima. Si aparece en BC, se bloquea a mano.
- `CARPETA IMPORTACION` y demás dimensiones que no se usan: fuera por el mismo `IN`.

**Qué dimensiones se traen:** las tres que la sincronización aplica sobre el proyecto, y **los códigos salen de la configuración contable de la empresa de BC** (`Global Dimension 1/2 Code` y `Shortcut Dimension 3 Code`), no escritos en el script.

**Trampas de datos que quedaron documentadas:** ver [[dim2-nav-actividad-bc-marea]] — el código de dimensión no coincide con el segmento del `No.` (`PP-HUAI` → `HUA`, `PP-MAT` → `MT1`) y hay mareas de 7 dígitos (`PP-TAE-2600001`). Las dos son razones para leer la dimensión de NAV en vez de parsear el número de proyecto.

Relacionado: [[dim2-nav-actividad-bc-marea]], [[job-confirm-dimension-inocuo]], [[migracion-estados-meta4]].

## Relacionado

- [[nav-odata-ntlm]]
- [[transporte-ws-sincronizacion]]
- Tema: `integracion-nav` (ver [[_Convenciones del vault]])
