namespace UAS.Payroll;

// Los avisos de una corrida de cálculo, como informe en vez de como cartel.
//
// Reemplaza el Message que salía al terminar de calcular una liquidación con todas las advertencias
// concatenadas en un solo texto separado por barras. Con dos o tres avisos se leía; con quince
// —que es lo normal en un tripulante con varios conceptos que miran parámetros— el cartel se pasaba
// de alto de la pantalla, no se podía copiar ni imprimir, y había que cerrarlo para seguir, con lo
// cual lo que uno quería anotar ya no estaba.
//
// NO ARMA NADA: lee "Entrada Registro Liq.", que es donde el motor ya deja cada aviso con su
// severidad, su categoría y su concepto. El cartel mostraba un texto que el motor concatenaba
// aparte, así que había dos versiones de lo mismo y sólo una quedaba guardada.
report 50047 "Avisos del Cálculo"
{
    ApplicationArea = All;
    Caption = 'Avisos del cálculo';
    UsageCategory = ReportsAndAnalysis;
    DefaultRenderingLayout = RDLCLayout;

    dataset
    {
        dataitem(Cabecera; "Registro Proceso Liq.")
        {
            DataItemTableView = sorting("No. Registro");

            column(NoRegistro; Cabecera."No. Registro") { }
            column(NoLiquidacion; Cabecera."No. Liquidación") { }
            column(NoEmpleado; Cabecera."No. Empleado") { }
            column(NombreEmpleado; Cabecera."Nombre Empleado") { }
            column(CodPeriodo; Cabecera."Cód. Período") { }
            column(CodTipoLiq; Cabecera."Cód. Tipo Liq.") { }
            column(FechaHoraInicio; Cabecera."Fecha Hora Inicio") { }
            column(TituloInforme; TituloInformeLbl) { }
            column(TotalAvisos; TotalAvisos) { }
            column(ResumenAlcance; FResumenAlcance) { }
            column(ResumenTotales; FResumenTotales) { }

            dataitem(Linea; "Entrada Registro Liq.")
            {
                DataItemLink = "No. Registro" = field("No. Registro");
                DataItemTableView = sorting("No. Registro", "No. Línea");

                column(Severidad; SeveridadVisible(Linea)) { }
                column(Categoria; Format(Linea.Categoría)) { }
                column(CodConcepto; Linea."Cód. Concepto") { }
                column(NombreVariable; Linea."Nombre Variable") { }
                column(Mensaje; Linea.Mensaje) { }
                column(Detalle; Linea.Detalle) { }
                column(Importe; Linea.Importe) { }
                column(SeccionInforme; SeccionDeEntrada(Linea)) { }
                column(OrdenSeccion; OrdenDeSeccion(Linea)) { }
                column(PrioridadSeveridad; PrioridadDeEntrada(Linea)) { }

                trigger OnPreDataItem()
                begin
                    // También las observaciones de orden, en su propia sección. La demás
                    // información sigue siendo la traza detallada del registro de procesos.
                    FiltrarEntradasVisibles(Linea);
                end;

            }

            trigger OnAfterGetRecord()
            begin
                // Un proceso sin avisos no debe producir una fila vacía en el dataset agrupado.
                if not FRegistrosConAvisos.ContainsKey(Cabecera."No. Registro") then
                    CurrReport.Skip();
            end;

            trigger OnPreDataItem()
            begin
                // POR SESIÓN, no por registro. El informe es para el final de un proceso largo
                // —"Crear y calcular liquidaciones", el lanzador, un lote desde la lista—, donde lo
                // que hay para revisar es lo que dejó LA CORRIDA ENTERA, repartido en cientos de
                // registros. Para una liquidación suelta no se abre: ahí el cartel de siempre es
                // más rápido de leer que un informe que hay que esperar, mirar y cerrar.
                if not IsNullGuid(FSesion) then
                    Cabecera.SetRange("No. Sesión", FSesion);
                CalcularResumen(Cabecera);
            end;
        }
    }

    // SIN ESTO EL INFORME NO ABRE. Un report de AL sin layout compila perfecto y recién falla en
    // runtime, con "El informe 50047 no tiene un diseño válido. Los tipos de diseño válidos son:
    // Word, RDLC, Excel y personalizado." No hay advertencia al compilar que lo anticipe.
    rendering
    {
        layout(RDLCLayout)
        {
            Type = RDLC;
            LayoutFile = './src/Reports/Rep50047.AvisosDelCalculo.rdl';
            Caption = 'Avisos del cálculo';
        }
    }

    /// <summary>Acota el informe a una corrida por lote, que es para lo que existe.</summary>
    procedure SetSesion(Sesion: Guid)
    begin
        FSesion := Sesion;
    end;

    internal procedure CalcularResumen(var FiltroRegistro: Record "Registro Proceso Liq.")
    var
        Registro: Record "Registro Proceso Liq.";
        Entrada: Record "Entrada Registro Liq.";
        Liquidaciones: Dictionary of [Code[20], Boolean];
        Periodos: Dictionary of [Code[10], Boolean];
        Cantidad: Integer;
        ListaPeriodos: Text;
        PrimerDocumento: Code[20];
        PrimerEmpleado: Code[20];
    begin
        TotalAvisos := 0;
        FTotalProcesos := 0;
        FTotalLiquidaciones := 0;
        FResumenAlcance := '';
        FResumenTotales := '';
        FTotalErrores := 0;
        FTotalAdvertencias := 0;
        FTotalControles := 0;
        Clear(FRegistrosConAvisos);
        Registro.CopyFilters(FiltroRegistro);
        Registro.SetLoadFields("No. Registro", "No. Liquidación", "No. Empleado", "Cód. Período");
        FiltrarEntradasVisibles(Entrada);
        Entrada.SetLoadFields(Severidad, Categoría);
        if Registro.FindSet() then
            repeat
                Entrada.SetRange("No. Registro", Registro."No. Registro");
                Cantidad := 0;
                if Entrada.FindSet() then
                    repeat
                        Cantidad += 1;
                        if EsControlDeOrden(Entrada) then
                            FTotalControles += 1
                        else
                            case Entrada.Severidad of
                                Entrada.Severidad::Error:
                                    FTotalErrores += 1;
                                Entrada.Severidad::Advertencia:
                                    FTotalAdvertencias += 1;
                            end;
                    until Entrada.Next() = 0;
                if Cantidad > 0 then begin
                    FRegistrosConAvisos.Add(Registro."No. Registro", Cantidad);
                    TotalAvisos += Cantidad;
                    FTotalProcesos += 1;
                    PrimerDocumento := Registro."No. Liquidación";
                    PrimerEmpleado := Registro."No. Empleado";
                    if Registro."No. Liquidación" <> '' then
                        if not Liquidaciones.ContainsKey(Registro."No. Liquidación") then
                            Liquidaciones.Add(Registro."No. Liquidación", true);
                    if Registro."Cód. Período" <> '' then
                        if not Periodos.ContainsKey(Registro."Cód. Período") then begin
                            Periodos.Add(Registro."Cód. Período", true);
                            if ListaPeriodos <> '' then ListaPeriodos += ', ';
                            ListaPeriodos += Registro."Cód. Período";
                        end;
                end;
            until Registro.Next() = 0;
        FTotalLiquidaciones := Liquidaciones.Count();
        FResumenAlcance := CorridaLbl;
        if (FTotalProcesos = 1) and (PrimerDocumento <> '') then
            FResumenAlcance := StrSubstNo(DocumentoLbl, PrimerDocumento, PrimerEmpleado);
        if ListaPeriodos <> '' then
            FResumenAlcance += StrSubstNo(PeriodosLbl, ListaPeriodos);
        FResumenTotales := StrSubstNo(TotalesLbl, TotalAvisos, FTotalProcesos, FTotalLiquidaciones,
            FTotalErrores, FTotalAdvertencias, FTotalControles);
    end;

    internal procedure ObtenerTotalesSecciones(var Errores: Integer; var Advertencias: Integer; var Controles: Integer)
    begin
        Errores := FTotalErrores;
        Advertencias := FTotalAdvertencias;
        Controles := FTotalControles;
    end;

    internal procedure FiltrarEntradasVisibles(var Entrada: Record "Entrada Registro Liq.")
    var
        GrupoAnterior: Integer;
    begin
        // El grupo -1 combina campos con OR: advertencia/error de cualquier categoría, O
        // categoría de orden (también información). Los filtros de sesión/registro siguen en AND.
        GrupoAnterior := Entrada.FilterGroup();
        Entrada.FilterGroup(-1);
        Entrada.SetFilter(Severidad, '%1|%2', Entrada.Severidad::Advertencia, Entrada.Severidad::Error);
        Entrada.SetRange(Categoría, Entrada.Categoría::"Orden Cálculo");
        Entrada.FilterGroup(GrupoAnterior);
    end;

    local procedure OrdenDeSeccion(Entrada: Record "Entrada Registro Liq."): Integer
    begin
        if EsControlDeOrden(Entrada) then
            exit(1);
        exit(0);
    end;

    local procedure EsControlDeOrden(Entrada: Record "Entrada Registro Liq."): Boolean
    begin
        // También reclasifica la PRESENTACIÓN de los avisos anteriores a este cambio. La entrada
        // histórica conserva su severidad, su contenido y sus metadatos. Un error sigue siendo error.
        exit((Entrada.Categoría = Entrada.Categoría::"Orden Cálculo") and
            (Entrada.Severidad <> Entrada.Severidad::Error));
    end;

    local procedure SeveridadVisible(Entrada: Record "Entrada Registro Liq."): Text
    begin
        if EsControlDeOrden(Entrada) then
            exit(ObservacionLbl);
        exit(Format(Entrada.Severidad));
    end;

    local procedure PrioridadDeEntrada(Entrada: Record "Entrada Registro Liq."): Integer
    begin
        if EsControlDeOrden(Entrada) then exit(0);
        exit(Entrada.Severidad.AsInteger());
    end;

    local procedure SeccionDeEntrada(Entrada: Record "Entrada Registro Liq."): Text
    begin
        if OrdenDeSeccion(Entrada) = 1 then
            exit(SeccionOrdenLbl);
        exit(SeccionAvisosLbl);
    end;

    internal procedure ObtenerResumen(var Avisos: Integer; var Procesos: Integer; var Liquidaciones: Integer; var Alcance: Text; var Totales: Text)
    begin
        Avisos := TotalAvisos;
        Procesos := FTotalProcesos;
        Liquidaciones := FTotalLiquidaciones;
        Alcance := FResumenAlcance;
        Totales := FResumenTotales;
    end;

    /// <summary>¿Esta corrida dejó avisos como para que valga la pena un informe?</summary>
    /// <remarks>
    /// Se pregunta ANTES de ejecutarlo, por dos motivos distintos. Uno: un informe vacío obliga a
    /// esperarlo, mirar que no hay nada y cerrarlo. El otro, y es el que decide el umbral: en un
    /// lote largo SIEMPRE hay algún aviso suelto, y abrir un informe por dos líneas molesta más de
    /// lo que ayuda. Con pocos avisos el resumen de texto los dice enteros y alcanza.
    /// </remarks>
    procedure ValeLaPena(Sesion: Guid): Boolean
    var
        Registro: Record "Registro Proceso Liq.";
        Entrada: Record "Entrada Registro Liq.";
        Cuantos: Integer;
    begin
        if IsNullGuid(Sesion) then
            exit(false);
        Registro.SetRange("No. Sesión", Sesion);
        Registro.SetLoadFields("No. Registro");
        if not Registro.FindSet() then
            exit(false);
        FiltrarEntradasVisibles(Entrada);
        repeat
            Entrada.SetRange("No. Registro", Registro."No. Registro");
            Cuantos += Entrada.Count();
            if Cuantos >= MinimoParaInforme() then
                exit(true);
        until Registro.Next() = 0;
        exit(false);
    end;

    /// <summary>A partir de cuántos avisos conviene el informe en vez del texto.</summary>
    /// <remarks>
    /// Cinco es donde el cartel deja de leerse de un vistazo: hasta cuatro entran en pantalla con
    /// su concepto y su variable, y de ahí para arriba empieza a crecer fuera de la ventana, que es
    /// el problema que el informe vino a resolver.
    /// </remarks>
    procedure MinimoParaInforme(): Integer
    begin
        // UNO, no cinco. Con cinco, una corrida con dos advertencias no abria el informe y esas dos
        // se mostraban en el cartel de resumen; ahora que el resumen no es un cartel, el umbral
        // alto las dejaria sin mostrar en ningun lado. El costo de bajarlo es abrir el informe por
        // dos lineas, que es justamente lo que se quiere.
        exit(1);
    end;

    var
        FSesion: Guid;
        TotalAvisos: Integer;
        FTotalProcesos: Integer;
        FTotalLiquidaciones: Integer;
        FTotalErrores: Integer;
        FTotalAdvertencias: Integer;
        FTotalControles: Integer;
        FRegistrosConAvisos: Dictionary of [Integer, Integer];
        FResumenAlcance: Text;
        FResumenTotales: Text;
        TituloInformeLbl: Label 'Avisos del cálculo';
        CorridaLbl: Label 'Avisos de la corrida seleccionada';
        DocumentoLbl: Label '%1 | Empleado %2';
        PeriodosLbl: Label ' | Período(s): %1';
        TotalesLbl: Label '%1 entrada(s) en %2 proceso(s) de %3 liquidación(es) | %4 error(es), %5 advertencia(s) y %6 control(es) de bases y orden';
        SeccionAvisosLbl: Label 'Advertencias y errores';
        SeccionOrdenLbl: Label 'Control de bases y orden';
        ObservacionLbl: Label 'Observación';
}
