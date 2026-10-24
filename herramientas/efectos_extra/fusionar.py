"""Fusiona los extras de herramientas/efectos_extra/<id> en los datos generados (efectos_fao_poderes*.lua y juego/arte/fao_efectos) sin necesitar fao-clases-dc.
Uso: python -I -X utf8 herramientas/efectos_extra/fusionar.py id1 id2 ..."""
import re, os, sys, json
RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
src = open(os.path.join(RAIZ, 'herramientas', 'generar_efectos_fao_poderes.py'), encoding='utf-8').read().replace('\nmain()\n', '\n')
G = {'__file__': os.path.join(RAIZ, 'herramientas', 'generar_efectos_fao_poderes.py')}
exec(compile(src, 'gen', 'exec'), G)
IDS = sys.argv[1:]
import shutil
arte = os.path.join(RAIZ, 'juego', 'arte', 'fao_efectos')
newsecs, newdat = {}, {}
for pid in IDS:
    carpeta = os.path.join(RAIZ, 'herramientas', 'efectos_extra', pid)
    j = json.load(open(os.path.join(carpeta, 'efecto.json'), encoding='utf-8'))
    for f in os.listdir(arte):
        if f.startswith(pid + '__'): os.remove(os.path.join(arte, f))
    for nombre, s in j['secuencias'].items():
        clave = '%s__%s' % (pid, nombre)
        destino = os.path.join(arte, clave + '.png')
        shutil.copy(os.path.join(carpeta, s['sheet']), destino)
        vw, vh = G['visible'](destino, s['frames'], s['cell'][0], s['cell'][1])
        newsecs[clave] = (s, vw, vh)
    c = j['composicion']
    capas = []
    for l in c['capas']:
        s0 = newsecs['%s__%s' % (pid, l['s'])][0]
        capa = dict(s='%s__%s' % (pid, l['s']), w=l['w'], t0=round(l['t0'], 4), ms=round(l['ms'], 4), sc=l.get('sc', 1.0), a=l.get('a', 1.0), modo=l.get('modo', 'once'))
        for k in ('t1', 'off', 'giro', 'flip'):
            if k in l: capa[k] = l[k]
        capa['dir'] = False
        capa['mezcla'] = 'add'
        capas.append(capa)
    newdat[pid] = dict(clase=j['clase'], dur=round(c['duracion_s'], 3), golpes=[round(x, 3) for x in c.get('golpes_s', [])], capas=capas)
num, lv = G['num'], G['lua_valor']
# datos de secuencias (cliente)
f = os.path.join(RAIZ, 'juego', 'src', 'presentacion', 'render', 'efectos_fao_poderes_datos.lua')
t = open(f, encoding='utf-8').read().split('\n')
cab = [l for l in t if l.startswith('--')]
lineas = {}
for l in t:
    m = re.match(r'  \["([^"]+)"\] =', l)
    if m and m.group(1).split('__')[0] not in IDS: lineas[m.group(1)] = l
for k, (s, vw, vh) in newsecs.items():
    lineas[k] = '  ["%s"] = { n = %d, w = %d, h = %d, ox = %d, oy = %d, ms = %s, vw = %d, vh = %d, mezcla = "add" },' % (k, s['frames'], s['cell'][0], s['cell'][1], s['origin'][0], s['origin'][1], num(round(s['ms_per_frame'] / 1000, 4)), vw, vh)
open(f, 'w', encoding='utf-8', newline='\n').write('\n'.join(cab + ['return {'] + [lineas[k] for k in sorted(lineas)] + ['}']) + '\n')
# capas por poder (compartido)
f = os.path.join(RAIZ, 'compartido', 'datos', 'efectos_fao_poderes.lua')
t = open(f, encoding='utf-8').read().split('\n')
cab = [l for l in t if l.startswith('--')]
bloques, cur, nombre = {}, None, None
for l in t:
    m = re.match(r'  (\w+) = \{ clase', l)
    if m: nombre, cur = m.group(1), [l]
    elif cur is not None:
        cur.append(l)
        if l == '  } },': bloques[nombre] = cur; cur = None
for pid in IDS: bloques.pop(pid, None)
for pid, d in newdat.items():
    b = ['  %s = { clase = "%s", dur = %s, golpes = %s, capas = {' % (pid, d['clase'], num(d['dur']), lv(d['golpes']))]
    for c in d['capas']: b.append('    { %s },' % ', '.join('%s = %s' % (k, lv(v)) for k, v in c.items()))
    b.append('  } },')
    bloques[pid] = b
out = cab + ['return {'] + [l for k in sorted(bloques) for l in bloques[k]] + ['}']
open(f, 'w', encoding='utf-8', newline='\n').write('\n'.join(out) + '\n')
print('ok', len(bloques), 'poderes', len(lineas), 'secuencias')
