/* NOVEDADES PENDIENTES DE ABRIL DE 2026 QUE NINGUNA LIQUIDACIÓN TOMABA (22 filas). Análisis del 21/10/2026.
   Valores anteriores, para revertir:
     8850 (8 filas: 6212 6490 6811 6947 6979 7341 7531 7579, de 03664 04105 04526 04659 04677 04848 04921 04929): No. Proyecto = el de la marea (PP-128-000062, PP-802-000009 o PP-801-000009), Fecha 25/4.
       Meta4 las descontó en la corrida del 25/4 (la regular de BC, 24-30/4, con proyecto de nómina PN-...): con el proyecto de la marea quedaban huérfanas (el cierre cubre sólo hasta el 23/4). En blanco, el proyecto lo decide el historial de estados a la fecha.
     8850 (7242 y 7243, 04802): Fecha 12/4, sin proyecto ni tipo. Su final cubre 1-10/4: fuera de toda cobertura.
     8830 (7336, 04848): Fecha 25/4, proyecto PP-801-000009. Es el descuento de poder que Meta4 hizo en la corrida de pilotaje del 21/4; el cierre del proyecto cubre hasta el 23/4.
     4057 (11527, 01767): Fecha 30/4; su final cubre 1-13/4.
     5310 (4453, 04351): Fecha 20/4; su regular cubre 23-30/4. (3548, 02879): Fecha 20/4; su final cubre 1-8/4.
     2041 (11339 11342 11343 11345 11346 11347 11350, de 04046 03104 03791 04760 04802 04393 04889): Tipo Liq. REGULAR; esos empleados sólo tienen LIQ_FINAL en abril. El 2041 es el indicador de guardia de puerto que usa el 2013.
   Con tipo explícito la fecha no filtra (NovedadAplica desde el 3/10), de modo que en estas dos últimas basta el tipo.
   NO se tocan: las 3973 (32) y las 2043 (8), cuyo tipo y proyecto ya coinciden con su liquidación y sólo estaban sin recalcular; 5310 de 02297, 02804 y 90308, que no tienen ninguna liquidación de abril en BC (necesitan una decisión).
   Rollback: devolver los valores anteriores de arriba.
   Después: reiniciar el servicio y recalcular abril. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @N nvarchar(300) = N'dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890]';
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [No_ Proyecto]='', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [No_ Movimiento] IN (6212,6490,6811,6947,6979,7341,7531,7579) AND [Cód_ Concepto]='8850' AND [Cód_ Período]='202604' AND Estado=0 AND [No_ Proyecto]<>'';
SELECT @@ROWCOUNT AS Proyecto_en_blanco_8850_esperado_8;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET Fecha='20260410', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [No_ Movimiento] IN (7242,7243) AND [Cód_ Concepto]='8850' AND [Cód_ Período]='202604' AND Estado=0 AND Fecha='20260412';
SELECT @@ROWCOUNT AS Fecha_8850_04802_esperado_2;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET Fecha='20260423', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [No_ Movimiento] IN (7336,4453) AND [Cód_ Período]='202604' AND Estado=0 AND Fecha IN ('20260425','20260420');
SELECT @@ROWCOUNT AS Fecha_8830_04848_y_5310_04351_esperado_2;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET Fecha='20260413', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [No_ Movimiento]=11527 AND [Cód_ Concepto]='4057' AND [Cód_ Período]='202604' AND Estado=0 AND Fecha='20260430';
SELECT @@ROWCOUNT AS Fecha_4057_01767_esperado_1;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET Fecha='20260408', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [No_ Movimiento]=3548 AND [Cód_ Concepto]='5310' AND [Cód_ Período]='202604' AND Estado=0 AND Fecha='20260420';
SELECT @@ROWCOUNT AS Fecha_5310_02879_esperado_1;
UPDATE dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Cód_ Tipo Liq_]='LIQ_FINAL', [$systemModifiedAt]=SYSUTCDATETIME()
 WHERE [No_ Movimiento] IN (11339,11342,11343,11345,11346,11347,11350) AND [Cód_ Concepto]='2041' AND [Cód_ Período]='202604' AND Estado=0 AND [Cód_ Tipo Liq_]='REGULAR';
SELECT @@ROWCOUNT AS Tipo_2041_esperado_7;
COMMIT;
