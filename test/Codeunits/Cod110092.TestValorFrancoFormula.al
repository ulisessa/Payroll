namespace UAS.Payroll;

codeunit 110092 "Test Valor Franco Fórmula"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure NombreSoloEsUnParametro()
    var
        Nombres: List of [Text];
    begin
        Identificadores('VALOR_FRANCO', Nombres);
        Assert((Nombres.Count() = 1) and (Nombres.Get(1) = 'VALOR_FRANCO'), 'Un nombre solo es un parámetro, como antes de que el campo fuera una fórmula.');
    end;

    [Test]
    procedure IfzeroDevuelveLosDosParametrosEnOrden()
    var
        Nombres: List of [Text];
    begin
        Identificadores('IFZERO(VALOR_FRANCO_EMP, VALOR_FRANCO)', Nombres);
        Assert(Nombres.Count() = 2, 'IFZERO es una función, no un parámetro: quedan los dos nombres.');
        Assert((Nombres.Get(1) = 'VALOR_FRANCO_EMP') and (Nombres.Get(2) = 'VALOR_FRANCO'), 'Los nombres salen en mayúsculas y en el orden de la fórmula.');
    end;

    [Test]
    procedure TextoEntreComillasYRepetidosNoSonParametros()
    var
        Nombres: List of [Text];
    begin
        Identificadores('if(X = ''ABC_DEF'', ifzero(Y, X), Y) + 1', Nombres);
        Assert(Nombres.Count() = 2, 'El texto entre comillas no es un nombre y un nombre repetido cuenta una vez.');
        Assert((Nombres.Get(1) = 'X') and (Nombres.Get(2) = 'Y'), 'Quedan X e Y, sin las funciones IF e IFZERO ni los números.');
    end;

    local procedure Identificadores(Formula: Text; var Nombres: List of [Text])
    var
        Francos: Codeunit "Gestión Francos";
    begin
        Francos.IdentificadoresDeValor(Formula, Nombres);
    end;

    local procedure Assert(Condicion: Boolean; Mensaje: Text)
    begin
        if not Condicion then Error(Mensaje);
    end;
}
