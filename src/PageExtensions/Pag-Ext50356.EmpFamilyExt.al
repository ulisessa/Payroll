namespace Payroll.Payroll;

using Microsoft.HumanResources.Employee;

pageextension 50357 EmpFamilyExt extends "Employee Relatives"
{
    layout
    {
        addfirst(Control1)
        {
            field("Employee No."; "Employee No.")
            {
                ApplicationArea = All;
                Visible = false;
                Caption = 'Employee No.';

            }
        }
    }
}
