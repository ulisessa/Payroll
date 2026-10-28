---
tipo: proceso
tags: [migracion-meta4, atributos, convenios-cct, ausentismos, personal-proyecto]
fuente: [scripts/MigrarAtributosCCT_1_Meta4_Oracle.sql, scripts/MigrarAtributosCCT_2_BC_SqlServer.sql, scripts/MigrarAusentismos_1_Meta4_Oracle.sql, scripts/MigrarAusentismos_2_BC_SqlServer.sql, scripts/RellenarEstadoActivoTierra.sql, scripts/MigrarPersonalProyecto_4.sql, scripts/ExplorarPuestosMeta4.sql, scripts/MapearPuestosMeta4ACategorias.sql, scripts/puestos/1_NormalizarHistorialPuestos.pl, scripts/puestos/2_GenerarStaging.pl, scripts/puestos/3_ValidarContraMarea59.pl, scripts/puestos/4_MigrarPuestos.sql, scripts/ExplorarValSindicato_Meta4_Oracle.sql]
actualizado: 2026-10-04
---

# Migración Meta4 - atributos CCT, puestos y ausentismos

Las migraciones que **no son estados/fases** pero dependen de ellas. Mapa general: [[Migración desde Meta4 - mapa y orden de ejecución]].

## 1. Convenio y categoría -> atributos con vigencia

- **Por qué atributos y no la ficha**: el motor no lee `Employee."Cód. Convenio"` (respaldo). El par canónico sale de `Atributo Entidad Liq.` (Tab110005) vía `ParDeEntidad` (Cod50080) y `ResolverParDeAtributos` (Tab60011); el orden es asignación -> ficha -> atributos y **el último pisa**. Antes: 103 convenios y 95 categorías contra 2.974 empleados con estados (por eso casi nadie liquidaba). Después del 13/9/2026: **285 de 330 activos** resuelven el par ([[migracion-atributos-cct-meta4]], [[atributos-tipados]]).
- **Paso 1 (Oracle)**: `UNION ALL` de `ARBPRO.M4T_HIST_CONVENIOS` y `M4T_HIST_CATEGORIAS` (`TIPO`, `LEGAJO`, `FEC_INICIO`, `FEC_FIN`, `VALOR_M4`, `COMENT`), `ID_SOCIEDAD = '01'`, ~21.000 filas, puente `dbo.MIG_AtributosM4`.
- **Paso 2 (BC)**, tres cosas obligatorias: (1) **traducir convenio** (`MR`->729/15, `FE`->ESP, `EC`->130/75, `OF`->según flota, `JO`/`FA` con el mismo código); la categoría no se traduce; (2) **resolver el padre de la categoría**: la clave de `Categoría CCT` es (convenio, código) -> el atributo de categoría guarda el convenio vigente **a esa fecha** en `Cód. Valor Padre` y se **parte** la categoría donde cambia el convenio; (3) **normalizar vigencias** (cierre el día antes del siguiente) porque la tabla rechaza superposiciones.
- **Por SQL y no por AL**: el `OnInsert` hace seis cosas y con 21.000 filas es inviable por página; se calculan `Cód. Valor Padre` y `Valor Numérico` (el único campo que lee `Fuente Datos`) a mano y el bloque 4 verifica.
- **Regla de oficiales** (bloque 0): buques 101-119 -> tangonero -> 175/75 (CAPECA); resto (126..129, 801, 802) -> potero -> 768/19 (AACPyPP). Es un **rango numérico = deuda**: un buque nuevo fuera del rango cae en potero sin avisar; debería ser un atributo `TIPO_BUQUE` sobre la entidad Buque (el modelo ya lo soporta).
- Pre-vuelo (3.a-3.g, todo CERO): par inexistente, legajos sin `Employee` (Meta4 tiene 6.490 con convenio, BC 4.806), categorías sin convenio, superposiciones, vigencias invertidas, choques con lo cargado (3.g: la **carga de arranque** hay que sacarla antes). Inserción en el bloque 4 (comentada, `BEGIN TRANSACTION`; mientras está abierta BC no puede guardar nada). Verificación 5.b: empleados con fase abierta que resuelven su par.
- **Normalizar antes de filtrar**: el `LEAD` que cierra cada vigencia tiene que ver todo; filtrando primero cerró una vigencia cuatro años tarde.
- Abierto: 11 activos de `CA` (faltan CA11/13/14/15 en 372/04), 5 con par inconsistente, 37 con convenio cerrado en Meta4 y fase abierta en BC; y `M4T_HIST_SINDICATOS` (ver `ExplorarValSindicato_Meta4_Oracle.sql`: busca el % de caja compensadora 8542 y fondo de desempleo 8543, creados como atributos **vacíos** `PCT_CAJA_COMPENSADORA`/`PCT_FDO_DESEMPLEO`; ver [[sindicato-obra-social-atributos]] y [[cuatro-conceptos-sin-disparar]]).

## 2. Ausentismos de tierra

- **El agujero**: `M4T_HIST_ESTADOS_EMPL` sólo cubre embarcados; los administrativos quedaron con cero estados. `M4T_AUSENTISMOS` tiene las ausencias **con fechas reales** (`FEC_INICIO`/`FEC_FIN`, tipo -> `AU*`; 9 = vacaciones): 15.202 filas de 1.561 legajos (1.079 embarcados, 482 de tierra).
- **Las fechas buenas son las del campo, no las del comentario** (texto libre desfasado de -7 a +30 días); validado contra `DIAS_VACACIONES` de `M4T_ACUMULADO_RL` del 90251 en ocho años.
- **Alcance = tierra** (`LEGAJO LIKE '8%' OR '9%'`): embarcados "ya está" 10.412 (92% materializado por Meta4), "falta" 945, tierra "falta" 3.845. Los 945 quedan **afuera a propósito**: el historial de un embarcado es denso y un `AU9` cae encima y `SincronizarContiguidad` cierra el anterior, **reescribiendo historia y moviendo el devengo de francos**. Los posteriores a 2025 van a mano.
- `MigrarAusentismos_1` **no migra nada** en sus bloques 1-4 (miden); el SELECT de exportación es el bloque 5 -> puente `dbo.MIG_AusentismosM4`. `_2`: pre-vuelo 2.a-2.e (códigos, legajos, fuera de fase, pisadas con estados, pisadas entre sí), **2.f proyecto de cada ausencia**: asignación vigente a esa fecha; si no hay, la primera del empleado (atribuido, no dato); si no, sin proyecto. Inserción en el bloque 3 (comentada), 3.b completa el proyecto de lo ya migrado, 4.d contrasta días de vacaciones contra Meta4.

## 3. Relleno `ACT` (`RellenarEstadoActivoTierra.sql`)

Tras los ausentismos los administrativos tienen **islas**: sin estado cubriendo un día, `Estado Actual` muestra la última ausencia, `GetEstado(fecha)` no encuentra nada y `ValidarEstadoExiste` corta el cálculo. Regla: todo día **dentro de una fase de alta** no cubierto por una ausencia es `ACT`. El relleno **no cruza una baja** (el relleno `OR` de `MigrarEstados_2` dejó 28 estados de hasta 54 días fuera de la empresa; el de 04513 se descubrió porque el motor liquidaba un mes de baja). El último tramo de una fase **abierta queda abierto**; el de una fase cerrada se cierra en la baja. Bloques: 1-2 miden, 3 inserta, 4 verifica.

## 4. Asignaciones (`MigrarPersonalProyecto_4.sql`)

Meta4 **no tiene** esta tabla: la asignación está implícita en que un estado apunte a un proyecto. Sin ella el motor corta con "El empleado %1 no está asignado al proyecto %2" (`ValidarAsignacionProyecto`, Cod50014). **Corre después de `MigrarEstados_2`**.
- **Por SQL es obligatorio**: `Personal Proyecto.OnInsert` llama a `SincronizarEstadoDesdeProyecto`, que **crearía un segundo estado** por asignación.
- Fechas de alta/baja: del **primer y último estado** del empleado en ese proyecto, no de las fechas del `Job` (un tripulante puede embarcar tarde o cortar la marea). Buque/Marea de las dimensiones 1 y 2 del `Job`; convenio y categoría del empleado (el trigger los exige con `TestField`).
- Bloques: 1 volumen, 2 pre-vuelo (empleados sin convenio/categoría; 2.d "¿está el par en los atributos?"), 3 inserción, 3.b corregir fechas existentes, 3.c completar convenio, 4 verificación, **5 previsualización de la derivación de las `PN-`** (tercera versión de la regla; las dos anteriores las atrapó la previsualización: cerraba nóminas con fechas de los noventa y movía 4.700 fechas en vez de 170). **La cobertura de una nómina son sus estados más los de las mareas de su buque**; tope = la nómina siguiente ([[nomina-no-es-intervalo-presencia]], [[previsualizar-antes-de-migrar]]).
- Una sola asignación por par empleado+proyecto (la PK): quien repite barco quedó con una que va del primer embarque al último desembarque -> ver `RecortarAsignacionesAlProyecto` en [[Migración Meta4 - correcciones y auditorías]].

## 5. Puestos (eje de la producción)

La **categoría del CCT paga el sueldo** y el **puesto paga la producción**; son listas distintas en Meta4 y la misma lista (`Categoría CCT`) en BC ([[puesto-vs-categoria-cct]], [[equivalencia-id-puesto-meta4]]). En A28/59 cinco tripulantes cobraron de menos 4.073.665,12 por usar la categoría.

1. `ExplorarPuestosMeta4.sql` (Oracle, DBeaver): `M4T_PUESTOS` (catálogo; **la tabla real es `M4T_PUESTOS_TRABAJO`** y la descripción es `N_PUESTO`, ver [[meta4-conectar-desde-powershell]]) e historial `M4T_HIST_PUESTOS` completo. `COMENT` es texto libre engañoso.
2. `MapearPuestosMeta4ACategorias.sql`: `#MapaPuesto` (`IdPuesto`, `CatBC`, `Certeza` exacta/decidida/sin mapeo, `Motivo`). 14 de 22 puestos embarcados coinciden exacto; 8 a mano (un `LIKE` mapeó mal "Contramaestre Argentino"). Los puestos de planta de tierra (PP, PZ, PD, PN, PM, PF, PE, PV, PC, PG, CM, MAE, ADM) quedan fuera; sin mapeo el concepto cae en la categoría del CCT.
3. `puestos/1_NormalizarHistorialPuestos.pl` -> `2_GenerarStaging.pl` (mapa `CB01=>OF01 ... PT02=>MR08`; cierra contra la fase de alta) -> `3_ValidarContraMarea59.pl` (simula puesto -> categoría -> `VALOR_CAL_ENT` -> producción y compara contra el recibo; fecha de referencia = arribo 29/01/2026, 633,639 t) -> `4_MigrarPuestos.sql` (crea el tipo de atributo `PUESTO`, `Espejo De` = 3, `Par CCT a Usar` = 2, y carga **10.107 de 14.810 vigencias**; quedan afuera 1.633 sin empleado en BC y 3.070 de tierra/`DES`; **42 activos con `DES` quedan en el fallback**).
4. **Orden**: publicar la extensión primero (el script usa dos valores de enum nuevos), luego Perl 1 -> 2, `sqlcmd -i cargaPuestos.sql` (llena `#Puesto`, 10.107 filas) y **el paso 4 en la misma sesión de `sqlcmd`** (`#Puesto` es temporal).
5. **Normalización**: una fila sin `FEC_FIN` significa "abierta cuando se escribió" y la pisa la siguiente (102 vigencias abiertas pisadas, 43 con fin dentro de la siguiente); el fin sale de la fila que **arranca última**, no del máximo de `FEC_FIN`.

> [!note] Discrepancia de memoria
> El índice de memoria dice "`M4T_HIST_PUESTOS` sigue sin migrar" pero la nota de detalle y el script `4_MigrarPuestos.sql` documentan que el puesto **sí** se migró el 18/9/2026. Prevalece el script. (Otra nota de memoria, `puesto-vs-categoria-cct`, dice además que la categoría exacta de `M4T_HIST_CATEGORIAS` no se trajo y que el 23/9/2026 aparecieron 61 de 374 empleados con categoría distinta a Meta4; eso contradice el "285 de 330 resuelven" de la migración de atributos del 13/9 y queda **sin verificar** cuál refleja el estado actual.)

## Ver también

[[Tabla - Atributo Entidad Liq]], [[Tabla - Tipo Atributo Liq]], [[Tabla - Valor Atributo Liq]], [[Tabla - Personal Proyecto]], [[Atributos tipados]], [[Migración Meta4 - estados y fases]].
