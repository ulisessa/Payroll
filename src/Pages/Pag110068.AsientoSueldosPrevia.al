namespace UAS.Payroll;

/// <summary>
/// Previa del asiento de sueldos de un período: lo que se contabilizaría, por cuenta y proyecto, y
/// los avisos de lo que no entró. No escribe el diario.
/// </summary>
page 110068 "Asiento Sueldos Previa"
{
    ApplicationArea = All;
    Caption = 'Previa del asiento de sueldos';
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    PageType = Worksheet;
    SourceTable = "Línea Asiento Buffer Liq.";
    SourceTableTemporary = true;
    UsageCategory = Tasks;

    layout
    {
        area(Content)
        {
            group(Seleccion)
            {
                Caption = 'Qué contabilizar';

                field(FCodPeriodo; FCodPeriodo)
                {
                    ApplicationArea = All;
                    Caption = 'Período';
                    TableRelation = "Período Liquidación".Código;
                    ToolTip = 'Mes del asiento. Entran las liquidaciones Calculadas y Aprobadas del período cuyo tipo tenga marcado Genera Asiento.';

                    trigger OnValidate()
                    begin
                        Armar();
                    end;
                }
                field(FIncluirBorradores; FIncluirBorradores)
                {
                    ApplicationArea = All;
                    Caption = 'Incluir borradores';
                    ToolTip = 'Activado, suma también las liquidaciones en Borrador, para ver cómo va a quedar el mes antes de aprobarlo.';

                    trigger OnValidate()
                    begin
                        Armar();
                    end;
                }
                field(FResumen; FResumen)
                {
                    ApplicationArea = All;
                    Caption = 'Resumen';
                    Editable = false;
                    ToolTip = 'Totales del asiento y cantidad de avisos. Los avisos van al final de la grilla.';
                }
            }
            repeater(Lines)
            {
                Editable = false;

                field(Clase; Rec.Clase)
                {
                    ApplicationArea = All;
                    StyleExpr = FEstilo;
                    ToolTip = 'Cuenta es una línea del asiento; Redondeo, la diferencia que va a la cuenta de redondeo; Aviso, algo que revisar antes de contabilizar.';
                }
                field(Cuenta; Rec.Cuenta)
                {
                    ApplicationArea = All;
                    ToolTip = 'Cuenta contable.';
                }
                field(NombreCuenta; Rec."Nombre Cuenta")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre de la cuenta.';
                }
                field(NoProyecto; Rec."No. Proyecto")
                {
                    ApplicationArea = All;
                    ToolTip = 'Proyecto de la línea. Lo decide el Registro por proyectos de la cuenta: las de pasivo van sin proyecto y en una sola línea; las de gasto, con el proyecto de cada liquidación.';
                }
                field(Debe; Rec.Debe)
                {
                    ApplicationArea = All;
                    ToolTip = 'Importe al debe. Abre las líneas de liquidación que lo forman.';

                    trigger OnDrillDown()
                    begin
                        MostrarOrigen();
                    end;
                }
                field(Haber; Rec.Haber)
                {
                    ApplicationArea = All;
                    ToolTip = 'Importe al haber. Abre las líneas de liquidación que lo forman.';

                    trigger OnDrillDown()
                    begin
                        MostrarOrigen();
                    end;
                }
                field(Conceptos; Rec.Conceptos)
                {
                    ApplicationArea = All;
                    ToolTip = 'Los conceptos que aportaron a la línea. PROV: marca la variación de una provisión.';
                }
                field(Cantidad; Rec.Cantidad)
                {
                    ApplicationArea = All;
                    ToolTip = 'En una cuenta, cuántas liquidaciones le aportaron. En un aviso, cuántas veces apareció.';
                }
                field(Mensaje; Rec.Mensaje)
                {
                    ApplicationArea = All;
                    StyleExpr = FEstilo;
                    ToolTip = 'Qué revisar. En un aviso, abre las liquidaciones y líneas que lo dispararon.';

                    trigger OnDrillDown()
                    begin
                        MostrarOrigen();
                    end;
                }
                field(Importe; Rec.Importe)
                {
                    ApplicationArea = All;
                    ToolTip = 'En un aviso, el importe en juego: lo que no se imputó, o la diferencia entre debe y haber. Abre su origen.';

                    trigger OnDrillDown()
                    begin
                        MostrarOrigen();
                    end;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Actualizar)
            {
                ApplicationArea = All;
                Caption = 'Actualizar';
                Image = Refresh;
                ToolTip = 'Vuelve a armar la previa con las liquidaciones y las reglas de ahora.';

                trigger OnAction()
                begin
                    Armar();
                end;
            }
            action(Origen)
            {
                ApplicationArea = All;
                Caption = 'Origen';
                Image = Navigate;
                ToolTip = 'Muestra de dónde sale la línea: cada línea de liquidación, partida de provisión o lote de francos que le aportó, con su importe. Desde ahí se abre la liquidación o la línea con su fórmula.';

                trigger OnAction()
                begin
                    MostrarOrigen();
                end;
            }
        }
        area(Navigation)
        {
            action(Cuentas)
            {
                ApplicationArea = All;
                Caption = 'Reglas del asiento';
                Image = ChartOfAccounts;
                RunObject = page "Reglas Asiento Liq.";
                ToolTip = 'A qué cuentas va cada concepto, según el tipo de liquidación, el proyecto, una dimensión o un atributo.';
            }
            action(TiposLiq)
            {
                ApplicationArea = All;
                Caption = 'Tipos de liquidación';
                Image = Setup;
                RunObject = page "Tipos Liquidación";
                ToolTip = 'Qué tipos de liquidación generan asiento.';
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(Actualizar_Promoted; Actualizar) { }
                actionref(Origen_Promoted; Origen) { }
                actionref(Cuentas_Promoted; Cuentas) { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        if FCodPeriodo = '' then
            FCodPeriodo := UltimoPeriodoConLiquidaciones();
        FResumen := TxtElegirPeriodo;
    end;

    trigger OnAfterGetRecord()
    begin
        case Rec.Clase of
            Rec.Clase::Aviso:
                FEstilo := 'Unfavorable';
            Rec.Clase::Redondeo:
                if Rec.Mensaje <> '' then
                    FEstilo := 'Unfavorable'
                else
                    FEstilo := 'Subordinate';
            else
                FEstilo := 'Standard';
        end;
    end;

    /// <remarks>
    /// Como SICOSS: el asiento se arma después de liquidar el mes, así que se arranca en el último
    /// período con liquidaciones y no en el del calendario.
    /// </remarks>
    local procedure UltimoPeriodoConLiquidaciones(): Code[10]
    var
        Periodo: Record "Período Liquidación";
        Liq: Record "Liquidación";
    begin
        Periodo.SetCurrentKey(Año, Mes);
        Periodo.Ascending(false);
        if Periodo.FindSet() then
            repeat
                Liq.SetRange("Cód. Período", Periodo.Código);
                if not Liq.IsEmpty() then
                    exit(Periodo.Código);
            until Periodo.Next() = 0;
        exit('');
    end;

    procedure SetPeriodo(CodPeriodo: Code[10])
    begin
        FCodPeriodo := CodPeriodo;
    end;

    local procedure Armar()
    var
        Asiento: Codeunit "Asiento Sueldos Liq.";
    begin
        if FCodPeriodo = '' then begin
            Rec.DeleteAll();
            FResumen := TxtElegirPeriodo;
        end else
            FResumen := Asiento.Previsualizar(FCodPeriodo, FIncluirBorradores, Rec);
        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    /// <remarks>
    /// El origen se arma en el momento, rearmando la previa con el mismo período y la misma opción
    /// de borradores y siguiendo sólo la clave de esta línea: así coincide con lo que se ve. La
    /// línea de redondeo no tiene origen propio (es la suma de los centavos de todas).
    /// </remarks>
    local procedure MostrarOrigen()
    var
        Asiento: Codeunit "Asiento Sueldos Liq.";
        Origen: Record "Línea Asiento Buffer Liq." temporary;
        Pagina: Page "Origen Asiento Previa";
        Titulo: Text;
    begin
        if Rec."Clave Origen" = '' then
            Error(ErrSinOrigen);
        Asiento.Origenes(FCodPeriodo, FIncluirBorradores, Rec."Clave Origen", Origen);
        if Origen.IsEmpty() then
            Error(ErrOrigenVacio);
        if Rec.Clase = Rec.Clase::Aviso then
            Titulo := Rec.Mensaje
        else
            Titulo := StrSubstNo(TxtTituloCuenta, Rec.Cuenta, Rec."Nombre Cuenta", Rec."No. Proyecto");
        Pagina.Cargar(Origen, Titulo);
        Pagina.Run();
    end;

    var
        FCodPeriodo: Code[10];
        FIncluirBorradores: Boolean;
        FResumen: Text;
        FEstilo: Text;
        TxtElegirPeriodo: Label 'Elegí el período y tocá Actualizar.';
        TxtTituloCuenta: Label '%1 %2 · %3', Comment = '%1=cuenta, %2=nombre, %3=proyecto';
        ErrSinOrigen: Label 'Esta línea no tiene un origen propio: el redondeo es la suma de los centavos de todas las cuentas.';
        ErrOrigenVacio: Label 'No se encontró el origen de la línea. Si las liquidaciones cambiaron, tocá Actualizar.';
}
