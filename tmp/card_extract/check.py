import json,pathlib,re,collections
o=pathlib.Path(__file__).parent; d=json.loads((o/'data.json').read_text(encoding='utf-8'))
money=re.compile(r'-?\d[\d.]*,\d{2}-?')
def n(s):return float(s.replace('.','').replace(',','.').strip('-'))*(-1 if '-' in s else 1)
for a in d['audit']:
 t=(o/(pathlib.Path(a[0]).stem+'.txt')).read_text(encoding='utf-8')
 lines=[l for l in t.splitlines() if re.search(r'Total Consumos de\s|TOTAL TITULAR|Subtotal de',l,re.I)]
 if 'BBVA' in a[0]:lines=lines[len(lines)//2:] if len(lines)>1 else lines
 controls=[list(money.finditer(l))[-2:] for l in lines]
 expected=[round(sum(n(c[i][0]) for c in controls if len(c)==2),2) for i in (0,1)]
 if not lines and 'MAST' in a[0]:
  m=re.search(r'TOTAL CONSUMOS DEL MES\s+([\d.,]+)\s+([\d.,]+)',t)
  if m:expected=[n(m[1]),n(m[2])]
 a.extend(expected)
 a.extend([round(a[2]-expected[0],2),round(a[3]-expected[1],2)])
 if a[-2:]!=[0,0]: print(a)
(o/'data.json').write_text(json.dumps(d,ensure_ascii=False),encoding='utf-8')

