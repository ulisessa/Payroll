namespace UAS.Payroll;

page 50181 "Ficha Préstamo Empleado"
{
    ApplicationArea = All;
    Caption = 'Préstamo / Anticipo';
    PageType = Card;
    SourceTable = "Préstamo Empleado";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("No."; Rec."No.") { ApplicationArea = All; Editable = Rec."No." = ''; }
                field(Tipo; Rec.Tipo) { ApplicationArea = All; }
                field("No. Empleado"; Rec."No. Empleado") { ApplicationArea = All; }
                field("Nombre Empleado"; Rec."Nombre Empleado") { ApplicationArea = All; Editable = false; }
                field(Fecha; Rec.Fecha) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Importe Total"; Rec."Importe Total") { ApplicationArea = All; }
                field("Cant. Cuotas"; Rec."Cant. Cuotas") { ApplicationArea = All; }
                field("Cód. Concepto Descuento"; Rec."Cód. Concepto Descuento")
                {
                    ApplicationArea = All;
                    ToolTip = 'Concepto de tipo Descuento que se usará para la deducción en la liquidación.';
                }
                field("Total Aplicado"; Rec."Total Aplicado") { ApplicationArea = All; Editable = false; }
                field(Observaciones; Rec.Observaciones) { ApplicationArea = All; }
            }

            part(Cuotas; "Cuotas Préstamo Sub")
            {
                ApplicationArea = All;
                Caption = 'Cuotas';
                SubPageLink = "No. Préstamo" = FIELD("No.");
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(GenerarCuotas)
            {
                ApplicationArea = All;
                Caption = 'Generar Cuotas';
                Image = CreateDocuments;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Genera las cuotas en partes iguales a partir del importe total y la cantidad de cuotas. Borra las cuotas pendientes existentes.';
                trigger OnAction()
                var
                    GestPrest: Codeunit "Gestión Préstamos";
                begin
                    GestPrest.GenerarCuotas(Rec);
                    CurrPage.Cuotas.Page.Update(false);
                    Message(MsgCuotasGeneradas, Rec."Cant. Cuotas", Rec."No.");
                end;
            }
        }
    }

    var
        MsgCuotasGeneradas: Label '%1 cuota(s) generada(s) para préstamo %2.';
}
