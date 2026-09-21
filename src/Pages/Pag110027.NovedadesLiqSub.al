namespace UAS.Payroll;

// Las novedades que entraron en esta liquidación.
//
// La ficha ya mostraba las Incidencias, que es en lo que las novedades se convierten al calcular —
// pero varias novedades del mismo concepto y empleado se suman en una sola incidencia, así que desde
// ahí no se puede saber de dónde salió el número. Acá está el origen: qué se cargó, quién lo cargó y
// con qué observación.
//
// Vacío significa que el cálculo no tomó ninguna novedad. Si alguien esperaba que sí, la respuesta
// está en la hoja de Novedades del período: o quedó Pendiente, o tiene un motivo de no aplicación.
page 110027 "Novedades Liq. Sub"
{
    ApplicationArea = All;
    Caption = 'Novedades aplicadas';
    PageType = ListPart;
    SourceTable = "Novedad Liquidación";
    SourceTableView = sorting("No. Liquidación");
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Fecha; Rec.Fecha)
                {
                    ApplicationArea = All;
                    ToolTip = 'Fecha de la novedad. Es la que decidió que entrara en ESTA liquidación y no en otra del mismo período.';
                }
                field("Cód. Concepto"; Rec."Cód. Concepto")
                {
                    ApplicationArea = All;
                    ShowMandatory = true;
                    ToolTip = 'Qué se paga o se descuenta. Es el único dato que la novedad no puede deducir de nada.';
                }
                field(DescConcepto; DescConcepto)
                {
                    ApplicationArea = All;
                    Caption = 'Concepto';
                }
                field(Cantidad; Rec.Cantidad) { ApplicationArea = All; }
                field("Unidad Cantidad"; Rec."Unidad Cantidad") { ApplicationArea = All; }
                field("Valor Unitario"; Rec."Valor Unitario") { ApplicationArea = All; }
                field(Importe; Rec.Importe)
                {
                    ApplicationArea = All;
                    Style = Strong;
                    ToolTip = 'Lo que aportó esta novedad. Varias del mismo concepto se suman en una sola incidencia, así que este importe puede ser una parte del que figura en la línea de la liquidación.';
                }
                field("No. Proyecto"; Rec."No. Proyecto")
                {
                    ApplicationArea = All;
                    ToolTip = 'Normalmente en blanco: el proyecto lo deduce la Fecha, mirando el historial de estados del empleado ese día. Cargalo sólo para forzar la novedad a una marea concreta.';
                }
                field(Recurrente; Rec.Recurrente)
                {
                    ApplicationArea = All;
                    ToolTip = 'Marcada, se vuelve a generar en el período siguiente con "Generar recurrentes".';
                }
                field(Observaciones; Rec.Observaciones) { ApplicationArea = All; }
                field("No. Movimiento"; Rec."No. Movimiento")
                {
                    ApplicationArea = All;
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AbrirHoja)
            {
                ApplicationArea = All;
                Caption = 'Abrir hoja de novedades';
                Image = Journal;
                ToolTip = 'Abre la hoja del período acotada a este empleado y a las colectivas, para ver también las que NO entraron: las que quedaron pendientes y las que el motor descartó con un motivo.';

                trigger OnAction()
                var
                    Nov: Record "Novedad Liquidación";
                begin
                    Nov.SetRange("Cód. Período", Rec."Cód. Período");
                    // Por empleado Y POR EMPLEADO EN BLANCO. La hoja de un período tiene las
                    // novedades de toda la nómina y se abre desde la liquidación de UNA persona, así
                    // que sin filtrar hay que volver a buscarla entre miles. Pero filtrar sólo por su
                    // legajo esconde las COLECTIVAS —las que van sin empleado y aplican por convenio y
                    // categoría—, y ésas también le entraron o le fueron descartadas: dejarlas fuera
                    // convierte la pantalla que explica el recibo en una que explica media.
                    Nov.SetFilter("No. Empleado", '%1|%2', Rec."No. Empleado", '');
                    Page.Run(Page::"Novedades Liquidación", Nov);
                end;
            }
        }
    }

    // La columna mostraba el código del concepto sin su nombre: DescConcepto estaba declarada pero
    // no la llenaba nadie, así que salía siempre en blanco.
    trigger OnAfterGetRecord()
    begin
        DescConcepto := DescMgt.Descripcion(Rec."Cód. Concepto");
    end;

    var
        DescConcepto: Text[100];
        DescMgt: Codeunit "Descripción Concepto Liq.";
}
