namespace UAS.Payroll;

codeunit 50049 "Install Parámetro Base"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    begin
        BackfillParametroBase();
    end;

    local procedure BackfillParametroBase()
    var
        ParamVig: Record "Parámetro Vigente";
        Param: Record "Parámetro";
        CodList: List of [Code[50]];
        VigList: List of [Date];
        BaseList: List of [Code[20]];
        BestCode: Code[20];
        BestLen: Integer;
        CodParamTxt: Text;
        i: Integer;
    begin
        ParamVig.SetRange("Cód. Parámetro Base", '');
        if not ParamVig.FindSet() then
            exit;
        repeat
            CodParamTxt := ParamVig."Cód. Parámetro";
            BestCode := '';
            BestLen := 0;
            Param.Reset();
            if Param.FindSet() then
                repeat
                    if (StrLen(Param.Código) > BestLen) and
                       ((ParamVig."Cód. Parámetro" = Param.Código) or
                        CodParamTxt.StartsWith(Param.Código + '_'))
                    then begin
                        BestCode := Param.Código;
                        BestLen := StrLen(Param.Código);
                    end;
                until Param.Next() = 0;
            if BestCode <> '' then begin
                CodList.Add(ParamVig."Cód. Parámetro");
                VigList.Add(ParamVig."Vigencia Desde");
                BaseList.Add(BestCode);
            end;
        until ParamVig.Next() = 0;

        for i := 1 to CodList.Count() do
            if ParamVig.Get('', CodList.Get(i), VigList.Get(i)) then
                ParamVig.Rename(BaseList.Get(i), CodList.Get(i), VigList.Get(i));
    end;
}
