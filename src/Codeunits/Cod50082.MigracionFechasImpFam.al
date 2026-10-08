namespace UAS.Payroll;

using System.Upgrade;

codeunit 50082 "Migracion Fechas ImpFam"
{
    Subtype = Upgrade;

    // QUEDÓ SIN EFECTO EL 22/9/2026.
    //
    // Canonizaba en 50000/50001 ("Fecha inicial" / "Fecha final") las fechas que vinieran de los
    // campos de impuesto (50008/50009) y de familiar a cargo (50010/50011), porque se creía que
    // 50000/50001 eran las que el motor leía para decidir una deducción de Ganancias.
    //
    // Esa premisa era el error. "Fecha inicial" es la vigencia del VÍNCULO familiar y está cargada
    // para los 8.315 familiares de la base; aplanar todo ahí hacía que cualquier familiar en la
    // ficha dedujera Ganancias, declarado o no. La deducción la deciden ahora "Fecha alta impuesto"
    // y "Fecha baja impuesto" (50008/50009), que son el par que Meta4 usa —FEC_ALTA_IMP /
    // FEC_BAJA_IMP— y el único que distingue "declarado ante AFIP" de "está en la ficha". Ver
    // CalcDeduccionesGanancias en "Contexto Liquidación".
    //
    // Se conserva la codeunit, vacía, en vez de borrarla: el tag de upgrade ya quedó puesto en los
    // entornos donde llegó a correr, y quitarla dispararía la migración de nuevo en el próximo
    // upgrade de cualquier entorno donde todavía no corrió, reintroduciendo el aplanamiento.

    trigger OnUpgradePerCompany()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if UpgradeTag.HasUpgradeTag(TagMigracionFechasImpFam()) then
            exit;
        UpgradeTag.SetUpgradeTag(TagMigracionFechasImpFam());
    end;

    local procedure TagMigracionFechasImpFam(): Code[250]
    begin
        exit('UAS-Payroll-EmpRelative-MigracionFechasImpFam-50000-20260825');
    end;
}
