# Reaplicar la configuración sobre el backup del 07/09 14:31

## Dónde estamos — 08/09, 13:00

### Verificado

| | Estado |
|---|---|
| `src/Tables copy/` | borrado |
| `.vscode/rad.json` | volvió a aparecer (08/09 12:43) pero con **0 objetos en `Removed`**: inocuo. El código ya no arrastra las eliminaciones viejas |
| Versión de la extensión | **1.0.0.412** (antes 411, que identificaba a dos builds distintos) |
| Concepto 4743 | fórmula corregida **y confirmada en la base** |
| Historial de fórmulas | arreglado el bug de `xRec` + la ventana deslizante de `AgruparConEntradaAbierta` |
| Árbol de liquidaciones | abre sin filtro de período |
| Compilación | sin errores ni AL0468 |

### Pendiente ahora mismo

**1.0.0.412 está publicada pero NO sincronizada.** El `Sync-NAVApp` se cortó porque el renombre del
campo 52016 se ve como una eliminación. Los dos comandos que faltan:

```powershell
Sync-NAVApp -ServerInstance $ServerInstance -Tenant default -Name $AppName -Version $Version -Mode ForceSync
Start-NAVAppDataUpgrade -ServerInstance $ServerInstance -Tenant default -Name $AppName -Version $Version
```

### Sin verificar — lo resuelve un solo script

El estado de los DATOS no lo sé, y no conviene suponerlo. Correr
[`scripts/EstadoConfiguracion.sql`](scripts/EstadoConfiguracion.sql) (Fase C) y actuar según marque.
Lo que se puede anticipar por las fechas:

| Qué | Pronóstico | Por qué |
|---|---|---|
| Fracción Acumulador | probablemente **las viejas** | la recarga fue ~22:00, el backup es de las 14:31 |
| Concepto `NETO_GARANT` | probablemente **no está** | se creó entre las 23:05 y las 23:24 |
| Filtros de Fuente Datos | probablemente **sí están** | se perdieron después de las 14:31 |
| Config. RRHH (los dos punteros) | se siembran solos | los escribe `Cod110038` en el `Start-NAVAppDataUpgrade` |
| Parámetros y escalas | desconocido | |

### Todavía sin hacer

Fase E completa (el flag del ConfigPackage sobre la 60029) y Fase F completa (`Invertir Signo`,
concepto 1223, el prorrateo del 4743 —la fórmula corregida ya está cargada, falta decidir si se
versiona aparte—, y los redondeos).

---


Todo lo que sigue se hizo **después** de las 14:31, así que el backup no lo tiene. El orden importa:
cada fase depende de la anterior.

| Hora (07-08/09) | Qué pasó |
|---|---|
| 14:52 | `PROPUESTA_TOPE_SIPA_PERIODO.md` — propuesta, **no implementada** |
| ~22:00 | Recarga de Fracción Acumulador desde la spec de Meta4 |
| 22:56 | `FRACCIONES_RETIRADAS_VS_META4.md` |
| 23:05 | Export **sin** `NETO_GARANT` |
| 23:24 | Export **con** `NETO_GARANT` → el concepto se creó entre las 23:05 y las 23:24 |
| 00:40+ | Se detecta que los 76 filtros de Fuente Datos desaparecieron |

---

## Fase A — Antes de restaurar

1. **Resguardar `Genérico07_09_2026_23_24_04.xlsx` fuera de la carpeta del proyecto.** Es la única
   copia de varias cosas (los 76 filtros, `NETO_GARANT`, las escalas). Si se pisa, no hay de dónde
   sacarlas.
2. Anotar contra qué se trabaja: base `Migr2013R2`, empresa `ArbuTest`. Todos los scripts empiezan
   con esas dos variables; si la empresa es otra, se ajusta en la primera línea de cada uno.

---

## Fase B — Código (se puede hacer mientras restaura)

Hay **dos bloqueadores** para publicar. Los dos están hoy en el repo.

3. **Borrar `src/Tables copy/`.** Son 57 archivos byte a byte idénticos a `src/Tables/`. Producen
   `AL0275` (objeto duplicado) y la extensión no compila. No están en git, así que borrarlos no
   pierde nada.

4. **Borrar `.vscode/rad.json`.** Volvió a aparecer (07/09 22:59) y tiene **128 objetos en
   `"Removed"`**, entre ellos `Tabla Escalonada Det.` (60014) y `Gestión Estado Empleado`. Publicar
   con RAD teniendo eso ahí los elimina de la base. VS Code lo regenera solo; el problema no es que
   exista, es publicar sin haberlo mirado.

5. Compilar y publicar. **No subir la versión de `app.json`** — eso lo hacés vos al publicar.

> Al publicar corre el upgrade `Cod110038`, que completa los dos campos nuevos de Config. RRHH
> (`NETO_GARANT` y `BASE_IG4`) **sólo si están en blanco**. No pisa lo que ya haya.

---

## Fase C — Medir antes de tocar

6. Correr **[`scripts/EstadoConfiguracion.sql`](scripts/EstadoConfiguracion.sql)**. Sólo lee.
   Imprime, al lado de cada valor real, el esperado:

   | Bloque | Qué responde | Esperado |
   |---|---|---|
   | 1 | ¿está publicada la versión con los campos nuevos? | `publicada` + `NETO_GARANT` / `BASE_IG4` |
   | 2 | ¿existe el concepto `NETO_GARANT`? | Informativo, orden 5, con fórmula |
   | 3 | filtros de Fuente Datos | **76**, y ninguna fuente activa sin filtros |
   | 4 | Fracción Acumulador | **1208**, `BASE_IG4` **123**, cero solapamiento, cero huérfanos |
   | 5 | parámetros `NETO_GU_*` | 90016, 90212, 90302, 90361 |
   | 6 | conceptos activos sin fórmula | cuantos menos, mejor |

   **Las fases siguientes son condicionales: hacé sólo lo que este script marque como faltante.**

---

## Fase D — Datos, en este orden

7. **Fracciones** — si el bloque 4 no da 1208: correr
   [`scripts/CargarFraccionesMeta4.sql`](scripts/CargarFraccionesMeta4.sql).
   Ya viene con las 4 fracciones duplicadas excluidas (ver la sección final). Borra la tabla entera
   y la reinserta.

8. **Filtros de Fuente Datos** — si el bloque 3 no da 76: correr
   [`scripts/RestaurarFiltrosFuenteDatos.sql`](scripts/RestaurarFiltrosFuenteDatos.sql).
   Sin esto cada fuente activa lee su tabla entera: una liquidación pasa de segundos a **123
   segundos**, de los cuales 0,22 s son el cálculo real.

9. **Concepto `NETO_GARANT`** — si el bloque 2 no lo encuentra, crearlo **a mano** en la ficha de
   conceptos. Es un solo registro, y evita reimportar el paquete:

   | Campo | Valor |
   |---|---|
   | Código | `NETO_GARANT` |
   | Vigencia Desde | `12/01/2023` |
   | Descripción | `Neto garantizado (objetivo grossing-up)` |
   | Nombre Impresión | `Neto garantizado` |
   | Tipo Concepto | **Informativo** |
   | Orden Cálculo | `5` |
   | Fórmula | `NETO_GU * (1 + DIAS_VAC_INICIO / 150)` |
   | Activo | sí |
   | Aplica A | Todos |

   El tipo **Informativo** no es un detalle: `CalcNetoDesdeBD` suma haberes, retenciones, descuentos
   y seguridad social. Un Informativo emite su línea —auditable, con su detalle de variables— sin
   mover el neto que el bucle de grossing-up trata de alcanzar. Si se carga como Haber, el
   grossing-up no converge.

   La fórmula **no puede** referenciar `COMPLEMENTO_GU`: el objetivo se movería en cada iteración.
   El motor corta con error si lo detecta.

10. **Config. RRHH** — si el bloque 1 muestra los campos vacíos, completar
    `Concepto Neto Garantizado (Grossing-up)` = `NETO_GARANT` y
    `Acumulador Haberes Gravados` = `BASE_IG4`.

11. **Parámetros y escalas** — si el bloque 5 no muestra los `NETO_GU_*`, hay que reimportar esa
    tabla. Leer la Fase E antes de hacerlo.

---

## Fase E — Que no se vuelva a romper

12. **El flag que borró los filtros.** En la ficha del paquete de configuración, revisar la columna
    **«Eliminar los registros de tablas antes del procesamiento»** para la tabla **60029** (y de
    paso para el resto). Si está tildada, cada importación vacía la tabla antes de aplicar; si el
    apply no llega a esa tabla, las filas quedan borradas y **no hay error**.

    Es la explicación más probable de por qué desaparecieron los 76 filtros: el archivo exportado
    los tenía en todas las versiones, así que se perdieron en la base, no en el archivo.

13. **Regla general:** no reimportar el ConfigPackage completo sobre tablas que ya están bien.
    Importar sólo la tabla que haga falta.

---

## Fase F — Revisar a mano (ninguna la resuelve un script)

14. **`Invertir Signo`.** Ese campo **no viaja en el ConfigPackage**, así que la carga de fracciones
    deja las 1208 filas en `0`. Si alguna fracción lo tenía en `1`, hay que volver a marcarla. El
    paso 4 de `CargarFraccionesMeta4.sql` lista los candidatos (conceptos de tipo 2, 4 y 5).

15. **Concepto 1223.** Su fórmula es `MAX(GARANTIA_MAREA, PROD_MAREA)` y **ninguna de las dos
    variables existe**. O se cierra la vigencia, o se crean las Fuente Datos.

16. **Concepto 4743 — el prorrateo está en la rama equivocada:**

    ```
    -round( IF( ES_GROSSING_UP > 0,
                COMPLEMENTO_GU,                          <- sin prorratear
                <base> / 30 * MIN(DIAS_VAC_PERIODO, 30)  <- prorrateado
           ), PRECISION_REDONDEO )
    ```

    Compará con el 1003 y el 3553, donde el multiplicador va **afuera** del `IF`. Hoy no muerde
    porque `MIN(31,30)/30 = 1`, pero con menos días de vacaciones en el período la rama de
    grossing-up descuenta el mes entero en vez de la parte proporcional.

    Fórmula corregida (el único cambio es dónde cierra el paréntesis del `IF`):

    ```
    -round(
        IF(
            ES_GROSSING_UP > 0,
            COMPLEMENTO_GU,
            IF(BASICO_EsFCY, BASICO * TC_CERCANO, #1003 + #1053 + #1054 + #1055 + #4573 + #2703)
        ) / 30 * MIN(
            DIAS_VAC_PERIODO,
            30
        ),
        PRECISION_REDONDEO
    )
    ```

    Con grossing-up el neto está clavado al objetivo, así que el bucle compensa subiendo el bruto:
    el error no se ve en el neto, se ve en el Total de Haberes, en las bases y —por lo tanto— en
    contribuciones, retención y SICOSS. Para un empleado con vacaciones **sin** grossing-up la rama
    `else` ya prorratea bien, así que no cambia nada.

    Cargalo con **vigencia nueva**, no editando la del 12/01/2023: las liquidaciones ya calculadas
    con la fórmula vieja tienen que seguir reproduciéndose igual.

17. **Redondeos que no cancelan.** El 1003 redondea a `0,0001` y el 4743 a `PRECISION_REDONDEO`
    (= 1). Están pensados para anularse y dejan `0,489`, que es lo que aparece como `BASE_SS_TRAB`
    en las fórmulas del 4751 y el 4752.

---

## Fase G — Validar

18. Reiniciar el service tier (o `Sync-NAVTenant`) para vaciar la caché de configuración.
19. Volver a correr `EstadoConfiguracion.sql`: todo en verde antes de liquidar.
20. Liquidar enero 2026 y comparar **Guillermo Re** contra el recibo. Es el caso difícil: tiene
    vacaciones **y** grossing-up, la única combinación que expuso la doble contabilización.
    Para el desglose: [`scripts/DiagnosticoLiquidacion.sql`](scripts/DiagnosticoLiquidacion.sql)
    (las grillas 5 y 6 son las de grossing-up).
21. Si vuelve a tardar de más, perfilar y mirar el reparto: `ResolveFuente` alto = faltan filtros.

---

## La decisión que sigue abierta

La corrección de las fracciones asume que **`BASE_IG4` son los haberes habituales** y
`BASE_EXT_IG4` los extraordinarios, y que las fórmulas 4750, 7000 y 5010 las suman porque son
disjuntas. Lo respaldan tres cosas:

- 9 de los 13 conceptos de `BASE_EXT_IG4` ya eran disjuntos de `BASE_IG4`;
- el campo de cabecera que alimenta `BASE_IG4` se llama **«Haberes Ordinarios Gravados»**;
- la 5010 lleva `YTD_HAB_GRAV_ANUAL` en paralelo a `YTD_HAB_EXTORD_ANUAL`.

Si resultara al revés —que `BASE_IG4` es la base total—, el arreglo es el otro: sacar el
`+ BASE_EXT_IG4` de esas tres fórmulas y **no** tocar las fracciones. **No hacer las dos cosas.**

Si ya cargaste las fracciones con los 4 duplicados (por ejemplo, con una versión anterior del
script), [`scripts/CorregirBaseIG4Duplicada.sql`](scripts/CorregirBaseIG4Duplicada.sql) los quita
sin recargar toda la tabla.
