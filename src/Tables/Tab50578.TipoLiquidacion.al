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
            Caption = 'Orden';
            DataClassification = CustomerContent;
            // Also feeds the TIPO_LIQ formula variable (Cod50016) — must stay unique so two types never
            // resolve to the same number in a concept's Fórmula/Condición.
            trigger OnValidate()
            begin
                ValidarOrdenUnico();
            end;
        }
        field(4; "Liquida al Arribo"; Boolean)
        {
            Caption = 'Liquida al Arribo';
            DataClassification = CustomerContent;
            // Cierre de Marea behaviour: reference date = arrival (Job Ending), coverage up to arrival,
            // job/personnel filters by arrival/discharge instead of period end.
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
            Caption = 'Sólo proyectos en curso';
            DataClassification = CustomerContent;
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
        ValidarOrdenUnico();
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

    // Code of the type flagged "Liquida al Arribo" (Cierre de Marea). Errors if none is configured.
    procedure CodigoArribo(): Code[20]
    var
        TipoLiq: Record "Tipo Liquidación";
    begin
        TipoLiq.SetRange("Liquida al Arribo", true);
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

    procedure EsArribo(Codigo: Code[20]): Boolean
    var
        TipoLiq: Record "Tipo Liquidación";
    begin
        exit(TipoLiq.Get(Codigo) and TipoLiq."Liquida al Arribo");
    end;

    var
        ErrSinArribo: Label 'No hay ningún Tipo de Liquidación marcado como "Liquida al Arribo" (Cierre de Marea).';
        ErrOrdenDuplicado: Label 'El Orden %1 ya está usado por el tipo ''%2''. Cada tipo debe tener un Orden distinto (también se usa como valor de TIPO_LIQ en fórmulas).';
}
