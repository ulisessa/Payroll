namespace UAS.Payroll;

page 110011 "Atributos de Entidad"
{
    ApplicationArea = All;
    Caption = 'Atributos';
    PageType = List;
    UsageCategory = Lists;
    SourceTable = "Atributo Entidad Liq.";
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Tipo Entidad"; Rec."Tipo Entidad") { ApplicationArea = All; }
                field("Cód. Entidad"; Rec."Cód. Entidad") { ApplicationArea = All; }
                field("Cód. Tipo Atributo"; Rec."Cód. Tipo Atributo")
                {
                    ApplicationArea = All;

                    trigger OnValidate()
                    begin
                        // El tipo decide qué columna se puede completar, así que hay que redibujar.
                        CurrPage.Update(true);
                    end;
                }
                field("Tipo Dato"; Rec."Tipo Dato") { ApplicationArea = All; }
                field("Cód. Valor"; Rec."Cód. Valor")
                {
                    ApplicationArea = All;
                    ToolTip = 'Valor elegido de la lista del atributo.';
                }
                field("Descripción Valor"; Rec."Descripción Valor") { ApplicationArea = All; }
                field("Valor Decimal"; Rec."Valor Decimal") { ApplicationArea = All; }
                field("Valor Texto"; Rec."Valor Texto") { ApplicationArea = All; }
                field("Valor Fecha"; Rec."Valor Fecha") { ApplicationArea = All; }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field("Vigencia Hasta"; Rec."Vigencia Hasta")
                {
                    ApplicationArea = All;
                    ToolTip = 'En blanco = vigencia abierta. Al cargar una vigencia nueva, la anterior se cierra sola el día previo si estaba abierta.';
                }
                field("Valor Numérico"; Rec."Valor Numérico")
                {
                    ApplicationArea = All;
                    Visible = false;
                    ToolTip = 'El número que efectivamente ve la fórmula. Queda congelado al asignar, para que un recálculo de un período viejo dé lo mismo que dio.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            // Dos acciones que se turnan la visibilidad: en AL el Caption de una acción es constante
            // y no admite expresión, así que es la única forma de que el botón diga qué va a hacer.
            action(VerTodas)
            {
                ApplicationArea = All;
                Caption = 'Ver historial completo';
                Image = History;
                Visible = SoloActualesActivo;
                ToolTip = 'Muestra también las vigencias que ya terminaron y las que todavía no empezaron.';
                trigger OnAction()
                begin
                    SoloActuales := false;
                    AplicarFiltros();
                end;
            }
            action(VerActuales)
            {
                ApplicationArea = All;
                Caption = 'Ver solo actuales';
                Image = FilterLines;
                Visible = VerTodasActivo;
                ToolTip = 'Muestra solo los atributos vigentes hoy.';
                trigger OnAction()
                begin
                    SoloActuales := true;
                    AplicarFiltros();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        SoloActuales := true;
        AplicarFiltros();
    end;

    trigger OnAfterGetRecord()
    begin
        Rec.CalcFields("Tipo Dato");
    end;

    // La fecha es parte de la clave primaria: sin proponerla, la fila se intenta escribir con la
    // fecha en blanco y la segunda choca contra la primera. El error que salía hablaba de registro
    // duplicado en vez de decir que faltaba la fecha, que es lo que realmente pasaba.
    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        if Rec."Vigencia Desde" = 0D then
            Rec."Vigencia Desde" := WorkDate();
    end;

    // El "hasta" no se filtra en SQL: haría falta un filtro de fecha en blanco sobre un campo Date, y
    // esa forma ya nos costó caro. Se filtra el inicio, que es lo selectivo, y las que ya terminaron
    // se ocultan marcándolas — sobre un solo empleado son unas pocas filas.
    local procedure AplicarFiltros()
    var
        Atributo: Record "Atributo Entidad Liq.";
    begin
        SoloActualesActivo := SoloActuales;
        VerTodasActivo := not SoloActuales;

        Rec.MarkedOnly(false);
        Rec.ClearMarks();
        if not SoloActuales then begin
            Rec.SetRange("Vigencia Desde");
            CurrPage.Update(false);
            exit;
        end;

        Rec.SetFilter("Vigencia Desde", '<=%1', WorkDate());
        Atributo.CopyFilters(Rec);
        if Atributo.FindSet() then
            repeat
                if Atributo.VigenteA(WorkDate()) then
                    if Rec.Get(Atributo."Tipo Entidad", Atributo."Cód. Entidad",
                               Atributo."Cód. Tipo Atributo", Atributo."Vigencia Desde")
                    then
                        Rec.Mark(true);
            until Atributo.Next() = 0;
        Rec.MarkedOnly(true);
        CurrPage.Update(false);
    end;

    var
        SoloActuales: Boolean;
        SoloActualesActivo: Boolean;
        VerTodasActivo: Boolean;
}
