namespace UAS.Payroll;

codeunit 110094 "Test Variables Guardadas"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ParametroRegistradoYEnPesosNoSeRepiteEnElResumen()
    var
        Motor: Codeunit "Motor Liquidación";
        Builder: Codeunit "Contexto Liquidación";
        Resumen: Record "Resumen Variable Liq.";
        Ctx: Dictionary of [Text, Decimal];
        LiqNo: Code[20];
    begin
        LiqNo := NuevaLiquidacion();
        CrearVersionYUso(LiqNo, 'TSTVG_P', 'TSTVGP', 5, '');
        Ctx.Add('TSTVG_P', 5);
        Ctx.Add('TSTVG_Q', 7);

        Motor.SaveResumenVariables(LiqNo, Ctx, Builder);

        Assert(not Resumen.Get(LiqNo, 'TSTVG_P'), 'Un parámetro registrado, en pesos y con el valor de su versión no debe repetirse en el resumen.');
        Assert(Resumen.Get(LiqNo, 'TSTVG_Q'), 'Una variable que no es parámetro registrado se guarda como siempre.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ParametroConValorDistintoDelDeLaVersionSeGuarda()
    var
        Motor: Codeunit "Motor Liquidación";
        Builder: Codeunit "Contexto Liquidación";
        Resumen: Record "Resumen Variable Liq.";
        Ctx: Dictionary of [Text, Decimal];
        LiqNo: Code[20];
    begin
        LiqNo := NuevaLiquidacion();
        CrearVersionYUso(LiqNo, 'TSTVG_P', 'TSTVGP', 5, '');
        // El contexto difiere de la versión (un override, un redondeo): ahí la fila es la única fuente del valor.
        Ctx.Add('TSTVG_P', 6);

        Motor.SaveResumenVariables(LiqNo, Ctx, Builder);

        Assert(Resumen.Get(LiqNo, 'TSTVG_P'), 'Si el valor del contexto no es el de la versión, la fila se guarda.');
        Assert(Resumen.Valor = 6, 'La fila guardada lleva el valor del contexto.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure ParametroEnDivisaSeGuarda()
    var
        Motor: Codeunit "Motor Liquidación";
        Builder: Codeunit "Contexto Liquidación";
        Resumen: Record "Resumen Variable Liq.";
        Ctx: Dictionary of [Text, Decimal];
        LiqNo: Code[20];
    begin
        LiqNo := NuevaLiquidacion();
        CrearVersionYUso(LiqNo, 'TSTVG_M', 'TSTVGM', 3, 'USD');
        Ctx.Add('TSTVG_M', 3);

        Motor.SaveResumenVariables(LiqNo, Ctx, Builder);

        Assert(Resumen.Get(LiqNo, 'TSTVG_M'), 'Un parámetro en divisa no se omite: recuperarlo exigiría el tipo de cambio.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure CargarDevuelveLoGuardadoYLoReconstruido()
    var
        Motor: Codeunit "Motor Liquidación";
        Builder: Codeunit "Contexto Liquidación";
        Guardadas: Codeunit "Variables Guardadas Liq.";
        Completas: Record "Resumen Variable Liq." temporary;
        Una: Record "Resumen Variable Liq.";
        Ctx: Dictionary of [Text, Decimal];
        LiqNo: Code[20];
    begin
        LiqNo := NuevaLiquidacion();
        CrearVersionYUso(LiqNo, 'TSTVG_P', 'TSTVGP', 5, '');
        Ctx.Add('TSTVG_P', 5);
        Ctx.Add('TSTVG_Q', 7);
        Motor.SaveResumenVariables(LiqNo, Ctx, Builder);

        Guardadas.Cargar(LiqNo, Completas);

        Assert(Completas.Get(LiqNo, 'TSTVG_P'), 'El parámetro omitido debe reconstruirse desde su versión.');
        Assert(Completas.Valor = 5, 'El valor reconstruido es el de la versión.');
        Assert(Completas.Get(LiqNo, 'TSTVG_Q'), 'La variable guardada sigue estando.');
        Assert(Guardadas.Obtener(LiqNo, 'TSTVG_P', Una), 'Obtener también reconstruye el parámetro omitido.');
        Assert(Una.Valor = 5, 'Obtener devuelve el valor de la versión.');
        Assert(not Guardadas.Obtener(LiqNo, 'TSTVG_NO_EXISTE', Una), 'Una variable que la liquidación nunca tuvo no se inventa.');
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure CargarDetalleReponeLasVariablesDeLaFilaUso()
    var
        Guardadas: Codeunit "Variables Guardadas Liq.";
        Destino: Record "Detalle Variable Línea Liq." temporary;
        Resumen: Record "Resumen Variable Liq.";
        LiqNo: Code[20];
    begin
        LiqNo := NuevaLiquidacion();
        Resumen."No. Liquidación" := LiqNo;
        Resumen."Nombre Variable" := 'TSTVG_A';
        Resumen.Valor := 100;
        Resumen.Insert(false);
        CrearDetalle(LiqNo, 1, '~USO1', 0, 'TSTVG_A|TSTVG_CERO|TSTVG_C=REGULAR');
        CrearDetalle(LiqNo, 1, 'TSTVG_B', 9, '');
        CrearDetalle(LiqNo, 2, '~USO1', 0, 'TSTVG_A');
        CrearDetalle(LiqNo, 2, 'TSTVG_B', 8, '');

        Guardadas.CargarDetalle(LiqNo, 1, Destino);

        Assert(Destino.Get(LiqNo, 1, 'TSTVG_A') and (Destino.Valor = 100), 'La variable de la fila ~USO se repone con el valor del resumen.');
        Assert(Destino.Get(LiqNo, 1, 'TSTVG_CERO') and (Destino.Valor = 0), 'Una variable que el resumen no tiene vale cero.');
        Assert(Destino.Get(LiqNo, 1, 'TSTVG_B') and (Destino.Valor = 9), 'La fila guardada de la línea se conserva.');
        Assert(not Destino.Get(LiqNo, 1, '~USO1'), 'La fila ~USO es del almacenamiento: no se muestra.');
        Assert(Destino.Get(LiqNo, 1, 'TSTVG_C') and (Destino."Código Atributo" = 'REGULAR'), 'El código de atributo viaja con el nombre en la fila ~USO.');
        Assert(not Destino.Get(LiqNo, 2, 'TSTVG_A'), 'Pedir una línea no trae las de otra.');

        Guardadas.CargarDetalle(LiqNo, 0, Destino);

        Assert(Destino.Get(LiqNo, 0, 'TSTVG_A') and (Destino.Valor = 100), 'Pedir todas las líneas agrupa lo que el motor no repite en una fila de línea 0.');
        Destino.SetRange("Nombre Variable", 'TSTVG_A');
        Assert(Destino.Count() = 1, 'La misma variable de varias líneas sale una sola vez.');
        Destino.SetRange("Nombre Variable");
        Assert(Destino.Get(LiqNo, 1, 'TSTVG_B') and Destino.Get(LiqNo, 2, 'TSTVG_B'), 'Una variable que vale distinto entre líneas se muestra línea por línea.');
        Assert(not Destino.Get(LiqNo, 0, 'TSTVG_B'), 'Una variable mixta no se agrupa en la línea 0.');
    end;

    local procedure CrearDetalle(LiqNo: Code[20]; LineNo: Integer; Nombre: Text[50]; Valor: Decimal; Detalle: Text[250])
    var
        Det: Record "Detalle Variable Línea Liq.";
    begin
        Det."No. Liquidación" := LiqNo;
        Det."No. Línea" := LineNo;
        Det."Nombre Variable" := Nombre;
        Det.Valor := Valor;
        Det.Detalle := Detalle;
        Det.Insert(false);
    end;

    local procedure NuevaLiquidacion(): Code[20]
    begin
        exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;

    local procedure CrearVersionYUso(LiqNo: Code[20]; Variable: Code[30]; Codigo: Code[20]; Valor: Decimal; Moneda: Code[10])
    var
        ParamVig: Record "Parámetro Vigente";
        Uso: Record "Uso Parámetro Liq.";
    begin
        ParamVig.Init();
        ParamVig."Cód. Parámetro Base" := Codigo;
        ParamVig."Cód. Parámetro" := Codigo;
        ParamVig."Vigencia Desde" := DMY2Date(1, 1, 2026);
        ParamVig.Valor := Valor;
        ParamVig.Moneda := Moneda;
        ParamVig.Insert(false);

        Uso.Init();
        Uso."No. Liquidación" := LiqNo;
        Uso."Nombre Variable" := Variable;
        Uso."Cód. Parámetro Base" := Codigo;
        Uso."Cód. Parámetro" := Codigo;
        Uso."Vigencia Desde" := ParamVig."Vigencia Desde";
        Uso.Insert(false);
    end;

    local procedure Assert(Condicion: Boolean; Mensaje: Text)
    begin
        if not Condicion then
            Error(Mensaje);
    end;
}
