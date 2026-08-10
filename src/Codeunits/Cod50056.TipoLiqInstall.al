namespace UAS.Payroll;

codeunit 50056 "Tipo Liq. Install"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        GestionTipoLiq: Codeunit "Gestión Tipo Liq.";
    begin
        GestionTipoLiq.Sembrar();
        GestionTipoLiq.MigrarDatos();
    end;
}
