namespace UAS.Payroll;

/// <summary>Las condiciones de estado de un tipo de liquidación, en la ficha del tipo.</summary>
page 110053 "Estados Tipo Liq. Sub"
{
    PageType = ListPart;
    SourceTable = "Estado Tipo Liq.";
    Caption = 'Estados que lo justifican';
    DelayedInsert = true;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Modo; Rec.Modo)
                {
                    ApplicationArea = All;
                    ToolTip = 'Exige: tiene que haber al menos un estado así. Excluye: si lo hay, la liquidación no corresponde. Entre varias líneas Exige alcanza con que se cumpla UNA; cualquier Excluye que se cumpla descarta.';
                }
                field("Cód. Estado"; Rec."Cód. Estado")
                {
                    ApplicationArea = All;
                    ToolTip = 'Los estados que se buscan, como filtro: un código (NV), una lista (NV|PL|PS) o un comodín (BAJ*). En blanco significa CUALQUIER estado, que no es lo mismo que ningún filtro: sigue pidiendo que haya al menos uno en la ventana.';

                    // El lookup sigue estando aunque el campo ya no tenga TableRelation —un filtro no
                    // es un valor de la tabla—, porque el caso corriente es elegir UN estado y
                    // escribirlo de memoria es como se cargan los códigos que no existen.
                    trigger OnLookup(var Text: Text): Boolean
                    var
                        CodEst: Record "Cód. Estado Empleado";
                    begin
                        if Page.RunModal(0, CodEst) <> Action::LookupOK then
                            exit(false);
                        Text := CodEst.Código;
                        exit(true);
                    end;
                }
                field(Ventana; Rec.Ventana)
                {
                    ApplicationArea = All;
                    ToolTip = 'Sobre qué días se busca. Los días que cubre la liquidación no son el mes entero cuando el tipo liquida al arribo: un cierre de marea cubre sólo el viaje. Mes siguiente es para lo que se paga por adelantado, como las vacaciones.';
                }
                field("Empieza en la Ventana"; Rec."Empieza en la Ventana")
                {
                    ApplicationArea = All;
                    ToolTip = 'Con Sí, el estado tiene que EMPEZAR dentro de la ventana; con No, alcanza con que la toque. La diferencia decide un recibo entero: unas vacaciones que arrancan el 1 de enero y terminan el 4 de febrero tocan el mes siguiente, pero no son un anticipo. Para la regla del anticipo va en Sí.';
                }
                field("Tipo Proyecto"; Rec."Tipo Proyecto")
                {
                    ApplicationArea = All;
                    ToolTip = 'De qué proyecto tiene que venir el estado. Es el proyecto DEL ESTADO, no el de la liquidación: así se puede pedir "días que no son de una marea", que es lo que distingue a la Regular. Un estado sin proyecto cuenta como improductivo.';
                }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
            }
        }
    }
}
