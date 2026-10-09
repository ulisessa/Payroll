import fs from 'node:fs/promises';
import {Workbook,SpreadsheetFile} from '@oai/artifact-tool';
const d=JSON.parse(await fs.readFile('tmp/card_extract/data_charges.json','utf8'));
const wb=Workbook.create();
const s=wb.worksheets.add('Gastos');
const extra=[['Transporte',/AUTOPIST|AUBASA|CVSA|AUSA|SUBE|TEMBICI/i],['Supermercado y alimentos',/DIA TIENDA|MARKET CABALLITO|CARNICER|ALMACEN/i],['Seguros',/INTEGRITY/i],['Suscripciones digitales',/TIDAL|CURSOR|LINKEDIN|DREAMHOST/i],['Restaurantes y delivery',/COFFEE|GIARDINO|MIGUSTO|JUVENIL|COMBOKING|COMBOWHOP|PASTELERIA|RAPANUI|CUCINA|CERVECER/i],['Indumentaria y accesorios',/MOOV|TUCCI|KEVINGSTON|MACCHI|NAKA OUTDOORS|SOLO DEPORTES/i],['Perfumería y cosmética',/LANCOME|LIDHERMA|SKIN HOUSE|PURASOAP/i],['Hogar',/ARREDO|PINTURER|^REX /i],['Deportes y clubes',/BOCAJUNIORS|GFITNESS|FITNESSC|ATLASCABALLITO/i],['Mascotas',/CATYCAN|PERRON|VIDARURAL/i],['Libros',/YENNY/i]];
for(const r of d.rows){
 if(/^\d/.test(r[2])) r[2]='No identificado (tarjeta terminada en '+r[2].slice(-4)+')';
 if(r[2]==='L Sasovsky Linari')r[2]='L. Sasovsky Linari';
 if(r[2]==='Hil Sasovsky Linari')r[2]='HIL Sasovsky Linari';
 if(r[2]==='L. Sasovsky Linari')r[2]='HIL Sasovsky Linari';
 if(r[2]==='Alejandra Linari' || r[2]==='Daniela Linari' || r[2]==='No identificado (tarjeta terminada en 0384)')r[2]='Daniela Linari';
 if(r[2]==='Tom Sasovsky Linari' || r[2]==='No identificado (tarjeta terminada en 2706)')r[2]='Tomás Sasovsky Linari';
 if(/integrity/i.test(r[7]))r[2]='Tomás Sasovsky Linari';
 if(r[5]==='Sin identificar'){const c=extra.find(([c,p])=>p.test(r[7]));if(c)r[5]=c[0];}
}
const headers=['Banco','Tarjeta','Quién hizo el gasto','Mes','Año','Categoría del gasto','Gasto en cuotas','Descripción del gasto en la tarjeta','Moneda del gasto','Importe','','Archivo de origen'];
const data=d.rows.map(r=>[...r.slice(0,10),'',r[10]]);
s.getRange(`A1:L${data.length+1}`).values=[headers,...data];
s.tables.add(`A1:J${data.length+1}`,true,'GastosTarjetas');
s.freezePanes.freezeRows(1);s.showGridLines=false;
s.getRange(`A1:L${data.length+1}`).format.font={name:'Arial',size:10};
s.getRange('A1:J1').format={fill:'#23364D',font:{color:'#FFFFFF',bold:true},wrapText:true,rowHeight:42};
const widths=[17,10,39,7,9,29,18,70,16,18,3,52];
widths.forEach((w,i)=>s.getRangeByIndexes(0,i,data.length+1,1).format.columnWidth=w);
s.getRange(`J2:J${data.length+1}`).setNumberFormat('#,##0.00;[Red]-#,##0.00');
s.getRange(`A2:L${data.length+1}`).format.rowHeight=22;
s.getRange('L1').format.font={bold:true};
const a=wb.worksheets.add('Control de resúmenes');a.showGridLines=false;
a.getRange('A1').values=[['Control de los '+d.audit.length+' archivos recibidos']];
a.getRange('A2').values=[['Mes y año: período del resumen según el nombre del archivo.']];
a.getRange('A3').values=[['Importe: consumo o cuota facturada. Moneda: ARS o USD según la facturación; no se convierten monedas.']];
a.getRange('A4').values=[['Incluye consumos, impuestos, intereses y comisiones. Devoluciones con importe negativo. Excluye pagos y saldos anteriores.']];
a.getRange('A5').values=[['Categorías estimadas por comercio. Personas unificadas según tus indicaciones: L. = HIL; Alejandra = Daniela; tarjeta 0384 = Daniela; tarjeta 2706 = Tomás.']];
a.getRange('A6').values=[['Dos archivos duplicados excluidos. Cargos generales del resumen sin asignación personal; el control de consumos excluye estos cargos.']];
const ah=['Archivo','Filas de consumos','Consumos ARS','Consumos USD','Tratamiento','Total fuente ARS','Total fuente USD','Diferencia ARS','Diferencia USD','Cargos agregados','Cargos netos ARS'];
const audit=d.audit.map(r=>{const charges=d.charges.filter(c=>c[10]===r[0]);return [...r,charges.length,Math.round(charges.reduce((v,c)=>v+c[9],0)*100)/100];});
a.getRange(`A8:K${8+d.audit.length}`).values=[ah,...audit];
a.tables.add(`A8:K${8+d.audit.length}`,true,'ControlResumenes');
a.getRange(`A1:I${8+d.audit.length}`).format.font={name:'Arial',size:10};
a.getRange('A1').format.font={name:'Arial',size:14,bold:true};
a.getRange('A8:I8').format={fill:'#23364D',font:{color:'#FFFFFF',bold:true},wrapText:true,rowHeight:40};
const aw=[55,17,19,19,60,19,19,19,19,18,22];aw.forEach((w,i)=>a.getRangeByIndexes(7,i,d.audit.length+1,1).format.columnWidth=w);
a.getRange('J8:K8').format={fill:'#23364D',font:{name:'Arial',size:10,color:'#FFFFFF',bold:true},wrapText:true,rowHeight:40};
a.getRange(`K9:K${8+d.audit.length}`).setNumberFormat('#,##0.00');
a.getRange(`C9:D${8+d.audit.length}`).setNumberFormat('#,##0.00');a.getRange(`F9:I${8+d.audit.length}`).setNumberFormat('#,##0.00');
a.freezePanes.freezeRows(8);
wb.recalculate();
console.log((await wb.inspect({kind:'table',range:'Gastos!A1:J4',tableMaxRows:4,tableMaxCols:10,maxChars:2000})).ndjson);
const out='outputs/01a10c8b-c821-7730-ad1f-cb15d728273f';await fs.mkdir(out,{recursive:true});
for(const [name,range] of [['Gastos','A1:J8'],['Control de resúmenes','A8:I15']]){
 const blob=await wb.render({sheetName:name,range,scale:1,format:'png'});await fs.writeFile(`tmp/card_extract/${name==='Gastos'?'gastos':'control'}.png`,new Uint8Array(await blob.arrayBuffer()));
}
await (await SpreadsheetFile.exportXlsx(wb)).save(out+'/Gastos_tarjetas_2026_actualizado_BNA.xlsx');
console.log(JSON.stringify({rows:d.rows.length,unknown:d.rows.filter(r=>r[5]==='Sin identificar').length}));
