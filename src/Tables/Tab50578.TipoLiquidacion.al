namespace UAS.Payroll;

table 50578 "Tipo Liquidación"
{
    // Configurable master of liquidation types, replacing the hard-coded enum. Generic types are pure data;
    // types with special engine behaviour are marked with a flag (there is no code keyed to a specific code).
    Caption = 'Tipo Liquidación';
    DataClassification = CustomerContent;
    LookupPageId = "Tipos Liquidación";
    DrillDownPageId = "Tipos Liquidación";

    fields
    {
        field(1; Código; Code[20])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; Descripción; Text[50])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(3; Orden; Integer)
        {
            Caption = 'Orden (valor de TIPO_LIQ)';
            DataClassification = CustomerContent;
            // Also feeds the TIPO_LIQ formula variable (Cod50016) — must stay unique so two types never
            // resolve to the same number in a concept's Fórmula/Condición.
            //
            // El caption lo anuncia porque antes no lo decía en ningún lado: una fórmula con
            // IF(TIPO_LIQ = 40, …) no tenía manera de leerse, y el número sólo se podía averiguar
            // entrando a esta tabla a contar. Hoy la forma recomendada es TIPO_LIQ = 'LIQ_FINAL',
            // pero el número sigue valiendo y las fórmulas viejas lo usan.
            trigger OnValidate()
            begin
                ValidarOrdenUnico();
            end;
        }
        field(4; "Liquida al Arribo"; Boolean)
        {
            Caption = 'Liquida al Arribo (obsoleto)';
            DataClassification = CustomerContent;
            ObsoleteState = Pending;
            ObsoleteReason = 'Reemplazado por Disparador = Arribo. Las tres banderas de disparo eran excluyentes entre sí.';
        }
        field(11; Disparador; Enum "Disparador Tipo Liq.")
        {
            Caption = 'Disparador';
            DataClassification = CustomerContent;
            // Qué hecho hace que este tipo corresponda. Ver el enum: reemplaza a "Liquida al Arribo"
            // y "Sólo Proyectos en Curso", que contestaban lo mismo con dos booleanos que podían
            // estar los dos en verdadero sin significar nada.
        }
        field(12; Meses; Text[30])
        {
            Caption = 'Meses en que corre';
            DataClassification = CustomerContent;
            // Filtro de BC sobre el número de mes: "6|12" para el aguinaldo, vacío para todos. Es el
            // único de los ocho casos que no depende del empleado sino del calendario, y por eso no
            // entra en los estados exigidos.
            //
            // Texto y no una lista de booleanos porque la sintaxis de filtro ya la conoce todo el
            // mundo acá —"Tipos Liq. Aplicables" es lo mismo— y un rango como "1..6" sale gratis.
        }
        field(14; "Sólo Conceptos Declarados"; Boolean)
        {
            Caption = 'Sólo conceptos declarados';
            DataClassification = CustomerContent;
            // INVIERTE LA REGLA DE "Tipos Liq. Aplicables". Esa lista es blanca y vacía significa
            // "todos los tipos", lo cual está bien para un concepto que no declara nada pero no
            // permite decir lo contrario: "en Vacaciones corren SOLAMENTE estos". Marcando esto, el
            // tipo corre únicamente los conceptos que lo nombran, y el vacío deja de ser comodín.
            //
            // Cinco asignaciones en vez de las ciento ochenta y cinco que habría que tocar para
            // sacarles el tipo uno por uno.
            //
            // LO QUE PASABA SIN ESTO: la liquidación de Vacaciones recalculaba el recibo entero. En
            // enero de 2026, 133 empleados cobraron dos veces el SAC devengado, la ART, las
            // contribuciones patronales, la jubilación, la cuota sindical y hasta Ganancias.
        }
        field(13; "Exige Estados"; Boolean)
        {
            Caption = 'Exige estados';
            FieldClass = FlowField;
            CalcFormula = exist("Estado Tipo Liq." where("Cód. Tipo Liq." = field(Código)));
            Editable = false;
        }
        field(5; "Incluye Francos Puerto"; Boolean)
        {
            Caption = 'Incluye Francos en Puerto';
            DataClassification = CustomerContent;
            // When created for a period, also generates project-less liquidations for employees enjoying
            // francos in port (was the Regular behaviour).
        }
        field(9; "Sólo Proyectos en Curso"; Boolean)
        {
            Caption = 'Sólo proyectos en curso (obsoleto)';
            DataClassification = CustomerContent;
            ObsoleteState = Pending;
            ObsoleteReason = 'Reemplazado por Disparador = Marea en curso. Las tres banderas de disparo eran excluyentes entre sí.';
            // Marcado, sólo entran los proyectos que al cierre del período TODAVÍA NO ARRIBARON. Es
            // lo que define a un Devengado: los fijos mensuales que se acumulan MIENTRAS la marea
            // está en el mar. Una marea que ya volvió no devenga nada — la paga su Cierre.
            //
            // NO SE PUEDE APLICAR A TODOS LOS TIPOS QUE NO LIQUIDAN AL ARRIBO. La Regular recorre los
            // proyectos sólo para encontrar a la gente y después agrupa por empleado: pedirle "que no
            // haya arribado" le sacaría a todos los que volvieron de una marea durante el mes, que
            // son justamente los que más tienen para cobrar.
            //
            // LA CONDICIÓN MIRA LA FECHA DE ARRIBO, NO EL Status DEL PROYECTO. El Status no se
            // mantiene y está mal en las dos direcciones: en enero de 2026 había dos mareas en Open
            // que habían arribado en agosto y octubre, y las tres que de verdad estaban navegando el
            // 31 —con 90 tripulantes— figuraban como Completed. Filtrar por Status daba las dos
            // equivocadas y ninguna de las tres buenas.
        }
        field(8; "Tipo Proyecto"; Option)
        {
            Caption = 'Tipo de proyecto';
            OptionMembers = Todos,Productivo,Improductivo;
            OptionCaption = 'Todos,Productivo,Improductivo';
            DataClassification = CustomerContent;
            // SOBRE QUÉ PROYECTOS CORRE ESTE TIPO. Los ordinales son los de Job.Tipo, así que el
            // valor se usa tal cual como filtro.
            //
            // ERA UNA ELECCIÓN DEL OPERADOR Y SE EQUIVOCÓ DOS VECES SEGUIDAS, las dos eligiendo
            // "Todos" en el combo del lanzador. La Regular salió sobre las mareas: 180 liquidaciones
            // en cero. Devengados salió sobre la nómina: 501 más, también en cero. En los dos casos
            // el proceso hizo lo que le pidieron y nada avisó, porque "Todos" es una opción legítima
            // para otros tipos.
            //
            // Que lo declare el tipo lo convierte en un dato que se configura una vez y se revisa,
            // en vez de una decisión que hay que acertar en cada corrida. Devengados y Cierre de
            // Marea son de una marea: Productivo. La Regular necesita Todos aunque no use el
            // proyecto —recorre los proyectos para ENCONTRAR a la gente, y después agrupa por
            // empleado—: restringirla dejaría afuera a quien sólo estuvo asignado a una marea.
        }
        field(7; "Agrupa por Empleado"; Boolean)
        {
            Caption = 'Agrupa por empleado';
            DataClassification = CustomerContent;
            // UNA CABECERA POR EMPLEADO Y PERÍODO, sin proyecto, en vez de una por cada proyecto al
            // que estuvo asignado. Es para la Regular: lo que paga —guardias de puerto, vacaciones,
            // órdenes, dique, francos, accidente y enfermedad— pertenece a la persona y al mes, no a
            // un buque. Sin esto se creaba una cabecera por cada proyecto abierto que el empleado
            // hubiera tocado: en enero de 2026, 180 regulares colgadas de mareas, las 180 en cero.
            //
            // SE DECLARA POR TIPO Y NO SE DEDUCE DE "Liquida al Arribo". Un tipo puede no liquidar al
            // arribo y NECESITAR el proyecto igual: Devengados es exactamente eso —se liquida después
            // de que la marea cerró, pero es de esa marea—. Agruparlo por empleado le dejaría la
            // cabecera sin proyecto, y con ella se irían a cero las variables de navegación y
            // producción, que salen todas del proyecto de la cabecera.
            //
            // OJO CON LA LÍNEA: el motor copia el proyecto de la cabecera a cada línea
            // (LinLiq."No. Proyecto" := Liq."No. Proyecto"). Con la cabecera sin proyecto, las líneas
            // también quedan sin proyecto. Marcar esto sólo tiene sentido en tipos cuyos importes no
            // dependan de un proyecto.
        }
        field(6; Activo; Boolean)
        {
            Caption = 'Activo';
            DataClassification = CustomerContent;
            InitValue = true;
        }
        field(15; "Aplica A"; Enum "Aplica A Liq.")
        {
            Caption = 'Aplica a';
            DataClassification = CustomerContent;
            // MISMO EJE QUE EL "Aplica A" DEL CONCEPTO, pero un escalón más arriba: ahí dice a qué
            // tipo de empleado le corresponde un concepto, y acá a qué tipo de empleado le
            // corresponde el DOCUMENTO entero.
            //
            // Existe porque acotar los conceptos no alcanzaba. Un mensualizado de vacaciones recibía
            // el recibo de Vacaciones con el haber completo Y el Regular con el sueldo completo: el
            // 90016 cobraba 50.381.512,84 contra los 24.208.252,13 de Meta4. El descuento de días
            // —4743— no lo corrige porque su condición es "HAY_LIQ_VACACIONES = 0", o sea que se
            // apaga justo cuando el documento de Vacaciones existe. Meta4 no emite ese segundo
            // documento para tierra: paga el haber y el descuento en el mismo recibo mensual.
            //
            // "Todos" no restringe. El tipo de empleado sale del convenio del empleado, igual que
            // para los conceptos (Convenio Colectivo."Tipo Empleado").
        }
        field(10; "Entra en Corrida Completa"; Boolean)
        {
            Caption = 'Entra en la corrida sin tipo';
            DataClassification = CustomerContent;
            // ARRANCA EN FALSO A PROPÓSITO. "Activo" dice que el tipo existe y se puede usar; esto
            // dice que corresponde correrlo TODOS los meses sin que nadie lo pida. Son dos cosas
            // distintas y confundirlas costó caro: cuando la corrida sin tipo pasó a significar
            // "todos los activos", los ocho tipos estaban activos y en enero de 2026 salieron 2.748
            // liquidaciones de SALDO_INICIAL, LIQ_FINAL, RELIQUIDACION y AGUINALDO — con importes,
            // no vacías, porque 185 conceptos no declaran tipo y aplican a todos. El comparador las
            // sumaba y el bruto de BC daba 29% arriba del de Meta4.
            //
            // SALDO_INICIAL es una importación de una sola vez, LIQ_FINAL es para bajas y AGUINALDO
            // es semestral: ninguno se dispara solo. Que el que quiera entrar lo diga.
        }
    }

    keys
    {
        key(PK; Código) { Clustered = true; }
        key(Orden; Orden) { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Código, Descripción) { }
    }

    trigger OnInsert()
    begin
        // El Orden arranca en cero y el cero ya lo usa SALDO_INICIAL, así que TODA fila nueva nacía
        // en error y la página la descartaba al navegar: no se podía dar de alta un tipo desde la
        // grilla sin cambiar el Orden antes de tocar cualquier otra cosa. Se le da el siguiente
        // libre y que lo cambie quien quiera; la unicidad se sigue validando igual.
        if Orden = 0 then
            if not EsElPrimero() then
                Orden := ProximoOrdenLibre();
        ValidarOrdenUnico();
    end;

    /// <summary>¿No hay ningún otro tipo todavía? Entonces el cero es legítimo.</summary>
    local procedure EsElPrimero(): Boolean
    var
        Otro: Record "Tipo Liquidación";
    begin
        Otro.SetFilter(Código, '<>%1', Código);
        exit(Otro.IsEmpty());
    end;

    local procedure ProximoOrdenLibre(): Integer
    var
        Otro: Record "Tipo Liquidación";
    begin
        Otro.SetCurrentKey(Orden);
        if not Otro.FindLast() then
            exit(0);
        exit(Otro.Orden + 10);
    end;

    trigger OnModify()
    begin
        ValidarOrdenUnico();
    end;

    // Guards TIPO_LIQ correctness: two types resolving to the same formula number would make a concept
    // condition like IF(TIPO_LIQ = 70, ...) ambiguously match both. Runs on every insert/modify — not just
    // the field's own OnValidate — so programmatic inserts (e.g. Cod50055.Sembrar) are covered too.
    local procedure ValidarOrdenUnico()
    var
        Otro: Record "Tipo Liquidación";
    begin
        Otro.SetRange(Orden, Orden);
        Otro.SetFilter(Código, '<>%1', Código);
        if Otro.FindFirst() then
            Error(ErrOrdenDuplicado, Orden, Otro.Código);
    end;

    // Code of the type triggered by the project's end date (Cierre de Marea). Errors if none exists.
    //
    // LEE EL DISPARADOR Y NO "Liquida al Arribo", que está obsoleta. Con la bandera, un tipo de
    // cierre creado como se crean hoy —sólo con el Disparador, que es lo único que la página
    // muestra— no aparecía acá y CrearCierreMarea fallaba diciendo que no hay ninguno configurado,
    // con el tipo a la vista en la lista. Era el hallazgo 3 de la revisión.
    procedure CodigoArribo(): Code[20]
    var
        TipoLiq: Record "Tipo Liquidación";
    begin
        TipoLiq.SetRange(Disparador, TipoLiq.Disparador::Arribo);
        if TipoLiq.FindFirst() then
            exit(TipoLiq.Código);
        Error(ErrSinArribo);
    end;

    // Code of the type flagged "Incluye Francos Puerto" (Regular), or '' if none.
    procedure CodigoFrancosPuerto(): Code[20]
    var
        TipoLiq: Record "Tipo Liquidación";
    begin
        TipoLiq.SetRange("Incluye Francos Puerto", true);
        if TipoLiq.FindFirst() then
            exit(TipoLiq.Código);
        exit('');
    end;

    // Los tres disparadores se preguntan por acá y no leyendo el campo, así el día que se saquen los
    // booleanos obsoletos no hay que tocar los siete lugares que preguntan por el arribo.
    procedure EsArribo(Codigo: Code[20]): Boolean
    var
        TipoLiq: Record "Tipo Liquidación";
    begin
        exit(TipoLiq.Get(Codigo) and (TipoLiq.Disparador = TipoLiq.Disparador::Arribo));
    end;

    procedure EsMareaEnCurso(Codigo: Code[20]): Boolean
    var
        TipoLiq: Record "Tipo Liquidación";
    begin
        exit(TipoLiq.Get(Codigo) and (TipoLiq.Disparador = TipoLiq.Disparador::MareaEnCurso));
    end;

    /// <summary>Si la cobertura de este tipo es el tramo del proyecto y no el período entero.</summary>
    /// <remarks>
    /// Lo decide el TIPO DE PROYECTO y no el disparador. Antes lo decidía "liquida al arribo", y eso
    /// dejaba afuera al Devengado: corre sobre mareas igual que el Cierre, pero se dispara sola en vez
    /// de al arribo, así que salía con el mes entero. Sus 90 liquidaciones de enero de 2026 cubrían
    /// 2.425 días de más — el devengado de una marea que arrancó el 25 tapaba desde el 1.
    ///
    /// Y un día tapado no lo reclama nadie: el control de cobertura lo ve cubierto y no pide otra
    /// liquidación, así que los días de guardia en puerto anteriores al embarque se quedaban sin
    /// pagar, sin hueco visible y sin error.
    ///
    /// TAMBIÉN LOS QUE SE DISPARAN AL ARRIBO, sea cual sea el tipo de proyecto. El pilotaje es una
    /// liquidación aparte con su propio proyecto —de dos o tres días— pero Improductivo, porque
    /// Productivo lo habría tomado también el cierre de marea (mismo disparador). Con sólo el tipo
    /// de proyecto cubría el mes entero: arrancaba el 1, tapaba los días de la regular y ésta no se
    /// generaba. Un tipo que liquida AL ARRIBO de un proyecto cubre el tramo de ese proyecto.
    /// </remarks>
    procedure CubreSoloElProyecto(Codigo: Code[20]): Boolean
    var
        TipoLiq: Record "Tipo Liquidación";
    begin
        if not TipoLiq.Get(Codigo) then
            exit(false);
        exit((TipoLiq."Tipo Proyecto" = TipoLiq."Tipo Proyecto"::Productivo) or (TipoLiq.Disparador = TipoLiq.Disparador::Arribo));
    end;

    procedure EsBajaEmpleado(Codigo: Code[20]): Boolean
    var
        TipoLiq: Record "Tipo Liquidación";
    begin
        exit(TipoLiq.Get(Codigo) and (TipoLiq.Disparador = TipoLiq.Disparador::BajaEmpleado));
    end;

    /// <summary>¿Este tipo corre en el mes de esa fecha? Sin "Meses" cargado, corre en todos.</summary>
    procedure CorreEnElMes(Codigo: Code[20]; Fecha: Date): Boolean
    var
        TipoLiq: Record "Tipo Liquidación";
        Mes: Record "Mes Filtro Liq." temporary;
    begin
        if not TipoLiq.Get(Codigo) then
            exit(true);
        if TipoLiq.Meses = '' then
            exit(true);
        if Fecha = 0D then
            exit(true);
        // El filtro se evalúa sobre una tabla temporal de una fila: es la forma de que "6|12" o
        // "1..6" se interpreten con la misma sintaxis que el usuario ya conoce, sin escribir un
        // parser propio que después difiera en algún caso de borde.
        Mes.Numero := Date2DMY(Fecha, 2);
        Mes.Insert();
        Mes.SetFilter(Numero, TipoLiq.Meses);
        exit(not Mes.IsEmpty());
    end;

    var
        ErrSinArribo: Label 'No hay ningún Tipo de Liquidación con Disparador = "Finalización del proyecto" (el Cierre de Marea).\\Cargalo en la lista de Tipos de Liquidación, en la columna Disparador.';
        ErrOrdenDuplicado: Label 'El Orden %1 ya está usado por el tipo ''%2''. Cada tipo debe tener un Orden distinto (también se usa como valor de TIPO_LIQ en fórmulas).';
}
