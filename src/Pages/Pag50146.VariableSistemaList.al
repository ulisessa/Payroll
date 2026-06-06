namespace UAS.Payroll;

page 50146 "Variable Sistema Liq."
{
    ApplicationArea = All;
    Caption = 'Variables Sistema Liquidación';
    PageType = List;
    SourceTable = "Variable Sistema Liq.";
    UsageCategory = Administration;
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Cód. Cálculo"; Rec."Cód. Cálculo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Código que identifica la lógica de cálculo. Valores disponibles: ANIOS_ANTIGUEDAD, DIAS_HAB, DIAS_HAB_ANIO, DIAS_ALTA_ANIO, DIAS_PROYECTO, PCT_ESCALA, VACACIONES_ANUALES, VACACIONES_PROP_DIAS, DIAS_VAC_PERIODO, DEDUC_GANANCIAS, MES_ANUAL, HAB_GRAV_ANUAL, HAB_EXTORD_ANUAL, RETENIDO_ANUAL, TIPO_LIQ, YTD_ACUM (requiere Cód. Acumulador).';
                }
                field("Cód. Acumulador"; Rec."Cód. Acumulador")
                {
                    ApplicationArea = All;
                    ToolTip = 'Requerido cuando Cód. Cálculo = YTD_ACUM. Acumulador cuyos conceptos contribuyentes se suman en el año fiscal.';
                }
                field("Tipo Concepto"; Rec."Tipo Concepto")
                {
                    ApplicationArea = All;
                    ToolTip = 'Requerido cuando Cód. Cálculo = YTD_LINEAS. Tipo de concepto cuyas líneas se suman en el año fiscal (ej: Retención para retención de Ganancias).';
                }
                field("Nombre Variable"; Rec."Nombre Variable")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre con el que este valor se expone en las fórmulas. Puede renombrarse sin tocar código.';
                }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field(Activo; Rec.Activo) { ApplicationArea = All; }
                field("Mostrar en Recibo"; Rec."Mostrar en Recibo") { ApplicationArea = All; }
                field("Etiqueta Recibo"; Rec."Etiqueta Recibo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Etiqueta que aparece en el recibo de sueldo. Si se deja vacío se usa la Descripción.';
                }
                field("Etiqueta Det. Ganancias"; Rec."Etiqueta Det. Ganancias")
                {
                    ApplicationArea = All;
                    ToolTip = 'Si se completa, el valor calculado aparece como paso informativo en el detalle de Ganancias del recibo.';
                }
                field("Orden Det. Ganancias"; Rec."Orden Det. Ganancias")
                {
                    ApplicationArea = All;
                    ToolTip = 'Posición en la que aparece dentro del detalle de Ganancias. Familiar/Gasto usan 500; valores menores aparecen antes, mayores después.';
                }
            }
        }
        area(FactBoxes)
        {
            part(Acumuladores; "Acumuladores Disponibles FB")
            {
                ApplicationArea = All;
                Caption = 'Acumuladores disponibles';
            }
        }
    }
}
