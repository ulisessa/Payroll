namespace UAS.Payroll;

using Microsoft.Foundation.Calendar;

table 60004 "Convenio Colectivo"
{
    Caption = 'Convenio Colectivo';
    DataClassification = CustomerContent;
    LookupPageId = "Convenios Colectivos";
    DrillDownPageId = "Convenios Colectivos";

    fields
    {
        field(1; Código; Code[20])
        {
            Caption = 'Código';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(2; Descripción; Text[100])
        {
            Caption = 'Descripción';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(3; "No. CCT"; Text[30])
        {
            Caption = 'No. CCT';
            DataClassification = CustomerContent;
        }
        field(4; Sindicato; Text[100])
        {
            Caption = 'Sindicato';
            DataClassification = CustomerContent;
        }
        field(5; Cámara; Text[100])
        {
            Caption = 'Cámara';
            DataClassification = CustomerContent;
        }
        field(6; Observaciones; Text[250])
        {
            Caption = 'Observaciones';
            DataClassification = CustomerContent;
        }
        field(8; "Cód. Calendario"; Code[10])
        {
            Caption = 'Cód. Calendario';
            DataClassification = CustomerContent;
            TableRelation = "Base Calendar";
            // Calendario de feriados de ESTE convenio. En blanco, se usa el del período.
            //
            // EXISTE PORQUE LOS CONVENIOS TIENEN FERIADOS DISTINTOS Y EL PERIODO TIENE UNO SOLO. El
            // Art. 36 del CCT 768/19 suma el 8 y 9 de febrero y fija el 20 de noviembre en su fecha,
            // no en la trasladada; el Art. 51 del 729/15 no los tiene. Los dos suman el 29 de
            // diciembre, Día del Pescador, que no es feriado nacional. Con un único calendario en el
            // período no se pueden representar las dos listas.
            //
            // El feriado se resuelve con el convenio VIGENTE A LA FECHA DE REFERENCIA, no día por
            // día. Si alguien cambia de convenio a mitad de mes, los feriados de todo el mes se
            // cuentan con el convenio del cierre. Es un caso raro y se documenta en vez de
            // resolverse: hacerlo día por día obligaría a resolver el par convenio-categoría 31
            // veces por empleado y por liquidación.
        }
        field(7; "Tipo Empleado"; Enum "Aplica A Liq.")
        {
            Caption = 'Tipo Empleado';
            DataClassification = CustomerContent;
            // Qué población encuadra este convenio: Tripulante, Mensualizado o Jornalizado. Decide
            // qué conceptos le aplican a la gente del CCT — el filtro "Aplica A" de cada concepto se
            // compara contra esto.
            //
            // POR QUÉ ESTÁ ACÁ Y NO EN EL ESTADO, que es donde estaba. El motor sacaba el tipo del
            // "Cód. Estado Empleado" en que la persona estaba ESE DÍA, y eso falla en cuanto el
            // estado es compartido: un tripulante de vacaciones está en AU9, que lo usa todo el
            // mundo. Si AU9 dice "Todos", SelectConceptos no filtra NADA y al tripulante le entran
            // los conceptos de mensualizado. Así apareció el legajo 00191 —CCT 729/15, Primer
            // Cocinero— cobrando "Antigüedad mensuales" en enero de 2026.
            //
            // El tipo es de la PERSONA, no del día. Y como ningún convenio mezcla poblaciones, el
            // lugar donde vale una sola vez es el convenio.
            //
            // EN BLANCO ES "Todos", Y ESO NO FILTRA. Un convenio sin configurar deja pasar todos los
            // conceptos, que es el comportamiento permisivo de antes: de más sale una línea que
            // alguien ve en el recibo; de menos, un concepto que falta y nadie nota.
        }
    }

    keys
    {
        key(PK; Código)
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Código, Descripción, "No. CCT") { }
    }

    // Esta tabla es la fuente de verdad de los convenios. Cuando existe un atributo declarado como
    // espejo de acá —el que le da historial al convenio de cada empleado—, sus valores se mantienen
    // desde estos cuatro triggers y no a mano. Sin ningún atributo espejo configurado, no hacen nada.
    trigger OnInsert()
    var
        Espejo: Codeunit "Espejo Atributos Liq.";
    begin
        Espejo.AlEscribirConvenio(Código, Descripción);
    end;

    trigger OnModify()
    var
        Espejo: Codeunit "Espejo Atributos Liq.";
    begin
        Espejo.AlEscribirConvenio(Código, Descripción);
    end;

    trigger OnRename()
    var
        Espejo: Codeunit "Espejo Atributos Liq.";
    begin
        Espejo.AlRenombrarConvenio(xRec.Código, Código);
    end;

    // Corta la baja si el valor espejo tiene historial: esas vigencias quedarían nombrando un
    // convenio que ya no existe.
    trigger OnDelete()
    var
        Espejo: Codeunit "Espejo Atributos Liq.";
    begin
        Espejo.AlBorrarConvenio(Código);
    end;
}
