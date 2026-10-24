/* NO HUBO CAMBIO DE PRECIO DEL FRANCO EN ABRIL (22/10/2026). Indicación del usuario: el precio del franco no cambió; lo que difiere debe ser el puesto con que se liquidan. Se deshace lo que se hizo para reproducir el +20 %:
   1. FactorFrancoNovedadAbril.sql (22/10): se borran las 18 novedades FACTOR_FRANCO, la fuente FACTOR_FRANCO_NOV con sus 3 filtros, el concepto FACTOR_FRANCO y la vigencia del 1/4 del 1063 (la del 1/1 vuelve a quedar abierta).
   2. FrancoAbril20PctYBajaPuerto.sql (21/10), sólo la parte de VALOR_FRANCO: se borran las seis filas del 1/4/2026 (175/75 OF02 3.600, 175/75 OF04 3.060, 768/19 OF01 4.140, 768/19 OF03 3.240, ESP FE01 4.140, ESP FE02 3.600); las del 1/1 siguen
      (3.000 / 2.550 / 3.450 / 2.700 / 3.450 / 3.000 USD, las de la lista de precios de Meta4). La parte de Personal Proyecto (baja 24/4) no se toca.
   Con esto la REGULAR de abril de los 18 oficiales da lo de Meta4 (116.025 / 122.850 / 136.500 / 156.975 por día). Quedan distintas las finales de 04163, 04836 y 04455, que Meta4 valuó a 141.780 / 141.780 / 165.600 (1,2 x), mientras 02450,
   con el mismo puesto y categoría que 04455, la valuó normal (139.000).
   Rollback: volver a correr FrancoAbril20PctYBajaPuerto.sql (sólo la parte de VALOR_FRANCO) y FactorFrancoNovedadAbril.sql.
   Después: reiniciar el servicio y recalcular la REGULAR de abril de los 17 (todos menos 04649) y las finales de 04649, 04163, 04836 y 04455. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
DELETE FROM dbo.[ArbuTest$Novedad Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Concepto]='FACTOR_FRANCO' AND [Estado]=2;
SELECT @@ROWCOUNT AS novedades_borradas_esperado_18;
DELETE FROM dbo.[ArbuTest$Filtro Fuente Datos Liq_$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]='FACTOR_FRANCO_NOV';
SELECT @@ROWCOUNT AS filtros_esperado_3;
DELETE FROM dbo.[ArbuTest$Fuente Datos Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Nombre Variable]='FACTOR_FRANCO_NOV';
SELECT @@ROWCOUNT AS fuente_esperado_1;
DELETE FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='FACTOR_FRANCO';
SELECT @@ROWCOUNT AS concepto_esperado_1;
DELETE FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código]='1063' AND [Vigencia Desde]='20260401' AND [Factor Importe Consumo]=N'IFZERO(FACTOR_FRANCO_NOV, 1)';
SELECT @@ROWCOUNT AS c1063_borrada_esperado_1;
UPDATE dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Vigencia Hasta]='17530101',[$systemModifiedAt]=SYSUTCDATETIME() WHERE [Código]='1063' AND [Vigencia Desde]='20260101' AND [Vigencia Hasta]='20260331';
SELECT @@ROWCOUNT AS c1063_reabierta_esperado_1;
DELETE FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base]='VALOR_FRANCO' AND [Vigencia Desde]='20260401' AND [Cód_ Categoría] IN ('OF02','OF04','OF01','OF03','FE01','FE02');
SELECT @@ROWCOUNT AS valor_franco_borradas_esperado_6;
SELECT [Cód_ Parámetro] p,CONVERT(varchar(10),[Vigencia Desde],120) d,CAST([Valor] AS decimal(10,2)) v FROM dbo.[ArbuTest$Parámetro Vigente$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Cód_ Parámetro Base]='VALOR_FRANCO' AND ([Cód_ Categoría] LIKE 'OF%' OR [Cód_ Categoría] LIKE 'FE%') ORDER BY 1,2;
SELECT [Código],CONVERT(varchar(10),[Vigencia Desde],120) d,CONVERT(varchar(10),[Vigencia Hasta],120) h FROM dbo.[ArbuTest$Concepto Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [Código] IN ('1063','FACTOR_FRANCO') ORDER BY 1,2;
COMMIT;
