namespace UAS.Payroll;

using Microsoft.Foundation.UOM;
using Microsoft.HumanResources.Employee;
using Microsoft.Projects.Project.Job;

table 60012 "Línea Liquidación"
{
    Caption = 'Línea Liquidación';
    DataClassification = CustomerContent;
    // El importe lleva SU PROPIO SIGNO. "Tipo Concepto" dice qué ES la línea; el signo dice para qué
    // lado va. Son dos cosas independientes:
    //   Haber Rem / Haber No Rem  → entra al neto sumando
    //   Descuento / Retención     → entra al neto restando
    //   Contribución Patronal     → lado patronal, fuera del neto
    // ...y dentro de cualquiera de esos, un importe negativo invierte esa dirección.
    //
    // Antes todos los importes se guardaban positivos (el motor les aplicaba Abs) y el signo salía
    // ENTERO del Tipo Concepto. El problema es que Tipo Concepto decide bastante más que el signo:
    // si es remunerativo, a qué acumuladores y bases aporta, el grupo de costo laboral, si imprime y
    // en qué total cae. Para expresar un haber remunerativo negativo había que declararlo con otro
    // tipo —"Deducción Remunerativa", que restaba de Total Haberes en lugar de sumar a Descuentos—
    // y eso le cambiaba también la naturaleza. Además no escalaba: no existía el espejo de "Haber No
    // Remunerativo" ni el de "Contribución Patronal". Ese tipo se eliminó junto con el Abs.
    //
    // UpdateTotals y CalcNetoDesdeBD no necesitaron cambios: sus CalcSums ya suman con signo.

    fields
    {
        field(32; "No. Lote Franco"; Integer) { DataClassification = CustomerContent; Editable = false; }
        field(33; "Id. Selección Francos"; Guid) { DataClassification = CustomerContent; Editable = false; }
        field(1; "No. Liquidación"; Code[20])
        {
            Caption = 'No. Liquidación';
            NotBlank = true;
            DataClassification = CustomerContent;
            TableRelation = "Liquidación"."No.";
        }
        field(2; "No. Línea"; Integer)
        {
            Caption = 'No. Línea';
            DataClassification = CustomerContent;
            AutoIncrement = true;
        }
        field(3; "Cód. Concepto"; Code[20])
        {
            Caption = 'Cód. Concepto';
            DataClassification = CustomerContent;
        }
        field(4; "Descripción Concepto"; Text[100])
        {
            Caption = 'Descripción Concepto';
            DataClassification = CustomerContent;
        }
        field(5; "Nombre Impresión"; Text[50])
        {
            Caption = 'Nombre Impresión';
            DataClassification = CustomerContent;
        }
        field(6; "Tipo Concepto"; Enum "Tipo Concepto Liq.")
        {
            Caption = 'Tipo Concepto';
            DataClassification = CustomerContent;
        }
        field(7; Importe; Decimal)
        {
            Caption = 'Importe';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(8; "Orden Cálculo"; Integer)
        {
            Caption = 'Orden Cálculo';
            DataClassification = CustomerContent;
        }
        field(9; "Fórmula Aplicada"; Text[2048])
        {
            Caption = 'Fórmula Aplicada';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(11; "Fuente Parámetros"; Text[2048])
        {
            Caption = 'Fuente Parámetros';
            DataClassification = CustomerContent;
            Editable = false;
            // Lo que leyó la fórmula de ESTE concepto (VAR:, TRAMO:, ACUMCCT:…), separado por |. Hasta la 1.0.0.696 llevaba delante
            // la traza del contexto de toda la liquidación, que la cortaba en 2048 antes de llegar a las variables del concepto; ahora
            // esa traza va una sola vez en "Liquidación"."Traza Contexto".
        }
        field(31; "Vigencias Distribución"; Text[250])
        {
            Caption = 'Vigencias Distribución';
            DataClassification = CustomerContent;
            Editable = false;
            // Lista "ACUMULADOR:AAAAMMDD" separada por | con la vigencia de la Fracción Acumulador
            // que se aplicó a cada acumulador, en el mismo formato que "Fuente Parámetros".
            //
            // Cierra un agujero de auditoría: "Vigencia Concepto" deja reconstruir con qué fórmula se
            // calculó, pero la distribución se versiona en su propia línea de tiempo (ver
            // BuildFractionCache). Sin esto, cargar una fracción con vigencia retroactiva hacía que
            // un recálculo de un período viejo distribuyera distinto, sin nada que lo delatara.
        }
        field(12; "Vigencia Concepto"; Date)
        {
            Caption = 'Vigencia Concepto';
            DataClassification = CustomerContent;
            Editable = false;
            // The VigenciaDesde of the ConceptoLiquidación version used.
        }
        field(13; Cantidad; Decimal)
        {
            Caption = 'Cantidad';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 4;
        }
        field(14; "Unidad Cantidad"; Code[10])
        {
            Caption = 'Unidad';
            DataClassification = CustomerContent;
        }
        field(15; "Fórmula Evaluada"; Text[2048])
        {
            Caption = 'Fórmula con Valores';
            DataClassification = CustomerContent;
            Editable = false;
        }

        // ── Campos desnormalizados de la cabecera ─────────────────────────────
        // Permiten consultar Línea Liquidación sin join a Liquidación.
        // Se escriben en el motor al crear la línea y se sincronizan en cada
        // recálculo (DeleteLineas + recreación). Estado se setea a Calculada;
        // las transiciones a Aprobada/Contabilizada requieren sincronización
        // adicional en los flujos de aprobación y contabilización.

        field(16; "No. Empleado"; Code[20])
        {
            Caption = 'No. Empleado';
            DataClassification = EndUserIdentifiableInformation;
            TableRelation = Employee."No.";
            Editable = false;
        }
        field(17; "Cód. Período"; Code[10])
        {
            Caption = 'Cód. Período';
            DataClassification = CustomerContent;
            TableRelation = "Período Liquidación".Código;
            Editable = false;
        }
        field(18; "No. Proyecto"; Code[20])
        {
            Caption = 'No. Proyecto';
            DataClassification = CustomerContent;
            TableRelation = Job."No.";
            Editable = false;
        }
        field(30; "Cód. Tipo Liq."; Code[20])
        {
            Caption = 'Tipo Liquidación';
            DataClassification = CustomerContent;
            TableRelation = "Tipo Liquidación".Código;
            Editable = false;
        }
        field(20; "Cód. Convenio"; Code[20])
        {
            Caption = 'Cód. Convenio';
            DataClassification = CustomerContent;
            TableRelation = "Convenio Colectivo".Código;
            Editable = false;
        }
        field(21; "Cód. Categoría"; Code[20])
        {
            Caption = 'Cód. Categoría';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(22; Estado; Enum "Estado Liq.")
        {
            Caption = 'Estado';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(23; "Fecha Liquidación"; Date)
        {
            Caption = 'Fecha Liquidación';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(24; "Imprime en Recibo"; Boolean)
        {
            Caption = 'Imprime en Recibo';
            DataClassification = CustomerContent;
            Editable = false;
            InitValue = true;
        }
        field(25; "Grupo Costo Laboral"; Enum "Grupo Costo Laboral Liq.")
        {
            Caption = 'Grupo Costo Laboral';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(27; "Base Cálculo"; Decimal)
        {
            Caption = 'Base Cálculo';
            DataClassification = CustomerContent;
            DecimalPlaces = 2 : 2;
        }
        field(26; "Es Devengo"; Boolean)
        {
            Caption = 'Is Accrual';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }

    keys
    {
        // SIN SumIndexFields A PROPOSITO. Una SIFT sobre la clave primaria agrupa por
        // (No. Liquidación, No. Línea), que es única: la vista indexada terminaba con UNA FILA POR
        // LÍNEA —104.588, igual que la tabla— y no ahorraba ninguna suma. Ningún CalcSums la usaba:
        // los de UpdateTotals y CalcNetoDesdeBD filtran por "Es Devengo" y "Tipo Concepto" y van a
        // K2; los acumulados recorren los índices ordinarios K4/K5 y suman en memoria. Medido
        // sobre 90 horas de uso real de la antigua SIFT de PK: 0 lecturas contra
        // 1.020.888 mantenimientos. Mantener una vista indexada es la escritura más cara que hay, y
        // esta tabla es el 45% del tiempo ocupado del cálculo.
        key(PK; "No. Liquidación", "No. Línea")
        {
            Clustered = true;
        }
        // "Es Devengo" va en el MEDIO a propósito: los dos únicos consumidores de esta SIFT
        // (UpdateTotals y CalcNetoDesdeBD en Cod50014) filtran siempre por los tres campos.
        // Con "Es Devengo" fuera de la clave, ese filtro impedía usar el índice acumulado y
        // ambos degradaban a suma con escaneo — CalcNetoDesdeBD, además, dentro del loop de
        // convergencia de Grossing Up. Si agregás un CalcSums que filtre No. Liquidación +
        // Tipo Concepto SIN "Es Devengo", no va a poder usar esta SIFT.
        key(K2; "No. Liquidación", "Es Devengo", "Tipo Concepto")
        {
            SumIndexFields = Importe;
        }
        key(K3; "No. Liquidación", "Orden Cálculo", "No. Línea")
        {
        }
        // Se conservan las claves de lectura y el contrato de CalcSums, sin mantener las vistas
        // acumuladas por empleado en cada INSERT/DELETE. Los lectores anual/período suman en
        // memoria; K2 sigue manteniendo la SIFT usada por los totales y el neto de grossing-up.
        key(K4; "No. Empleado", "Fecha Liquidación", "Tipo Concepto")
        {
            SumIndexFields = Importe;
            MaintainSIFTIndex = false;
        }
        key(K5; "No. Empleado", "Cód. Período", "Tipo Concepto")
        {
            SumIndexFields = Importe;
            MaintainSIFTIndex = false;
        }
        // Consultas de configuración: "¿esta versión del concepto ya se usó, y después de qué
        // fecha?". La usa Concepto Liquidación para no dejar cerrar una vigencia por delante de una
        // liquidación que ya la aplicó. Estado queda FUERA de la clave a propósito: se filtra con un
        // <> y, metido en el medio, cortaría el uso del índice para el rango de fechas — el mismo
        // problema que describe el comentario de K2.
        key(K6; "Cód. Concepto", "Vigencia Concepto", "Fecha Liquidación")
        {
        }
        // Lecturas por concepto + empleado + fecha: el ledger de francos (Cod50053) y los acumulados
        // por concepto. Reemplaza al missing_index_5916_5915, que SQL había armado con CUATRO columnas
        // de clave y las 30 restantes en INCLUDE: una copia entera de la tabla (357 MB contra 275 del
        // clustered), que cada Insert y cada Delete del cálculo tenía que mantener. Estado queda
        // afuera —se filtra con un <> y en el medio cortaría el rango de fechas—; Cantidad e Importe
        // viajan incluidos porque son lo único que esas lecturas traen.
        key(K7; "Cód. Concepto", "No. Empleado", "Fecha Liquidación")
        {
            IncludedFields = Cantidad, Importe;
        }
    }

    trigger OnDelete()
    var
        Det: Record "Detalle Variable Línea Liq.";
    begin
        Det.SetRange("No. Liquidación", "No. Liquidación");
        Det.SetRange("No. Línea", "No. Línea");
        Det.DeleteAll();
    end;

    /// <summary>
    /// La unidad concordada con la cantidad: "1 DIA", "9 DIAS", "35.676 KN".
    /// </summary>
    /// <remarks>
    /// Es presentación, no dato: la unidad se guarda como está configurada en el concepto —siempre en
    /// singular— y el plural se arma al mostrarla. Guardar el plural en la línea obligaría a
    /// reescribirla cada vez que cambia la cantidad, y dejaría el dato dependiendo de un número.
    ///
    /// El plural sale de "Plural (recibo)" en la unidad de medida cuando está cargado; si no, se
    /// deriva. Las reglas de derivación, en orden: una cantidad de 1 (o de -1) no pluraliza; una
    /// unidad SIN VOCALES es un símbolo de medida y es invariable —KN, KB, TN, KG no llevan ese—; el
    /// resto sigue el español: termina en vocal, se le agrega S; termina en consonante, ES. Así
    /// DIA→DIAS, HORA→HORAS, AÑO→AÑOS, MES→MESES, y KN se queda como está.
    ///
    /// La derivación se mantiene y NO se reemplazó por el campo: si el plural fuera obligatorio,
    /// cada unidad nueva empezaría mostrándose vacía en el recibo hasta que alguien se acuerde de
    /// cargarlo. El campo es la excepción, no el mecanismo.
    /// </remarks>
    procedure UnidadParaMostrar(): Text[20]
    var
        UdM: Record "Unit of Measure";
        Unidad: Text[20];
        Ultima: Text[1];
    begin
        Unidad := "Unidad Cantidad";
        if Unidad = '' then
            exit('');
        if Abs(Cantidad) = 1 then
            exit(Unidad);

        if UdM.Get("Unidad Cantidad") then
            if UdM."Plural Liq." <> '' then
                exit(UdM."Plural Liq.");

        if not TieneVocal(Unidad) then
            exit(Unidad);

        Ultima := CopyStr(Unidad, StrLen(Unidad), 1);
        if TieneVocal(Ultima) then
            exit(Unidad + 'S');
        exit(Unidad + 'ES');
    end;

    local procedure TieneVocal(Texto: Text): Boolean
    var
        i: Integer;
    begin
        for i := 1 to StrLen(Texto) do
            if UpperCase(CopyStr(Texto, i, 1)) in ['A', 'E', 'I', 'O', 'U', 'Á', 'É', 'Í', 'Ó', 'Ú'] then
                exit(true);
        exit(false);
    end;
}
