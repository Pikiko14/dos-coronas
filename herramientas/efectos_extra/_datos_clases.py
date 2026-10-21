# Uso único: añade a habilidades.xml / arbol.xml los poderes 7-10 de guerrero, cazador y clérigo (ya aplicado; se deja como referencia).
def ed(f, pairs):
    s = open(f, encoding='utf-8', newline='').read()
    crlf = '\r\n' in s
    s = s.replace('\r\n', '\n')
    for a, b in pairs:
        assert a in s, (f, a[:70])
        s = s.replace(a, b, 1)
    open(f, 'w', encoding='utf-8', newline='').write(s.replace('\n', '\r\n') if crlf else s)

H = 'compartido/datos/habilidades.xml'
ed(H, [
 ('  <!-- ---- mago ---- -->', '''  <habilidad id="golpe_terrestre" nombre="Golpe terrestre" clase="guerrero" tipo="punto" aoe="2.4" cd="12" coef="1.9" aturde="1.2" desc="Golpeas el suelo: daña y aturde a los enemigos de la zona." mana="30" rango="5"/>
  <habilidad id="salto_impacto" nombre="Salto de impacto" clase="guerrero" tipo="punto" salto="true" aoe="2.2" cd="14" coef="1.6" lentitud="0.4" desc="Saltas hasta un punto y lo aplastas al caer: daña y ralentiza." mana="28" rango="6"/>
  <habilidad id="estocada_lineal" nombre="Estocada lineal" clase="guerrero" tipo="enemigo" cd="6" coef="2.2" desc="Una estocada larga y certera que hace sangrar." mana="20" rango="3.2">
    <estado tipo="sangrar" dur="6" prob="0.6"/>
  </habilidad>
  <habilidad id="ejecucion" nombre="Ejecución" clase="guerrero" tipo="enemigo" cd="22" coef="1.8" ejecuta="2.4" desc="Remata a su presa: daña mucho más a un enemigo con poca vida." mana="40" rango="1.8"/>
  <!-- ---- mago ---- -->'''),
 ('  <!-- ---- clerigo ---- -->', '''  <habilidad id="disparo_multiple" nombre="Disparo múltiple" clase="cazador" tipo="enemigo" aoe="2" cd="6" coef="1.25" desc="Una andanada que alcanza también a los que rodean al objetivo." mana="24" proyectil="flecha" rango="7.4"/>
  <habilidad id="disparo_explosivo" nombre="Disparo explosivo" clase="cazador" tipo="enemigo" aoe="2.4" cd="12" coef="1.7" desc="Una flecha que estalla al impactar y prende a los cercanos." mana="34" proyectil="flecha" rango="7.4">
    <estado tipo="quemar" dur="5" prob="0.6"/>
  </habilidad>
  <habilidad id="disparo_helado" nombre="Disparo helado" clase="cazador" tipo="enemigo" cd="9" coef="1.3" desc="Una flecha de hielo que ralentiza mucho al objetivo." mana="26" proyectil="flecha" rango="7.4">
    <estado tipo="lentitud" dur="4" pct="0.5" prob="1"/>
  </habilidad>
  <habilidad id="marca_cazador" nombre="Marca del cazador" clase="cazador" tipo="enemigo" cd="20" coef="0.5" marca="0.25" dur="8" desc="Marcas a tu presa: recibe un 25% más de daño de cualquiera durante unos segundos." mana="22" proyectil="flecha" rango="8"/>
  <!-- ---- clerigo ---- -->'''),
 ('  <!-- ---- lancero ---- -->', '''  <habilidad id="escudo_divino" nombre="Escudo divino" clase="clerigo" tipo="aliado" buff="escudo" cd="18" dur="10" desc="Un escudo de luz absorbe el daño de un aliado o el tuyo." mana="45" rango="6.5"/>
  <habilidad id="cadena_sanacion" nombre="Cadena de sanación" clase="clerigo" tipo="aliado" rebotes="2" cura="20" curaN="3" cd="9" desc="Cura a un aliado y la luz salta a otros dos cercanos." mana="36" rango="6.5"/>
  <habilidad id="tormenta_divina" nombre="Tormenta divina" clase="clerigo" tipo="punto" aoe="3.2" pulsos="3" cd="24" coef="1.2" dano="magico" cura="14" curaN="2" desc="Una tormenta de luz castiga tres veces la zona y cura a tus aliados dentro." mana="70" rango="7.5"/>
  <habilidad id="resurreccion" nombre="Resurrección" clase="clerigo" tipo="resucitar" cd="90" desc="Devuelve a la vida a un aliado caído cerca de ti, con la mitad de su vida." mana="100" rango="6"/>
  <!-- ---- lancero ---- -->'''),
 ('<guerrero lista="golpe,tajo,grito,carga,pantera,furia"/>', '<guerrero lista="golpe,tajo,grito,carga,pantera,furia,golpe_terrestre,salto_impacto,estocada_lineal,ejecucion"/>'),
 ('<cazador lista="disparo,lluvia,trampa,preciso,flecha_veneno,paso_agil"/>', '<cazador lista="disparo,lluvia,trampa,preciso,flecha_veneno,paso_agil,disparo_multiple,disparo_explosivo,disparo_helado,marca_cazador"/>'),
 ('<clerigo lista="curar,bendicion,castigo,consagrar,sanacion,juicio"/>', '<clerigo lista="curar,bendicion,castigo,consagrar,sanacion,juicio,escudo_divino,cadena_sanacion,tormenta_divina,resurreccion"/>'),
 ('(teclas 1 a 6; el mago tiene 10)', '(teclas 1 a 6; guerrero, cazador, mago y clérigo tienen 10)'),
])
A = 'compartido/datos/arbol.xml'
def nodos(lista):
    return ''.join('      <i id="%s" nivel="%d" tipo="activa" slot="%d">\n        <requiere lista="%s"/>\n      </i>\n' % x for x in lista)
ed(A, [
 ('      <i id="furia" nivel="20" tipo="activa" slot="6">\n        <requiere lista="grito,2"/>\n      </i>\n',
  '      <i id="furia" nivel="20" tipo="activa" slot="6">\n        <requiere lista="grito,2"/>\n      </i>\n' + nodos([
      ("golpe_terrestre", 22, 7, "tajo,2"), ("salto_impacto", 24, 8, "carga,2"), ("estocada_lineal", 26, 9, "golpe,3"), ("ejecucion", 28, 10, "pantera,2")])),
 ('      <i id="paso_agil" nivel="20" tipo="activa" slot="6">\n        <requiere lista="trampa,2"/>\n      </i>\n',
  '      <i id="paso_agil" nivel="20" tipo="activa" slot="6">\n        <requiere lista="trampa,2"/>\n      </i>\n' + nodos([
      ("disparo_multiple", 22, 7, "disparo,3"), ("disparo_explosivo", 24, 8, "lluvia,2"), ("disparo_helado", 26, 9, "preciso,1"), ("marca_cazador", 28, 10, "flecha_veneno,1")])),
 ('      <i id="juicio" nivel="20" tipo="activa" slot="6">\n        <requiere lista="castigo,3"/>\n      </i>\n',
  '      <i id="juicio" nivel="20" tipo="activa" slot="6">\n        <requiere lista="castigo,3"/>\n      </i>\n' + nodos([
      ("escudo_divino", 22, 7, "curar,3"), ("cadena_sanacion", 24, 8, "sanacion,1"), ("tormenta_divina", 26, 9, "juicio,1"), ("resurreccion", 28, 10, "consagrar,1")])),
 ('    <rayo_hielo cd=', '''    <golpe_terrestre cd="0.04" mana="0.03" pot="0.12"/>
    <salto_impacto cd="0.04" mana="0.03" pot="0.12"/>
    <estocada_lineal cd="0.04" mana="0.03" pot="0.12"/>
    <ejecucion cd="0.04" mana="0.03" pot="0.12"/>
    <disparo_multiple cd="0.04" mana="0.03" pot="0.1"/>
    <disparo_explosivo cd="0.04" mana="0.03" pot="0.12"/>
    <disparo_helado cd="0.04" mana="0.03" pot="0.1"/>
    <marca_cazador cd="0.04" mana="0.03" dur="1" pot="0.1"/>
    <escudo_divino cd="0.04" mana="0.03" dur="1" pot="0.12"/>
    <cadena_sanacion cd="0.04" mana="0.03" pot="0.12"/>
    <tormenta_divina cd="0.04" mana="0.03" pot="0.12"/>
    <resurreccion cd="0.05" mana="0.04" pot="0"/>
    <rayo_hielo cd='''),
])
print('ok')
