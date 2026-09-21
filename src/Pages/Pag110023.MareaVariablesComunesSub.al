namespace UAS.Payroll;

// Las variables de cálculo que valen lo mismo para toda la tripulación de la marea.
//
// Son los datos del viaje, no del tripulante: días de navegación y de puerto, kilos del buque, tipo
// de cambio, parámetros del convenio. No están enumeradas en ningún lado — se descubren comparando
// las variables que el motor guardó en cada liquidación y quedándose con las que coinciden en todas.
// Una fuente de datos nueva aparece acá sola, sin tocar código ni configurar nada.
//
// Que una variable NO esté acá también dice algo: significa que a algún tripulante le dio distinto,
// y eso se mira en la matriz o en el detalle.
page 110023 "Marea Variables Comunes Sub"
{
    ApplicationArea = All;
    Caption = 'Datos de cálculo de la marea';
    PageType = ListPart;
    SourceTable = "Resumen Variable Liq.";
    SourceTableTemporary = true;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                ShowCaption = false;

                field("Nombre Variable"; Rec."Nombre Variable")
                {
                    ApplicationArea = All;
                    Caption = 'Variable';
                    ToolTip = 'Nombre con el que la fórmula usa este valor.';
                }
                field(Etiqueta; Rec.Etiqueta)
                {
                    ApplicationArea = All;
                    ToolTip = 'Descripción configurada para la variable. En blanco cuando es un parámetro o un acumulador sin etiqueta propia.';
                }
                field(Valor; Rec.Valor)
                {
                    ApplicationArea = All;
                    BlankNumbers = BlankZero;
                    Style = Strong;
                    ToolTip = 'Valor que tomó en esta marea. Es el mismo para toda la tripulación: si a alguien le hubiera dado distinto, la variable no estaría en esta lista.';
                }
                field("Valor Texto"; Rec."Valor Texto")
                {
                    ApplicationArea = All;
                    Caption = 'Valor (texto)';
                    ToolTip = 'Para las fuentes de datos de tipo Texto o Fecha, el valor sin convertir a número.';
                }
            }
        }
    }

    procedure Cargar(var Origen: Record "Resumen Variable Liq." temporary)
    begin
        Rec.Reset();
        Rec.DeleteAll();
        Origen.Reset();
        if Origen.FindSet() then
            repeat
                Rec := Origen;
                Rec.Insert();
            until Origen.Next() = 0;
        Origen.Reset();
        CurrPage.Update(false);
    end;
}
