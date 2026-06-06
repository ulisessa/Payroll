namespace UAS.Payroll;

page 50151 "Ded. Ganancias Vigente Card"
{
    ApplicationArea = All;
    Caption = 'Tipo Deducción Ganancias';
    PageType = Card;
    SourceTable = "Ded. Ganancias Vigente";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field(Código; Rec.Código) { ApplicationArea = All; }
                field("Vigencia Desde"; Rec."Vigencia Desde") { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Importe Anual"; Rec."Importe Anual") { ApplicationArea = All; }
                field("Aplica Cantidad"; Rec."Aplica Cantidad")
                {
                    ApplicationArea = All;
                    ToolTip = 'Activar para tipos por cantidad de personas (hijos, ascendientes). Desactivar para montos fijos (prepaga, hipoteca).';
                }
            }
        }
    }
}
