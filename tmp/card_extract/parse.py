import pathlib,re,json,collections,hashlib
o=pathlib.Path(__file__).parent
money=re.compile(r'-?\d[\d.]*,\d{2}-?')
rows=[]; audit=[]; seen={}
def num(s): return float(s.replace('.','').replace(',','.').strip('-'))*(-1 if '-' in s else 1)
def category(s):
 s=s.upper()
 rules=[('Impuestos',r'IVA |IIBB|PERCEP|DB.RG|RG 4815|RG 5617|SELLOS'),('Intereses y comisiones',r'INTERES|COMISION|COMIS\.|CARGO|MANTENIMIENTO'),('Reintegros y ajustes',r'BONIF|REINTEGRO|DEVOL|DEV |CR\.RG'),('Transporte',r'EMOVA|SUBTE|UBER|CABIFY|PEAJE'),('Combustible',r'YPF|SHELL|AXION|ESTACION DE SERV'),('Seguros',r'FEDERACION|ITURAN|SEGURO|PATRONAL'),('Servicios y comunicaciones',r'PERSFLOW|PERSONAL|CLARO|MOVISTAR|TELECENTRO|EDENOR|EDESUR|METROGAS'),('Suscripciones digitales',r'GOOGLE|YOUTUBE|APPLE.COM|NETFLIX|SPOTIFY|AUDIBLE|AMAZON ?PRIME|AMAZONPRIME|HBO|MERPAGO\*MAX|RAPPI PRO|PEDIDOSYA PLUS|MERPAGO\*MELI'),('Salud y farmacia',r'FARMACITY|FARMACIA|DR.AHORRO|GALENO|OSDE|SWISS MED'),('Supermercado y alimentos',r'COTO|DISCO|CARREFOUR|JUMBO|EXPRESS RIVADAVIA|MERCADO RURAL|SUPER USA|CLAMALAC|DIA %'),('Restaurantes y delivery',r'RAPPI|PEDIDOSYA|PROPINA|CAFE|SUSHI|PIZZERIA|RESTAUR|MOLLY|OTERO|MCDONALD|BURGER|LUCCIANO|KINGDEPOLLO|BALDEDEPAPAS|SANDWICH|LA VACA|CALAPOP'),('Indumentaria y accesorios',r'GRIMOLDI|LACOSTE|EQUUS|JUANITA|DECATHLON|ZARA|ADIDAS|NIKE|TIENDA NOVA'),('Perfumería y cosmética',r'JULERIAQUE|ROUGE|PERFUM'),('Viajes',r'SMILES|AEROLINE|LATAM|FLYBONDI|BOOKING|AIRBNB|HOTEL'),('Deportes y clubes',r'BOCA JRS|GOLDEN ?BIKE|SPORT|CLUB'),('Entretenimiento',r'FESTIVAL|CINE|HOYTS|SHOW|TICKET|PROM.CLU'),('Hogar',r'PIROSOL|STANLEY|FRAVEGA|EASY|SODIMAC'),('Compras en línea',r'MERCADOLIBRE|AMAZON MKTPL|IMPORTADOR')]
 return next((c for c,p in rules if re.search(p,s)),'Sin identificar')
def person(s):
 s=s.upper().strip(' *')
 if 'ULISES' in s:return 'Ulises Andrés Sasovsky'
 if 'ALEJANDRA' in s:return 'Alejandra Linari'
 if 'LUCIA' in s or 'LUCÍA' in s:return 'Lucía Sasovsky Linari'
 if 'TOM' in s:return 'Tom Sasovsky Linari'
 return s.title() or 'No identificado'
for f in sorted(o.glob('2026-*.txt')):
 name=f.stem; bank=next((b for b in ['BBVA','Santander','Galicia','BNA','Supervielle'] if b in name),'?')
 if bank=='Galicia' and ('MAS' in name.upper()):bank='Galicia Más'
 card='Visa' if 'VISA' in name else 'Amex' if 'AMEX' in name else 'Master'
 month=int(name[5:7]); year=int(name[:4]); local=[]; pending=[]; holder='Ulises Andrés Sasovsky'; active=False
 text=f.read_text(encoding='utf-8')
 for ln,line in enumerate(text.splitlines(),1):
  st=line.strip()
  if card=='Master' and bank=='Galicia Más' and st.startswith('SUBTOTAL'):
   pending=[]
  hm=re.search(r'^Consumos (.+)',st,re.I)
  if hm:holder=person(hm[1]);active=True
  tm=re.search(r'(?:Total Consumos de\s|TOTAL TITULAR\s+|TOTAL ADICIONAL DE\s+)(.+?)(?=\s+-?\d[\d.]*,\d{2})',st,re.I)
  if tm:
   who=person(tm[1])
   for r in pending:r[2]=who
   pending=[];active=False
  if re.search(r'DETALLE DEL (?:CONSUMO|MES)|COMPRAS DEL MES|^Movimientos$|^CUOTA DEL MES|DEBITOS AUTOMATICOS',st):active=True
  datepat=r'^\s*(?:\d{2}[-.][A-Za-zÁá]{3}[-.]\d{2}|\d{2}[-.]\d{2}[-.]\d{2}|\d{4}-\d{2}-\d{2})\s+'
  if bank=='Santander':datepat=r'^\s*(?:\d{2}\s+[A-Za-z.]+\s+)?\d{2}\s+'
  dated=re.match(datepat,line)
  if not dated:continue
  ms=[m for m in money.finditer(line) if m.start()>=53]
  if not ms:continue
  if len(ms)>1 and num(ms[-1][0])==0:ms=ms[-2:-1]
  else:ms=ms[-1:]
  prefix=line[:ms[0].start()].strip()
  if re.search(r'SU PAGO|SALDO|PAGO MIN|CIERRE|VENCIMIENTO|LIMITE|LÍMITE',prefix,re.I):continue
  # Santander date prefix varies with month changes.
  rawdesc=prefix[dated.end()-len(line)+len(line.lstrip()):] if False else line[dated.end():ms[0].start()].strip()
  hascoupon=bool(re.search(r'^\d{5,8}[KEF*]?\s+|\s+\d{5,8}\s*$',rawdesc))
  fiscal=bool(re.match(r'(?:DB\.|CR\.|IVA |IIBB|PERCEP|INTERES|COMIS|BONIF|DEV[ .]|IMPUESTO|SELLOS)',rawdesc,re.I))
  if not hascoupon and not fiscal:continue
  if fiscal:continue
  desc=rawdesc
  desc=re.sub(r'^\d{5,8}[KEF*]?\s+(?:[KEF*]\s+)?','',desc)
  desc=re.sub(r'^[KEF*]\s+','',desc)
  desc=re.sub(r'\s+\d{5,8}\s*$','',desc).strip()
  if not desc:continue
  # Ignore prose/date rows outside transaction sections; permit explicit tax rows.
  quota=re.search(r'(?:C\.\s*)?(\d{2})/(\d{2})',desc)
  # Subscription billing month is not a purchase installment.
  q='Sí ('+quota[1]+'/'+quota[2]+')' if quota and (int(quota[1])<=int(quota[2]) and int(quota[2])<=24) else 'No'
  for m in ms:
   value=num(m[0])
   if value==0:continue
   currency='USD' if m.start()>=68 else 'ARS'
   row=[bank,card,holder,month,year,category(desc),q,desc,currency,value,name+'.pdf',ln]
  local.append(row);pending.append(row)
 if bank=='Santander' and 'Movimientos de ' in text:
  local=[]; in_moves=False
  for ln,line in enumerate(text.splitlines(),1):
   st=line.strip()
   h=re.match(r'Movimientos de (.+)',st)
   if h:holder=person(h[1]);in_moves=True;continue
   if st.startswith('Subtotal de ') or st.startswith('Impuestos,'):in_moves=False
   if not in_moves:continue
   m=re.search(r'(-?)(?:U\$S|\$)\s*(-?\d[\d.]*,\d{2})\s*$',st)
   if not m:continue
   pref=st[:m.start()].strip()
   if not re.search(r'\d{6}\s*$',pref):continue
   desc=re.sub(r'^\d{2}/\d{2}/\d{2}\s+','',pref)
   desc=re.sub(r'\s+\d{6}\s*$','',desc)
   q=re.search(r'(\d+) de (\d+)',desc)
   quota='Sí ('+q[1]+'/'+q[2]+')' if q else 'No'
   value=num(m[2])*(-1 if m[1]=='-' else 1)
   local.append([bank,card,holder,month,year,category(desc),quota,desc,'USD' if 'U$S' in m[0] else 'ARS',value,name+'.pdf',ln])
 sig=json.dumps([r[:10] for r in local],ensure_ascii=False,sort_keys=True)
 duplicate=seen.get(sig) if local else None
 if not duplicate:rows.extend(local);seen[sig]=name
 audit.append([name+'.pdf',len(local),round(sum(r[9] for r in local if r[8]=='ARS'),2),round(sum(r[9] for r in local if r[8]=='USD'),2),('Duplicado de '+duplicate) if duplicate else 'Incluido'])
o.joinpath('data.json').write_text(json.dumps({'rows':rows,'audit':audit},ensure_ascii=False),encoding='utf-8')
print('filas',len(rows),'resúmenes',len(audit));print(json.dumps(audit,ensure_ascii=False))

