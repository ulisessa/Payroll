namespace UAS.Payroll;

/// <summary>
/// Emite el reporte mensual para SICOSS en Excel.
/// </summary>
/// <remarks>
/// SIN TABLA DE ORIGEN: la página no muestra datos, elige el mes y los filtros. Una grilla de
/// previsualización necesitaría una tabla buffer de treinta y pico de campos para repetir lo que ya
/// se ve mejor en el Excel; lo que sí hace falta antes de generar es saber si hay algo que avisar, y
/// eso cabe en una línea.
/// </remarks>
page 110063 "Reporte SICOSS"
{
    ApplicationArea = All;
    Caption = 'Reporte SICOSS';
    PageType = Card;
    UsageCategory = Tasks;

    layout
    {
        area(Content)
        {
            group(Seleccion)
            {
                Caption = 'Qué declarar';

                field(FCodPeriodo; FCodPeriodo)
                {
                    ApplicationArea = All;
                    Caption = 'Período';
                    TableRelation = "Período Liquidación".Código;
                    ToolTip = 'Mes a declarar. El reporte toma todas las liquidaciones del período: una línea por empleado, con los topes aplicados una sola vez sobre el mes entero.';

                    trigger OnValidate()
                    begin
                        FResumen := '';
                    end;
                }
                field(FTiposLiq; FTiposLiq)
                {
                    ApplicationArea = All;
                    Caption = 'Tipos de liquidación';
                    Editable = false;
                    ToolTip = 'Tipos de liquidación a incluir. Vacío = todos, que es lo normal: SICOSS declara el mes completo, con su regular, sus cierres de marea y sus vacaciones. Los devengos nunca entran, aunque se elija el tipo DEVENGADOS.';

                    trigger OnAssistEdit()
                    var
                        Selector: Page "Selector Tipos Liq.";
                    begin
                        Selector.SetSeleccion(CopyStr(FTiposLiq, 1, 250));
                        Selector.RunModal();
                        if Selector.Confirmado() then begin
                            FTiposLiq := Selector.GetSeleccion();
                            FResumen := '';
                            CurrPage.Update(false);
                        end;
                    end;
                }
                field(FIncluirBorradores; FIncluirBorradores)
                {
                    ApplicationArea = All;
                    Caption = 'Incluir borradores';
                    ToolTip = 'Activado, suma también las liquidaciones en Borrador. Sirve para mirar cómo va a quedar la declaración antes de aprobar el mes; para declarar de verdad tiene que estar desactivado.';

                    trigger OnValidate()
                    begin
                        FResumen := '';
                    end;
                }
            }
            group(Control)
            {
                Caption = 'Antes de generar';

                field(FResumen; FResumen)
                {
                    ApplicationArea = All;
                    Caption = 'Resumen';
                    Editable = false;
                    MultiLine = true;
                    ToolTip = 'Lo que va a salir y lo que hay que revisar. Se calcula con Actualizar resumen; el detalle de cada aviso va en la hoja Avisos del Excel.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Generar)
            {
                ApplicationArea = All;
                Caption = 'Generar Excel';
                Image = Excel;
                ToolTip = 'Arma el libro con las hojas TOTALES, CNT, FSR, Dto 814 y Avisos, y lo baja.';

                trigger OnAction()
                var
                    Reporte: Codeunit "Reporte SICOSS Liq.";
                begin
                    Reporte.Generar(FCodPeriodo, FTiposLiq, FIncluirBorradores);
                end;
            }
            action(ActualizarResumen)
            {
                ApplicationArea = All;
                Caption = 'Actualizar resumen';
                Image = Refresh;
                ToolTip = 'Recorre el mes y muestra cuántos empleados y liquidaciones entran, y cuántos avisos hay, sin generar el Excel.';

                trigger OnAction()
                var
                    Reporte: Codeunit "Reporte SICOSS Liq.";
                begin
                    FResumen := Reporte.Resumen(FCodPeriodo, FTiposLiq, FIncluirBorradores);
                    if FResumen = '' then
                        FResumen := TxtElegirPeriodo;
                end;
            }
            action(Parametros)
            {
                ApplicationArea = All;
                Caption = 'Parámetros';
                Image = Setup;
                RunObject = page "Parámetros";
                ToolTip = 'Abre los parámetros, que es donde se cargan los topes, la detracción, las alícuotas y los porcentajes del decreto 814 que el reporte lee.';
            }
            action(Conceptos)
            {
                ApplicationArea = All;
                Caption = 'Conceptos';
                Image = Journals;
                RunObject = page "Conceptos Liquidación";
                ToolTip = 'Abre los conceptos, que es donde se asigna la Columna SICOSS de cada aporte y contribución. Un concepto con importe y sin columna aparece en la hoja Avisos.';
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(Generar_Promoted; Generar) { }
                actionref(ActualizarResumen_Promoted; ActualizarResumen) { }
            }
        }
    }

    /// <remarks>
    /// Arranca en el último período con liquidaciones y no en el del calendario: la declaración se
    /// arma después de cerrar el mes, así que el mes corriente casi nunca es el que se declara.
    /// </remarks>
    trigger OnOpenPage()
    var
        Periodo: Record "Período Liquidación";
        Liq: Record "Liquidación";
    begin
        Periodo.SetCurrentKey(Año, Mes);
        Periodo.Ascending(false);
        if Periodo.FindSet() then
            repeat
                Liq.SetRange("Cód. Período", Periodo.Código);
                if not Liq.IsEmpty() then begin
                    FCodPeriodo := Periodo.Código;
                    exit;
                end;
            until Periodo.Next() = 0;
    end;

    var
        FCodPeriodo: Code[10];
        FTiposLiq: Text[250];
        FIncluirBorradores: Boolean;
        FResumen: Text;
        TxtElegirPeriodo: Label 'Elegí el período a declarar.';
}
