namespace UAS.Payroll;

/// <summary>
/// Materializa la plantilla de atributos de una clase sobre una entidad concreta.
/// </summary>
/// <remarks>
/// "Plantilla" no es una tabla nueva: es el conjunto de tipos de atributo obligatorios de una clase.
/// Definir la clase ya define qué se espera de cada entidad que la tenga; esto solo crea las filas
/// vacías para que quien carga vea qué falta en vez de tener que acordarse.
///
/// Es idempotente: no toca ningún atributo que ya exista para la entidad, ni siquiera si está vacío.
/// Una asignación existente puede tener vigencias, historial y valores ya usados en liquidaciones.
/// </remarks>
codeunit 50073 "Plantilla Atributos Liq."
{
    Access = Public;

    /// <summary>
    /// Crea los atributos obligatorios que le falten a la entidad, según su clase.
    /// Devuelve cuántos creó.
    /// </summary>
    procedure Aplicar(TipoEntidad: Enum "Tipo Entidad Estado"; CodEntidad: Code[20]; CodClase: Code[20]; FechaDesde: Date) Creados: Integer
    var
        TipoAtr: Record "Tipo Atributo Liq.";
    begin
        if (CodEntidad = '') or (CodClase = '') then
            exit(0);
        if FechaDesde = 0D then
            FechaDesde := WorkDate();

        TipoAtr.SetRange("Cód. Clase", CodClase);
        TipoAtr.SetRange(Obligatorio, true);
        if not TipoAtr.FindSet() then
            exit(0);
        repeat
            Creados += CrearSiFalta(TipoEntidad, CodEntidad, TipoAtr.Código, FechaDesde);
        until TipoAtr.Next() = 0;
    end;

    /// <summary>Tipos obligatorios de la clase que la entidad todavía no tiene.</summary>
    procedure ContarFaltantes(TipoEntidad: Enum "Tipo Entidad Estado"; CodEntidad: Code[20]; CodClase: Code[20]) Faltan: Integer
    var
        TipoAtr: Record "Tipo Atributo Liq.";
        Atributo: Record "Atributo Entidad Liq.";
    begin
        if (CodEntidad = '') or (CodClase = '') then
            exit(0);

        TipoAtr.SetRange("Cód. Clase", CodClase);
        TipoAtr.SetRange(Obligatorio, true);
        if not TipoAtr.FindSet() then
            exit(0);
        repeat
            Atributo.SetRange("Tipo Entidad", TipoEntidad);
            Atributo.SetRange("Cód. Entidad", CodEntidad);
            Atributo.SetRange("Cód. Tipo Atributo", TipoAtr.Código);
            if Atributo.IsEmpty() then
                Faltan += 1;
        until TipoAtr.Next() = 0;
    end;

    local procedure CrearSiFalta(TipoEntidad: Enum "Tipo Entidad Estado"; CodEntidad: Code[20]; CodTipoAtr: Code[20]; FechaDesde: Date): Integer
    var
        Atributo: Record "Atributo Entidad Liq.";
    begin
        // Cualquier vigencia existente cuenta como "ya lo tiene": la plantilla propone lo que falta,
        // no reabre lo que alguien ya definió con su propia historia.
        Atributo.SetRange("Tipo Entidad", TipoEntidad);
        Atributo.SetRange("Cód. Entidad", CodEntidad);
        Atributo.SetRange("Cód. Tipo Atributo", CodTipoAtr);
        if not Atributo.IsEmpty() then
            exit(0);

        Atributo.Init();
        Atributo."Tipo Entidad" := TipoEntidad;
        Atributo."Cód. Entidad" := CodEntidad;
        Atributo."Cód. Tipo Atributo" := CodTipoAtr;
        Atributo."Vigencia Desde" := FechaDesde;
        Atributo.Insert(true);
        exit(1);
    end;
}
