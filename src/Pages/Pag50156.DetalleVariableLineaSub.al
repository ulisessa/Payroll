namespace UAS.Payroll;

page 50156 "Detalle Variable Línea Sub"
{
    PageType = ListPart;
    Caption = 'Variables del Cálculo';
    SourceTable = "Detalle Variable Línea Liq.";
    SourceTableTemporary = true;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("No. Línea"; Rec."No. Línea")
                {
                    ApplicationArea = All;
                    Caption = 'Lín.';
                    Visible = false;
                }
                field("Nombre Variable"; Rec."Nombre Variable")
                {
                    ApplicationArea = All;
                    Caption = 'Variable';
                }
                field(Valor; ValorVisible)
                {
                    ApplicationArea = All;
                    Caption = 'Valor';
                }
                field(Detalle; Rec.Detalle)
                {
                    ApplicationArea = All;
                    // Solo tiene contenido en las filas TRAMO: en qué tramo cayó la base y con qué
                    // monto fijo y porcentaje se resolvió. En una variable común queda vacío.
                    ToolTip = 'Para una consulta TRAMO, en qué tramo de la tabla escalonada cayó la base y con qué monto fijo y porcentaje se resolvió.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        ValorVisible := FormatValor();
    end;

    /// <summary>
    /// Carga las variables de una línea, o de toda la liquidación con LineNo = 0. Las que el motor no repite por línea —su valor es
    /// el del resumen de la liquidación— se reponen acá. Lo llaman la ficha y la lista de líneas al cambiar de registro.
    /// </summary>
    procedure Cargar(LiqNo: Code[20]; LineNo: Integer)
    var
        Guardadas: Codeunit "Variables Guardadas Liq.";
    begin
        Guardadas.CargarDetalle(LiqNo, LineNo, Rec);
        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    local procedure FormatValor(): Text
    begin
        if IsPercentageVariable(Rec."Nombre Variable") then begin
            // ≤ 1 → fracción (0,85 → 85%); > 1 → ya es porcentaje entero (78 → 78%, no 7800%).
            if Abs(Rec.Valor) <= 1 then
                exit(Format(Round(Rec.Valor * 100, 0.000001)) + '%');
            exit(Format(Round(Rec.Valor, 0.000001)) + '%');
        end;
        exit(Format(Round(Rec.Valor, 0.000001)));
    end;

    local procedure IsPercentageVariable(VariableName: Text): Boolean
    begin
        VariableName := VariableName.ToUpper();
        exit(VariableName.StartsWith('PCT_') or VariableName.Contains('_PCT') or VariableName.Contains('PORC'));
    end;

    var
        ValorVisible: Text[50];
}
