import pathlib,json,pdfplumber
d=pathlib.Path('C:/Users/ulises.sasovsky/OneDrive/Documentos/Gastos')
o=pathlib.Path(__file__).parent
status=[]
for f in sorted(d.glob('2026-*')):
 if f.suffix.lower()!='.pdf': continue
 try:
  with pdfplumber.open(f) as pdf:
   pages=[p.extract_text(layout=True) or '' for p in pdf.pages]
  o.joinpath(f.stem+'.txt').write_text('\n'.join(pages),encoding='utf-8')
  status.append([f.name,len(pages),'ok'])
 except Exception as e: status.append([f.name,0,type(e).__name__])
o.joinpath('status.json').write_text(json.dumps(status,ensure_ascii=False),encoding='utf-8')
print(json.dumps(status,ensure_ascii=False))
