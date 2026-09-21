namespace UAS.Payroll;

// Control del saldo de francos: cuántos tiene cada tripulante pendientes, ganados en qué categoría, y
// cuánto costaría pagarlos.
//
// Es la única vista que contesta esa pregunta. Una liquidación muestra los francos de SU período; el
// saldo vive repartido en los lotes de todas las liquidaciones anteriores, y hasta ahora había que
// reconstruirlo a mano para saber si un tripulante estaba por quedarse sin francos o si la empresa
// tenía una deuda acumulada que nadie había puesto en pesos.
//
// La fila es (tripulante, convenio, categoría) y no (tripulante): los francos NO son fungibles. Cada
// lote queda sellado con la categoría en la que se ganó y se paga a ESE precio aunque hoy el
// tripulante esté encuadrado en otra. Un marinero que ascendió tiene francos de dos precios, y un
// total por persona escondería justamente eso.
page 110024 "Francos por Tripulante"
{
    ApplicationArea = All;
    Caption = 'Francos por Tripulante';
    PageType = List;
    UsageCategory = ReportsAndAnalysis;
    SourceTable = "Francos Buffer Liq.";
    SourceTableTemporary = true;
    InsertAllowed = false;
    DeleteAllowed = false;
    // Sin "Editable = false" ni "ModifyAllowed = false" a nivel página: bloquean TODOS los controles,
    // incluidos los de la cabecera, que no pertenecen al registro y son lo único que acá se escribe.
    // La grilla se protege campo por campo.

    layout
    {
        area(Content)
        {
            group(Corte)
            {
                Caption = 'Corte';

                field(FechaCorte; FechaCorte)
                {
                    ApplicationArea = All;
                    Caption = 'Saldo a la fecha';
                    ToolTip = 'Fecha de corte: entran los lotes devengados hasta ese día y se descuenta el consumo anterior a él. El valor del franco también se busca a esta fecha, así que cambiarla revalúa la deuda.';

                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
                field(FiltroEmpleado; FiltroEmpleado)
                {
                    ApplicationArea = All;
                    Caption = 'Filtro de empleado';
                    ToolTip = 'Acepta un filtro de Business Central: un número, varios separados por barra vertical, o un rango. En blanco, todos los que tengan algún franco devengado.';

                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
                field(TotalSaldo; TotalSaldo)
                {
                    ApplicationArea = All;
                    Caption = 'Total de francos pendientes';
                    Editable = false;
                    DecimalPlaces = 0 : 2;
                }
                field(TotalImporte; TotalImporte)
                {
                    ApplicationArea = All;
                    Caption = 'Importe a pagar si se liquidaran';
                    Editable = false;
                    Style = Strong;
                    ToolTip = 'Lo que costaría pagar hoy todo el saldo pendiente, cada franco al valor de la categoría en que se ganó.';
                }
                field(SinValor; SinValor)
                {
                    ApplicationArea = All;
                    Caption = 'Categorías sin valor de franco';
                    Editable = false;
                    Style = Attention;
                    StyleExpr = SinValor > 0;
                    ToolTip = 'Cuántas filas con saldo no tienen cargado VALOR_FRANCO_<CONVENIO>_<CATEGORÍA> a la fecha de corte. Esos francos se pagarían a cero, así que un número distinto de cero acá es un parámetro que falta, no un dato.';
                }
            }
            repeater(Lines)
            {
                field("No. Empleado"; Rec."No. Empleado") { ApplicationArea = All; Editable = false; }
                field("Nombre Empleado"; Rec."Nombre Empleado") { ApplicationArea = All; Editable = false; }
                field("Cód. Convenio"; Rec."Cód. Convenio")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Convenio del LOTE: aquel con el que se ganaron estos francos, que puede no ser el encuadre actual del tripulante.';
                }
                field("Cód. Categoría"; Rec."Cód. Categoría") { ApplicationArea = All; Editable = false; }
                field("Descripción Categoría"; Rec."Descripción Categoría") { ApplicationArea = All; Editable = false; }
                field(Devengados; Rec.Devengados)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Francos ganados en esta categoría hasta la fecha de corte.';

                    trigger OnDrillDown()
                    begin
                        MostrarLotes();
                    end;
                }
                field(Consumidos; Rec.Consumidos)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Francos ya gozados que se imputan a esta categoría. No está guardado en ninguna línea: se deduce recorriendo los lotes del más viejo al más nuevo, que es el mismo orden en que los paga el motor.';
                }
                field(Saldo; Rec.Saldo)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Style = Strong;
                    ToolTip = 'Francos pendientes de esta categoría. Hacé clic en el encabezado para ordenar por saldo.';
                }
                field("Valor Franco"; Rec."Valor Franco")
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = ValorEnCero;
                    Style = Attention;
                    ToolTip = 'VALOR_FRANCO_<CONVENIO>_<CATEGORÍA> a la fecha de corte. En cero significa que el parámetro no está cargado para esa categoría, y esos francos se pagarían a cero.';
                }
                field("Importe Saldo"; Rec."Importe Saldo") { ApplicationArea = All; Editable = false; Style = Strong; }
                field(Lotes; Rec.Lotes)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'En cuántas liquidaciones se fueron ganando estos francos.';
                }
                field("Lote Más Antiguo"; Rec."Lote Más Antiguo")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Fecha del lote más viejo de esta categoría. Como el consumo es FIFO, es el que se paga primero.';
                }
                field("Lote Más Reciente"; Rec."Lote Más Reciente") { ApplicationArea = All; Editable = false; }
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
                ToolTip = 'Vuelve a recorrer el ledger de francos con la fecha de corte y el filtro actuales.';

                trigger OnAction()
                begin
                    Cargar();
                end;
            }
            action(VerLotes)
            {
                ApplicationArea = All;
                Caption = 'Ver lotes';
                Image = Lot;
                ToolTip = 'Abre las líneas de liquidación en las que se devengaron los francos de esta fila, para ver de qué marea salió cada una.';

                trigger OnAction()
                begin
                    MostrarLotes();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';
                actionref(ActualizarProm; Actualizar) { }
                actionref(VerLotesProm; VerLotes) { }
            }
        }
    }

    /// <summary>Abre la página ya acotada a un empleado. Hay que llamarlo ANTES de Run.</summary>
    procedure SetFiltroEmpleado(EmployeeNo: Code[20])
    begin
        FiltroEmpleado := EmployeeNo;
    end;

    trigger OnOpenPage()
    begin
        if FechaCorte = 0D then
            FechaCorte := WorkDate();
        Cargar();
    end;

    trigger OnAfterGetRecord()
    begin
        ValorEnCero := (Rec.Saldo <> 0) and (Rec."Valor Franco" = 0);
    end;

    local procedure Cargar()
    var
        FrancosMgt: Codeunit "Gestión Francos";
    begin
        FrancosMgt.ResumenPorCategoria(FiltroEmpleado, FechaCorte, Rec);

        TotalSaldo := 0;
        TotalImporte := 0;
        SinValor := 0;
        Rec.Reset();
        if Rec.FindSet() then
            repeat
                TotalSaldo += Rec.Saldo;
                TotalImporte += Rec."Importe Saldo";
                if (Rec.Saldo <> 0) and (Rec."Valor Franco" = 0) then
                    SinValor += 1;
            until Rec.Next() = 0;
        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    /// <remarks>
    /// Los lotes se buscan por empleado y por el par convenio/categoría de la LÍNEA, que es el del
    /// lote. Filtrar por el encuadre actual del tripulante devolvería vacío justo en el caso que
    /// importa: el que cambió de categoría.
    /// </remarks>
    local procedure MostrarLotes()
    var
        Lin: Record "Línea Liquidación";
        Concepto: Record "Concepto Liquidación";
        Codigos: TextBuilder;
    begin
        if Rec."No. Empleado" = '' then
            exit;

        Concepto.SetRange("Rol Franco", "Rol Franco Liq."::Devengo);
        if Concepto.FindSet() then
            repeat
                if Codigos.Length() > 0 then
                    Codigos.Append('|');
                Codigos.Append(Concepto.Código);
            until Concepto.Next() = 0;
        if Codigos.Length() = 0 then begin
            Message(MsgSinConceptos);
            exit;
        end;

        Lin.SetCurrentKey("No. Empleado", "Fecha Liquidación", "Tipo Concepto");
        Lin.SetRange("No. Empleado", Rec."No. Empleado");
        Lin.SetFilter("Cód. Concepto", Codigos.ToText());
        Lin.SetRange("Cód. Convenio", Rec."Cód. Convenio");
        Lin.SetRange("Cód. Categoría", Rec."Cód. Categoría");
        Lin.SetFilter("Fecha Liquidación", '<=%1', FechaCorte);
        Page.Run(Page::"Líneas Liq. Con Variables", Lin);
    end;

    var
        FechaCorte: Date;
        FiltroEmpleado: Text;
        TotalSaldo: Decimal;
        TotalImporte: Decimal;
        SinValor: Integer;
        ValorEnCero: Boolean;
        MsgSinConceptos: Label 'No hay ningún concepto marcado con Rol Franco = Devengo, así que no hay lotes que mostrar.';
}
