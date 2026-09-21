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
                    ToolTip = 'Código que identifica la lógica de cálculo. Valores disponibles: AÑOS_ANTIGUEDAD, DIAS_HAB, DIAS_HAB_AÑO, DIAS_ALTA_AÑO, DIAS_PROYECTO, PCT_ESCALA, VACACIONES_ANUALES, VACACIONES_PROP_DIAS, DIAS_VAC_PERIODO, DEDUC_GANANCIAS, MES_ANUAL, HAB_GRAV_ANUAL, HAB_EXTORD_ANUAL, RETENIDO_ANUAL, TIPO_LIQ, YTD_ACUM (requiere Cód. Acumulador), PERIODO_ACUM (requiere Cód. Acumulador), PERIODO_CONCEPTO (requiere Cód. Concepto), YTD_LINEAS (requiere Tipo Concepto). El botón de búsqueda del campo muestra la lista completa.';
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
                field("Cód. Concepto"; Rec."Cód. Concepto")
                {
                    ApplicationArea = All;
                    ToolTip = 'Requerido cuando Cód. Cálculo = PERIODO_CONCEPTO. Concepto cuyo importe ya liquidado en el período se suma, sin contar la liquidación en curso. Para incluir también la actual, la fórmula suma #CÓDIGO.';
                }
                field("Nombre Variable"; Rec."Nombre Variable")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre con el que este valor se expone en las fórmulas. Puede renombrarse sin tocar código.';
                }
                field(Descripción; Rec.Descripción) { ApplicationArea = All; }
                field(Activo; Rec.Activo) { ApplicationArea = All; }
                field("Mostrar en Recibo"; Rec."Mostrar en Recibo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Imprime el valor en el recibo de sueldo (PDF). La ficha de Liquidación (Acumuladores Anuales) muestra automáticamente cualquier variable con valor distinto de cero, sin necesidad de marcar este campo.';
                }
                field("Etiqueta Recibo"; Rec."Etiqueta Recibo")
                {
                    ApplicationArea = All;
                    ToolTip = 'Etiqueta que aparece en el recibo de sueldo y en la ficha de Liquidación. Si se deja vacío se usa la Descripción.';
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

    actions
    {
        area(Processing)
        {
            action(RevisarNombres)
            {
                ApplicationArea = All;
                Caption = 'Revisar nombres duplicados';
                Image = CheckList;
                ToolTip = 'Busca nombres que resuelvan a dos cosas distintas: un parámetro y una variable de sistema, una fuente de datos y un concepto, etc. El motor los guarda a todos en el mismo diccionario, así que el segundo pisa al primero sin dar error y la fórmula sigue con el número equivocado.';

                trigger OnAction()
                var
                    Catalogo: Codeunit "Catálogo Variables Liq.";
                    Conflictos: Text;
                begin
                    Conflictos := Catalogo.NombresEnConflicto();
                    if Conflictos = '' then
                        Message(MsgSinConflictos)
                    else
                        Message(MsgConflictos, Conflictos);
                end;
            }
            action(SembrarEstandar)
            {
                ApplicationArea = All;
                Caption = 'Sembrar variables estándar';
                Image = Setup;
                ToolTip = 'Agrega las variables de sistema estándar que falten, con el nombre igual al código de cálculo. No modifica ni borra las que ya estén configuradas.';

                trigger OnAction()
                var
                    Gestion: Codeunit "Gestión Variables Sistema";
                    Agregadas: Integer;
                begin
                    Agregadas := Gestion.Sembrar();
                    CurrPage.Update(false);
                    if Agregadas = 0 then begin
                        Message(MsgNadaQueSembrar);
                        exit;
                    end;
                    Message(MsgSembradas, Agregadas);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';
                actionref(SembrarProm; SembrarEstandar) { }
            }
        }
    }

    var
        // Sin Confirm previo: la acción no pisa ni borra nada, así que no hay nada que confirmar.
        // Lo que sí importa decir es lo que NO sembró, que es lo único que queda por hacer a mano.
        MsgSembradas: Label '%1 variable(s) agregada(s).\\Falta configurar a mano las que necesitan que se les diga QUÉ sumar: YTD_ACUM y PERIODO_ACUM piden un acumulador, PERIODO_CONCEPTO un concepto y YTD_LINEAS un tipo de concepto. Una misma instalación suele tener varias de cada una, por eso no se siembran.', Comment = '%1=cantidad de variables agregadas';
        MsgSinConflictos: Label 'Ningún nombre está repetido entre parámetros, variables de sistema, fuentes de datos y códigos de concepto.';
        MsgConflictos: Label 'Estos nombres resuelven a dos cosas distintas. El que se calcule último pisa al otro, sin error:\%1\Renombrá uno de los dos. Ojo: el código de un concepto no se puede renombrar —viaja dentro del texto de las fórmulas— así que lo que conviene cambiar es el nombre de la variable.', Comment = '%1 = lista de conflictos';
        MsgNadaQueSembrar: Label 'No había nada que agregar: todos los códigos de cálculo estándar ya están configurados.';
}
