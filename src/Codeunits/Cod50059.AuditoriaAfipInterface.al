namespace UAS.Payroll;

codeunit 50059 "Auditoria AFIP Interface"
{
    // Registra el import/proceso de SIRADIG en el mismo esquema de trazabilidad que usan las
    // demás interfaces con AFIP del sistema ("AFIP Interface Register" / "AFIP Interface
    // Register detail", de la extensión Grupo Arbumasa). Acá no hay una llamada real a un web
    // service de AFIP: el "Archivo" del registro es el XML SIRADIG importado, y cada detalle
    // registra un campo insertado/modificado a partir de esa importación (deducciones, cargas
    // de familia). Ninguna de las dos tablas usa AutoIncrement en su clave, por eso se numera
    // a mano (con LockTable) igual que se ve que exige su diseño.

    procedure CrearRegistro(Servicio: Text[30]; Origen: Text[100]; Destino: Text[100]; UniqueId: Text[30]; var XmlContent: Text) EntryNo: Integer
    var
        Registro: Record "AFIP Interface Register";
        OutStr: OutStream;
    begin
        Registro.LockTable();
        if Registro.FindLast() then
            Registro."Entry no." += 1
        else
            Registro."Entry no." := 1;

        Registro.Service := Servicio;
        Registro.Source := Origen;
        Registro.Destination := Destino;
        Registro.UniqueID := UniqueId;
        Registro.GenerationTime := CurrentDateTime();
        Registro.File.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(XmlContent);
        Registro.Insert();

        exit(Registro."Entry no.");
    end;

    // Crea el registro de cabecera para UNA importación SIRADIG (Servicio='SIRADIG', Archivo=XML
    // importado) y deja el Entry no. resultante en "AFIP Register Entry No." del propio registro
    // de importación, para poder engancharle detalles más adelante (incluso en otra sesión, si el
    // procesamiento no es automático).
    procedure RegistrarImportacionSiradig(var RegistroImportacion: Record "Importación SIRADIG"; var XmlContent: Text)
    var
        UniqueId: Text[30];
    begin
        UniqueId := CopyStr(StrSubstNo('%1-%2', RegistroImportacion."Período", RegistroImportacion."Nro. Presentación"), 1, 30);
        RegistroImportacion."AFIP Register Entry No." :=
            CrearRegistro('SIRADIG', RegistroImportacion."Archivo Origen", RegistroImportacion."CUIL Empleado", UniqueId, XmlContent);
    end;

    procedure RegistrarDetalle(RegisterEntryNo: Integer; TableNo: Integer; FieldNo: Integer; TipoCambio: Option Insertion,Modification,Deletion,"No change"; OldValue: Text[250]; NewValue: Text[250]; ClaveRegistro: Text[250])
    var
        Detalle: Record "AFIP Interface Register detail";
    begin
        if RegisterEntryNo = 0 then
            exit;

        Detalle.LockTable();
        if Detalle.FindLast() then
            Detalle."Entry no." += 1
        else
            Detalle."Entry no." := 1;

        Detalle."Date and Time" := CurrentDateTime();
        Detalle.Time := Time;
        Detalle."User ID" := CopyStr(UserId(), 1, MaxStrLen(Detalle."User ID"));
        Detalle."Table No." := TableNo;
        Detalle."Field No." := FieldNo;
        Detalle."Type of Change" := TipoCambio;
        Detalle."Old Value" := OldValue;
        Detalle."New Value" := NewValue;
        Detalle."Clave registro" := ClaveRegistro;
        Detalle."Register entry no." := RegisterEntryNo;
        Detalle.Insert();
    end;
}
