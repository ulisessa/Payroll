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
                    trigger OnValidate() begin Cargar(); CurrPage.Update(false); end;
                }
                field(FMarea; FMarea)
                {
                    ApplicationArea = All;
                    Editable = true;
                    Caption = 'Marea';
                    TableRelation = Job."No.";
                    ToolTip = 'Proyecto de la marea, que es buque y número de marea a la vez (PP-128-000059 = buque 128, marea 59). Compara recibo de marea contra recibo de marea: de los dos lados entra sólo lo de esa marea, sin la liquidación mensual. Para ver el mes completo, dejalo en blanco.';
                    trigger OnValidate() begin Cargar(); CurrPage.Update(false); end;
                }
                field(FSoloDif; FSoloDif)
                {
                    ApplicationArea = All;
                    Editable = true;
                    Caption = 'Sólo diferencias';
                    ToolTip = 'Deja fuera los meses que coinciden al centavo.';
                    trigger OnValidate() begin Cargar(); CurrPage.Update(false); end;
                }
                field(FSoloConBC; FSoloConBC)
                {
                    ApplicationArea = All;
                    Editable = true;
                    Caption = 'Sólo meses que BC calculó';
                    ToolTip = 'Sin esto también aparecen los meses que Meta4 liquidó y BC todavía no, que suelen ser la mayoría y tapan las diferencias reales.';
                    trigger OnValidate() begin Cargar(); CurrPage.Update(false); end;
                }
            }
            repeater(Lines)
            {
                field("No. Empleado"; Rec."No. Empleado") { ApplicationArea = All; Editable = false; }
                field(Apellido; Rec.Apellido) { ApplicationArea = All; Editable = false; }
                field(Nombre; Rec.Nombre) { ApplicationArea = All; Editable = false; }
                field(Mes; Rec.Mes) { ApplicationArea = All; Editable = false; }
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
                    var
                        Detalle: Page "Detalle Comp. Meta4";
                    begin
                        // Se pasan los tres datos y la página arma su propio buffer: el detalle es
                        // de un solo empleado-mes, así que no tiene sentido calcularlo para los
                        // 2.000 meses de la lista por si alguien hace clic en uno.
                        Detalle.Cargar(Rec."No. Empleado", Rec.Año, Rec.Mes, FMarea, FNoMarea);
                        Detalle.Run();
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
                    ToolTip = 'BC menos Meta4. Ojo con el signo: acá un positivo es BC reteniendo de MÁS, y eso BAJA el neto.';
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
                    ToolTip = 'BC menos Meta4 sobre el líquido. Es la columna que dice si la persona cobraría distinto: un bruto que coincide puede tapar un neto que no.';
                }
                field("Liq. en BC"; Rec."Liq. en BC")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Cuántas liquidaciones de BC entraron. Cero con Meta4 distinto de cero es un mes que BC no calculó.';
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
                ToolTip = 'Vuelve a leer el archivo y las liquidaciones.';
                trigger OnAction() begin Cargar(); CurrPage.Update(false); end;
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
        EstiloNeto := Estilo(Rec."Dif. Neto");
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

    local procedure NoColumna(Nombre: Code[50]): Integer
    var
        Col: Record "Columna Hist. Meta4";
    begin
        Col.Reset();
        Col.SetRange("Tabla Origen", 'M4T_ACUMULADO_RL');
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
                Rec."Neto BC" += Liq."Neto a Pagar";
            end;
            Rec."Liq. en BC" += 1;
            if LinLiq.Estado = LinLiq.Estado::Borrador then
                Rec."Hay Borrador" := true;
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
    /// Y se toma el MAXIMO por empleado-mes, no la suma: TOT_REMUN_27617 es un acumulador corrido
    /// dentro del mes. Sumar las corridas de un mes con tres liquidaciones lo triplica.
    /// </remarks>
    local procedure Cargar()
    var
        Cab: Record "Hist. Liq. Meta4";
        Val: Record "Valor Hist. Meta4";
        Col: Record "Columna Hist. Meta4";
        LinLiq: Record "Línea Liquidación";
        Empl: Record Employee;
        Meta4: Dictionary of [Text, Decimal];
        Meta4Desc: Dictionary of [Text, Decimal];
        Meta4Neto: Dictionary of [Text, Decimal];
        DeLaMarea: Dictionary of [Code[20], Boolean];
        Clave: Text;
        ClaveAnt: Text;
        NoCol: Integer;
        NoColRet: Integer;
        NoColLiq: Integer;
        NoMarea: Integer;
        Acum: Decimal;
        Delta: Decimal;
    begin
        Rec.Reset();
        Rec.DeleteAll();

        // Los números de columna del catálogo: sin esto habría que joinear por nombre en cada fila.
        // Las tres viven en M4T_ACUMULADO_RL y NO se comportan igual —ver la nota de cada una en la
        // tabla del buffer—: TOT_REMUN_27617 es acumulado corrido, las otras dos son por corrida.
        NoCol := NoColumna('TOT_REMUN_27617');
        NoColRet := NoColumna('TOT_RETEN');
        NoColLiq := NoColumna('LIQUIDO');
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
            LinLiq.SetFilter("Fecha Liquidación", '%1..%2', DMY2Date(1, 1, FAnio), DMY2Date(31, 12, FAnio));
            LinLiq.SetFilter("Cód. Tipo Liq.", '<>%1', 'HIST_REMUN');
            LinLiq.SetFilter("Tipo Concepto", '<>%1&<>%2',
                LinLiq."Tipo Concepto"::Informativo, LinLiq."Tipo Concepto"::"Contribución Patronal");
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
        if FMarea <> '' then
            Cab.SetFilter("No. Empleado", ConstruirFiltroEmpleados(DeLaMarea));
        if Cab.FindSet() then
            repeat
                Clave := Cab."No. Empleado" + '|' + Format(Cab.Mes);
                if Clave <> ClaveAnt then begin
                    ClaveAnt := Clave;
                    Acum := 0;      // empieza otro empleado-mes: el acumulador de Meta4 se reinicia
                end;
                // Descuentos y neto: se suman las corridas de la marea tal cual, sin restar la
                // anterior, porque estas dos columnas SÍ son de su corrida. Va antes del bruto
                // porque el bruto puede cortar con un CONTINUE implícito si la corrida no tiene
                // TOT_REMUN_27617, y estos dos no tienen por qué perderse por eso.
                if EsDeLaMarea(Cab, NoMarea) then begin
                    Sumar(Meta4Desc, Clave, ValorDe(Val, Cab."No. Entrada", NoColRet));
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
            until Cab.Next() = 0;

        foreach Clave in Meta4.Keys() do begin
            Rec.Init();
            Rec."No. Empleado" := CopyStr(Clave.Split('|').Get(1), 1, 20);
            Rec.Año := FAnio;
            Evaluate(Rec.Mes, Clave.Split('|').Get(2));
            Rec."Importe Meta4" := Meta4.Get(Clave);
            if Meta4Desc.ContainsKey(Clave) then
                Rec."Descuentos Meta4" := Meta4Desc.Get(Clave);
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
        LinLiq.SetRange("Fecha Liquidación", DMY2Date(1, 1, FAnio), DMY2Date(31, 12, FAnio));
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

        // ── cierre ───────────────────────────────────────────────────────────
        Rec.Reset();
        if Rec.FindSet() then
            repeat
                Rec.Diferencia := Rec."Importe BC" - Rec."Importe Meta4";
                Rec."Dif. Descuentos" := Rec."Descuentos BC" - Rec."Descuentos Meta4";
                Rec."Dif. Neto" := Rec."Neto BC" - Rec."Neto Meta4";
                if Rec."Importe Meta4" <> 0 then
                    Rec."% Diferencia" := Round(Rec.Diferencia / Rec."Importe Meta4" * 100, 0.01)
                else
                    Rec."% Diferencia" := 0;
                Rec.Modify();
            until Rec.Next() = 0;

        Rec.Reset();
        if FSoloConBC then
            Rec.SetFilter("Liq. en BC", '>%1', 0);
        if FSoloDif then
            Rec.SetFilter(Diferencia, '<>%1', 0);
        if Rec.FindFirst() then;
    end;

    var
        FAnio: Integer;
        FMarea: Code[20];
        FSoloDif: Boolean;
        FSoloConBC: Boolean;
        FNoMarea: Integer;   // la marea de FMarea ya resuelta, para que el drilldown filtre igual
        EstiloDif: Text;
        EstiloDesc: Text;
        EstiloNeto: Text;
}
