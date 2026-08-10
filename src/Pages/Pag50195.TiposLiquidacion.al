namespace UAS.Payroll;

page 50195 "Tipos Liquidación"
{
    ApplicationArea = All;
    Caption = 'Tipos de Liquidación';
    PageType = List;
    SourceTable = "Tipo Liquidación";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field(Orden; Rec.Orden) { ApplicationArea = All; }
                field("Liquida al Arribo"; Rec."Liquida al Arribo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Comportamiento Cierre de Marea: liquida a la fecha de arribo (navegación + producción).';
                }
                field("Incluye Francos Puerto"; Rec."Incluye Francos Puerto")
                {
                    ApplicationArea = All;
                    ToolTip = 'Al crear por período, genera también liquidaciones para empleados en francos en puerto (comportamiento Regular).';
                }
                field(Activo; Rec.Activo) { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SembrarMigrar)
            {
                ApplicationArea = All;
                Caption = 'Sembrar y migrar datos';
                Image = Setup;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Crea los tipos por defecto (si faltan) y convierte las liquidaciones, líneas y conceptos existentes del enum al código de esta tabla. Es seguro ejecutarlo varias veces.';

                trigger OnAction()
                var
                    GestionTipoLiq: Codeunit "Gestión Tipo Liq.";
                begin
                    if not Confirm(QstMigrar, true) then
                        exit;
                    GestionTipoLiq.Sembrar();
                    GestionTipoLiq.MigrarDatos();
                    Message(MsgMigrado);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    var
        QstMigrar: Label 'Se crearán los tipos por defecto y se convertirán las liquidaciones, líneas y conceptos existentes al nuevo código. ¿Continuar?';
        MsgMigrado: Label 'Tipos sembrados y datos migrados.';
}
