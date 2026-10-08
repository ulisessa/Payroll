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

            dataitem(Linea; "Entrada Registro Liq.")
            {
                DataItemLink = "No. Registro" = field("No. Registro");
                DataItemTableView = sorting("No. Registro", "No. Línea");

                column(Severidad; Format(Linea.Severidad)) { }
                column(Categoria; Format(Linea.Categoría)) { }
                column(CodConcepto; Linea."Cód. Concepto") { }
                column(NombreVariable; Linea."Nombre Variable") { }
                column(Mensaje; Linea.Mensaje) { }
                column(Detalle; Linea.Detalle) { }
                column(Importe; Linea.Importe) { }

                trigger OnPreDataItem()
                begin
                    // Sólo advertencias y errores: la traza informativa es el detalle de CADA
                    // concepto calculado y son cientos de filas por liquidación. Quien la necesita
                    // va al registro de procesos, que la tiene entera.
                    Linea.SetFilter(Severidad, '%1|%2',
                        Linea.Severidad::Advertencia, Linea.Severidad::Error);
                end;

                trigger OnAfterGetRecord()
                begin
                    TotalAvisos += 1;
                end;
            }

            trigger OnPreDataItem()
            begin
                // POR SESIÓN, no por registro. El informe es para el final de un proceso largo
                // —"Crear y calcular liquidaciones", el lanzador, un lote desde la lista—, donde lo
                // que hay para revisar es lo que dejó LA CORRIDA ENTERA, repartido en cientos de
                // registros. Para una liquidación suelta no se abre: ahí el cartel de siempre es
                // más rápido de leer que un informe que hay que esperar, mirar y cerrar.
                if not IsNullGuid(FSesion) then
                    Cabecera.SetRange("No. Sesión", FSesion);
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
        repeat
            Entrada.SetRange("No. Registro", Registro."No. Registro");
            Entrada.SetFilter(Severidad, '%1|%2',
                Entrada.Severidad::Advertencia, Entrada.Severidad::Error);
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
        TituloInformeLbl: Label 'Avisos del cálculo';
}
