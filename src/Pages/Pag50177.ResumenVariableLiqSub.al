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
    SourceTableTemporary = true;
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
                field(Moneda; Rec.Moneda)
                {
                    ApplicationArea = All;
                    ToolTip = 'En una cotización, la moneda del tipo de cambio con el que se calculó.';
                }
                field("Fecha Cotización"; Rec."Fecha Cotización")
                {
                    ApplicationArea = All;
                    ToolTip = 'En una cotización, la fecha a la que se pidió el tipo de cambio.';
                }
            }
        }
    }

    /// <summary>
    /// Carga todas las variables de la liquidación: las guardadas y los parámetros que el resumen omite porque ya están en el uso
    /// del parámetro. Lo llama la ficha al cambiar de registro.
    /// </summary>
    procedure Cargar(LiqNo: Code[20])
    var
        VariablesGuardadas: Codeunit "Variables Guardadas Liq.";
    begin
        VariablesGuardadas.Cargar(LiqNo, Rec);
        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;
}
