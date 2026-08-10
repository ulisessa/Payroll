namespace UAS.Payroll;

using System.Upgrade;

codeunit 50065 "Estado Fecha Fin Upgrade"
{
    Subtype = Upgrade;

    // Materializa la Fecha Fin del historial que se cargó mientras el fin era derivado (el día
    // anterior al inicio del estado siguiente). Sin esto, las filas viejas quedarían con Fecha Fin en
    // blanco: FechaFinEfectiva las seguiría resolviendo bien por derivación, pero la columna se vería
    // vacía en la grilla y no se podría filtrar ni reportar por ella.
    //
    // Se corre una sola vez por empresa y es idempotente: solo escribe donde la fecha calculada
    // difiere de la guardada, y el último estado de cada entidad queda abierto (en blanco).

    trigger OnUpgradePerCompany()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if UpgradeTag.HasUpgradeTag(TagFechaFinEstados()) then
            exit;
        CompletarFechasFin();
        UpgradeTag.SetUpgradeTag(TagFechaFinEstados());
    end;

    local procedure CompletarFechasFin()
    var
        Estado: Record "Estado Empleado";
        Siguiente: Record "Estado Empleado";
        NuevoFin: Date;
    begin
        Estado.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
        if not Estado.FindSet() then
            exit;
        repeat
            Siguiente.Reset();
            Siguiente.SetCurrentKey("Tipo Entidad", "No. Empleado", "Fecha Inicio");
            Siguiente.SetRange("Tipo Entidad", Estado."Tipo Entidad");
            Siguiente.SetRange("No. Empleado", Estado."No. Empleado");
            Siguiente.SetFilter("Fecha Inicio", '>%1', Estado."Fecha Inicio");
            Siguiente.SetFilter("No. Mov.", '<>%1', Estado."No. Mov.");
            if Siguiente.FindFirst() then
                NuevoFin := Siguiente."Fecha Inicio" - 1
            else
                // El último estado de cada entidad es el vigente: queda abierto.
                NuevoFin := 0D;

            if Estado."Fecha Fin" <> NuevoFin then begin
                Estado."Fecha Fin" := NuevoFin;
                // Modify sin disparar el trigger: la sincronización de contigüidad es justamente lo
                // que se está reconstruyendo acá, y correrla por fila haría trabajo cuadrático.
                Estado.Modify();
            end;
        until Estado.Next() = 0;
    end;

    local procedure TagFechaFinEstados(): Code[250]
    begin
        exit('UAS-Payroll-EstadoEmpleado-FechaFin-20260807');
    end;
}
