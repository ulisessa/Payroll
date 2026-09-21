namespace UAS.Payroll;

using Microsoft.Projects.Project.Job;

// Control de liquidación de una marea, para el liquidador.
//
// Reemplaza el armado a mano en Excel: exportar las líneas de cada liquidación por separado, pegarlas
// una debajo de otra y recién ahí poder comparar contra el sistema anterior. Acá sale toda la
// tripulación de una vez, como matriz de conceptos por tripulante: se recorre una fila de punta a
// punta y se ve a quién le salió distinto.
//
// Hubo una segunda grilla con el detalle línea por línea. Se sacó porque la matriz ya muestra a cada
// tripulante en su columna y el detalle repetía los mismos números en vertical; para ir al fondo de
// un caso está el drill-down de cada celda, que abre la liquidación con su fórmula y sus variables.
page 110022 "Control Liquidación Marea"
{
    ApplicationArea = All;
    Caption = 'Control de Liquidación por Marea';
    PageType = Card;
    UsageCategory = ReportsAndAnalysis;
    SourceTable = Job;
    InsertAllowed = false;
    DeleteAllowed = false;
    // A propósito SIN "Editable = false" a nivel página: eso bloquea TODOS los controles, incluidos
    // los de filtro, que no pertenecen al registro y son lo único que acá se escribe. La protección
    // del proyecto va campo por campo — todo lo que sale de Job y todo lo calculado es Editable =
    // false, y lo único editable son los dos filtros. Es el mismo esquema de "Analysis by
    // Dimensions" en la base.

    layout
    {
        area(Content)
        {
            group(Marea)
            {
                Caption = 'Marea';

                field("No."; Rec."No.") { ApplicationArea = All; Editable = false; Caption = 'Proyecto'; }
                field(Description; Rec.Description) { ApplicationArea = All; Editable = false; Caption = 'Descripción'; }
                field("Starting Date"; Rec."Starting Date") { ApplicationArea = All; Editable = false; Caption = 'Fecha de salida'; }
                field("Hora de zarpada"; Rec."Hora de zarpada")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Antes de las 12:00 el día de zarpada cuenta como navegación; de 12:00 en adelante, como puerto. Es lo que hace que los días de navegación no sean simplemente la resta de las fechas.';
                }
                field("Ending Date"; Rec."Ending Date") { ApplicationArea = All; Editable = false; Caption = 'Fecha de arribo'; }
                field("Hora ingreso a puerto"; Rec."Hora ingreso a puerto")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Hora de arribo';
                    ToolTip = 'Antes de las 12:00 el día de arribo cuenta como puerto; de 12:00 en adelante, como navegación.';
                }
                field("Zona Desfavorable"; Rec."Zona Desfavorable")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Adicional patagónico del viaje, que comparte toda la dotación. En 0, cada empleado usa el de su ficha — y entonces este número no explica las diferencias que se vean en la matriz.';
                }
            }
            group(DatosCalculo)
            {
                Caption = 'Datos de cálculo';

                field(DiasNavegacion; DiasNavegacion)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Días de navegación';
                    DecimalPlaces = 0 : 2;
                    ToolTip = 'Días de navegación que el motor usó al liquidar (variable de sistema DIAS_PROYECTO). Sale de lo que quedó calculado, no de recalcularlo acá: si difiriera del recibo, el control no controlaría nada.';
                }
                field(DiasPuerto; DiasPuerto)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Días de puerto';
                    DecimalPlaces = 0 : 2;
                    ToolTip = 'Días de puerto de la marea (variable de sistema DIAS_PUERTO), los bordes del viaje según las horas de zarpada y arribo.';
                }
                field(DiasFeriados; DiasFeriados)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Feriados a bordo';
                    DecimalPlaces = 0 : 2;
                    ToolTip = 'Feriados dentro de la ventana de la marea (variable de sistema DIAS_FERIADOS_MAREA), base del recargo por feriado trabajado.';
                }
                field(TipoCambio; TipoCambio)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Tipo de cambio';
                    ToolTip = 'Cuántos pesos vale una unidad de cada moneda que apareció en los parámetros que la marea usó, y de qué fecha es la cotización que se aplicó. Sale de la misma llamada que hace el motor al liquidar, así que es el número con el que se calculó y no la cotización de hoy.';
                }
            }
            group(Netos)
            {
                Caption = 'Netos de la tripulación';

                field(NetoMinimo; NetoMinimo)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Neto mínimo';
                    ToolTip = 'El neto más bajo del filtro actual. Junto con el máximo, deja ver un neto fuera de rango sin recorrer la matriz.';
                }
                field(NetoPromedio; NetoPromedio) { ApplicationArea = All; Editable = false; Caption = 'Neto promedio'; }
                field(NetoMaximo; NetoMaximo) { ApplicationArea = All; Editable = false; Caption = 'Neto máximo'; }
            }
            group(Filtros)
            {
                Caption = 'Filtros';

                field(FiltroConvenio; FiltroConvenio)
                {
                    ApplicationArea = All;
                    Caption = 'Convenio';
                    ToolTip = 'Deja en el control únicamente a los tripulantes encuadrados en este convenio. En blanco, toda la marea.';

                    trigger OnLookup(var Texto: Text): Boolean
                    var
                        Conv: Record "Convenio Colectivo";
                    begin
                        if Conv.Get(FiltroConvenio) then;
                        if Page.RunModal(Page::"Convenios Colectivos", Conv) <> Action::LookupOK then
                            exit(false);
                        Texto := Conv.Código;
                        exit(true);
                    end;

                    trigger OnValidate()
                    begin
                        // Una categoría solo existe dentro de su convenio: dejarla puesta al cambiar
                        // de convenio daría un filtro que no puede coincidir con nadie.
                        if FiltroConvenio = '' then
                            FiltroCategoria := ''
                        else
                            if not CategoriaExiste() then
                                FiltroCategoria := '';
                        Cargar();
                    end;
                }
                field(FiltroCategoria; FiltroCategoria)
                {
                    ApplicationArea = All;
                    Caption = 'Categoría';
                    ToolTip = 'Deja en el control únicamente a los tripulantes de esta categoría. Es la del encuadre del empleado; los conceptos que se liquidan con el convenio de la asignación a la marea siguen mostrándose, con el par que usaron.';

                    trigger OnLookup(var Texto: Text): Boolean
                    var
                        Cat: Record "Categoría CCT";
                    begin
                        if FiltroConvenio <> '' then
                            Cat.SetRange("Cód. Convenio", FiltroConvenio);
                        if Page.RunModal(Page::"Categorías CCT", Cat) <> Action::LookupOK then
                            exit(false);
                        FiltroConvenio := Cat."Cód. Convenio";
                        Texto := Cat.Código;
                        exit(true);
                    end;

                    trigger OnValidate()
                    begin
                        Cargar();
                    end;
                }
            }
            group(Totales)
            {
                Caption = 'Totales de la marea';

                field(CantLiquidaciones; CantLiquidaciones)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Liquidaciones';
                    ToolTip = 'Liquidaciones de este proyecto, en cualquier estado. Un control que escondiera los borradores serviría recién después de aprobar, que es cuando ya no se puede corregir.';
                }
                field(TotalHaberes; TotalHaberes) { ApplicationArea = All; Editable = false; Caption = 'Total Haberes'; }
                field(TotalDescuentos; TotalDescuentos) { ApplicationArea = All; Editable = false; Caption = 'Total Descuentos'; }
                field(TotalContribuciones; TotalContribuciones) { ApplicationArea = All; Editable = false; Caption = 'Total Contribuciones'; }
                field(TotalNeto; TotalNeto) { ApplicationArea = All; Editable = false; Caption = 'Neto a Pagar'; Style = Strong; }
                field(RangoColumnas; RangoColumnas)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Tripulantes a la vista';
                    ToolTip = 'Qué columnas de la matriz se están viendo. La matriz muestra hasta 32 tripulantes por vez; si la marea tiene más, el resto se recorre con "Columnas siguientes".';
                }
                field(CantDiferencias; CantDiferencias)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Diferencias';
                    Style = Attention;
                    StyleExpr = CantDiferencias > 0;
                    ToolTip = 'Cuántos casos hay de un tripulante que cobró distinto que la mayoría de su categoría. En cero, la matriz se puede leer categoría por categoría; con algo, están listados en la grilla de abajo.';
                }
                field(ConceptosOcultos; ConceptosOcultos)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Conceptos ocultos';
                    Style = Ambiguous;
                    StyleExpr = ConceptosOcultos > 0;
                    ToolTip = 'Conceptos que la matriz no está mostrando: los que dieron importe cero en toda la tripulación y los que no imprimen en recibo (contribuciones patronales, acumuladores). Los totales de arriba SÍ los incluyen, porque salen de las cabeceras. Con "Mostrar todos los conceptos" aparecen.';
                }
            }
            part(VariablesComunes; "Marea Variables Comunes Sub")
            {
                ApplicationArea = All;
                Caption = 'Datos de cálculo de la marea';
            }
            part(Resumen; "Control Marea Matriz Sub")
            {
                ApplicationArea = All;
                Caption = 'Conceptos por tripulante';
            }
            part(Diferencias; "Control Marea Difs. Sub")
            {
                ApplicationArea = All;
                Caption = 'Diferencias dentro de la misma categoría';
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Actualizar)
            {
                ApplicationArea = All;
                Caption = 'Actualizar';
                Image = Refresh;
                ToolTip = 'Vuelve a leer las liquidaciones de la marea y rehace las dos secciones.';
                trigger OnAction()
                begin
                    Cargar();
                end;
            }
            action(VerCantidades)
            {
                ApplicationArea = All;
                Caption = 'Ver cantidades';
                Image = UnitOfMeasure;
                ToolTip = 'Cambia las celdas de la matriz de importes a cantidades (kilos, días, horas). En los conceptos de producción es la primera pregunta cuando dos tripulantes de la misma categoría cobraron distinto: si les cargaron cantidades distintas, la diferencia no está en la fórmula.';
                trigger OnAction()
                begin
                    MostrarCantidades := not MostrarCantidades;
                    CurrPage.Resumen.Page.VerCantidades(MostrarCantidades);
                end;
            }
            action(MostrarTodosConceptos)
            {
                ApplicationArea = All;
                Caption = 'Mostrar todos los conceptos';
                Image = ShowList;
                ToolTip = 'Trae de vuelta los conceptos que la matriz oculta: los de importe cero en toda la tripulación y los que no imprimen en recibo. Sirve para verificar que un concepto que "no aparece" está oculto por regla y no porque no se calculó.';
                trigger OnAction()
                begin
                    MostrarTodos := not MostrarTodos;
                    CurrPage.Resumen.Page.MostrarTodos(MostrarTodos);
                    ConceptosOcultos := CurrPage.Resumen.Page.ConceptosOcultos();
                end;
            }
            action(ColumnasAnteriores)
            {
                ApplicationArea = All;
                Caption = 'Columnas anteriores';
                Image = PreviousSet;
                ToolTip = 'Corre la matriz al bloque anterior de tripulantes.';
                trigger OnAction()
                begin
                    CurrPage.Resumen.Page.ColumnasAnteriores();
                    RangoColumnas := CurrPage.Resumen.Page.RangoColumnas();
                end;
            }
            action(ColumnasSiguientes)
            {
                ApplicationArea = All;
                Caption = 'Columnas siguientes';
                Image = NextSet;
                ToolTip = 'Corre la matriz al siguiente bloque de tripulantes.';
                trigger OnAction()
                begin
                    CurrPage.Resumen.Page.ColumnasSiguientes();
                    RangoColumnas := CurrPage.Resumen.Page.RangoColumnas();
                end;
            }
            action(ControlExcel)
            {
                ApplicationArea = All;
                Caption = 'Control de Liquidación (Excel)';
                Image = ExportToExcel;
                ToolTip = 'Baja a Excel la matriz de control: una fila por concepto y una columna por categoría, con el importe de un tripulante representante de cada una, los totales del viaje y —al pie— los casos en que alguien cobró distinto que sus pares. Respeta los filtros de convenio y categoría de la cabecera.';
                trigger OnAction()
                var
                    ControlExcelLiq: Codeunit "Control Marea Excel Liq.";
                begin
                    ControlExcelLiq.SetFiltro(FiltroConvenio, FiltroCategoria);
                    ControlExcelLiq.Generar(Rec."No.");
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Proceso';
                actionref(ActualizarProm; Actualizar) { }
                actionref(VerCantidadesProm; VerCantidades) { }
                actionref(MostrarTodosProm; MostrarTodosConceptos) { }
                actionref(ColumnasAnterioresProm; ColumnasAnteriores) { }
                actionref(ColumnasSiguientesProm; ColumnasSiguientes) { }
                actionref(ControlExcelProm; ControlExcel) { }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        Cargar();
    end;

    local procedure Cargar()
    var
        Buffer: Record "Control Marea Buffer" temporary;
        Comunes: Record "Resumen Variable Liq." temporary;
        Liq: Record "Liquidación";
        Control: Codeunit "Control Marea Liq.";
    begin
        Control.Construir(Buffer, Rec."No.");

        Control.ConstruirVariablesComunes(Comunes, Rec."No.", FiltroConvenio, FiltroCategoria);
        DiasNavegacion := Control.ValorVariableSistema(Comunes, 'DIAS_PROYECTO');
        DiasPuerto := Control.ValorVariableSistema(Comunes, 'DIAS_PUERTO');
        DiasFeriados := Control.ValorVariableSistema(Comunes, 'DIAS_FERIADOS_MAREA');
        TipoCambio := Control.TiposDeCambio(Rec."No.", FiltroConvenio, FiltroCategoria);
        Control.Netos(Rec."No.", FiltroConvenio, FiltroCategoria, NetoMinimo, NetoMaximo, NetoPromedio);
        CurrPage.VariablesComunes.Page.Cargar(Comunes);
        CurrPage.Resumen.Page.Filtrar(FiltroConvenio, FiltroCategoria);
        CurrPage.Resumen.Page.Cargar(Buffer);
        CurrPage.Resumen.Page.VerCantidades(MostrarCantidades);
        CurrPage.Resumen.Page.MostrarTodos(MostrarTodos);
        CurrPage.Diferencias.Page.Cargar(Buffer, FiltroConvenio, FiltroCategoria);
        RangoColumnas := CurrPage.Resumen.Page.RangoColumnas();
        ConceptosOcultos := CurrPage.Resumen.Page.ConceptosOcultos();
        CantDiferencias := CurrPage.Diferencias.Page.Cuantas();

        CantLiquidaciones := 0;
        Clear(TotalHaberes);
        Clear(TotalDescuentos);
        Clear(TotalContribuciones);
        Clear(TotalNeto);
        // Los totales salen de las cabeceras y no de sumar el detalle: son los que el motor dejó
        // guardados y los que se ven en cada liquidación, así que si alguna vez no coincidieran con
        // la suma de las líneas, eso mismo es lo que hay que mirar.
        //
        // El filtro se aplica también acá: un total de toda la marea encima de una matriz de cuatro
        // capitanes invita a restar dos números que no se pueden restar.
        Liq.SetCurrentKey("No. Proyecto");
        Liq.SetRange("No. Proyecto", Rec."No.");
        if FiltroConvenio <> '' then
            Liq.SetRange("Cód. Convenio", FiltroConvenio);
        if FiltroCategoria <> '' then
            Liq.SetRange("Cód. Categoría", FiltroCategoria);
        if Liq.FindSet() then
            repeat
                CantLiquidaciones += 1;
                TotalHaberes += Liq."Total Haberes";
                TotalDescuentos += Liq."Total Descuentos";
                TotalContribuciones += Liq."Total Contribuciones";
                TotalNeto += Liq."Neto a Pagar";
            until Liq.Next() = 0;
    end;

    /// <summary>Si la categoría filtrada pertenece al convenio filtrado.</summary>
    local procedure CategoriaExiste(): Boolean
    var
        Cat: Record "Categoría CCT";
    begin
        if FiltroCategoria = '' then
            exit(true);
        exit(Cat.Get(FiltroConvenio, FiltroCategoria));
    end;

    var
        FiltroConvenio: Code[20];
        FiltroCategoria: Code[20];
        MostrarCantidades: Boolean;
        MostrarTodos: Boolean;
        ConceptosOcultos: Integer;
        CantDiferencias: Integer;
        RangoColumnas: Text;
        CantLiquidaciones: Integer;
        TotalHaberes: Decimal;
        TotalDescuentos: Decimal;
        TotalContribuciones: Decimal;
        TotalNeto: Decimal;
        DiasNavegacion: Decimal;
        DiasPuerto: Decimal;
        DiasFeriados: Decimal;
        NetoMinimo: Decimal;
        NetoMaximo: Decimal;
        NetoPromedio: Decimal;
        TipoCambio: Text;
}
