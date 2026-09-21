namespace UAS.Payroll;

page 110049 "Valores Hist. Meta4"
{
    ApplicationArea = All;
    Caption = 'Valores';
    PageType = ListPart;
    SourceTable = "Valor Hist. Meta4";
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    // Ordenada por la clave agrupada, que es "No. Entrada" + "No. Columna". Eso deja los valores en el
    // orden en que las columnas están definidas en Meta4 — que agrupa lo relacionado— y evita que la
    // página pida un orden distinto al del índice sobre una tabla de 117 millones de filas.

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Nombre Columna"; Rec."Nombre Columna")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre de la columna tal como se llama en Meta4.';
                }
                field("Descripción Columna"; Rec."Descripción Columna")
                {
                    ApplicationArea = All;
                    ToolTip = 'Descripción cargada a mano en el catálogo de columnas. Está vacía salvo en las columnas que alguien se tomó el trabajo de documentar.';
                }
                field(Valor; Rec.Valor)
                {
                    ApplicationArea = All;
                    ToolTip = 'Valor numérico. Las columnas que no tenían dato no generan fila: un valor ausente significa cero, igual que en Meta4.';
                }
                field("Valor Texto"; Rec."Valor Texto") { ApplicationArea = All; }
                field("Valor Fecha"; Rec."Valor Fecha") { ApplicationArea = All; }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        Rec.CalcFields("Nombre Columna", "Descripción Columna");
    end;
}
