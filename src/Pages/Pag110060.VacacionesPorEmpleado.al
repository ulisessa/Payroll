namespace UAS.Payroll;

// El promedio de vacaciones desarmado paso a paso, por empleado.
//
// El valor de un día de vacaciones sale de una cadena larga —fase, ventana, meses, base, promedio,
// /25— y cuando no cuadra hay que poder ver EN QUÉ ESLABÓN se rompe. Un recibo muestra el resultado;
// esta vista muestra de dónde salió.
//
// Las tres puntas ya fallaron por separado en la conciliación de enero de 2026: la ventana se metía
// en la fase anterior y promediaba otra relación laboral, el divisor contaba meses que el numerador
// no sumaba, y la base llegaba corta porque un aportante no entraba al acumulador. Las tres daban el
// mismo síntoma —un importe bajo sin un solo error— y un total por empleado las escondía.
page 110060 "Vacaciones por Empleado"
{
    ApplicationArea = All;
    Caption = 'Vacaciones por Empleado';
    PageType = List;
    UsageCategory = ReportsAndAnalysis;
    SourceTable = "Vacaciones Buffer Liq.";
    SourceTableTemporary = true;
    InsertAllowed = false;
    DeleteAllowed = false;
    // Sin Editable = false a nivel página: bloquearía también los campos de la cabecera, que son lo
    // único que acá se escribe. La grilla se protege campo por campo.

    layout
    {
        area(Content)
        {
            group(Corte)
            {
                Caption = 'Corte';

                field(CodPeriodo; CodPeriodo)
                {
                    ApplicationArea = All;
                    Caption = 'Período';
                    TableRelation = "Período Liquidación";
                    ToolTip = 'Período a analizar. Se parte de las liquidaciones de ese período, no de la nómina entera.';

                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
                field(FiltroEmpleado; FiltroEmpleado)
                {
                    ApplicationArea = All;
                    Caption = 'Filtro de empleado';
                    ToolTip = 'Acepta un filtro de Business Central: un número, varios separados por barra vertical, o un rango. En blanco, todos los que tengan liquidación en el período.';

                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
                field(ConHuecos; ConHuecos)
                {
                    ApplicationArea = All;
                    Caption = 'Con meses sin base';
                    Editable = false;
                    ToolTip = 'Cuántos tienen algún mes que el divisor cuenta pero que no aporta base. Son los que van a pagar de menos sin dar ningún error.';
                }
            }

            repeater(Grilla)
            {
                field("No. Empleado"; Rec."No. Empleado") { ApplicationArea = All; Editable = false; }
                field("Nombre Empleado"; Rec."Nombre Empleado") { ApplicationArea = All; Editable = false; }
                field(Tripulante; Rec.Tripulante)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'El art. 49 del CCT —181 días, uno cada veinte— rige sólo para tripulantes; el personal de tierra va por LCT.';
                }
                field("Cód. Convenio"; Rec."Cód. Convenio") { ApplicationArea = All; Editable = false; }
                field("Cód. Categoría"; Rec."Cód. Categoría") { ApplicationArea = All; Editable = false; }
                field("Fecha Alta Fase"; Rec."Fecha Alta Fase")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Alta de la fase vigente. El promedio no puede cruzar hacia atrás de esta fecha: sería otra relación laboral.';
                }
                field("Fecha Baja"; Rec."Fecha Baja") { ApplicationArea = All; Editable = false; }
                field("Días Prestación"; Rec."Días Prestación")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Días corridos de la fase. Por debajo de 181 el tripulante no llega al mínimo del art. 49 y le corresponde un día cada veinte.';
                }
                field("Ventana Desde"; Rec."Ventana Desde") { ApplicationArea = All; Editable = false; }
                field("Ventana Hasta"; Rec."Ventana Hasta") { ApplicationArea = All; Editable = false; }
                field("Ventana es Fracción"; Rec."Ventana es Fracción")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'La ventana es el propio mes que se liquida, porque la fase arrancó en él y no hay meses anteriores que mirar.';
                }
                field("Días Prestación Ventana"; Rec."Días Prestación Ventana")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'El divisor del art. 49, en DÍAS: el promedio es base / días * 30. Un mes trabajado a medias pesa los días que pesa, no un mes entero.';
                }
                field("Meses con Dato"; Rec."Meses con Dato")
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = EstiloMeses;
                }
                field("Base Acumulada"; Rec."Base Acumulada") { ApplicationArea = All; Editable = false; }
                field("Promedio Mensual"; Rec."Promedio Mensual") { ApplicationArea = All; Editable = false; }
                field("Valor Día"; Rec."Valor Día")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'El promedio mensual dividido por 25, que es el divisor que fija el art. 49.';
                }
                field("Días Art. 150"; Rec."Días Art. 150") { ApplicationArea = All; Editable = false; }
                field("Días Proporcionales"; Rec."Días Proporcionales")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Los días del art. 150 si llegó a 181 días de prestación; si no, uno cada veinte, truncado.';
                }
                field("Días Gozados"; Rec."Días Gozados") { ApplicationArea = All; Editable = false; }
                field("Días No Gozados"; Rec."Días No Gozados") { ApplicationArea = All; Editable = false; }
                field("Importe No Gozadas"; Rec."Importe No Gozadas")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Lo que esta vista calcula.';
                }
                field("Liquidado 3973"; Rec."Liquidado 3973")
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = EstiloLiquidado;
                    ToolTip = 'Lo que el motor liquidó de verdad. Si no coincide con el importe calculado, uno de los dos está mal y el resto de las columnas dice cuál.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(VerMeses)
            {
                ApplicationArea = All;
                Caption = 'Meses del promedio';
                Image = PeriodEntries;
                ToolTip = 'Abre el detalle mes a mes de la ventana: qué aportó cada uno y si cuenta en el divisor.';

                trigger OnAction()
                var
                    TempMes: Record "Vac. Mes Buffer Liq." temporary;
                    VacMgt: Codeunit "Análisis Vacaciones";
                    PagMeses: Page "Meses del Promedio";
                begin
                    if Rec."No. Empleado" = '' then
                        exit;
                    VacMgt.DetalleMeses(Rec."No. Empleado", CodPeriodo, TempMes);
                    PagMeses.Cargar(TempMes, Rec."No. Empleado", Rec."Nombre Empleado");
                    PagMeses.RunModal();
                end;
            }
            action(Recargar)
            {
                ApplicationArea = All;
                Caption = 'Recargar';
                Image = Refresh;
                ToolTip = 'Vuelve a leer las liquidaciones.';

                trigger OnAction()
                begin
                    Cargar();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(VerMeses_Promoted; VerMeses) { }
                actionref(Recargar_Promoted; Recargar) { }
            }
        }
    }

    var
        CodPeriodo: Code[20];
        FiltroEmpleado: Text;
        ConHuecos: Integer;
        EstiloMeses: Text;
        EstiloLiquidado: Text;

    trigger OnOpenPage()
    var
        Periodo: Record "Período Liquidación";
    begin
        // Arranca en el último período con liquidaciones, que es el que se está conciliando.
        Periodo.SetCurrentKey(Código);
        if Periodo.FindLast() then
            CodPeriodo := Periodo.Código;
        Cargar();
    end;

    trigger OnAfterGetRecord()
    begin
        // Rojo cuando el divisor cuenta meses que el numerador no suma: es el caso que paga de menos
        // sin dar ningún error.
        if (Rec."Meses con Dato" = 0) or (Rec."Días Prestación Ventana" = 0) then
            EstiloMeses := 'Unfavorable'
        else
            EstiloMeses := 'Standard';

        if Round(Rec."Liquidado 3973", 0.01) <> Round(Rec."Importe No Gozadas", 0.01) then
            EstiloLiquidado := 'Attention'
        else
            EstiloLiquidado := 'Favorable';
    end;

    local procedure Cargar()
    var
        VacMgt: Codeunit "Análisis Vacaciones";
    begin
        VacMgt.Resumen(FiltroEmpleado, CodPeriodo, Rec);

        ConHuecos := 0;
        Rec.Reset();
        if Rec.FindSet() then
            repeat
                if (Rec."Meses con Dato" = 0) or (Rec."Días Prestación Ventana" = 0) then
                    ConHuecos += 1;
            until Rec.Next() = 0;
        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;
}
