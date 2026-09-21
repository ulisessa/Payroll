namespace UAS.Payroll;

// Todo lo que el motor tuvo en el contexto al calcular: parámetros, variables de sistema, fuentes
// de datos y acumuladores. NO es una lista de acumuladores —se llamaba "Acumuladores Anuales" y
// eso hacía buscar una explicación de por qué figuraban PCT_JUB o VALOR_L1_SOMU—.
//
// SaveResumenVariables guarda toda variable de contexto con valor, sin pedir configuración por
// variable: es la foto de con qué se calculó. Lo único que excluye son los códigos de concepto que no
// son acumuladores, porque ésos ya tienen su propia Línea Liquidación.
page 50177 "Resumen Variable Liq. Sub"
{
    ApplicationArea = All;
    Caption = 'Contexto del Cálculo';
    PageType = ListPart;
    SourceTable = "Resumen Variable Liq.";
    SourceTableView = SORTING("No. Liquidación", "Nombre Variable");
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Etiqueta; Rec.Etiqueta) { ApplicationArea = All; }
                field("Nombre Variable"; Rec."Nombre Variable") { ApplicationArea = All; }
                field(Valor; Rec.Valor)
                {
                    ApplicationArea = All;
                    Style = Strong;
                }
            }
        }
    }
}
