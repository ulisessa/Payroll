/* ============================================================================
   ¿Hay más asignaciones con el buque o la marea mal?

   Disparado por PP-119-000308 del legajo 00794, que figura con Marea 000307 —el
   de la asignación anterior— en vez de 000308.

   "Buque" y "Marea" de Personal Proyecto son COPIAS: se llenan desde las
   dimensiones globales del proyecto al elegirlo (Tab60009, OnValidate de
   "No. Proyecto"). Una copia puede estar mal por dos motivos que son problemas
   distintos y se arreglan distinto:

     · El PROYECTO tiene mal su dimensión, y la asignación copió fielmente un
       dato equivocado. Se arregla en el proyecto, y después hay que rehacer las
       copias.
     · El proyecto está bien pero la asignación quedó VIEJA: se creó cuando la
       dimensión era otra, y corregir el proyecto después no reescribe lo ya
       copiado. Se arregla sólo en la asignación.

   Los bloques 1 y 2 los separan. El 3 no depende de ninguno de los dos: mira el
   propio código del proyecto, que ya lleva el buque y la marea adentro
   (PP-119-000308), así que detecta el caso en que proyecto y asignación estén
   los dos mal de la misma forma.

   NINGÚN BLOQUE ESCRIBE NADA.
   ========================================================================== */


/* ---------------------------------------------------------------------------
   BLOQUE 1 — Asignaciones cuya copia NO coincide con la dimensión actual del
   proyecto. Son las copias viejas.
--------------------------------------------------------------------------- */
SELECT pp.[No_ Empleado],
       pp.[No_ Proyecto],
       pp.[Buque]                        AS BuqueEnLaAsignacion,
       j.[Global Dimension 1 Code]       AS BuqueDelProyecto,
       pp.[Marea]                        AS MareaEnLaAsignacion,
       j.[Global Dimension 2 Code]       AS MareaDelProyecto,
       pp.[Fecha Alta Asignación],
       pp.[Fecha Baja]
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
       ON j.[No_] = pp.[No_ Proyecto]
WHERE  pp.[Buque] <> j.[Global Dimension 1 Code]
   OR  pp.[Marea] <> j.[Global Dimension 2 Code]
ORDER  BY pp.[No_ Proyecto], pp.[No_ Empleado];
GO


/* ---------------------------------------------------------------------------
   BLOQUE 2 — Proyectos cuya dimensión no coincide con su propio código.

   El código de una marea es PP-<buque>-<marea>, así que el código y las
   dimensiones tienen que decir lo mismo. Si no lo dicen, el problema está en el
   proyecto y todas sus asignaciones lo heredaron.

   Sólo los PP-: los PN- de nómina no siguen ese patrón.
--------------------------------------------------------------------------- */
SELECT j.[No_]                                                AS Proyecto,
       j.[Description],
       PARSENAME(REPLACE(SUBSTRING(j.[No_], 4, 100), '-', '.'), 2) AS BuqueEnElCodigo,
       j.[Global Dimension 1 Code]                            AS BuqueEnLaDimension,
       PARSENAME(REPLACE(SUBSTRING(j.[No_], 4, 100), '-', '.'), 1) AS MareaEnElCodigo,
       j.[Global Dimension 2 Code]                            AS MareaEnLaDimension,
       j.[Starting Date], j.[Ending Date]
FROM   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
WHERE  j.[No_] LIKE 'PP-%-%'
   AND (PARSENAME(REPLACE(SUBSTRING(j.[No_], 4, 100), '-', '.'), 2) <> j.[Global Dimension 1 Code]
     OR PARSENAME(REPLACE(SUBSTRING(j.[No_], 4, 100), '-', '.'), 1) <> j.[Global Dimension 2 Code])
ORDER  BY j.[No_];
GO


/* ---------------------------------------------------------------------------
   BLOQUE 3 — El control que no depende de nadie: la asignación contra el CÓDIGO
   del proyecto.

   Si el proyecto tiene mal la dimensión Y la asignación copió esa dimensión
   mala, los bloques 1 y 2 por separado podrían no verlo como el mismo problema.
   Este los agarra a los dos de una, porque compara contra el código, que es el
   único dato que nadie puede haber editado sin renombrar el proyecto entero.

   Es el bloque que debería mostrar el caso de 00794 / PP-119-000308.
--------------------------------------------------------------------------- */
SELECT pp.[No_ Empleado],
       pp.[No_ Proyecto],
       pp.[Marea]                                                 AS MareaEnLaAsignacion,
       PARSENAME(REPLACE(SUBSTRING(pp.[No_ Proyecto], 4, 100), '-', '.'), 1) AS MareaEnElCodigo,
       pp.[Buque]                                                 AS BuqueEnLaAsignacion,
       PARSENAME(REPLACE(SUBSTRING(pp.[No_ Proyecto], 4, 100), '-', '.'), 2) AS BuqueEnElCodigo,
       pp.[Fecha Alta Asignación],
       pp.[Fecha Baja]
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
WHERE  pp.[No_ Proyecto] LIKE 'PP-%-%'
   AND (pp.[Marea] <> PARSENAME(REPLACE(SUBSTRING(pp.[No_ Proyecto], 4, 100), '-', '.'), 1)
     OR pp.[Buque] <> PARSENAME(REPLACE(SUBSTRING(pp.[No_ Proyecto], 4, 100), '-', '.'), 2))
ORDER  BY pp.[No_ Proyecto], pp.[No_ Empleado];
GO


/* ---------------------------------------------------------------------------
   BLOQUE 4 — Cuántos son, para saber si esto es un caso suelto o un patrón.
--------------------------------------------------------------------------- */
SELECT 'Asignaciones desalineadas del proyecto' AS Control,
       COUNT(*) AS Casos,
       COUNT(DISTINCT pp.[No_ Proyecto]) AS Proyectos,
       COUNT(DISTINCT pp.[No_ Empleado]) AS Empleados
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = pp.[No_ Proyecto]
WHERE  pp.[Buque] <> j.[Global Dimension 1 Code] OR pp.[Marea] <> j.[Global Dimension 2 Code]

UNION ALL
SELECT 'Proyectos con dimensión distinta al código',
       COUNT(*), COUNT(*), 0
FROM   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j
WHERE  j.[No_] LIKE 'PP-%-%'
   AND (PARSENAME(REPLACE(SUBSTRING(j.[No_], 4, 100), '-', '.'), 2) <> j.[Global Dimension 1 Code]
     OR PARSENAME(REPLACE(SUBSTRING(j.[No_], 4, 100), '-', '.'), 1) <> j.[Global Dimension 2 Code])

UNION ALL
SELECT 'Asignaciones distintas al código del proyecto',
       COUNT(*), COUNT(DISTINCT pp.[No_ Proyecto]), COUNT(DISTINCT pp.[No_ Empleado])
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
WHERE  pp.[No_ Proyecto] LIKE 'PP-%-%'
   AND (pp.[Marea] <> PARSENAME(REPLACE(SUBSTRING(pp.[No_ Proyecto], 4, 100), '-', '.'), 1)
     OR pp.[Buque] <> PARSENAME(REPLACE(SUBSTRING(pp.[No_ Proyecto], 4, 100), '-', '.'), 2));
GO


/* ---------------------------------------------------------------------------
   BLOQUE 5 — La corrección, COMENTADA. No la corras sin haber mirado los
   bloques 1 a 3 y haber decidido cuál de los dos problemas es.

   Rehace la copia de la asignación desde la dimensión del proyecto. Sirve SÓLO
   si el proyecto está bien (bloque 2 en cero). Si el proyecto está mal, esto
   propaga el error a más filas en vez de arreglarlo: primero hay que corregir
   la dimensión del proyecto y recién después rehacer las copias.
--------------------------------------------------------------------------- */
/*
UPDATE pp
SET    pp.[Buque] = j.[Global Dimension 1 Code],
       pp.[Marea] = j.[Global Dimension 2 Code]
FROM   dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] pp
JOIN   dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] j ON j.[No_] = pp.[No_ Proyecto]
WHERE  pp.[Buque] <> j.[Global Dimension 1 Code]
   OR  pp.[Marea] <> j.[Global Dimension 2 Code];
*/
