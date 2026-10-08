namespace UAS.Payroll;

/// <summary>
/// Qué estados tiene que tener —o no tener— un empleado para que este tipo de liquidación le
/// corresponda.
/// </summary>
/// <remarks>
/// ES LA TERCERA PREGUNTA DE LA SELECCIÓN. El lote venía mirando dos: que el empleado esté ASIGNADO
/// a un proyecto del tipo dentro de las fechas del período, y que alguna FASE DE ALTA diga que ese
/// mes pertenecía a la empresa. Faltaba la que decide si hay algo que liquidar: sus ESTADOS.
///
/// LA REGLA: la liquidación se crea si ALGUNA línea "Exige" encuentra estado y NINGUNA línea
/// "Excluye" lo encuentra. Sin líneas, el tipo no tiene condición de estados y se comporta como
/// antes. Las "Exige" se combinan con O y no con Y a propósito: el caso que lo pide son las
/// vacaciones, que se pagan si el empleado las toma este mes O si las va a tomar el que viene.
///
/// POR QUÉ UNA TABLA Y NO CAMPOS EN TIPO LIQUIDACIÓN. Porque la cantidad de condiciones no está
/// acotada y porque cada una lleva tres calificadores propios —ventana, modo y tipo de proyecto—.
/// Con campos habría que inventar "Estado 1", "Estado 2"… y la Regular necesita algo que ninguno de
/// esos campos podría decir: "un estado cualquiera cuyo PROYECTO no sea productivo".
/// </remarks>
table 110059 "Estado Tipo Liq."
{
    Caption = 'Estados exigidos por tipo de liquidación';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Cód. Tipo Liq."; Code[20])
        {
            Caption = 'Cód. Tipo Liq.';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Tipo Liquidación".Código;
        }
        field(2; "No. Línea"; Integer)
        {
            Caption = 'No. Línea';
            AutoIncrement = true;
            DataClassification = CustomerContent;
        }
        field(3; Modo; Enum "Modo Estado Tipo Liq.")
        {
            Caption = 'Modo';
            DataClassification = CustomerContent;
        }
        field(4; "Cód. Estado"; Code[50])
        {
            Caption = 'Estado (filtro)';
            DataClassification = CustomerContent;
            // ES UN FILTRO, no un código suelto: admite 'BAJ*', 'NV|PL|PS', '<>OI'. Un código a secas
            // sigue siendo un filtro válido que coincide sólo consigo mismo, así que las líneas
            // cargadas antes de este cambio significan exactamente lo mismo que significaban.
            //
            // Lo motivó LIQ_FINAL, que necesitaba una línea por cada código de baja —dieciocho, de
            // BAJ-0 a BAJ-17— y que con una baja nueva se rompía sin que nadie se enterara. 'BAJ*'
            // las reemplaza a todas y absorbe las que vengan.
            //
            // NO lleva TableRelation, porque un filtro no es un valor de la tabla. Lo que se pierde
            // —que BC te impida escribir un código inexistente— lo cubre OnValidate avisando cuando
            // el filtro no coincide con ningún estado: un typo acá no da error, deja al tipo sin
            // generarse y en silencio.
            //
            // EN BLANCO = CUALQUIER ESTADO, que no es lo mismo que "ningún filtro": sigue exigiendo
            // que haya AL MENOS UNO en la ventana. Es lo que necesita la Regular, a la que no le
            // importa cuál sea el estado sino que el empleado tenga alguno que no venga de una marea.

            trigger OnValidate()
            var
                CodEst: Record "Cód. Estado Empleado";
            begin
                if "Cód. Estado" = '' then
                    exit;
                if not TryAplicarFiltro("Cód. Estado") then
                    Error(ErrFiltroInvalido, "Cód. Estado");
                CodEst.SetFilter(Código, "Cód. Estado");
                if CodEst.IsEmpty() then
                    Message(MsgFiltroSinEstados, "Cód. Estado");
            end;
        }
        field(5; Ventana; Enum "Ventana Estado Tipo Liq.")
        {
            Caption = 'Ventana';
            DataClassification = CustomerContent;
        }
        field(6; "Tipo Proyecto"; Option)
        {
            Caption = 'Tipo de proyecto del estado';
            OptionMembers = Todos,Productivo,Improductivo;
            OptionCaption = 'Todos,Productivo,Improductivo';
            DataClassification = CustomerContent;
            // EL PROYECTO DEL ESTADO, no el de la liquidación. Estado Empleado guarda su "No.
            // Proyecto", así que se puede preguntar de dónde viene cada día: la Regular quiere los
            // días que NO son de una marea, porque esos los paga el Cierre.
            //
            // Los ordinales son los de Job.Tipo, así que el valor se usa tal cual como filtro.
        }
        field(7; Descripción; Text[100])
        {
            Caption = 'Descripción';
            DataClassification = CustomerContent;
        }
        field(8; "Empieza en la Ventana"; Boolean)
        {
            Caption = 'El estado empieza en la ventana';
            DataClassification = CustomerContent;
            // SOLAPAR NO ES EMPEZAR, y la diferencia decide un recibo entero.
            //
            // Sin esto, "Exige AU9 con ventana MesSiguiente" pregunta si el empleado tiene UN AU9 QUE
            // TOQUE el mes que viene. Eso da verdadero para quien empezó sus vacaciones el 1 de enero
            // y las termina el 4 de febrero, que no está cobrando ningún anticipo: ya las está
            // tomando. En enero de 2026 eran 64 liquidaciones de vacaciones de más, 522 millones en
            // haberes.
            //
            // La regla del anticipo es sobre la FECHA DE INICIO: se paga por adelantado cuando la
            // fecha de liquidación es anterior al comienzo de las vacaciones. Con esto en Sí, la
            // línea pide que el estado ARRANQUE dentro de la ventana y no que la roce.
            //
            // Queda como campo aparte y no como una ventana nueva del enum porque es ortogonal: sirve
            // para cualquier ventana, y una ventana "MesSiguienteQueEmpieza" obligaría a duplicar
            // cada valor futuro.
        }
    }

    keys
    {
        key(PK; "Cód. Tipo Liq.", "No. Línea") { Clustered = true; }
        key(Modo; "Cód. Tipo Liq.", Modo) { }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Cód. Tipo Liq.", Modo, "Cód. Estado", Ventana) { }
    }

    var
        ErrFiltroInvalido: Label 'El filtro de estados "%1" no es válido. Se puede usar un código (NV), una lista (NV|PL|PS) o un comodín (BAJ*).', Comment = '%1=filtro';
        MsgFiltroSinEstados: Label 'El filtro "%1" no coincide con ningún código de estado. La línea se guarda igual, pero mientras no exista un estado que coincida esta condición nunca se va a cumplir.', Comment = '%1=filtro';

    /// <summary>¿Este código de estado coincide con el filtro de la línea?</summary>
    /// <remarks>
    /// Para los que ya tienen el estado en la mano y no pueden volver a consultar la base —la
    /// evaluación por estado del lote—. Se resuelve con el mismo motor de filtros que usa SQL, sobre
    /// un registro temporal de una sola fila, así que un filtro raro se comporta igual en los dos
    /// caminos. El blanco coincide con todo, que es lo que significa en este campo.
    /// </remarks>
    procedure CoincideEstado(CodEstado: Code[20]): Boolean
    var
        Tmp: Record "Cód. Estado Empleado" temporary;
    begin
        if "Cód. Estado" = '' then
            exit(true);
        Tmp.Código := CodEstado;
        Tmp.Insert();
        Tmp.SetFilter(Código, "Cód. Estado");
        exit(not Tmp.IsEmpty());
    end;

    // El SetFilter revienta con sintaxis inválida; el IsEmpty fuerza que se evalúe de verdad y no
    // quede como un filtro guardado que recién falla cuando alguien calcula una liquidación.
    [TryFunction]
    local procedure TryAplicarFiltro(Filtro: Text)
    var
        CodEst: Record "Cód. Estado Empleado";
    begin
        CodEst.SetFilter(Código, Filtro);
        if CodEst.IsEmpty() then;
    end;
}
