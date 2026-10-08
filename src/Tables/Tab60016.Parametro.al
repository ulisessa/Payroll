namespace UAS.Payroll;

table 60016 "Parámetro"
{
    Caption = 'Parámetro';
    DataClassification = CustomerContent;
    LookupPageId = "Parámetros";
    DrillDownPageId = "Parámetros";

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
            DataClassification = CustomerContent;
        }
        field(3; Notas; Text[250])
        {
            Caption = 'Notas';
            DataClassification = CustomerContent;
        }
        field(4; "Nombre Variable"; Code[30])
        {
            Caption = 'Nombre Variable';
            DataClassification = CustomerContent;
            // Variable name exposed in the formula context. Blank = not auto-loaded.

            trigger OnValidate()
            var
                Nombres: Codeunit "Nombres Variables Liq.";
            begin
                Nombres.ExigirLibre("Nombre Variable", Database::"Parámetro", Código);
            end;
        }
        // Las tres banderas de sufijo quedaron sin uso. Declaraban por qué eje se especializaba el
        // parámetro, y de esa declaración dependían tres cosas: qué cascada corría el motor, qué
        // columnas se habilitaban al cargar los valores, y una migración de claves cada vez que la
        // bandera cambiaba.
        //
        // Ahora la clave derivada sale de los campos que cada valor tenga completos y la cascada las
        // consulta todas (ver Claves Parámetro Liq.). Un parámetro puede tener a la vez un valor por
        // defecto, una excepción por convenio y otra por empleado, cosa que las banderas impedían por
        // ser excluyentes entre sí.
        //
        // Pasaron a Removed el 7/10/2026: la publicación anterior ya las llevó como Pending, que es
        // el paso que BC exige antes de sacar una columna, y ninguna línea de código ni ninguna
        // página las leía.
        //
        // SE DEJA LA DECLARACIÓN, que es la diferencia entre Removed y borrar el campo del archivo.
        // Borrándolo, los ids 5, 6 y 8 vuelven a estar libres y alguien podría reusarlos para otra
        // cosa; en un upgrade, BC leería los datos viejos de esa columna como si fueran del campo
        // nuevo. Declarados como Removed quedan quemados para siempre.
        field(5; "Sufijo CCT"; Boolean)
        {
            Caption = 'Sufijo Convenio/Categoría (obsoleto)';
            DataClassification = CustomerContent;
            ObsoleteState = Removed;
            ObsoleteReason = 'La clave derivada se calcula desde los campos de alcance del valor. Ver Claves Parámetro Liq.';
        }
        field(6; "Sufijo Empleado"; Boolean)
        {
            Caption = 'Sufijo Empleado (obsoleto)';
            DataClassification = CustomerContent;
            ObsoleteState = Removed;
            ObsoleteReason = 'La clave derivada se calcula desde los campos de alcance del valor. Ver Claves Parámetro Liq.';
        }
        field(8; "Sufijo Convenio"; Boolean)
        {
            Caption = 'Sufijo Convenio (obsoleto)';
            DataClassification = CustomerContent;
            ObsoleteState = Removed;
            ObsoleteReason = 'La clave derivada se calcula desde los campos de alcance del valor. Ver Claves Parámetro Liq.';
        }
        field(7; "Antigüedad Máxima Vigencia"; DateFormula)
        {
            Caption = 'Antigüedad Máxima Vigencia';
            DataClassification = CustomerContent;
            // Vacío = sin chequeo. Fórmula de fecha relativa (ej. '-1M', '-35D') aplicada
            // sobre la fecha de la liquidación: si la última "Vigencia Desde" cargada en
            // Parámetro Vigente es anterior a esa fecha límite, se avisa al calcular que
            // el valor podría estar desactualizado (ej. MNI_ANUAL, DESP_4CAT_ANUAL, que
            // la AFIP actualiza periódicamente).

            trigger OnValidate()
            var
                Hoy: Date;
            begin
                // La fórmula tiene que retroceder. Una que no lo hace deja la fecha límite en el
                // presente o en el futuro, y ahí NINGUNA versión puede estar al día: el aviso sale
                // en cada liquidación y deja de señalar nada. COEF_GUARDIA_PUERTO estaba cargado
                // '+1M' y dejó 2.532 avisos en enero de 2026 sin que faltara ningún valor.
                if Format("Antigüedad Máxima Vigencia") = '' then
                    exit;
                Hoy := Today();
                if CalcDate("Antigüedad Máxima Vigencia", Hoy) >= Hoy then
                    Error(ErrAntiguedadNoRetrocede, Format("Antigüedad Máxima Vigencia"));
            end;
        }
        field(9; "Edad Máxima Familiar"; Integer)
        {
            Caption = 'Edad máxima del familiar';
            DataClassification = CustomerContent;
            MinValue = 0;
            // Tope de edad para deducir a un familiar a cargo en Ganancias 4ta. CERO = SIN LÍMITE,
            // que es el valor por defecto y deja el cálculo exactamente como estaba.
            //
            // El artículo dice: "hijos e hijastros menores de 18 años de edad, o incapacitados sin
            // límite de edad". O sea que el tope NO es del concepto "hijo" sino del TIPO DE
            // DEDUCCIÓN: HIJO lleva 18 y HIJO_INC no lleva ninguno. Por eso vive acá, en el
            // parámetro que representa al tipo, y no escrito en el motor: el día que la AFIP cambie
            // la edad se corrige en la ficha, y un tipo nuevo trae su propia regla.
            //
            // CONYUGE también queda en cero: no tiene tope de edad.
            //
            // SIN FECHA DE NACIMIENTO NO SE APLICA. Es deliberado: dar de baja una deducción por un
            // dato que falta sería cobrarle impuesto de más a alguien por un hueco de carga. El
            // control de "familiares sin fecha de nacimiento" es la contraparte de esta decisión.
        }
    }

    keys
    {
        key(PK; Código) { Clustered = true; }
    }

    // Renombrar el código tiene que arrastrar los valores vigentes: no solo su "Cód. Parámetro Base",
    // sino también la CLAVE DERIVADA, que lleva el código base como prefijo (ZONA_DESF → ZONA_DESF_ADM).
    // Sin esto, renombrar dejaba las claves apuntando al código viejo y el motor no volvía a encontrar
    // ni un valor: arma la clave efectiva desde el código nuevo (Cod50016 LoadParametros) y no hay nada
    // que la matchee. La misma reconstrucción que hace CopiarEn, que ya la tenía resuelta.
    trigger OnRename()
    var
        Vigente: Record "Parámetro Vigente";
        Snapshot: List of [Guid];
        Id: Guid;
        ClaveVieja: Text;
        NuevaClave: Code[50];
        Sufijo: Text;
    begin
        if xRec.Código = Código then
            exit;

        // Se fotografían los SystemId antes de tocar nada: "Cód. Parámetro" es parte de la clave
        // primaria, así que renombrar en medio del recorrido reordena el conjunto y haría saltear o
        // repetir filas. Mismo criterio que RecalcularClaves en la subpágina.
        Vigente.SetRange("Cód. Parámetro Base", xRec.Código);
        if Vigente.FindSet() then
            repeat
                Snapshot.Add(Vigente.SystemId);
            until Vigente.Next() = 0;

        foreach Id in Snapshot do
            if Vigente.GetBySystemId(Id) then begin
                ClaveVieja := Vigente."Cód. Parámetro";
                NuevaClave := Vigente."Cód. Parámetro";
                if ClaveVieja = xRec.Código then
                    NuevaClave := Código
                else
                    if ClaveVieja.StartsWith(xRec.Código + '_') then begin
                        Sufijo := CopyStr(ClaveVieja, StrLen(xRec.Código) + 1);
                        NuevaClave := CopyStr(Código + Sufijo, 1, MaxStrLen(Vigente."Cód. Parámetro"));
                    end;
                Vigente.Rename(Código, NuevaClave, Vigente."Vigencia Desde");
            end;
    end;

    trigger OnDelete()
    var
        Vigente: Record "Parámetro Vigente";
    begin
        Vigente.SetRange("Cód. Parámetro Base", Código);
        Vigente.SetRange("En Uso", true);
        if not Vigente.IsEmpty() then
            Error(ErrTieneEnUso);
        Vigente.SetRange("En Uso");
        Vigente.DeleteAll();
    end;

    procedure CopiarEn(NuevoCodigo: Code[20])
    var
        NuevoParam: Record "Parámetro";
        VigenteOrig: Record "Parámetro Vigente";
        VigenteNuevo: Record "Parámetro Vigente";
        CodParamOrigTxt: Text;
        Sufijo: Text;
    begin
        NuevoParam := Rec;
        NuevoParam.Código := NuevoCodigo;
        NuevoParam.Insert(true);

        VigenteOrig.SetRange("Cód. Parámetro Base", Código);
        if VigenteOrig.FindSet() then
            repeat
                VigenteNuevo := VigenteOrig;
                VigenteNuevo."Cód. Parámetro Base" := NuevoCodigo;
                // La clave derivada ("Cód. Parámetro") lleva el código base como prefijo
                // (ej. ZONA_DESF_ADM). Al copiar a un código nuevo hay que reconstruirla con
                // el nuevo prefijo; de lo contrario queda apuntando al código viejo y el motor
                // (Contexto Liquidación) nunca la encuentra al armar la clave efectiva.
                CodParamOrigTxt := VigenteOrig."Cód. Parámetro";
                if VigenteOrig."Cód. Parámetro" = Código then
                    VigenteNuevo."Cód. Parámetro" := NuevoCodigo
                else if CodParamOrigTxt.StartsWith(Código + '_') then begin
                    Sufijo := CopyStr(CodParamOrigTxt, StrLen(Código) + 1);
                    VigenteNuevo."Cód. Parámetro" := CopyStr(NuevoCodigo + Sufijo, 1, MaxStrLen(VigenteNuevo."Cód. Parámetro"));
                end;
                VigenteNuevo."En Uso" := false;
                VigenteNuevo.Insert(true);
            until VigenteOrig.Next() = 0;
    end;

    var
        ErrTieneEnUso: Label 'No se puede eliminar el parámetro porque tiene valores que fueron utilizados en liquidaciones registradas.';
        ErrAntiguedadNoRetrocede: Label 'La antigüedad máxima "%1" no retrocede en el tiempo, así que ninguna versión del parámetro podría estar al día y el aviso saldría en todas las liquidaciones. Usá una fórmula negativa (por ejemplo -1M o -35D), o dejá el campo vacío para no chequear.', Comment = '%1=fórmula de fecha cargada';
}
