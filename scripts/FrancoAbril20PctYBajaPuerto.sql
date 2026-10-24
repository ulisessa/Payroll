/* VALOR DEL FRANCO DE OFICIALES +20 % DESDE EL 1/4/2026 Y UN DÍA MÁS DE PUERTO PARA 40 EMPLEADOS. Decisión del usuario (21/10/2026).
   1. VALOR_FRANCO. Meta4 valúa en abril el franco de oficiales a 141.780 (OF04) y 165.600 (OF02), exactamente 1,2 x los 118.150 y 138.000 que sale de BC (el precio manual que traían las tres novedades 1062 anuladas). Las seis filas
      de VALOR_FRANCO (USD, TC_COMPRADOR) pasan a una vigencia nueva desde el 1/4/2026 con Valor x 1,2; la del 1/1/2026 queda como está:
        175/75 OF02 3.000 -> 3.600 | 175/75 OF04 2.550 -> 3.060 | 768/19 OF01 3.450 -> 4.140 | 768/19 OF03 2.700 -> 3.240 | ESP FE01 3.450 -> 4.140 | ESP FE02 3.000 -> 3.600.
      768/19 OF02 y 768/19 OF04 no tienen fila propia: resuelven a las de 175/75 (convenio OF según categoría). VALOR_FRANCO_EMP (franco de la empresa) no se toca: con el convenio por encima de él, el 2083 (a cuenta de futuros aumentos
      de francos) tiene que dar 0, que es lo que informa Meta4.
   2. PERSONAL PROYECTO. 39 empleados tienen en el 1083 exactamente un día de precio menos que Meta4 y 02452 tiene 1,06 días: 01477 02452 03062 03487 03664 03777 04066 04105 04163 04450 04455 04518 04526 04586 04591 04659 04677 04714 04724
      04738 04791 04822 04825 04826 04836 04838 04839 04840 04841 04848 04868 04906 04913 04914 04915 04919 04921 04923 04924 04932. Todos tienen una asignación a su marea (PP-...) con Fecha Baja 23/4/2026. Se pasa a 24/4/2026 para que cubra
      el 23, día en puerto (estado PL), que Meta4 paga con el 1083.
      Valor anterior: Fecha Baja = 2026-04-23 en las 40 filas.
   CORRECCIÓN (misma fecha): la primera versión del INSERT copiaba TODAS las filas de VALOR_FRANCO del 1/1 (15) y no sólo las seis de oficiales: creó además 9 filas de 729/15 MR00..MR08 con +20 %. Se borraron (Notas "Abril 2026: +20 %") y el script ya filtra Categoría OF% o FE%.
   Rollback: borrar las seis filas de VALOR_FRANCO del 2026-04-01 y devolver Fecha Baja a 2026-04-23.
   Después: reiniciar el servicio y recalcular abril de los 40 empleados (y todo el que tenga francos de oficiales en abril). */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
IF EXISTS (SELECT 1 FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base]=N'VALOR_FRANCO' AND [Vigencia Desde]='20260401')
BEGIN PRINT 'Ya existen las vigencias de abril'; ROLLBACK; RETURN; END;
DECLARE @P nvarchar(300) = N'dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
DECLARE @cc nvarchar(max), @sql nvarchar(max);
SET @cc = (SELECT STRING_AGG(QUOTENAME(c.name), ',') FROM sys.columns c WHERE c.object_id = OBJECT_ID(@P) AND c.name <> 'timestamp' AND c.name NOT LIKE '$system%' AND c.name NOT IN (N'Vigencia Desde', N'Valor', N'Notas'));
SET @sql = N'INSERT ' + @P + N' ([Vigencia Desde],[Valor],[Notas],' + @cc + N',[$systemId],[$systemCreatedAt],[$systemCreatedBy],[$systemModifiedAt],[$systemModifiedBy]) SELECT ''20260401'', [Valor] * 1.2, N''Abril 2026: +20 % (Meta4 valúa el franco de oficiales a 141.780 / 165.600)'', ' + @cc
  + N',NEWID(),SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'',SYSUTCDATETIME(),''00000000-0000-0000-0000-000000000000'' FROM ' + @P + N' WHERE [Cód_ Parámetro Base]=N''VALOR_FRANCO'' AND [Vigencia Desde]=''20260101'' AND ([Cód_ Categoría] LIKE N''OF%'' OR [Cód_ Categoría] LIKE N''FE%'');';
EXEC sp_executesql @sql;
SELECT @@ROWCOUNT AS VALOR_FRANCO_altas_esperado_6;
UPDATE p SET p.[Fecha Baja]='20260424', p.[$systemModifiedAt]=SYSUTCDATETIME()
FROM dbo.[ArbuTest$Personal Proyecto$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] p
WHERE p.[No_ Empleado] IN ('01477','02452','03062','03487','03664','03777','04066','04105','04163','04450','04455','04518','04526','04586','04591','04659','04677','04714','04724','04738','04791','04822','04825','04826','04836','04838','04839','04840','04841','04848','04868','04906','04913','04914','04915','04919','04921','04923','04924','04932')
  AND p.[No_ Proyecto] LIKE 'PP-%' AND p.[Fecha Baja]='20260423';
SELECT @@ROWCOUNT AS Personal_Proyecto_esperado_40;
SELECT [Cód_ Parámetro] pa, CONVERT(varchar(10),[Vigencia Desde],120) d, CAST([Valor] AS decimal(18,2)) v FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base]=N'VALOR_FRANCO' ORDER BY 1,2;
COMMIT;
