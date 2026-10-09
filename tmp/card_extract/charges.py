import pathlib,re,json,collections
o=pathlib.Path(__file__).parent
d=json.loads((o/'data.json').read_text(encoding='utf-8'))
money=re.compile(r'-?\d[\d.]*,\d{2}-?')
def num(s):return float(s.replace('.','').replace(',','.').strip('-'))*(-1 if '-' in s else 1)
charges=[]
for a in d['audit']:
 if a[4].startswith('Duplicado'):continue
 f=o/(pathlib.Path(a[0]).stem+'.txt');name=f.stem
 bank=next(b for b in ['BBVA','Santander','Galicia','BNA','Supervielle'] if b in name)
 if bank=='Galicia' and 'MAS' in name.upper():bank='Galicia Más'
 card='Visa' if 'VISA' in name else 'Amex' if 'AMEX' in name else 'Master'
 for ln,line in enumerate(f.read_text(encoding='utf-8').splitlines(),1):
  st=line.strip()
  st=re.sub(r'^(?:\d{4}-\d{2}-\d{2}|\d{2}[-./][A-Za-zÁá0-9]{2,3}[-./]\d{2})\s+','',st)
  st=re.sub(r'^(?:\d{2}\s+[A-Za-z.]+\s+)?\d{2}\s+','',st)
  if re.match(r'(?:INTERES|PUNIT\.|INT\.|INTER\.)',st,re.I):cat='Intereses'
  elif re.match(r'(?:COMISION|COMIS\.|COM\.|CARGO\s|MANTENIMIENTO)',st,re.I):cat='Comisiones'
  elif re.match(r'(?:DB[ .]+IVA|IVA\b|I\.V\.A\.|IIBB|PERCEP|PERC\b|DB\.RG|CR\.RG|DEV[ .]*(?:IMP|PER)|IMPUESTO|SELLOS)',st,re.I):cat='Impuestos'
  else:continue
  if not re.search(r'\d,\d{2}-?\s*_*\s*$',st):continue
  ms=[m for m in money.finditer(line) if m.start()>=45]
  if not ms:continue
  if len(ms)>1 and num(ms[-1][0])==0:ms=ms[-2:-1]
  else:ms=ms[-1:]
  m=ms[0];value=num(m[0])
  if not value:continue
  desc=line[:m.start()].strip()
  desc=re.sub(r'^(?:\d{4}-\d{2}-\d{2}|\d{2}[-./][A-Za-zÁá0-9]{2,3}[-./]\d{2})\s+','',desc)
  desc=re.sub(r'^(?:\d{2}\s+[A-Za-z.]+\s+)?\d{2}\s+','',desc)
  desc=re.sub(r'\s+-?(?:U\$S|\$)\s*$','',desc)
  # Prefix minus is separate from the amount in the newer Santander layout.
  if re.search(r'-\$\s*$',line[:m.start()]):value=-abs(value)
  row=[bank,card,'Cargo del resumen (sin asignar)',int(name[5:7]),int(name[:4]),cat,'No',desc,'ARS',value,a[0],ln]
  charges.append(row)
d['rows']=[r for r in d['rows'] if r[2]!='Cargo del resumen (sin asignar)']+charges
d['charges']=charges
(o/'data_charges.json').write_text(json.dumps(d,ensure_ascii=False),encoding='utf-8')
print('Cargos:',len(charges),collections.Counter(r[5] for r in charges))
for r in charges:print(r[10],r[5],r[7],r[9])
