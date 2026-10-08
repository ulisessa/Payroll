namespace UAS.Payroll;

codeunit 110048 "Test Escritura Auditoria"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure DetalleConservaPrimeroTramosYCeros()
    var
        Motor: Codeunit "Motor Liquidación";
        Evaluador: Codeunit "Evaluador Fórmula";
        Det: Record "Detalle Variable Línea Liq.";
        Ctx: Dictionary of [Text, Decimal];
        LiqNo: Code[20];
        Prefijo: Text;
    begin
        LiqNo := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20);
        Prefijo := PadStr('COLISION', 50, 'X');
        Ctx.Add(Prefijo + 'A', 12);
        Ctx.Add(Prefijo + 'B', 34);
        Ctx.Add('TRAMO(T)', 7);
        Evaluador.Init(Ctx, Today());
        Motor.WriteVariableDetail(LiqNo, 10000,
            'VAR:' + Prefijo + 'A|VAR:' + Prefijo + 'B|VAR:TRAMO(T)|TRAMO:T~5~primero|TRAMO:T~5~primero|TRAMO:T~6~segundo|VAR:AUSENTE',
            Ctx, Evaluador);
        Det.Get(LiqNo, 10000, Prefijo);
        Assert(Det.Valor = 12, 'La colisión truncada debe conservar el primer valor.');
        Det.Get(LiqNo, 10000, 'TRAMO(T)');
        Assert(Det.Valor = 7, 'La variable debe conservar su nombre frente al tramo posterior.');
        Det.Get(LiqNo, 10000, 'TRAMO(T) #2');
        Assert((Det.Valor = 5) and (Det.Detalle = 'primero'), 'Debe conservar el primer tramo y su detalle.');
        Det.Get(LiqNo, 10000, 'TRAMO(T) #3');
        Assert((Det.Valor = 6) and (Det.Detalle = 'segundo'), 'El tramo distinto debe tener otro sufijo.');
        Det.Get(LiqNo, 10000, 'AUSENTE');
        Assert((Det.Valor = 0) and (Det.Detalle = ''), 'La variable ausente debe quedar en cero sin heredar detalle.');
        Det.SetRange("No. Liquidación", LiqNo);
        Assert(Det.Count() = 5, 'La entrada TRAMO idéntica no debe repetirse.');
        Motor.WriteVariableDetail(LiqNo, 20000, 'VAR:AUSENTE', Ctx, Evaluador);
        Det.Get(LiqNo, 20000, 'AUSENTE');
        Det.DeleteAll();
    end;

    [Test]
    procedure ResumenConservaUltimoTrasTruncar()
    var
        Motor: Codeunit "Motor Liquidación";
        Builder: Codeunit "Contexto Liquidación";
        Resumen: Record "Resumen Variable Liq.";
        Ctx: Dictionary of [Text, Decimal];
        LiqNo: Code[20];
        Prefijo: Text;
        Nombre: Text;
        Ultimo: Decimal;
    begin
        LiqNo := CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20);
        Prefijo := PadStr('TESTAUDITORIA', 30, 'X');
        Ctx.Add(Prefijo + 'A', 12);
        Ctx.Add(Prefijo + 'B', 34);
        foreach Nombre in Ctx.Keys() do
            Ultimo := Ctx.Get(Nombre);
        Motor.SaveResumenVariables(LiqNo, Ctx, Builder);
        Resumen.Get(LiqNo, Prefijo);
        Assert(Resumen.Valor = Ultimo, 'Debe persistir el último valor de la clave truncada.');
        Resumen.SetRange("No. Liquidación", LiqNo);
        Assert(Resumen.Count() = 1, 'Debe persistir una sola fila por clave normalizada.');
        Resumen.DeleteAll();
    end;

    local procedure Assert(Condition: Boolean; Message: Text)
    begin
        if not Condition then
            Error(Message);
    end;
}
