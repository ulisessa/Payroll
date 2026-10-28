namespace UAS.Payroll;

codeunit 110060 "Orden Concepto Upgrade"
{
    Subtype = Upgrade;
    trigger OnUpgradePerCompany()
    var
        Concepto: Record "Concepto Liquidación";
        Motor: Codeunit "Motor Liquidación";
        Formula: Text;
    begin
        if Concepto.FindSet(true) then
            repeat
                Formula := Motor.FormulaOrdenConfigurada(Concepto);
                Formula := UpperCase(Formula).Replace('ORDEN_BASE', Format(Concepto."Orden Cálculo", 0, 9));
                if Concepto."Fórmula Orden Cálculo" <> Formula then begin
                    Concepto."Fórmula Orden Cálculo" := CopyStr(Formula, 1, MaxStrLen(Concepto."Fórmula Orden Cálculo"));
                    Concepto.Modify(false);
                end;
            until Concepto.Next() = 0;
    end;
}
