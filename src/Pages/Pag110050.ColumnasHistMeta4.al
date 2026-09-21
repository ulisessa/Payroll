namespace UAS.Payroll;

page 110050 "Columnas Hist. Meta4"
{
    ApplicationArea = All;
    Caption = 'Columnas de la Historia Meta4';
    PageType = List;
    UsageCategory = Lists;
    SourceTable = "Columna Hist. Meta4";
    SourceTableView = sorting("Filas con Valor") order(descending);
    InsertAllowed = false;
    DeleteAllowed = false;

    // Ordenada por uso descendente: de las ~1.818 columnas de Meta4 la mayoría son residuo de
    // versiones viejas, y lo primero que uno quiere saber al abrir esto es cuáles se usaron de verdad.

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Nombre Columna"; Rec."Nombre Columna")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Filas con Valor"; Rec."Filas con Valor")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'En cuántas liquidaciones esta columna tenía dato. Un cero significa que la columna existe en Meta4 pero nunca se usó en los 31 años migrados.';
                }
                field(Descripción; Rec.Descripción)
                {
                    ApplicationArea = All;
                    ToolTip = 'Para documentar a mano qué es esta columna. Es el único campo editable del archivo, y es una nota, no un mapeo: si hace falta que BC calcule con este dato, va como línea en Línea Liquidación con su código de concepto.';
                }
                field("Cód. Concepto BC"; Rec."Cód. Concepto BC")
                {
                    ApplicationArea = All;
                    ToolTip = 'Concepto de BC equivalente. En blanco significa que no hay equivalencia conocida, no que BC no lo liquide. Es una ayuda para comparar, no una autoridad: el mapeo por nombre es parcial.';
                }
                field("Mapeo Verificado"; Rec."Mapeo Verificado")
                {
                    ApplicationArea = All;
                    ToolTip = 'Marcalo cuando COMPROBASTE la equivalencia, no cuando la dedujiste del nombre. Marcado, la columna entra en la comparación aunque su clasificación en Meta4 no sea de importe. De los 205 mapeos automáticos hay al menos cinco colisiones: mismo número de concepto, concepto distinto.';
                }
                field("Clasificación Meta4"; Rec."Clasificación Meta4")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Importes: DV devengos, RT retenciones al empleado, SS seguridad social. NO son importes: D días, U horas y cantidades, P precios unitarios, CT contribuciones patronales, AX/O/RS maquinaria interna de Meta4.';
                }
                field("Tipo Dato"; Rec."Tipo Dato")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Cuál de los tres campos de valor está cargado en el detalle.';
                }
                field("Tabla Origen"; Rec."Tabla Origen")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Cuál de las cinco tablas de Meta4 traía esta columna. El nombre de columna no es único entre ellas.';
                }
                field("No."; Rec."No.") { ApplicationArea = All; Editable = false; Visible = false; }
            }
        }
    }
}
