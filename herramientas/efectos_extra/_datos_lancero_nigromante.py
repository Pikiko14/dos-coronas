def ed(f, pairs):
    s = open(f, encoding='utf-8', newline='').read()
    crlf = '\r\n' in s
    s = s.replace('\r\n', '\n')
    for a, b in pairs:
        assert a in s, (f, a[:70])
        s = s.replace(a, b, 1)
    open(f, 'w', encoding='utf-8', newline='').write(s.replace('\n', '\r\n') if crlf else s)

ed('compartido/datos/habilidades.xml', [
 ('  <!-- ---- nigromante ---- -->', '''  <habilidad id="fisura_del_lancero" nombre="Fisura del lancero" clase="lancero" tipo="punto" aoe="2.6" cd="12" coef="1.8" lentitud="0.4" desc="Clavas la lanza y abres una fisura que daña y frena a los de la zona." mana="30" rango="6"/>
  <habilidad id="pulso_terrestre" nombre="Pulso terrestre" clase="lancero" tipo="alrededor" cd="14" coef="1.7" aturde="0.9" desc="Una onda de choque a tu alrededor daña y aturde." mana="28" rango="3.4"/>
  <habilidad id="torbellino_lanzas" nombre="Torbellino de lanzas" clase="lancero" tipo="alrededor" pulsos="4" seguir="true" cd="20" coef="0.9" lentitud="0.3" desc="Giras la lanza sin parar: golpeas cuatro veces a los que te rodean." mana="45" rango="3.2"/>
  <habilidad id="juicio_final" nombre="Juicio final" clase="lancero" tipo="punto" aoe="3.4" pulsos="3" cd="30" coef="1.5" aturde="0.6" desc="Una lluvia de lanzas de luz cae tres veces sobre la zona." mana="70" rango="7.5"/>
  <!-- ---- nigromante ---- -->'''),
 ('  <!-- ---- orden de los poderes en la barra', '''  <habilidad id="explosion_cadaverica" nombre="Explosión cadavérica" clase="nigromante" tipo="punto" aoe="2.8" cd="14" coef="2" dano="magico" desc="Un cadáver estalla y desgarra a todos los de la zona." mana="40" rango="7.5">
    <estado tipo="veneno" dur="5" prob="0.5"/>
  </habilidad>
  <habilidad id="nova_oscura" nombre="Nova oscura" clase="nigromante" tipo="alrededor" cd="12" coef="1.8" dano="magico" lentitud="0.4" desc="Una onda de oscuridad a tu alrededor daña y frena a los enemigos." mana="38" rango="3.6"/>
  <habilidad id="lluvia_profana" nombre="Lluvia profana" clase="nigromante" tipo="punto" aoe="3.2" pulsos="4" cd="24" coef="0.95" dano="magico" desc="Llueven almas envenenadas durante un rato sobre la zona." mana="65" rango="7.5">
    <estado tipo="veneno" dur="5" prob="0.6"/>
  </habilidad>
  <habilidad id="apocalipsis_necromantico" nombre="Apocalipsis necromántico" clase="nigromante" tipo="punto" aoe="3.8" pulsos="2" cd="40" coef="2.6" dano="magico" desc="La muerte misma barre la zona dos veces." mana="95" rango="7.5"/>
  <!-- ---- orden de los poderes en la barra'''),
 ('<lancero lista="estocada,barrido,muro_lanzas,embestida,jabalina,tormenta_lanzas"/>', '<lancero lista="estocada,barrido,muro_lanzas,embestida,jabalina,tormenta_lanzas,fisura_del_lancero,pulso_terrestre,torbellino_lanzas,juicio_final"/>'),
 ('<nigromante lista="toque_necro,espinas,maldecir,alzar_esqueletos,drenar,espectro"/>', '<nigromante lista="toque_necro,espinas,maldecir,alzar_esqueletos,drenar,espectro,explosion_cadaverica,nova_oscura,lluvia_profana,apocalipsis_necromantico"/>'),
 ('guerrero, cazador, mago y clérigo tienen 10', 'todas las clases tienen 10'),
])


def nodos(lista):
    return ''.join('      <i id="%s" nivel="%d" tipo="activa" slot="%d">\n        <requiere lista="%s"/>\n      </i>\n' % x for x in lista)


ed('compartido/datos/arbol.xml', [
 ('      <i id="tormenta_lanzas" nivel="20" tipo="activa" slot="6">\n        <requiere lista="muro_lanzas,2"/>\n      </i>\n',
  '      <i id="tormenta_lanzas" nivel="20" tipo="activa" slot="6">\n        <requiere lista="muro_lanzas,2"/>\n      </i>\n' + nodos([
      ("fisura_del_lancero", 22, 7, "embestida,2"), ("pulso_terrestre", 24, 8, "barrido,2"), ("torbellino_lanzas", 26, 9, "barrido,3"), ("juicio_final", 28, 10, "tormenta_lanzas,1")])),
 ('      <i id="espectro" nivel="20" tipo="activa" slot="6">\n        <requiere lista="alzar_esqueletos,2"/>\n      </i>\n',
  '      <i id="espectro" nivel="20" tipo="activa" slot="6">\n        <requiere lista="alzar_esqueletos,2"/>\n      </i>\n' + nodos([
      ("explosion_cadaverica", 22, 7, "espinas,2"), ("nova_oscura", 24, 8, "maldecir,2"), ("lluvia_profana", 26, 9, "drenar,2"), ("apocalipsis_necromantico", 28, 10, "espectro,1")])),
 ('    <golpe_terrestre cd=', '''    <fisura_del_lancero cd="0.04" mana="0.03" pot="0.12"/>
    <pulso_terrestre cd="0.04" mana="0.03" pot="0.12"/>
    <torbellino_lanzas cd="0.04" mana="0.03" pot="0.1"/>
    <juicio_final cd="0.04" mana="0.03" pot="0.12"/>
    <explosion_cadaverica cd="0.04" mana="0.03" pot="0.12"/>
    <nova_oscura cd="0.04" mana="0.03" pot="0.12"/>
    <lluvia_profana cd="0.04" mana="0.03" pot="0.1"/>
    <apocalipsis_necromantico cd="0.04" mana="0.03" pot="0.12"/>
    <golpe_terrestre cd='''),
])

ed('compartido/dominio/mundo.lua', [
 ('''  elseif h.tipo == "alrededor" then
    for _, o in pairs(self.entidades) do
      if o.vivo and self:mismoLugar(p, o) and self:puedeDanar(p, o) and Util.dist(p.x, p.y, o.x, o.y) <= h.rango then
        golpe(o, h.coef)
        if h.lentitud and o.vivo then self:aplicarEstado(o, "lentitud", 3, h.lentitud, p) end
      end
    end''', '''  elseif h.tipo == "alrededor" then
    for _, o in pairs(self.entidades) do
      if o.vivo and self:mismoLugar(p, o) and self:puedeDanar(p, o) and Util.dist(p.x, p.y, o.x, o.y) <= h.rango then
        golpe(o, h.coef)
        if h.lentitud and o.vivo then self:aplicarEstado(o, "lentitud", 3, h.lentitud, p) end
        if h.aturde and o.vivo then self:aplicarEstado(o, "aturdir", h.aturde, nil, p) end
      end
    end
    if h.pulsos and h.pulsos > 1 then
      -- torbellino: los golpes siguientes llegan mientras gira y siguen a quien lo lanza
      self.pulsos = self.pulsos or {}
      for i = 1, h.pulsos - 1 do
        self.pulsos[#self.pulsos + 1] = { t = self.tiempo + 0.45 + 0.35 * (i - 1), p = p, x = p.x, y = p.y, h = h, seguir = h.seguir, rango = h.rango }
      end
    end'''),
 ('''      elseif q.p.vivo then
        for _, o in pairs(self.entidades) do
          if o.vivo and self:mismoLugar(q.p, o) and self:puedeDanar(q.p, o) and Util.dist(q.x, q.y, o.x, o.y) <= (q.h.aoe or 2) then''',
  '''      elseif q.p.vivo then
        if q.seguir then q.x, q.y = q.p.x, q.p.y end
        for _, o in pairs(self.entidades) do
          if o.vivo and self:mismoLugar(q.p, o) and self:puedeDanar(q.p, o) and Util.dist(q.x, q.y, o.x, o.y) <= (q.rango or q.h.aoe or 2) then'''),
 ('  golpe_terrestre = "corte",', '''  fisura_del_lancero = "lanza", pulso_terrestre = "lanza", torbellino_lanzas = "lanza", juicio_final = "lanza",
  explosion_cadaverica = "oscuro", nova_oscura = "oscuro", lluvia_profana = "oscuro", apocalipsis_necromantico = "oscuro",
  golpe_terrestre = "corte",'''),
])
print('ok')
