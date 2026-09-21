namespace UAS.Payroll;

table 110041 "Ctrl Sinc NAV"
{
    Caption = 'Control de Sincronización NAV';
    DataClassification = CustomerContent;
    LookupPageId = "Control Sinc. NAV";
    DrillDownPageId = "Control Sinc. NAV";
    // Una fila por entidad sincronizada. Es el único punto donde se tocan las dos mitades del
    // mecanismo: el job de SQL Agent escribe "Marca Agua", "Traido El" y "Filas Traidas" por SQL
    // directo, y el Job Queue de BC escribe las de proceso. Por eso los nombres de tabla y de campo
    // no llevan puntos ni acentos: el script T-SQL los referencia literalmente y un "Cód." se
    // convierte en "Cód_" del lado SQL, que es exactamente la clase de detalle que rompe callado.
    //
    // "Marca Agua" es el rowversion de NAV hasta donde ya se leyó, en decimal y como texto. Se
    // guarda acá y no en una tabla propia del script para que se pueda ver —y corregir a mano si
    // hace falta rehacer una traída— desde BC, sin abrir SSMS.

    fields
    {
        field(1; Entidad; Enum "Entidad Sinc NAV")
        {
            Caption = 'Entidad';
            DataClassification = CustomerContent;
        }
        field(2; Habilitada; Boolean)
        {
            Caption = 'Habilitada';
            DataClassification = CustomerContent;
            InitValue = true;
            // La mira el script SQL antes de traer y el proceso de BC antes de aplicar. Apagar una
            // entidad es la forma de cortar la sincronización de algo puntual sin desarmar el job.
        }
        field(10; "Marca Agua"; Text[20])
        {
            Caption = 'Marca de Agua (rowversion)';
            DataClassification = CustomerContent;
            // Vaciarla fuerza una traída completa en la próxima corrida. Es la palanca de
            // resincronización: no borra nada en BC, sólo vuelve a ofrecer todo el origen.
        }
        field(11; "Traido El"; DateTime)
        {
            Caption = 'Última Traída';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(12; "Filas Traidas"; Integer)
        {
            Caption = 'Filas Traídas (último lote)';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(20; "Procesado El"; DateTime)
        {
            Caption = 'Último Proceso';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(21; "Filas Procesadas"; Integer)
        {
            Caption = 'Filas Procesadas (último proceso)';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(22; "Ultima Observacion"; Text[250])
        {
            Caption = 'Última Observación';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }

    keys
    {
        key(PK; Entidad) { Clustered = true; }
    }

    fieldgroups
    {
        fieldgroup(DropDown; Entidad, "Traido El", "Procesado El") { }
    }

    /// <summary>
    /// Crea las filas que falten. Idempotente: no pisa nada de lo que ya está, porque "Marca Agua"
    /// puede haber sido ajustada a mano y esa decisión vale más que un valor por defecto.
    /// </summary>
    procedure AsegurarFilas()
    var
        Ordinal: Integer;
    begin
        foreach Ordinal in Enum::"Entidad Sinc NAV".Ordinals() do
            if not Get(Enum::"Entidad Sinc NAV".FromInteger(Ordinal)) then begin
                Init();
                Entidad := Enum::"Entidad Sinc NAV".FromInteger(Ordinal);
                Insert(true);
            end;
    end;

    /// <summary>
    /// Devuelve la fila de la entidad, creándola si falta. False si la entidad está deshabilitada.
    /// </summary>
    procedure ObtenerHabilitada(Ent: Enum "Entidad Sinc NAV"): Boolean
    begin
        if not Get(Ent) then begin
            Init();
            Entidad := Ent;
            Insert(true);
        end;
        exit(Habilitada);
    end;

    procedure RegistrarProceso(Filas: Integer; Observacion: Text)
    begin
        "Procesado El" := CurrentDateTime();
        "Filas Procesadas" := Filas;
        "Ultima Observacion" := CopyStr(Observacion, 1, MaxStrLen("Ultima Observacion"));
        Modify(true);
    end;
}
