namespace UAS.Payroll;

page 50104 "Cód. Estados Empleado"
{
    ApplicationArea = All;
    Caption = 'Cód. Estados Empleado';
    PageType = List;
    SourceTable = "Cód. Estado Empleado";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Código; Rec.Código) { ApplicationArea = All; }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field("Descripción Ampliada"; Rec."Descripción Ampliada")
                {
                    ApplicationArea = All;
                    ToolTip = 'Detalle de la causal: qué indemnización genera, contra qué artículo, y cualquier cosa que convenga leer antes de elegir este código en lugar de otro parecido.';
                }
                field("Tipo Empleado"; Rec."Tipo Empleado") { ApplicationArea = All; }
                field("Tipo Estado"; Rec."Tipo Estado") { ApplicationArea = All; }
                field("Ámbito"; Rec."Ámbito")
                {
                    ApplicationArea = All;
                    ToolTip = 'A qué entidades aplica este estado: Empleado, Buque o Ambos.';
                }
                field("Estado Siguiente"; Rec."Estado Siguiente")
                {
                    ApplicationArea = All;
                    ToolTip = 'Estado al que se transiciona automáticamente cuando termina la condición de éste (ej. Francos → Órdenes al agotarse el saldo). Vacío = terminal.';
                }
                field("Devenga Francos"; Rec."Devenga Francos")
                {
                    ApplicationArea = All;
                    ToolTip = 'Se trabaja: sus días cuentan para el devengo de francos (DIAS_ENROLAMIENTO). Guardia en puerto, dique y pilotaje lo tienen en Sí — se trabaja aunque no se esté en una marea.';
                }
                field("Transcurre en Marea"; Rec."Transcurre en Marea")
                {
                    ApplicationArea = All;
                    ToolTip = 'Estos días transcurren a bordo, dentro de una marea: navegación y los días de puerto del viaje —salida y llegada—. Guardia en puerto, dique y pilotaje van en No: se trabaja, pero fuera de la marea, y sus días pertenecen al proyecto de nómina del buque. No confundir con "Devenga Francos", que contesta otra pregunta.';
                }
                field(Activo; Rec.Activo) { ApplicationArea = All; }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AltaEstadosBuque)
            {
                ApplicationArea = All;
                Caption = 'Crear estados de buque';
                Image = Status;
                ToolTip = 'Da de alta los estados operativos de buque (Pesca, Navegación, Puerto, Amarrado, Dique) con Ámbito = Buque. Solo crea los que falten: los existentes no se tocan.';

                trigger OnAction()
                var
                    Alta: Codeunit "Alta Estados Buque";
                    Creados: Integer;
                begin
                    Creados := Alta.CrearFaltantes();
                    if Creados = 0 then
                        Message(MsgSinFaltantes)
                    else
                        Message(MsgCreados, Creados);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    var
        MsgCreados: Label '%1 estado(s) de buque creado(s). Revisá "Devenga Francos" en cada uno antes de usarlos: es la marca que dispara el pase de la tripulación a Francos al salir de un estado productivo.';
        MsgSinFaltantes: Label 'Los cinco estados de buque ya existen. No se modificó ninguno.';
}
