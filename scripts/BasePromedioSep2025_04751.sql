/* BASE_PROMEDIO DE SEPTIEMBRE DE 2025 DE 04751: SÓLO LA FASE VIGENTE (alta 23/9/2025).
   La carga de la historia sumó para ese mes 522.929,96 = 279.292,29 (TOT_REM_IMP de la liquidación de la fase nueva) + 243.637,67 (TOT_PROMEDIOS de la final de la fase
   anterior, baja el 5/9/2025). Meta4 promedia sólo la fase vigente: PROM_6_ULT_MES 2.732.877,21 = (279.292,29 + 11.654.269 de oct-ene) / 131 días x 30. Con la fase vieja
   BC daba 2.686.147 (12.177.198 / 136 x 30) y las vacaciones no gozadas de la final quedaban 11.215 abajo (3973) y 934 (3974).
   Junto con el cambio de Cod50016 (CalcDiasPrestacionPromedioVac no cuenta fases anteriores a la vigente): divisor 131.
   Rollback: volver el importe a 522929,96. */
SET XACT_ABORT ON; SET NOCOUNT ON;
BEGIN TRAN;
SELECT [Importe] antes FROM dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] WHERE [No_ Empleado]=N'04751' AND [Cód_ Período]=N'202509' AND [Cód_ Tipo Liq_]=N'HIST_REMUN' AND [Cód_ Concepto]=N'BASE_PROMEDIO';
UPDATE dbo.[ArbuTest$Línea Liquidación$d4f5a6b7-c8d9-4e0f-a1b2-c3d4e5f67890] SET [Importe]=279292.29, [$systemModifiedAt]=SYSUTCDATETIME()
WHERE [No_ Empleado]=N'04751' AND [Cód_ Período]=N'202509' AND [Cód_ Tipo Liq_]=N'HIST_REMUN' AND [Cód_ Concepto]=N'BASE_PROMEDIO' AND ABS([Importe]-522929.96)<1;
SELECT @@ROWCOUNT AS Actualizadas_esperado_1;
COMMIT;
