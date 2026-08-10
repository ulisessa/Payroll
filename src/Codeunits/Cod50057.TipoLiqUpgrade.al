namespace UAS.Payroll;

codeunit 50057 "Tipo Liq. Upgrade"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    var
        GestionTipoLiq: Codeunit "Gestión Tipo Liq.";
    begin
        GestionTipoLiq.Sembrar();
        GestionTipoLiq.MigrarDatos();
    end;
}
