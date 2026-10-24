/* ESCALA DE LAS CATEGORÍAS DE OFICIALES COMO EN META4 (22/10/2026). El 1603 (categoría superior) es base / escala de la categoría x escala de la categoría del puesto - base. En BC las categorías OF01 a OF05
   tenían todas "% Escala" = 100, así que un oficial con puesto superior a su categoría cobraba cero. 04826 tiene categoría OF04 (765.000 de sueldo de navegación) y puesto OF02 (900.000) desde el 13/2/2026 (BC y
   Meta4 coinciden: MQ01 = OF02): Meta4 le paga 17,647 % (100 / 85 - 1) de la base: 99.540 en la corrida de pilotaje (base 564.060), 169.470 en el cierre de abril.
   Escala de Meta4 (M4T_VAL_CONVENIO_CATEG_PUESTO, concepto 2082, vigente desde el 1/7/2025, convenio OF): OF01 115, OF02 100, OF03 90, OF04 85, OF05 77,83 (la combinación categoría/puesto da el mismo valor para
   la categoría sola: OF04 con MQ01 o MQ03 = 85, OF02 = 100). Se carga en los dos convenios de BC (175/75 y 768/19). Para quien tiene puesto = categoría no cambia nada (escala / escala = 1).
   Valores anteriores: 100 en todas. Rollback: volver a 100. Efecto colateral: 04826 pasa a cobrar 1603 desde el 13/2 (Meta4 empieza en marzo): se ve en febrero.
   Después: reiniciar el servicio y recalcular abril en orden. */
SET NOCOUNT ON;
UPDATE c SET c.[_ Escala]=v.e, c.[$systemModifiedAt]=SYSUTCDATETIME()
FROM dbo.[ArbuTest$Categoría CCT$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] c
JOIN (VALUES (N'OF01',115.0),(N'OF02',100.0),(N'OF03',90.0),(N'OF04',85.0),(N'OF05',77.83)) v(cat,e) ON v.cat=c.[Código]
WHERE c.[Cód_ Convenio] IN (N'175/75',N'768/19') AND c.[_ Escala]=100 AND v.e<>100;
SELECT @@ROWCOUNT AS cambiadas;
SELECT [Cód_ Convenio] cv,[Código] c,[_ Escala] e FROM dbo.[ArbuTest$Categoría CCT$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] LIKE 'OF%' ORDER BY 1,2;
