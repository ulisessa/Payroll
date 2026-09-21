namespace UAS.Payroll;

using System.Upgrade;
using Microsoft.HumanResources.Employee;

codeunit 50082 "Migracion Fechas ImpFam"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if UpgradeTag.HasUpgradeTag(TagMigracionFechasImpFam()) then
            exit;

        Migrar();
        UpgradeTag.SetUpgradeTag(TagMigracionFechasImpFam());
    end;

    /// <summary>Canoniza las fechas en 50000/50001 y devuelve cuántas filas modificó.</summary>
    /// <remarks>
    /// Pública a propósito. Como codeunit de Upgrade sólo corre en una actualización real de la
    /// extensión: no en una instalación nueva, y tampoco en un publish de RAD, que es como se trabaja
    /// en desarrollo. Sin una forma de dispararla a mano, en el entorno donde se prueba no se ejecuta
    /// nunca y las fechas parecen no haberse migrado.
    ///
    /// Es idempotente: sólo escribe donde el destino está vacío, así que correrla de más no hace daño
    /// y nunca pisa una fecha ya cargada.
    /// </remarks>
    procedure Migrar() Tocadas: Integer
    var
        EmpRel: Record "Employee Relative";
        RecRef: RecordRef;
        Modificado: Boolean;
        FechaAlta: Date;
        FechaBaja: Date;
    begin
        if not EmpRel.FindSet(true) then
            exit;

        repeat
            RecRef.GetTable(EmpRel);
            Modificado := false;

            // Canoniza fecha alta en 50000 ("Fecha inicial"), en ese orden de preferencia: familiar a
            // cargo, impuesto, y por último la nuestra que quedó obsoleta.
            FechaAlta := LeerFecha(RecRef, 50000);
            if FechaAlta = 0D then begin
                FechaAlta := PrimeraFechaNoVacia(
                    LeerFecha(RecRef, 50010),
                    PrimeraFechaNoVacia(LeerFecha(RecRef, 50008), LeerFecha(RecRef, 50211)));
                if FechaAlta <> 0D then
                    Modificado := EscribirFecha(RecRef, 50000, FechaAlta) or Modificado;
            end;

            // Canoniza fecha baja en 50001 ("Fecha final"). Mismo orden.
            FechaBaja := LeerFecha(RecRef, 50001);
            if FechaBaja = 0D then begin
                FechaBaja := PrimeraFechaNoVacia(
                    LeerFecha(RecRef, 50011),
                    PrimeraFechaNoVacia(LeerFecha(RecRef, 50009), LeerFecha(RecRef, 50212)));
                if FechaBaja <> 0D then
                    Modificado := EscribirFecha(RecRef, 50001, FechaBaja) or Modificado;
            end;

            if Modificado then begin
                RecRef.Modify();
                Tocadas += 1;
            end;
        until EmpRel.Next() = 0;
    end;

    local procedure PrimeraFechaNoVacia(Fecha1: Date; Fecha2: Date): Date
    begin
        if Fecha1 <> 0D then
            exit(Fecha1);
        exit(Fecha2);
    end;

    local procedure LeerFecha(var RecRef: RecordRef; FieldNo: Integer): Date
    begin
        if not RecRef.FieldExist(FieldNo) then
            exit(0D);
        exit(FieldRefToDate(RecRef.Field(FieldNo)));
    end;

    local procedure EscribirFecha(var RecRef: RecordRef; FieldNo: Integer; Fecha: Date): Boolean
    var
        FieldVar: FieldRef;
    begin
        if (Fecha = 0D) or (not RecRef.FieldExist(FieldNo)) then
            exit(false);

        FieldVar := RecRef.Field(FieldNo);
        if FieldRefToDate(FieldVar) = Fecha then
            exit(false);

        FieldVar.Value(Fecha);
        exit(true);
    end;

    local procedure FieldRefToDate(FieldVar: FieldRef): Date
    var
        V: Variant;
        Result: Date;
    begin
        V := FieldVar.Value();
        if V.IsDate() then
            Result := V;
        exit(Result);
    end;

    local procedure TagMigracionFechasImpFam(): Code[250]
    begin
        exit('UAS-Payroll-EmpRelative-MigracionFechasImpFam-50000-20260825');
    end;
}
