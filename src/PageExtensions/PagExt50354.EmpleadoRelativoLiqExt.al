namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;

pageextension 50354 "Empleado Relativo Liq. Ext." extends "Employee Relatives"
{
    layout
    {
        addafter("Birth Date")
        {
            field("Tipo Documento"; Rec."Tipo Documento")
            {
                ApplicationArea = All;
                ToolTip = 'Tipo de documento del familiar. Lo completa la importación SIRADIG con el código informado por AFIP.';
            }
            field("Nro. Documento"; Rec."Nro. Documento")
            {
                ApplicationArea = All;
                ToolTip = 'Número de documento del familiar. La importación SIRADIG lo usa para reconocer una carga ya existente y actualizarla en vez de duplicarla.';
            }
            // Campos de tableextension 50673 ("Final Version Customization Extension - Tables Only"),
            // no nuestros. Ojo: el motor NO lee estos dos para decidir la vigencia de una deducción de
            // Ganancias — usa "Fecha alta/baja familiar a cargo" (50010/50011). Ver Cod50016.
            field("Fecha inicial"; Rec."Fecha inicial")
            {
                ApplicationArea = All;
                ToolTip = 'Fecha de inicio del vínculo familiar.';
            }
            field("Fecha final"; Rec."Fecha final")
            {
                ApplicationArea = All;
                ToolTip = 'Fecha de fin del vínculo familiar. Vacío = vigente.';
            }
            field("Cód. Tipo Ded."; Rec."Cód. Tipo Ded.")
            {
                ApplicationArea = All;
                ToolTip = 'Parámetro de deducción de Ganancias 4ta que aplica a este familiar (ej. DED_CONYUGE, DED_HIJO_MENOR). Su Parámetro Vigente aporta el importe anual. Vacío = no genera deducción impositiva.';
            }
            field("% Deducción"; Rec."% Deducción")
            {
                ApplicationArea = All;
                ToolTip = 'Porcentaje de la deducción que aplica a este familiar. 100 = deducción completa, 50 = mitad (ej: hijo compartido). ATENCIÓN: cero NO anula la deducción — el motor lo lee como "sin cargar" y aplica el 100%. Para excluir a un familiar, dejá vacío el Cód. Tipo Ded. o cerrá su Fecha final.';
            }
            field("Adic. Obra Social"; Rec."Adic. Obra Social")
            {
                ApplicationArea = All;
                ToolTip = 'Indica si este familiar genera adicional de obra social del trabajador. Se usa para calcular 1,5% extra por cada familiar marcado.';
            }
        }
    }

    actions
    {
        addlast(processing)
        {
            action(MigrarFechasFamiliares)
            {
                ApplicationArea = All;
                Caption = 'Migrar fechas de familiares';
                Image = ChangeDate;
                ToolTip = 'Copia las fechas de alta y baja que hayan quedado en los campos viejos (familiar a cargo, impuesto) a Fecha inicial y Fecha final, que son las que lee el motor. No pisa ninguna fecha ya cargada y se puede correr las veces que haga falta.';

                trigger OnAction()
                var
                    Migracion: Codeunit "Migracion Fechas ImpFam";
                    Tocadas: Integer;
                begin
                    Tocadas := Migracion.Migrar();
                    if Tocadas = 0 then
                        Message(MsgSinCambios)
                    else
                        Message(MsgMigradas, Tocadas);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    var
        MsgSinCambios: Label 'No hubo nada que migrar: todos los familiares ya tienen sus fechas en Fecha inicial/Fecha final, o no tienen ninguna cargada.';
        MsgMigradas: Label 'Se migraron las fechas de %1 familiar(es).', Comment = '%1=cantidad de registros modificados';
}
