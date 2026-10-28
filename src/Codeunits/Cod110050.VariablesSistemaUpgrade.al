namespace UAS.Payroll;

/// <summary>Siembra las Variables de Sistema que falten en cada actualización.</summary>
/// <remarks>
/// Sin tag de upgrade a propósito: no es una migración que se corre una vez, es un catálogo que
/// crece. Cada versión que agrega una variable necesita que esto vuelva a correr, y un tag lo
/// dejaría corriendo sólo la primera. Sembrar es idempotente —ver "Gestión Variables Sistema"—.
///
/// OJO: un publish de RAD no dispara Upgrade. En desarrollo hay que usar la acción "Sembrar" de la
/// página Variables de Sistema, que es la misma llamada.
/// </remarks>
codeunit 110050 "Variables Sistema Upgrade"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    var
        Gestion: Codeunit "Gestión Variables Sistema";
    begin
        Gestion.Sembrar();
    end;
}
