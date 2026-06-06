namespace UAS.Payroll;

using Microsoft.HumanResources.Setup;

// DEPENDENCIA: Este permission set cubre únicamente los objetos del módulo Payroll (rango 50000-61000).
// Para acceso completo se requieren además los siguientes roles estándar de BC:
//   • Employee / HR Setup  → "D365 HUMAN RES, FULL" o equivalente
//   • Job (Marea)          → "D365 PROJECT MGMT" o equivalente
// Asignar junto a uno de los roles anteriores.
permissionset 50300 "Liq. Pesca - Admin"
{
    Assignable = true;
    Caption = 'Liq. Pesca - Admin';

    Permissions =
        // ── Tables — data access ──
        tabledata "Estado Empleado" = RIMD,
        tabledata "Cód. Estado Empleado" = RIMD,
        tabledata "Convenio Colectivo" = RIMD,
        tabledata "Categoría CCT" = RIMD,
        tabledata "Concepto Liquidación" = RIMD,
        tabledata "Parámetro Vigente" = RIMD,
        tabledata "Personal Proyecto" = RIMD,
        tabledata "Período Liquidación" = RIMD,
        tabledata "Liquidación" = RIMD,
        tabledata "Línea Liquidación" = RIMD,
        tabledata "Tabla Escalonada" = RIMD,
        tabledata "Tabla Escalonada Det." = RIMD,
        tabledata "Fuente Datos Liquidación" = RIMD,
        tabledata "Parámetro" = RIMD,
        tabledata "Fracción Acumulador" = RIMD,
        tabledata "Variable Sistema Liq." = RIMD,
        tabledata "Concepto CCT Vigente" = RIMD,
        tabledata "Incidencia Liquidación" = RIMD,
        tabledata "Ded. Ganancias Vigente" = RIMD,
        tabledata "Ded. Ganancias Empleado" = RIMD,
        tabledata "Detalle Variable Línea Liq." = RIMD,
        tabledata "Resumen Variable Liq." = RIMD,
        tabledata "Human Resources Setup" = RM,
        // ── Tables — schema access ──
        table "Estado Empleado" = X,
        table "Cód. Estado Empleado" = X,
        table "Convenio Colectivo" = X,
        table "Categoría CCT" = X,
        table "Concepto Liquidación" = X,
        table "Parámetro Vigente" = X,
        table "Personal Proyecto" = X,
        table "Período Liquidación" = X,
        table "Liquidación" = X,
        table "Línea Liquidación" = X,
        table "Tabla Escalonada" = X,
        table "Tabla Escalonada Det." = X,
        table "Fuente Datos Liquidación" = X,
        table "Parámetro" = X,
        table "Fracción Acumulador" = X,
        table "Variable Sistema Liq." = X,
        table "Concepto CCT Vigente" = X,
        table "Incidencia Liquidación" = X,
        table "Ded. Ganancias Vigente" = X,
        table "Ded. Ganancias Empleado" = X,
        table "Detalle Variable Línea Liq." = X,
        table "Resumen Variable Liq." = X,
        // ── Codeunits ──
        codeunit "Motor Liquidación" = X,
        codeunit "Evaluador Fórmula" = X,
        codeunit "Contexto Liquidación" = X,
        codeunit "Gestión Estado Empleado" = X,
        codeunit "Proceso Liq. Por Lotes" = X,
        codeunit "Gestión Liquidación" = X,
        // ── Pages ──
        page "Lista Liquidaciones" = X,
        page "Ficha Liquidación" = X,
        page "Líneas Liquidación" = X,
        page "Estados Empleado" = X,
        page "Cód. Estados Empleado" = X,
        page "Nuevo Estado Empleado" = X,
        page "Estado Empleado FactBox" = X,
        page "Convenios Colectivos" = X,
        page "Categorías CCT" = X,
        page "Conceptos Liquidación" = X,
        page "Concepto Liq. Card" = X,
        page "Parámetros" = X,
        page "Parámetro Card" = X,
        page "Parámetro Vigente Subpag" = X,
        page "Parámetro Sufijo Sub" = X,
        page "Parámetros Vigentes" = X,
        page "Personal Proyecto" = X,
        page "Períodos Liquidación" = X,
        page "Tabla Escalonada List" = X,
        page "Tabla Escalonada Card" = X,
        page "Tabla Escalonada Det. Sub" = X,
        page "Fuente Datos Liquidación" = X,
        page "Fuente Datos Card" = X,
        page "Tabla Liq. Lookup" = X,
        page "Campo Liq. Lookup" = X,
        page "Fracción Acumulador Sub" = X,
        page "Variable Sistema Liq." = X,
        page "Variables Liq. Test Sub" = X,
        page "Concepto CCT Sub" = X,
        page "Incidencias Liquidación Sub" = X,
        page "Asistente Fórmula Liq." = X,
        page "Lanzador Liquidaciones" = X,
        page "Detalle Variable Línea Sub" = X,
        page "Variables Cálculo Línea" = X,
        page "Ded. Ganancias Vigente" = X,
        page "Ded. Ganancias Vigente Card" = X,
        page "Ded. Ganancias Empleado Sub" = X,
        page "Payroll Role Center" = X,
        // ── Reports ──
        report "Recibo de Sueldo" = X,
        // ── BC base objects used by extension ──
        page "Human Resources Setup" = X;
}
