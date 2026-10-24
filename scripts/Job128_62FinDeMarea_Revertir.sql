/* REVIERTE Job128_62FinDeMarea.sql (22/10/2026). El fin del proyecto PP-128-000062 vuelve al 22/4: es la LLEGADA real (el estado PL ocupa el 22 y el 23), y con el 23/4 la tripulación pasa de 21 días de navegación y 2 de puerto
   (lo que paga Meta4) a 22 y 1: 03753 y 29 más perdían 9.300 de bruto cada uno. La CLC (llegada 23/4, 24 días) cuenta hasta el último día de puerto. Los 24 días de enrolamiento y el tipo de cambio del 23/4 (1.365) se resuelven en el código,
   no moviendo la fecha del proyecto. Después: reiniciar el servicio y volver a recalcular el CIERRE_MAREA de abril de los 30. */
SET NOCOUNT ON;
UPDATE dbo.[ArbuTest$Job$437dbf0e-84ff-417a-965d-ed2bb9650972] SET [Ending Date]='20260422' WHERE [No_]='PP-128-000062' AND [Ending Date]='20260423';
SELECT @@ROWCOUNT AS esperado_1;
