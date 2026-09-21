namespace UAS.Payroll;

using Microsoft.HumanResources.Setup;

/// <summary>
/// Siembra los dos punteros de Config. Recursos Humanos que reemplazan nombres que antes estaban
/// escritos en el motor: el concepto que calcula el neto garantizado del grossing-up, y el
/// acumulador del que sale "Haberes Ordinarios Gravados".
/// </summary>
/// <remarks>
/// Sin este upgrade, una instalación existente publica la versión nueva y se queda con los dos
/// campos en blanco: el grossing-up dejaría de aplicarse y "Haberes Ordinarios Gravados" quedaría
/// en cero. Los valores que se siembran son exactamente los que el motor tenía a fuego, así que el
/// comportamiento no cambia al publicar.
///
/// Sólo escribe si el campo está vacío. Un upgrade puede correr más de una vez —una por empresa, y
/// otra vez si se reinstala— y no tiene que pisar lo que alguien haya configurado a mano.
///
/// El concepto NETO_GARANT en sí no se crea acá: viene en el ConfigPackage, junto con su fórmula
/// y su vigencia. Si todavía no está cargado, el campo queda apuntando a un código inexistente y
/// ResolverNetoGarantizado no encuentra versión vigente, que es el mismo efecto que dejarlo en
/// blanco: sin grossing-up, sin error.
/// </remarks>
codeunit 110038 "Neto Garantizado Upgrade"
{
    Subtype = Upgrade;

    var
        CodConceptoNetoGarant: Label 'NETO_GARANT', Locked = true;
        CodAcumHaberesGravados: Label 'BASE_IG4', Locked = true;

    trigger OnUpgradePerCompany()
    begin
        SembrarPunteros();
    end;

    procedure SembrarPunteros()
    var
        HRSetup: Record "Human Resources Setup";
        Modificado: Boolean;
    begin
        if not HRSetup.Get() then
            exit;

        if HRSetup."Cód. Concepto Neto Garantizado" = '' then begin
            HRSetup."Cód. Concepto Neto Garantizado" := CopyStr(CodConceptoNetoGarant, 1, MaxStrLen(HRSetup."Cód. Concepto Neto Garantizado"));
            Modificado := true;
        end;

        if HRSetup."Cód. Acum. Haberes Gravados" = '' then begin
            HRSetup."Cód. Acum. Haberes Gravados" := CopyStr(CodAcumHaberesGravados, 1, MaxStrLen(HRSetup."Cód. Acum. Haberes Gravados"));
            Modificado := true;
        end;

        if Modificado then
            HRSetup.Modify();
    end;
}
