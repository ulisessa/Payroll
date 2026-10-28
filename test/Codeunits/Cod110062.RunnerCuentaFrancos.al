namespace UAS.Payroll;

codeunit 110062 "Runner Cuenta Francos"
{
    Subtype = TestRunner;
    TestIsolation = Function;

    trigger OnRun()
    begin
        Ejecutadas := 0;
        Codeunit.Run(Codeunit::"Test Cuenta Francos");
        if Ejecutadas <> 10 then Error('Se esperaban diez pruebas; se ejecutaron %1.', Ejecutadas);
    end;

    trigger OnAfterTestRun(CodeunitId: Integer; CodeunitName: Text; FunctionName: Text; Permissions: TestPermissions; Success: Boolean)
    begin
        if (FunctionName <> '') and (UpperCase(FunctionName) <> 'ONRUN') then begin
            if not Success then Error('Falló %1.%2: %3', CodeunitName, FunctionName, GetLastErrorText());
            Ejecutadas += 1;
        end;

    end;

    var
        Ejecutadas: Integer;
}


