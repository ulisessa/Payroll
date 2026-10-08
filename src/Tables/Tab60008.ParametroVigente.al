namespace UAS.Payroll;

using Microsoft.HumanResources.Employee;
using Microsoft.Finance.Currency;

table 60008 "Parámetro Vigente"
{
    Caption = 'Parámetro Vigente';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Cód. Parámetro"; Code[50])
        {
            Caption = 'Clave Derivada';
            NotBlank = true;
            DataClassification = CustomerContent;
            Editable = false;
            // Se calcula SIEMPRE a partir del código base y de los campos que la fila tenga
            // completos (ver RecalcularClave). Antes se tipeaba a mano en unos casos y se derivaba
            // en otros según qué bandera de sufijo tuviera el parámetro; eso obligaba a habilitar y
            // deshabilitar columnas y a migrar las claves cada vez que la bandera cambiaba.
            //
            // Sin TableRelation: las claves derivadas (BASICO_175/75_CAPITAN) no existen como
            // registros de Parámetro. La integridad la sostiene Parámetro.OnDelete.
        }
        field(2; "Vigencia Desde"; Date)
        {
            Caption = 'Vigencia Desde';
            NotBlank = true;
            DataClassification = CustomerContent;
        }
        field(3; Descripción; Text[100])
        {
            Caption = 'Descripción Versión';
            DataClassification = CustomerContent;
        }
        field(4; Valor; Decimal)
        {
            Caption = 'Valor';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 6;
        }
        field(5; Moneda; Code[10])
        {
            Caption = 'Moneda';
            DataClassification = CustomerContent;
            TableRelation = Currency;
        }
        field(14; "Cód. Variable TC"; Code[60])
        {
            Caption = 'Variable Tipo de Cambio';
            DataClassification = CustomerContent;
            // Qué variable convierte ESTE valor a pesos. Acompaña a Moneda y por eso vive en la misma
            // fila: tener la moneda en un lado y su tipo de cambio en otro es de las cosas que seis
            // meses después nadie entiende.
            //
            // POR FILA Y NO POR PARÁMETRO, a propósito. Queda por alcance —USD_MAREA_04724 puede ir
            // al vendedor y USD_MAREA_768/19_OF03 al comprador, porque son filas distintas— y por
            // vigencia, así que un cambio de convención se expresa con una fila nueva en vez de
            // reescribir la anterior.
            //
            // El motor TODAVÍA NO LA LEE. Hoy convierte el neto del grossing-up con el vendedor
            // cableado (Cod50014, TipoCambioVendedor), que es correcto para los cuatro de tierra y no
            // para todos: la producción va al comprador. El plan para encenderla, con sus seis pasos
            // y qué verificar en cada uno, está en GROSSING_UP_Y_TC_CONFIGURABLES.md.
            //
            // Sin TableRelation que valide: hoy los dos candidatos —TC_COMPRADOR y TC_VENDEDOR— son
            // Fuentes de Datos, pero el TC de una marea NO es una cotización sino un valor acordado,
            // y ese caso puede resolverse por otra vía. El lookup ayuda a cargar; no acota.
            TableRelation = "Fuente Datos Liquidación"."Nombre Variable";
            ValidateTableRelation = false;
        }
        field(6; "En Uso"; Boolean)
        {
            Caption = 'En Uso';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(7; Notas; Text[250])
        {
            Caption = 'Notas';
            DataClassification = CustomerContent;
        }
        field(8; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            DataClassification = CustomerContent;
            TableRelation = Employee."No.";

            trigger OnValidate()
            begin
                // El empleado es el eje más específico y no se combina con los otros: cargarlo
                // limpia convenio y categoría en vez de armar una clave que nadie va a buscar.
                if "No. Empleado" <> '' then begin
                    "Cód. Convenio" := '';
                    "Cód. Categoría" := '';
                end;
                RecalcularClave();
            end;
        }
        field(10; "Cód. Parámetro Base"; Code[20])
        {
            Caption = 'Cód. Parámetro Base';
            DataClassification = CustomerContent;
            TableRelation = "Parámetro";

            trigger OnValidate()
            begin
                RecalcularClave();
            end;
        }
        field(11; "Cód. Convenio"; Code[20])
        {
            Caption = 'Cód. Convenio';
            DataClassification = CustomerContent;
            TableRelation = "Convenio Colectivo".Código;

            trigger OnValidate()
            begin
                if "Cód. Convenio" = '' then
                    "Cód. Categoría" := '';
                if "Cód. Convenio" <> '' then
                    "No. Empleado" := '';
                RecalcularClave();
            end;
        }
        field(12; "Cód. Categoría"; Code[20])
        {
            Caption = 'Cód. Categoría';
            DataClassification = CustomerContent;
            TableRelation = "Categoría CCT".Código WHERE("Cód. Convenio" = FIELD("Cód. Convenio"));

            trigger OnValidate()
            begin
                if ("Cód. Categoría" <> '') and ("Cód. Convenio" = '') then
                    Error(ErrCategoriaSinConvenio);
                RecalcularClave();
            end;
        }
        field(13; Nivel; Integer)
        {
            Caption = 'Nivel';
            DataClassification = CustomerContent;
            Editable = false;
            // 0 base, 1 convenio o empleado, 2 convenio + categoría. Es la columna de indentación
            // del árbol de parámetros: se calcula junto con la clave y no se carga a mano.
        }
    }

    keys
    {
        key(PK; "Cód. Parámetro Base", "Cód. Parámetro", "Vigencia Desde")
        {
            Clustered = true;
        }
        key(Codigo; "Cód. Parámetro", "Vigencia Desde") { }
    }

    trigger OnInsert()
    begin
        if "Cód. Parámetro Base" = '' then
            "Cód. Parámetro Base" := DeriveBase("Cód. Parámetro");
        RecalcularClave();
        // Alta: la fila todavía no existe, así que no hay nada que excluir.
        ValidarClaveLibre('', '', 0D);
    end;

    /// <summary>
    /// Recalcula la clave derivada y el nivel a partir de los campos completos.
    /// </summary>
    procedure RecalcularClave()
    var
        Claves: Codeunit "Claves Parámetro Liq.";
    begin
        if "Cód. Parámetro Base" = '' then
            exit;
        "Cód. Parámetro" := Claves.ArmarDeFila(Rec);
        Nivel := Claves.NivelDeFila(Rec);
    end;

    /// <summary>
    /// Corta si otra fila ya responde por la misma clave derivada en la misma vigencia.
    /// </summary>
    /// <remarks>
    /// La clave derivada identifica el valor que va a buscar el motor. Dos filas con la misma clave
    /// y la misma vigencia son dos respuestas para la misma pregunta, y la clave primaria las
    /// admitiría solo si difieren en el código base — que es justo el caso confuso.
    ///
    /// Los tres parámetros son la clave primaria de la fila que se está editando, para que no se
    /// detecte a sí misma. En un alta llegan vacíos y no excluyen nada.
    ///
    /// Se recorre en vez de usar IsEmpty() porque hay que mirar la PK de cada candidato: la fila
    /// propia y una duplicada real comparten el filtro, y solo se distinguen por el código base.
    /// </remarks>
    local procedure ValidarClaveLibre(BasePropia: Code[20]; ParamPropio: Code[50]; VigPropia: Date)
    var
        Existente: Record "Parámetro Vigente";
    begin
        Existente.SetCurrentKey("Cód. Parámetro", "Vigencia Desde");
        Existente.SetRange("Cód. Parámetro", "Cód. Parámetro");
        Existente.SetRange("Vigencia Desde", "Vigencia Desde");
        if Existente.FindSet() then
            repeat
                if not ((Existente."Cód. Parámetro Base" = BasePropia) and
                        (Existente."Cód. Parámetro" = ParamPropio) and
                        (Existente."Vigencia Desde" = VigPropia))
                then
                    Error(ErrClaveDuplicada, "Cód. Parámetro", "Vigencia Desde");
            until Existente.Next() = 0;
    end;

    trigger OnModify()
    begin
        // La clave derivada se rearma en los OnValidate de empleado, convenio, categoría y vigencia
        // (ver RecalcularClave). Sin este control, modificar cualquiera de esos campos podía dejar
        // dos filas respondiendo por la misma clave: la validación vivía solo en el alta.
        //
        // Acá la PK no pudo cambiar —si cambia, BC va por OnRename, no por acá—, así que la fila
        // propia se excluye con su propia clave y no hace falta xRec.
        ValidarClaveLibre("Cód. Parámetro Base", "Cód. Parámetro", "Vigencia Desde");

        if xRec."En Uso" and "En Uso" then
            if HayLiquidacionesBloqueantes() then
                Error(ErrEnUso)
            else begin
                "En Uso" := false;
                xRec."En Uso" := false;
            end;
    end;

    // "Cód. Parámetro" es parte de la clave primaria, así que cuando RecalcularClave lo cambia la
    // página no guarda con Modify sino con Rename, y el control de OnModify no llega a correr.
    // Acá la fila propia se excluye con su clave ANTERIOR, que es la que todavía está en la base.
    trigger OnRename()
    begin
        ValidarClaveLibre(xRec."Cód. Parámetro Base", xRec."Cód. Parámetro", xRec."Vigencia Desde");
    end;

    trigger OnDelete()
    begin
        if "En Uso" then
            if HayLiquidacionesBloqueantes() then
                Error(ErrEnUso)
            else
                "En Uso" := false;
    end;

    local procedure HayLiquidacionesBloqueantes(): Boolean
    var
        Liq: Record "Liquidación";
    begin
        if "No. Empleado" <> '' then
            Liq.SetRange("No. Empleado", "No. Empleado");
        Liq.SetFilter(Estado, '%1|%2|%3',
            Liq.Estado::Calculada, Liq.Estado::Aprobada, Liq.Estado::Contabilizada);
        exit(not Liq.IsEmpty());
    end;

    local procedure DeriveBase(CodParam: Code[50]): Code[20]
    var
        Param: Record "Parámetro";
        BestCode: Code[20];
        BestLen: Integer;
        CodParamTxt: Text;
    begin
        CodParamTxt := CodParam;
        if Param.FindSet() then
            repeat
                if (StrLen(Param.Código) > BestLen) and
                   ((CodParam = Param.Código) or
                    CodParamTxt.StartsWith(Param.Código + '_'))
                then begin
                    BestCode := Param.Código;
                    BestLen := StrLen(Param.Código);
                end;
            until Param.Next() = 0;
        exit(BestCode);
    end;

    var
        ErrEnUso: Label 'No se puede modificar ni eliminar un parámetro que ya fue utilizado en una liquidación registrada.';
        ErrClaveDuplicada: Label 'Ya existe un valor con la clave %1 y vigencia %2. Cambiá el convenio, la categoría o el empleado, o modificá la fila existente.';
        ErrCategoriaSinConvenio: Label 'La categoría se carga junto con el convenio: primero indicá el convenio.';
}
