namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.Projects.Project.Job;

page 110051 "Comparar BC contra Meta4"
{
    ApplicationArea = All;
    Caption = 'Comparar BC contra Meta4';
    PageType = List;
    UsageCategory = Lists;
    SourceTable = "Comp. Meta4 Buffer";
    SourceTableTemporary = true;
    // ESTA PAGINA NO LLEVA "Editable = false" NI "ModifyAllowed = false", y las dos cosas por el
    // mismo motivo: dejan la PAGINA en estado de solo lectura, y entonces no se puede tocar ningun
    // control — tampoco los campos de filtro, que no son del registro sino variables globales. Un
    // "Editable = true" en el campo no alcanza, porque la editabilidad de la pagina manda sobre la
    // del control.
    //
    // Con Insert, Modify y Delete los tres cerrados, BC resuelve la pagina entera como no editable.
    // Por eso queda Modify abierto.
    //
    // Los datos igual estan protegidos: el origen es TEMPORAL —lo que se escriba no va a ninguna
    // tabla— y todos los campos del repetidor son "Editable = false". Lo unico editable es lo que
    // tiene que serlo: los filtros.
    InsertAllowed = false;
    DeleteAllowed = false;

    // Pone lado a lado lo que liquidó Meta4 y lo que calculó BC, por empleado y mes. Es la pantalla
    // de la corrida en paralelo: mientras Meta4 siga siendo producción, esto es lo que dice si el
    // motor de BC está dando bien.
    //
    // ARRANCA EN 2026 porque es el año en que los dos sistemas corrieron a la vez. 2025 se puede
    // mirar igual, pero ahí BC no calculó nada: la columna BC va a estar vacía salvo por la
    // historia importada, que es el propio Meta4 y compararla contra sí misma no dice nada.

    layout
    {
        area(Content)
        {
            group(Filtros)
            {
                Caption = 'Filtros';
                field(FAnio; FAnio)
                {
                    ApplicationArea = All;
                    Editable = true;
                    Caption = 'Año';
                    ToolTip = 'Año a comparar. 2026 es el año en que Meta4 y BC corrieron en paralelo.';
                    trigger OnValidate() begin RecargarEnElLugar(); end;
                }
                field(FMesDesde; FMesDesde)
                {
                    ApplicationArea = All;
                    Editable = true;
                    Caption = 'Mes desde';
                    MinValue = 0;
                    MaxValue = 12;
                    ToolTip = 'Primer mes a comparar, 1 a 12. En cero, desde enero.';
                    trigger OnValidate() begin RecargarEnElLugar(); end;
                }
                field(FMesHasta; FMesHasta)
                {
                    ApplicationArea = All;
                    Editable = true;
                    Caption = 'Mes hasta';
                    MinValue = 0;
                    MaxValue = 12;
                    ToolTip = 'Último mes a comparar, 1 a 12. En cero, hasta diciembre. El corte es por MES entero y no por fecha suelta: del lado de Meta4 el bruto es un acumulador corrido dentro del mes, así que partir un mes por la mitad compararía un acumulado contra unos pocos días de BC.';
                    trigger OnValidate() begin RecargarEnElLugar(); end;
                }
                field(FMarea; FMarea)
                {
                    ApplicationArea = All;
                    Editable = true;
                    Caption = 'Marea';
                    TableRelation = Job."No.";
                    ToolTip = 'Proyecto de la marea, que es buque y número de marea a la vez (PP-128-000059 = buque 128, marea 59). Compara recibo de marea contra recibo de marea: de los dos lados entra sólo lo de esa marea, sin la liquidación mensual. Para ver el mes completo, dejalo en blanco.';
                    trigger OnValidate() begin RecargarEnElLugar(); end;
                }
                field(FSoloDif; FSoloDif)
                {
                    ApplicationArea = All;
                    Editable = true;
                    Caption = 'Sólo diferencias';
                    ToolTip = 'Deja fuera los meses cuyos importes coinciden en bruto, descuentos y neto. Usa la diferencia exacta, sin redondearla. Las contribuciones no cuentan acá: son costo patronal y no cambian lo que cobra la persona.';
                    trigger OnValidate() begin RecargarEnElLugar(); end;
                }
                field(FSoloFaltantes; FSoloFaltantes)
                {
                    ApplicationArea = All;
                    Editable = true;
                    Caption = 'Sólo los que faltan en un sistema';
                    ToolTip = 'Deja únicamente los empleados-mes que existen en Meta4 y no en BC, o al revés. Es lo contrario de comparar importes: acá el dato es la ausencia.';
                    trigger OnValidate() begin RecargarEnElLugar(); end;
                }
                field(FSoloConBC; FSoloConBC)
                {
                    ApplicationArea = All;
                    Editable = true;
                    Caption = 'Sólo meses que BC calculó';
                    ToolTip = 'Sin esto también aparecen los meses que Meta4 liquidó y BC todavía no, que suelen ser la mayoría y tapan las diferencias reales.';
                    trigger OnValidate() begin RecargarEnElLugar(); end;
                }
                field(FResumenDiferencias; FResumenDiferencias)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'Con diferencias';
                    ToolTip = 'Filas con diferencia en bruto, descuentos o neto, sobre el total de filas de la vista actual. Respeta todos los filtros y las casillas de esta página. Una fila cuenta una sola vez; las contribuciones se comparan aparte.';
                }
                field(FDiferenciasBruto; FDiferenciasBruto)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'En bruto';
                    ToolTip = 'Cantidad de filas de la vista actual cuya diferencia de bruto es distinta de cero. Se usa el importe exacto, igual que la columna Dif. Bruto.';
                }
                field(FDiferenciasNeto; FDiferenciasNeto)
                {
                    ApplicationArea = All;
                    Editable = false;
                    Caption = 'En neto';
                    ToolTip = 'Cantidad de filas de la vista actual cuya diferencia de neto es distinta de cero. Una fila puede diferir tanto en bruto como en neto.';
                }
            }
            repeater(Lines)
            {
                field("No. Empleado"; Rec."No. Empleado")
                {
                    ApplicationArea = All;
                    Editable = false;
                    DrillDown = true;
                    ToolTip = 'Hacé clic para abrir el legajo. Conviene para mirar convenio, categoría y fecha de ingreso sin perder el lugar en la comparación.';

                    trigger OnDrillDown()
                    begin
                        AbrirLegajo();
                    end;
                }
                field(Apellido; Rec.Apellido) { ApplicationArea = All; Editable = false; }
                field(Nombre; Rec.Nombre) { ApplicationArea = All; Editable = false; }
                field(Mes; Rec.Mes) { ApplicationArea = All; Editable = false; }
                field(Presencia; Rec.Presencia)
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = EstiloPresencia;
                    ToolTip = 'Si el empleado tiene liquidación en los dos sistemas ese mes, o en uno solo. Sale de contar corridas, no importes: una corrida que liquidó cero sigue contando.';
                }
                field("Importe Meta4"; Rec."Importe Meta4")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Lo que liquidó Meta4: la suma de lo que aportó cada corrida. Sin filtro de marea es el mes entero; con filtro, sólo las corridas de esa marea.';
                }
                field("Importe BC"; Rec."Importe BC")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Suma del acumulador REMUNERATIVO_BRUTO de las liquidaciones que calculó BC ese mes.';
                }
                field(Diferencia; Rec.Diferencia)
                {
                    ApplicationArea = All;
                    Editable = false;   // no editable, pero el DrillDown sigue funcionando
                    StyleExpr = EstiloDif;
                    DrillDown = true;
                    ToolTip = 'BC menos Meta4. Positivo = BC liquidó de más. Hacé clic para ver qué concepto la explica.';

                    trigger OnDrillDown()
                    begin
                        AbrirDetalle();
                    end;
                }
                field("% Diferencia"; Rec."% Diferencia") { ApplicationArea = All; Editable = false; StyleExpr = EstiloDif; }
                field("Descuentos Meta4"; Rec."Descuentos Meta4")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Lo que retuvo Meta4 (TOT_RETEN). No incluye contribuciones patronales.';
                }
                field("Descuentos BC"; Rec."Descuentos BC")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Total Descuentos de la cabecera de las liquidaciones de BC. Tampoco incluye contribuciones.';
                }
                field("Dif. Descuentos"; Rec."Dif. Descuentos")
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = EstiloDesc;
                    DrillDown = true;
                    ToolTip = 'BC menos Meta4. Ojo con el signo: acá un positivo es BC reteniendo de MÁS, y eso BAJA el neto. Hacé clic para ver qué concepto la explica.';

                    trigger OnDrillDown()
                    begin
                        AbrirDetalle();
                    end;
                }
                field("Contrib. Meta4"; Rec."Contrib. Meta4")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Visible = false;
                    ToolTip = 'Lo que Meta4 liquidó de contribuciones patronales de la seguridad social (TOT_CONT_SUSS). No incluye las otras contribuciones a pagar (OTR_CONTR_A_PAG). No entra en el recibo: es costo de la empresa.';
                }
                field("Contrib. BC"; Rec."Contrib. BC")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Visible = false;
                    ToolTip = 'Total Contribuciones de la cabecera de las liquidaciones de BC, sin el seguro de vida obligatorio (7080) ni las otras contribuciones que Meta4 lleva en OTR_CONTR_A_PAG (7090 a 7099: sindicales, 8/1000 de Chubut, acción social por marea, STIA e INACAP), para compararlo con TOT_CONT_SUSS.';
                }
                field("Dif. Contrib."; Rec."Dif. Contrib.")
                {
                    ApplicationArea = All;
                    Editable = false;
                    Visible = false;
                    StyleExpr = EstiloContrib;
                    DrillDown = true;
                    ToolTip = 'BC menos Meta4 sobre las contribuciones. Es la única de las cuatro que NO toca el recibo: una diferencia acá no explica el bruto ni el neto, ni se explica por ellos. Hacé clic para ver qué concepto la explica.';

                    trigger OnDrillDown()
                    begin
                        AbrirDetalle();
                    end;
                }
                field("Neto Meta4"; Rec."Neto Meta4")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'El líquido a cobrar según Meta4 (LIQUIDO).';
                }
                field("Neto BC"; Rec."Neto BC")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Neto a Pagar de la cabecera de las liquidaciones de BC.';
                }
                field("Dif. Neto"; Rec."Dif. Neto")
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = EstiloNeto;
                    DrillDown = true;
                    ToolTip = 'BC menos Meta4 sobre el líquido. Es la columna que dice si la persona cobraría distinto: un bruto que coincide puede tapar un neto que no. Hacé clic para ver qué concepto la explica.';

                    trigger OnDrillDown()
                    begin
                        AbrirDetalle();
                    end;
                }
                field("Liq. en Meta4"; Rec."Liq. en Meta4")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Cuántas corridas de Meta4 entraron. Cero con liquidaciones en BC es un mes que Meta4 no liquidó.';
                }
                field("Liq. en BC"; Rec."Liq. en BC")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Cuántas liquidaciones de BC entraron. Cero con corridas en Meta4 es un mes que BC no calculó.';
                }
                field("Hay Borrador"; Rec."Hay Borrador")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Hay liquidaciones en Borrador. Cuentan acá pero NO en los acumuladores del motor, que ignoran los borradores.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Refrescar)
            {
                ApplicationArea = All;
                Caption = 'Refrescar';
                Image = Refresh;
                ToolTip = 'Vuelve a leer el archivo y las liquidaciones, sin moverse de la fila donde estabas.';
                trigger OnAction() begin RecargarEnElLugar(); end;
            }
            action(FichaEmpleado)
            {
                ApplicationArea = All;
                Caption = 'Ficha del empleado';
                Image = Employee;
                ShortCutKey = 'Shift+F7';
                ToolTip = 'Abre el legajo del empleado de la fila.';
                trigger OnAction() begin AbrirLegajo(); end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        if FAnio = 0 then
            FAnio := 2026;
        FSoloConBC := true;
        Cargar();
    end;

    trigger OnAfterGetRecord()
    begin
        EstiloDif := Estilo(Rec.Diferencia);
        EstiloDesc := Estilo(Rec."Dif. Descuentos");
        EstiloContrib := Estilo(Rec."Dif. Contrib.");
        // Una fila que esta en un solo sistema se marca aunque sus importes no difieran: el dato
        // es la ausencia, no el monto.
        if Rec.Presencia = Rec.Presencia::Ambos then
            EstiloPresencia := 'Standard'
        else
            EstiloPresencia := 'Attention';
        EstiloNeto := Estilo(Rec."Dif. Neto");
    end;

    trigger OnAfterGetCurrRecord()
    begin
        if ActualizarContadores(false) then
            CurrPage.Update(false);
    end;

    /// <summary>Cuenta sólo el buffer temporal filtrado, sin mover el registro del llamador.</summary>
    procedure ContarFilas(var Origen: Record "Comp. Meta4 Buffer" temporary; var Total: Integer; var Diferentes: Integer; var Bruto: Integer; var Neto: Integer)
    var
        Filas: Record "Comp. Meta4 Buffer" temporary;
    begin
        Total := 0;
        Diferentes := 0;
        Bruto := 0;
        Neto := 0;
        // Copy(..., true) comparte las filas temporales y copia todos los grupos de filtros,
        // orden y marcas. Recorrer Rec cambiaría el cursor; reconstruir la vista perdería filtros.
        Filas.Copy(Origen, true);
        if Filas.FindSet() then
            repeat
                Total += 1;
                if Filas."Hay Dif. Recibo" then
                    Diferentes += 1;
                if Filas.Diferencia <> 0 then
                    Bruto += 1;
                if Filas."Dif. Neto" <> 0 then
                    Neto += 1;
            until Filas.Next() = 0;
    end;

    /// <summary>Completa las diferencias de una fila temporal antes de filtrarla o contarla.</summary>
    procedure ActualizarDiferencias(var Fila: Record "Comp. Meta4 Buffer" temporary)
    begin
        Fila.Diferencia := Fila."Importe BC" - Fila."Importe Meta4";
        Fila."Dif. Descuentos" := Fila."Descuentos BC" - Fila."Descuentos Meta4";
        Fila."Dif. Contrib." := Fila."Contrib. BC" - Fila."Contrib. Meta4";
        Fila."Dif. Neto" := Fila."Neto BC" - Fila."Neto Meta4";
        // El neto debe estar actualizado ANTES del indicador: puede diferir aunque bruto y
        // descuentos coincidan, porque proviene de totales independientes de ambos sistemas.
        Fila."Hay Dif. Recibo" :=
            (Fila.Diferencia <> 0) or (Fila."Dif. Descuentos" <> 0) or (Fila."Dif. Neto" <> 0);
        case true of
            (Fila."Liq. en Meta4" > 0) and (Fila."Liq. en BC" = 0):
                Fila.Presencia := Fila.Presencia::"Sólo Meta4";
            (Fila."Liq. en Meta4" = 0) and (Fila."Liq. en BC" > 0):
                Fila.Presencia := Fila.Presencia::"Sólo BC";
            else
                Fila.Presencia := Fila.Presencia::Ambos;
        end;
        if Fila."Importe Meta4" <> 0 then
            Fila."% Diferencia" := Round(Fila.Diferencia / Fila."Importe Meta4" * 100, 0.01)
        else
            Fila."% Diferencia" := 0;
    end;

    local procedure ActualizarContadores(Forzar: Boolean): Boolean
    var
        Firma: Text;
        ResumenAnterior: Text;
        Total: Integer;
        Diferentes: Integer;
        BrutoAnterior: Integer;
        NetoAnterior: Integer;
    begin
        Firma := FirmaFiltrosContador();
        if not Forzar then
            if FContadoresListos and (Firma = FFiltrosContador) then
                if not Rec.MarkedOnly() then
                    exit(false);
        ResumenAnterior := FResumenDiferencias;
        BrutoAnterior := FDiferenciasBruto;
        NetoAnterior := FDiferenciasNeto;
        ContarFilas(Rec, Total, Diferentes, FDiferenciasBruto, FDiferenciasNeto);
        FResumenDiferencias := StrSubstNo(TxtContador, Diferentes, Total);
        FFiltrosContador := Firma;
        FContadoresListos := true;
        exit((ResumenAnterior <> FResumenDiferencias) or
            (BrutoAnterior <> FDiferenciasBruto) or (NetoAnterior <> FDiferenciasNeto));
    end;

    local procedure FirmaFiltrosContador(): Text
    var
        Filas: Record "Comp. Meta4 Buffer" temporary;
        Firma: TextBuilder;
        Grupo: Integer;
        Filtros: Text;
    begin
        Filas.Copy(Rec, true);
        // Salir de «sólo marcadas» debe invalidar el último conteo del subconjunto,
        // aunque los filtros de campos sigan siendo idénticos.
        Firma.Append(Format(Rec.MarkedOnly()));
        Firma.AppendLine();
        // El usuario filtra en grupo 0, pero una vista o quien abre la página puede imponer
        // filtros en otros grupos. La caché se invalida por todos ellos, sin leer Meta4 otra vez.
        for Grupo := -1 to 255 do begin
            Filas.FilterGroup(Grupo);
            Filtros := Filas.GetFilters();
            if Filtros <> '' then begin
                Firma.Append(Format(Grupo));
                Firma.Append(':');
                Firma.AppendLine(Filtros);
            end;
        end;
        exit(Firma.ToText());
    end;

    /// <summary>Recarga el buffer y vuelve a la fila donde estaba el cursor.</summary>
    /// <remarks>
    /// Cargar() vacía y rehace la tabla temporal entera, así que sin esto el cursor vuelve a la
    /// primera fila. Con dos mil empleados-mes, mirar una diferencia, corregir el parámetro,
    /// refrescar y tener que buscar de nuevo dónde estabas hace que uno deje de refrescar.
    ///
    /// La clave se guarda antes y se reposiciona después. Si la fila ya no está —se corrigió y con
    /// "sólo diferencias" salió de la lista, que es el final feliz— se queda donde la dejó Cargar,
    /// sin error: no encontrarla es un resultado posible, no una falla.
    /// </remarks>
    local procedure RecargarEnElLugar()
    var
        EmpAnt: Code[20];
        AnioAnt: Integer;
        MesAnt: Integer;
    begin
        EmpAnt := Rec."No. Empleado";
        AnioAnt := Rec.Año;
        MesAnt := Rec.Mes;

        Cargar();

        if EmpAnt <> '' then
            if Rec.Get(EmpAnt, AnioAnt, MesAnt) then;
        CurrPage.Update(false);
    end;

    /// <summary>El detalle concepto por concepto de este empleado-mes.</summary>
    /// <remarks>
    /// Lo abren los TRES campos de diferencia —haberes, descuentos y neto— porque los tres se
    /// explican con la misma lista: el detalle trae todos los conceptos del mes, de los dos lados,
    /// y un descuento que difiere es una fila como cualquier otra. Antes sólo se llegaba desde la
    /// diferencia de haberes, y para una de descuentos había que adivinar que ahí también estaba.
    ///
    /// El buffer lo arma la página de detalle: es de un solo empleado-mes, así que no tiene sentido
    /// calcularlo para los 2.000 meses de la lista por si alguien hace clic en uno.
    /// </remarks>
    local procedure AbrirDetalle()
    var
        Detalle: Page "Detalle Comp. Meta4";
    begin
        Detalle.Cargar(Rec."No. Empleado", Rec.Año, Rec.Mes, FMarea, FNoMarea);
        Detalle.Run();
    end;

    /// <summary>Abre el legajo del empleado de la fila actual.</summary>
    local procedure AbrirLegajo()
    var
        Emp: Record Employee;
    begin
        if Rec."No. Empleado" = '' then
            exit;
        // Un legajo de la comparación puede no existir como empleado —el archivo de Meta4 trae gente
        // que no se migró— y ahí abrir la ficha vacía confundiría más que no hacer nada.
        if not Emp.Get(Rec."No. Empleado") then
            Error(ErrSinLegajo, Rec."No. Empleado");
        Page.Run(Page::"Employee Card", Emp);
    end;

    // Verde si cierra, rojo si no. Va por columna: el bruto puede cerrar y el neto no, y eso es
    // justamente lo que hay que poder ver de un vistazo.
    local procedure Estilo(Dif: Decimal): Text
    begin
        if Dif = 0 then
            exit('Favorable');
        exit('Unfavorable');
    end;

    /// <summary>
    /// El número de marea de Meta4 que corresponde a un proyecto de BC. 0 si no se puede deducir.
    /// </summary>
    /// <remarks>
    /// SALE DEL CÓDIGO DEL PROYECTO: PP-128-000059 es el buque 128, marea 59. La descripción lo
    /// confirma en texto ("Proy.Prod.Buque Arbumasa XXVIII Marea 059").
    ///
    /// NO HACE FALTA EL BUQUE. Parece que sí —el archivo lo tiene y sería lo natural— pero el
    /// número de marea MÁS el conjunto de tripulantes ya identifican la corrida sin ambigüedad: dos
    /// buques no comparten número de marea y tripulación a la vez. Evitar el buque evita tener que
    /// mantener una equivalencia entre los códigos de BC (128) y los de Meta4 (A28), que no se
    /// derivan uno del otro y que habría que actualizar con cada buque nuevo.
    ///
    /// Si el código no tiene la forma esperada devuelve 0 y la comparación no se acota por marea:
    /// queda como estaba, mes contra liquidación. Es preferible a acotar por un número inventado.
    /// </remarks>
    local procedure MareaDelProyecto(CodProyecto: Code[20]): Integer
    var
        Partes: List of [Text];
        Ultima: Text;
        Txt: Text;
        N: Integer;
    begin
        Txt := CodProyecto;   // Split es de Text, no de Code
        Partes := Txt.Split('-');
        if Partes.Count() < 2 then
            exit(0);
        Ultima := Partes.Get(Partes.Count());
        if not Evaluate(N, Ultima) then
            exit(0);
        exit(N);
    end;

    /// <summary>
    /// Arma un filtro "A|B|C" con los legajos de la marea, para no recorrer el archivo entero.
    /// </summary>
    /// <remarks>
    /// Cada legajo va entre comillas simples y las internas se duplican. Un legajo no debería tener
    /// apóstrofes, pero el filtro se arma por concatenación y un dato raro no puede convertirse en
    /// sintaxis de filtro.
    /// </remarks>
    /// <summary>
    /// Vuelca en el buffer las líneas de BC que vengan filtradas, sumando por empleado y mes.
    /// </summary>
    /// <remarks>
    /// Está aparte porque el lado de BC se recorre DOS VECES con filtros distintos —las líneas de la
    /// marea y, para algunos legajos, las de la liquidación sin proyecto— y las dos pasadas tienen que
    /// acumular igual. Duplicar el bucle es lo que hace que una de las dos se quede sin el conteo de
    /// borradores el día que alguien toque una sola.
    /// </remarks>
    /// <summary>
    /// ¿Esta corrida de Meta4 entra en lo que se está mirando?
    /// </summary>
    /// <remarks>
    /// NI LA MENSUAL NI LA FINAL SON DE LA MAREA, aunque Meta4 las impute a una. Cada una tiene su
    /// propio recibo y el de la marea no las incluye:
    ///   TP_IMPUT 1  — la mensual: días de puerto, francos, feriados de guardia.
    ///   TP_IMPUT 14 — la liquidación final: vacaciones y francos no gozados, egreso, los SAC de
    ///                 cada uno y una devolución de Ganancias. Las 7 corridas TP 14 de enero de 2026
    ///                 son todas finales, sin excepción.
    /// Sin filtro de marea entran las tres, que es la vista del mes.
    ///
    /// ESTÁ APARTE PORQUE LA USAN TRES ACUMULACIONES —bruto, descuentos y neto— y si se separan
    /// terminan comparando conjuntos distintos sin que nada avise.
    /// </remarks>
    local procedure EsDeLaMarea(var Cab: Record "Hist. Liq. Meta4"; NoMarea: Integer): Boolean
    begin
        if NoMarea = 0 then
            exit(true);
        exit((Cab."No. Marea Meta4" = NoMarea) and
             (Cab."Tipo Imputación" <> 1) and (Cab."Tipo Imputación" <> 14));
    end;

    /// <summary>El TP_IMPUT de Meta4 que identifica una corrida de anticipos.</summary>
    /// <remarks>
    /// Va acá y no como número suelto porque se compara en más de un lugar y el 4 solo no dice nada.
    /// El significado de cada TP_IMPUT está anotado en "Hist. Liq. Meta4"."Tipo Imputación": se
    /// dedujo perfilando qué columnas trae cada uno en no-cero, no de un catálogo.
    /// </remarks>
    local procedure TipoImputAnticipo(): Integer
    begin
        exit(4);
    end;

    local procedure NoColumna(Nombre: Code[50]): Integer
    var
        Col: Record "Columna Hist. Meta4";
    begin
        Col.Reset();
        // LOS ACUMULADOS DE MÉTA4 ESTÁN PARTIDOS EN VARIAS TABLAS: M4T_ACUMULADO_RL, _RL2 y _RL3
        // (probablemente por el límite de columnas de la tabla origen). TOT_CONTRIB vive en _RL2, y
        // buscar sólo en _RL devolvía 0: ValorDe devuelve cero con la columna 0, así que la pantalla
        // mostraba Contribuciones Meta4 en cero para todos sin ningún error. Con el comodín entran
        // las tres; el nombre de la columna no se repite entre ellas (salvo COMENT, CONTADOR_LIQ y
        // FEC_ULT_ACTUALIZACION, que esta pantalla no usa).
        Col.SetFilter("Tabla Origen", 'M4T_ACUMULADO_RL*');
        Col.SetRange("Nombre Columna", Nombre);
        if Col.FindFirst() then
            exit(Col."No.");
        exit(0);
    end;

    local procedure ValorDe(var Val: Record "Valor Hist. Meta4"; NoEntrada: Integer; NoCol: Integer): Decimal
    begin
        if NoCol = 0 then
            exit(0);
        Val.SetRange("No. Entrada", NoEntrada);
        Val.SetRange("No. Columna", NoCol);
        if Val.FindFirst() then
            exit(Val.Valor);
        exit(0);
    end;

    /// <remarks>
    /// Suma aunque el importe sea cero, a propósito: la clave tiene que existir igual. Un
    /// empleado-mes que Meta4 liquidó en cero es una fila que hay que ver —sobre todo si BC le puso
    /// algo—, y saltearla lo haría desaparecer del listado sin aviso.
    /// </remarks>
    local procedure Sumar(var Acumulado: Dictionary of [Text, Decimal]; Clave: Text; Importe: Decimal)
    begin
        if Acumulado.ContainsKey(Clave) then
            Acumulado.Set(Clave, Acumulado.Get(Clave) + Importe)
        else
            Acumulado.Add(Clave, Importe);
    end;

    local procedure AcumularLineasBC(var LinLiq: Record "Línea Liquidación")
    var
        Empl: Record Employee;
        Liq: Record "Liquidación";
        LinFuera: Record "Línea Liquidación";
    begin
        if not LinLiq.FindSet() then
            exit;
        repeat
            if not Rec.Get(LinLiq."No. Empleado", FAnio, Date2DMY(LinLiq."Fecha Liquidación", 2)) then begin
                Rec.Init();
                Rec."No. Empleado" := LinLiq."No. Empleado";
                Rec.Año := FAnio;
                Rec.Mes := Date2DMY(LinLiq."Fecha Liquidación", 2);
                if Empl.Get(Rec."No. Empleado") then begin
                    Rec.Apellido := Empl."Last Name";
                    Rec.Nombre := Empl."First Name";
                end;
                Rec.Insert();
            end;
            Rec."Importe BC" += LinLiq.Importe;
            // Los descuentos y el neto salen de la CABECERA, no de las líneas. Hay exactamente una
            // línea de REMUNERATIVO_BRUTO por liquidación —es un acumulador—, así que leer la
            // cabecera acá suma cada liquidación una sola vez.
            if Liq.Get(LinLiq."No. Liquidación") then begin
                Rec."Descuentos BC" += Liq."Total Descuentos";
                // LO MISMO CONTRA LO MISMO: Contrib. Meta4 es TOT_CONT_SUSS, la parte de la seguridad social, y
                // el Total Contribuciones de BC trae dos cosas que no están ahí. El 7080 (seguro de vida
                // obligatorio) Meta4 no lo guarda en ninguna columna con importe, y del 7090 al 7099 son las otras
                // contribuciones (sindicales, farmacia, 8/1000 de Chubut, acción social por marea, STIA, INACAP), que Meta4 lleva aparte
                // (OTR_CONTR_A_PAG). Sin sacarlas,
                // la diferencia de enero eran 424,62 por empleado del 7080 y 22,7 M de las otras contribuciones.
                LinFuera.SetRange("No. Liquidación", Liq."No.");
                LinFuera.SetFilter("Cód. Concepto", '7080|7090..7099');
                LinFuera.CalcSums(Importe);
                Rec."Contrib. BC" += Liq."Total Contribuciones" - LinFuera.Importe;
                Rec."Neto BC" += Liq."Neto a Pagar";
            end;
            Rec."Liq. en BC" += 1;
            if LinLiq.Estado = LinLiq.Estado::Borrador then
                Rec."Hay Borrador" := true;
            Rec.Modify();
        until LinLiq.Next() = 0;
    end;

    /// <summary>Suma al bruto de BC el acumulador no remunerativo, sin tocar descuentos ni neto.</summary>
    /// <remarks>
    /// Sólo el importe: los descuentos, el neto y el contador de liquidaciones ya los cargó
    /// AcumularLineasBC leyendo la cabecera una vez por liquidación.
    ///
    /// Si la fila no existe se crea igual. Una liquidación con acumulador no remunerativo y sin
    /// remunerativo es rara pero posible —un mes de puro acuerdo sindical o de prestación ILT— y
    /// saltearla la haría desaparecer del listado sin aviso, que es lo que esta pantalla no debe
    /// hacer nunca.
    /// </remarks>
    local procedure AcumularNoRemunerativoBC(var LinLiq: Record "Línea Liquidación")
    var
        Empl: Record Employee;
    begin
        if not LinLiq.FindSet() then
            exit;
        repeat
            if not Rec.Get(LinLiq."No. Empleado", FAnio, Date2DMY(LinLiq."Fecha Liquidación", 2)) then begin
                Rec.Init();
                Rec."No. Empleado" := LinLiq."No. Empleado";
                Rec.Año := FAnio;
                Rec.Mes := Date2DMY(LinLiq."Fecha Liquidación", 2);
                if Empl.Get(Rec."No. Empleado") then begin
                    Rec.Apellido := Empl."Last Name";
                    Rec.Nombre := Empl."First Name";
                end;
                Rec.Insert();
            end;
            Rec."Importe BC" += LinLiq.Importe;
            Rec.Modify();
        until LinLiq.Next() = 0;
    end;

    local procedure ConstruirFiltroEmpleados(var Legajos: Dictionary of [Code[20], Boolean]): Text
    var
        Cod: Code[20];
        Sb: TextBuilder;
        Txt: Text;
        Comilla: Text[1];
    begin
        Comilla[1] := 39;   // el apóstrofe, por código: escribirlo literal en AL exige duplicarlo
                            // cuatro veces dentro de otra cadena y se vuelve ilegible
        foreach Cod in Legajos.Keys() do begin
            if Sb.Length() > 0 then
                Sb.Append('|');
            Txt := Cod;
            Sb.Append(Comilla + Txt.Replace(Comilla, Comilla + Comilla) + Comilla);
        end;
        exit(Sb.ToText());
    end;

    /// <summary>
    /// Arma el buffer leyendo el archivo de Meta4 y las liquidaciones de BC.
    /// </summary>
    /// <remarks>
    /// EL ARCHIVO SE RECORRE POR EL VALOR, NO POR LA CABECERA. La tabla de valores tiene 116
    /// millones de filas y la de cabeceras 485.000: entrar por cabecera y pedirle sus valores a cada
    /// una son 485.000 busquedas. Entrando por el valor, acotado a UNA columna del catalogo, el
    /// conjunto ya viene chico.
    ///
    /// Y NO SE SUMAN LAS CORRIDAS: TOT_REMUN_27617 es un acumulador corrido dentro del mes, asi que
    /// sumar un mes de tres liquidaciones lo triplica. Se resta cada corrida contra la anterior, en
    /// orden de contador, reiniciando en cada empleado-mes. (Este comentario decia "se toma el
    /// MAXIMO", que es lo que daba el codigo viejo y lo mismo que la suma de diferencias cuando el
    /// acumulador solo crece; dejo de ser cierto al atribuir cada diferencia a SU marea.)
    /// </remarks>
    // ── el rango de meses ────────────────────────────────────────────────────
    // En cero significa "sin acotar" y no "mes cero", para que la pantalla siga abriendo con el año
    // entero como antes. El corte es por MES ENTERO a propósito: el bruto de Meta4 —TOT_REMUN_27617—
    // es un acumulador corrido DENTRO del mes, y la carga lo desarma restando cada corrida contra la
    // anterior, reiniciando en cada empleado-mes. Cortar a mitad de mes dejaría a Meta4 con el
    // acumulado de todo el mes enfrentado a unos pocos días de BC.
    local procedure MesD(): Integer
    begin
        if (FMesDesde < 1) or (FMesDesde > 12) then exit(1);
        exit(FMesDesde);
    end;

    local procedure MesH(): Integer
    begin
        if (FMesHasta < 1) or (FMesHasta > 12) then exit(12);
        if FMesHasta < MesD() then exit(MesD());
        exit(FMesHasta);
    end;

    local procedure FechaD(): Date
    begin
        exit(DMY2Date(1, MesD(), FAnio));
    end;

    local procedure FechaH(): Date
    begin
        exit(CalcDate('<CM>', DMY2Date(1, MesH(), FAnio)));
    end;

    local procedure Cargar()
    var
        Cab: Record "Hist. Liq. Meta4";
        Val: Record "Valor Hist. Meta4";
        Col: Record "Columna Hist. Meta4";
        LinLiq: Record "Línea Liquidación";
        Empl: Record Employee;
        Meta4: Dictionary of [Text, Decimal];
        Meta4Desc: Dictionary of [Text, Decimal];
        Meta4Contrib: Dictionary of [Text, Decimal];
        Meta4Corridas: Dictionary of [Text, Decimal];
        Meta4Neto: Dictionary of [Text, Decimal];
        DeLaMarea: Dictionary of [Code[20], Boolean];
        Clave: Text;
        ClaveAnt: Text;
        NoCol: Integer;
        NoColRet: Integer;
        NoColContrib: Integer;
        NoColLiq: Integer;
        NoColSac: Integer;
        NoMarea: Integer;
        Acum: Decimal;
        AcumSac: Decimal;
        Delta: Decimal;
        VistaUsuario: Text;
    begin
        // LO QUE EL USUARIO FILTRÓ SE GUARDA ANTES DE TOCAR NADA. Para vaciar el buffer hace falta
        // un Reset —DeleteAll con filtros borraría sólo una parte—, y ese Reset se lleva puestos
        // TODOS los filtros, incluidos los que puso el usuario en la página. Hasta acá, refrescar
        // dejaba la lista entera de vuelta: con dos mil empleados-mes, filtrar por un legajo,
        // corregir un parámetro y refrescar significaba volver a filtrar cada vez.
        //
        // La vista lleva también la ordenación, así que se repone igual: quien ordenó por diferencia
        // descendente sigue ahí después de refrescar.
        VistaUsuario := Rec.GetView();

        Rec.Reset();
        Rec.DeleteAll();
        ActualizarContadores(true);

        // Los números de columna del catálogo: sin esto habría que joinear por nombre en cada fila.
        // Las tres (TOT_CONTRIB está en M4T_ACUMULADO_RL2) NO se comportan igual —ver la nota de cada una en la
        // tabla del buffer—: TOT_REMUN_27617 es acumulado corrido, las otras dos son por corrida.
        NoCol := NoColumna('TOT_REMUN_27617');
        NoColRet := NoColumna('TOT_RETEN');
        NoColContrib := NoColumna('TOT_CONT_SUSS');
        NoColLiq := NoColumna('LIQUIDO');
        // EL SAC VA APARTE PORQUE TOT_REMUN_27617 NO LO INCLUYE.
        //
        // Es la cuarta regla de asimetría de esta pantalla, y la encontró la conciliación de las
        // finales de enero de 2026: enfrentados así, los ocho egresados daban 2.060.565 de brecha de
        // bruto, y en cinco de ellos la diferencia era EXACTAMENTE su SAC de egreso al centavo.
        // Sumando SAC_ABONADO del lado de Meta4, seis de los ocho cierran con un resto de 0,86 o
        // menos: la brecha era la métrica, no el motor.
        //
        // HOY SÓLO MUERDE EN LOS EGRESADOS, pero en junio y en diciembre lo cobra toda la nómina —por
        // 3613 y 3623— y la pantalla mostraría un error de cálculo masivo que no existe.
        //
        // Se trata IGUAL que TOT_REMUN_27617 —por diferencia contra la corrida anterior— y no con una
        // suma, aunque en enero aparezca una sola vez por empleado-mes: vive en la misma
        // M4T_ACUMULADO_RL, que es la tabla de los acumulados corridos. Si alguna vez se repite en dos
        // corridas, la diferencia da cero en la segunda y la suma lo contaría dos veces.
        NoColSac := NoColumna('SAC_ABONADO');
        if NoCol = 0 then
            exit;

        // ── acotar a una marea, si se pidió ──────────────────────────────────
        // EL FILTRO ACOTA LOS DOS LADOS. Del lado de BC, por proyecto: PP-128-000059 es el buque
        // 128, marea 59, y de ahí sale el conjunto de tripulantes. Del lado de Meta4, por el
        // ID_MAREA que ahora trae la cabecera del archivo.
        //
        // ID_MAREA SÓLO SIRVE FILA POR FILA. Agregado por empleado-mes engaña —da la marea de la
        // última corrida, que suele ser la siguiente, ya reembarcado— y por eso lo había descartado.
        // Por corrida es exacto: el legajo 03664 en enero de 2026 tiene contador 1 → marea 59 (el
        // cierre, el que coincide con el recibo), contador 2 → marea 58, contador 3 → marea 60.
        //
        // Sin esto se enfrentaba el MES ENTERO de Meta4 contra UNA liquidación de BC, y el 37% de
        // los empleado-mes tienen más de una marea: no era un caso de borde.
        NoMarea := MareaDelProyecto(FMarea);
        FNoMarea := NoMarea;
        if FMarea <> '' then begin
            LinLiq.Reset();
            LinLiq.SetRange("No. Proyecto", FMarea);
            LinLiq.SetFilter("Fecha Liquidación", '%1..%2', FechaD(), FechaH());
            LinLiq.SetFilter("Cód. Tipo Liq.", '<>%1', 'HIST_REMUN');
            LinLiq.SetFilter("Tipo Concepto", '<>%1&<>%2',
                LinLiq."Tipo Concepto"::Informativo, LinLiq."Tipo Concepto"::"Contribución Patronal");
            // Mismos criterios que el detalle (ver Pag110052): el devengo no se paga en el mes y no
            // está en el recibo de Meta4. Acá sólo arma la lista de empleados de la marea, pero un
            // tripulante cuya única línea del proyecto fuera de devengo entraría a la comparación
            // sin tener nada que comparar.
            LinLiq.SetRange("Es Devengo", false);
            if LinLiq.FindSet() then
                repeat
                    if not DeLaMarea.ContainsKey(LinLiq."No. Empleado") then
                        DeLaMarea.Add(LinLiq."No. Empleado", true);
                until LinLiq.Next() = 0;
            if DeLaMarea.Count() = 0 then
                exit;
        end;

        // ── Meta4 ────────────────────────────────────────────────────────────
        // NO SE PUEDE FILTRAR LA MAREA EN LA CONSULTA, aunque el campo esté en la cabecera y sea el
        // reflejo obvio de hacerlo. TOT_REMUN_27617 es un ACUMULADOR CORRIDO dentro del mes: cada
        // corrida guarda el total del mes HASTA ELLA, no lo suyo. Leer directo la corrida de la
        // marea 58 —que en enero es el contador 2— devuelve la 59 más la 58, porque la 59 corrió
        // antes y ya está adentro del número.
        //
        // Por eso se recorren TODAS las corridas del empleado-mes en orden de contador y se toma la
        // DIFERENCIA contra la anterior: eso es lo que aportó cada corrida. Después se suman sólo
        // las diferencias de la marea pedida. Sin filtro de marea la suma de las diferencias vuelve
        // a dar el acumulado final, o sea el mes entero: el comportamiento de antes, intacto.
        //
        // El orden por contador es obligatorio y por eso va el SetCurrentKey: con cualquier otro
        // orden las diferencias se calculan contra la corrida equivocada y salen negativas.
        // Y POR LO MISMO NO SE PUEDE SALTEAR NINGUNA CORRIDA. Antes se excluían los anticipos
        // (TP_IMPUT 4) con un filtro, y con un acumulado corrido eso no los saca: los ESCONDE. El
        // acumulador de la corrida siguiente ya los lleva adentro, así que la diferencia se los come
        // igual, pero atribuidos a la marea de OTRA corrida. El legajo 04190 en enero lo muestra:
        // contador 0 es un anticipo de 250.000, y salteándolo esos 250.000 aparecían dentro de la
        // corrida de cierre.
        //
        // Se recorren todas y se atribuye cada diferencia a SU marea. El anticipo tampoco sobra:
        // está dentro del bruto remunerativo de Meta4 y también del de BC —verificado en el 04190,
        // 6.299.341,22 contra 6.299.415,05—, así que sacarlo rompería la simetría.
        Cab.SetCurrentKey("No. Empleado", Año, Mes, "Contador Liq.");
        Cab.SetRange(Año, FAnio);
        Cab.SetRange(Mes, MesD(), MesH());
        if FMarea <> '' then
            Cab.SetFilter("No. Empleado", ConstruirFiltroEmpleados(DeLaMarea));
        if Cab.FindSet() then
            repeat
                Clave := Cab."No. Empleado" + '|' + Format(Cab.Mes);
                if Clave <> ClaveAnt then begin
                    ClaveAnt := Clave;
                    Acum := 0;      // empieza otro empleado-mes: el acumulador de Meta4 se reinicia
                    AcumSac := 0;   // y el del SAC con él, por el mismo motivo
                end;
                // Descuentos y neto: se suman las corridas de la marea tal cual, sin restar la
                // anterior, porque estas dos columnas SÍ son de su corrida. Va antes del bruto
                // porque el bruto puede cortar con un CONTINUE implícito si la corrida no tiene
                // TOT_REMUN_27617, y estos dos no tienen por qué perderse por eso.
                if EsDeLaMarea(Cab, NoMarea) then begin
                    Sumar(Meta4Desc, Clave, ValorDe(Val, Cab."No. Entrada", NoColRet));
                    // Las contribuciones van con los descuentos y no con el neto: TOT_CONTRIB es
                    // por corrida como TOT_RETEN, y en la corrida de anticipo viene nula, asi que
                    // no hay que excluirla a mano.
                    Sumar(Meta4Contrib, Clave, ValorDe(Val, Cab."No. Entrada", NoColContrib));
                    // Una corrida es una corrida aunque todos sus totales den cero: el contador
                    // sube igual, porque 'tiene liquidacion en Meta4' y 'liquido algo' son dos
                    // preguntas distintas y la segunda no sirve para encontrar a los que faltan.
                    Sumar(Meta4Corridas, Clave, 1);
                    // EL NETO ES LA ÚNICA DE LAS TRES QUE SACA LA CORRIDA DE ANTICIPO. El LIQUIDO de
                    // un TP_IMPUT 4 es plata entregada a cuenta —250.000 en cada uno de los 107
                    // empleados que tienen esa corrida en enero de 2026— y el recibo de BC no la
                    // paga: las novedades de anticipo están anuladas a propósito. Sumándola, Meta4
                    // quedaba con un neto 250.000 MAYOR QUE SU PROPIO bruto menos sus descuentos
                    // (04924: 13.697.168,47 - 7.196.653,43 = 6.500.515,04, y la columna mostraba
                    // 6.750.516,00), y esa diferencia contra BC se leía como un error de cálculo.
                    //
                    // EL BRUTO SÍ LA CONSERVA, por lo explicado arriba: el anticipo está dentro del
                    // acumulado de TOT_REMUN_27617 y también dentro del bruto de BC, así que sacarlo
                    // rompería la simetría y además escondería su delta en la corrida siguiente.
                    // Son dos reglas distintas porque miden cosas distintas: el bruto, lo devengado
                    // en el mes; el neto, lo que se pagó con ESTE recibo.
                    if Cab."Tipo Imputación" <> TipoImputAnticipo() then
                        Sumar(Meta4Neto, Clave, ValorDe(Val, Cab."No. Entrada", NoColLiq));
                end;

                Val.SetRange("No. Entrada", Cab."No. Entrada");
                Val.SetRange("No. Columna", NoCol);
                if Val.FindFirst() then begin
                    Delta := Val.Valor - Acum;
                    Acum := Val.Valor;
                    if EsDeLaMarea(Cab, NoMarea) then
                        Sumar(Meta4, Clave, Delta);
                end;

                // El SAC, al mismo diccionario del bruto y con la misma mecánica de diferencia.
                // Va en su propio bloque y no dentro del anterior porque una corrida puede traer el
                // SAC sin traer TOT_REMUN_27617: metido adentro, se perdería con el resto.
                if NoColSac <> 0 then begin
                    Val.SetRange("No. Columna", NoColSac);
                    if Val.FindFirst() then begin
                        Delta := Val.Valor - AcumSac;
                        AcumSac := Val.Valor;
                        if EsDeLaMarea(Cab, NoMarea) then
                            Sumar(Meta4, Clave, Delta);
                    end;
                end;
            until Cab.Next() = 0;

        // SE RECORRE EL CONTADOR DE CORRIDAS Y NO Meta4, que es el diccionario del bruto. El bruto
        // sólo se carga si la corrida trae TOT_REMUN_27617, así que una corrida sin esa columna no
        // generaba NINGUNA fila: el empleado desaparecía de la comparación en vez de aparecer como
        // "Sólo Meta4", que es justo lo que se vino a buscar. El contador sube por cada corrida de
        // la marea, tenga las columnas que tenga, así que sus claves son el superconjunto.
        foreach Clave in Meta4Corridas.Keys() do begin
            Rec.Init();
            Rec."No. Empleado" := CopyStr(Clave.Split('|').Get(1), 1, 20);
            Rec.Año := FAnio;
            Evaluate(Rec.Mes, Clave.Split('|').Get(2));
            if Meta4.ContainsKey(Clave) then
                Rec."Importe Meta4" := Meta4.Get(Clave);
            if Meta4Desc.ContainsKey(Clave) then
                Rec."Descuentos Meta4" := Meta4Desc.Get(Clave);
            if Meta4Contrib.ContainsKey(Clave) then
                Rec."Contrib. Meta4" := Meta4Contrib.Get(Clave);
            if Meta4Corridas.ContainsKey(Clave) then
                Rec."Liq. en Meta4" := Round(Meta4Corridas.Get(Clave), 1);
            if Meta4Neto.ContainsKey(Clave) then
                Rec."Neto Meta4" := Meta4Neto.Get(Clave);
            if Empl.Get(Rec."No. Empleado") then begin
                Rec.Apellido := Empl."Last Name";
                Rec.Nombre := Empl."First Name";
            end;
            Rec.Insert();
        end;

        // ── BC ───────────────────────────────────────────────────────────────
        // Se excluye HIST_REMUN: es la historia importada de Meta4, y compararla contra Meta4 daría
        // cero siempre. Acá interesa sólo lo que CALCULÓ el motor.
        LinLiq.Reset();
        LinLiq.SetRange("Cód. Concepto", 'REMUNERATIVO_BRUTO');
        LinLiq.SetRange("Fecha Liquidación", FechaD(), FechaH());
        LinLiq.SetFilter("Cód. Tipo Liq.", '<>%1', 'HIST_REMUN');
        // LA LIQUIDACIÓN SIN PROYECTO NO ENTRA, y es el espejo de dejar afuera la corrida mensual
        // del lado de Meta4. Con filtro de marea esta pantalla compara RECIBO DE MAREA CONTRA RECIBO
        // DE MAREA; el mes tiene el suyo, y se mira sin filtro.
        //
        // Llegué a incluirla y salió peor por los dos lados: al 03664 le daba 180.000 de sueldo de
        // puerto —los 60.000 del cierre más los 120.000 de la regular— contra 60.000 de Meta4, y al
        // 03772 le metía en el recibo de la marea el feriado y el franco de la mensual, que ahí no
        // están.
        if FMarea <> '' then begin
            LinLiq.SetFilter("No. Empleado", ConstruirFiltroEmpleados(DeLaMarea));
            LinLiq.SetRange("No. Proyecto", FMarea);
        end;
        AcumularLineasBC(LinLiq);

        // EL BRUTO DE META4 NO ES SÓLO LO REMUNERATIVO. TOT_REMUN_27617 —la columna que se compara—
        // incluye el acuerdo sindical del Dto 633/18, que es no remunerativo: para el 00949 son
        // 3.648.920,23 de los cuales 2.554.244,16 son acuerdo. Enfrentarlo contra REMUNERATIVO_BRUTO
        // solo mostraba un -70% que no existe, y encima en los casos donde el 70/30 del convenio
        // 729/15 es MÁS grande que la parte remunerativa, o sea justo los tripulantes.
        //
        // Va en una pasada aparte y no agregando el concepto al filtro de arriba: esa pasada también
        // lee descuentos y neto de la CABECERA y cuenta liquidaciones, y con dos líneas por
        // liquidación los duplicaría.
        LinLiq.SetRange("Cód. Concepto", 'NO_REMUNERATIVO');
        AcumularNoRemunerativoBC(LinLiq);

        // ── cierre ───────────────────────────────────────────────────────────
        Rec.Reset();
        if Rec.FindSet() then
            repeat
                ActualizarDiferencias(Rec);
                Rec.Modify();
            until Rec.Next() = 0;

        // Se repone lo que el usuario tenía y DESPUÉS se imponen los filtros de la página.
        //
        // Un Reset acá volvería a tirar los filtros del usuario, que es el bug que esto arregla. Y
        // reponer la vista a secas tampoco alcanza: trae los filtros de las tres casillas TAL COMO
        // ESTABAN, así que destildar una no la soltaría —la vista guardada la reinstalaría—. Por eso
        // los tres campos que maneja la página se limpian uno por uno, con SetRange sin valor, y
        // recién ahí se aplica el estado actual de las casillas. Todo lo demás —el legajo, el mes,
        // el orden— es del usuario y sobrevive intacto.
        Rec.SetView(VistaUsuario);
        Rec.SetRange(Presencia);
        Rec.SetRange("Liq. en BC");
        Rec.SetRange("Hay Dif. Recibo");

        // Va primero: si se piden los faltantes, "solo con liq. en BC" los contradice —esconderia
        // justo los que estan solo en Meta4— asi que este gana y el otro no se aplica.
        if FSoloFaltantes then
            Rec.SetFilter(Presencia, '<>%1', Rec.Presencia::Ambos)
        else
            if FSoloConBC then
                Rec.SetFilter("Liq. en BC", '>%1', 0);
        // Mira las TRES del recibo y no solo el bruto: un bruto que coincide puede tapar un neto
        // que no, que es justo el caso que el grossing-up produce.
        if FSoloDif then
            Rec.SetRange("Hay Dif. Recibo", true);
        ActualizarContadores(true);
        if Rec.FindFirst() then;
    end;

    var
        FAnio: Integer;
        FMesDesde: Integer;
        FMesHasta: Integer;
        FMarea: Code[20];
        FSoloDif: Boolean;
        FSoloConBC: Boolean;
        FSoloFaltantes: Boolean;
        FNoMarea: Integer;   // la marea de FMarea ya resuelta, para que el drilldown filtre igual
        FResumenDiferencias: Text;
        FDiferenciasBruto: Integer;
        FDiferenciasNeto: Integer;
        FFiltrosContador: Text;
        FContadoresListos: Boolean;
        EstiloDif: Text;
        EstiloDesc: Text;
        EstiloContrib: Text;
        EstiloPresencia: Text;
        EstiloNeto: Text;
        ErrSinLegajo: Label 'El legajo %1 no existe como empleado: figura en el archivo de Meta4 pero no está en Business Central.', Comment = '%1=legajo';
        TxtContador: Label '%1 de %2', Comment = '%1=filas con diferencias; %2=total de filas visibles';
}
