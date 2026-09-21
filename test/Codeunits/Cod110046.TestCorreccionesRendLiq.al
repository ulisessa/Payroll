namespace UAS.Payroll;

codeunit 110046 "Test Correcciones Rend. Liq."
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure NetoPropioSuperaGarantizado()
    var
        Motor: Codeunit "Motor Liquidación";
    begin
        Assert(Motor.NetoGarantizadoSatisfecho(100, 120, 0), 'El neto propio superior al piso debe aceptarse.');
        Assert(not Motor.NetoGarantizadoSatisfecho(100, 120, 20), 'Un exceso con complemento debe seguir ajustándose.');
        Assert(not Motor.NetoGarantizadoSatisfecho(100, 80, 0), 'Un neto inferior al piso necesita complemento.');
        Assert(not Motor.NetoGarantizadoSatisfecho(100, 80, 10), 'No debe aceptarse una iteración que todavía paga de menos.');
    end;

    [Test]
    procedure ConservaToleranciaDeUnCentavo()
    var
        Motor: Codeunit "Motor Liquidación";
    begin
        Assert(Motor.NetoGarantizadoSatisfecho(100, 100, 10), 'Igualdad exacta.');
        Assert(Motor.NetoGarantizadoSatisfecho(100, 99.99, 10), 'Un centavo por debajo.');
        Assert(Motor.NetoGarantizadoSatisfecho(100, 100.01, 10), 'Un centavo por encima.');
        Assert(not Motor.NetoGarantizadoSatisfecho(100, 99.98, 10), 'Dos centavos por debajo requieren ajuste.');
        Assert(not Motor.NetoGarantizadoSatisfecho(100, 100.02, 10), 'Dos centavos por encima con complemento requieren ajuste.');
    end;

    [Test]
    procedure FiltroConApostrofesYOperadores()
    var
        Francos: Codeunit "Gestión Francos";
        Lin: Record "Línea Liquidación" temporary;
        Codigos: List of [Code[20]];
        Codigo: Code[20];
        Numero: Integer;
    begin
        Codigos.Add('FR''01');
        Codigos.Add('A|B');
        Codigos.Add('A&B');
        Codigos.Add('F*');
        Codigos.Add('A..Z');
        Codigos.Add('@FR');
        foreach Codigo in Codigos do begin
            Numero += 1;
            InsertarLinea(Lin, Numero, Codigo);
        end;
        InsertarLinea(Lin, 100, 'A');
        InsertarLinea(Lin, 101, 'B');
        InsertarLinea(Lin, 102, 'FR02');
        InsertarLinea(Lin, 103, 'FR');
        Lin.SetFilter("Cód. Concepto", Francos.ConstruirFiltroCodigos(Codigos));
        Assert(Lin.Count() = Codigos.Count(), 'El filtro debe seleccionar exactamente los códigos literales.');
        if Lin.FindSet() then
            repeat
                Assert(Codigos.Contains(Lin."Cód. Concepto"), 'El filtro incluyó un código ajeno.');
            until Lin.Next() = 0;
    end;

    local procedure InsertarLinea(var Lin: Record "Línea Liquidación" temporary; Numero: Integer; Codigo: Code[20])
    begin
        Lin.Init();
        Lin."No. Liquidación" := 'TEST';
        Lin."No. Línea" := Numero;
        Lin."Cód. Concepto" := Codigo;
        Lin.Insert(false);
    end;

    local procedure Assert(Condicion: Boolean; Mensaje: Text)
    begin
        if not Condicion then
            Error(Mensaje);
    end;
}
