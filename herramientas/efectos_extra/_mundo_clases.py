def ed(f, pairs):
    s = open(f, encoding='utf-8', newline='').read()
    crlf = '\r\n' in s
    s = s.replace('\r\n', '\n')
    for a, b in pairs:
        assert a in s, (f, a[:70])
        s = s.replace(a, b, 1)
    open(f, 'w', encoding='utf-8', newline='').write(s.replace('\n', '\r\n') if crlf else s)

ed('compartido/dominio/mundo.lua', [
 # ejecución: más daño a quien tiene poca vida
 ('''  local function golpe(obj, coef)
    self:golpear(p, obj, coef, nil, h.dano or "fisico")''',
  '''  if h.marca and objetivo and objetivo ~= p and objetivo.vivo then
    -- marca del cazador: la presa recibe más daño de quien sea durante unos segundos
    objetivo.marcaHasta, objetivo.marcaPct = self.tiempo + (h.dur or 8), h.marca
    self:numero(objetivo, "Marcado", { 1, 0.35, 0.3 })
  end
  local function golpe(obj, coef)
    if h.ejecuta and obj.hpMax and obj.hp < obj.hpMax * 0.3 then coef = coef * h.ejecuta end       -- ejecución: remata a quien tiene poca vida
    self:golpear(p, obj, coef, nil, h.dano or "fisico")'''),
 # punto: salto, aturdir, curar
 ('''    if h.blink then
      -- teletransporte: te mueves al punto (como mucho hasta el alcance, y a la casilla libre más cercana)''',
  '''    if h.blink or h.salto then
      -- teletransporte y salto: te mueves al punto (como mucho hasta el alcance, y a la casilla libre más cercana)'''),
 ('''      p.blinkDesde = { ox, oy }
      p.persigue, p.objetivoMover = nil, nil
      px, py = p.x, p.y
    else
      p.impactoX, p.impactoY = px, py
      for _, o in pairs(self.entidades) do
        if o.vivo and self:mismoLugar(p, o) and self:puedeDanar(p, o) and Util.dist(px, py, o.x, o.y) <= (h.aoe or 2) then
          golpe(o, h.coef)
          if h.lentitud and o.vivo then self:aplicarEstado(o, "lentitud", 3, h.lentitud, p) end
        end
      end
''', '''      p.blinkDesde = h.blink and { ox, oy } or nil
      p.persigue, p.objetivoMover = nil, nil
      px, py = p.x, p.y
    end
    if not h.blink then
      p.impactoX, p.impactoY = px, py
      for _, o in pairs(self.entidades) do
        if o.vivo and self:mismoLugar(p, o) and self:puedeDanar(p, o) and Util.dist(px, py, o.x, o.y) <= (h.aoe or 2) then
          golpe(o, h.coef)
          if h.lentitud and o.vivo then self:aplicarEstado(o, "lentitud", 3, h.lentitud, p) end
          if h.aturde and o.vivo then self:aplicarEstado(o, "aturdir", h.aturde, nil, p) end
        elseif h.cura and o.vivo and self:mismoLugar(p, o) and self:aliado(p, o) and Util.dist(px, py, o.x, o.y) <= (h.aoe or 2) then
          self:curar(o, self:potenciaCura(p, h), p)       -- tormenta divina: cura a los aliados de la zona
        end
      end
'''),
 # aliado: escudo y cadena
 ('''  elseif h.tipo == "aliado" then
    if h.cura then self:curar(objetivo, self:potenciaCura(p, h), p) end
    if h.buff == "bendicion"''', '''  elseif h.tipo == "aliado" then
    if h.cura then self:curar(objetivo, self:potenciaCura(p, h), p) end
    if h.rebotes then
      -- cadena de sanación: la luz salta a los aliados más cercanos (con menos fuerza cada vez)
      local desde, curados, fuerza = objetivo, { [objetivo.id] = true }, 1
      for _ = 1, h.rebotes do
        local mejor, md
        for _, o in pairs(self.entidades) do
          if o.vivo and not curados[o.id] and (o.kind == "jugador" or o.kind == "bot") and self:mismoLugar(p, o) and self:aliado(p, o) then
            local d = Util.dist(desde.x, desde.y, o.x, o.y)
            if d <= 4.5 and (not md or d < md) then mejor, md = o, d end
          end
        end
        if not mejor then break end
        fuerza = fuerza * 0.75
        curados[mejor.id] = true
        self:curar(mejor, self:potenciaCura(p, h) * fuerza, p)
        desde = mejor
      end
    end
    if h.buff == "escudo" then
      local abs = (30 + p.nivel * 4) * (h.pot or 1) * 1.2
      self:ponerBuff(objetivo, "escudo", h.dur, { absorbe = abs, habilidad = idh })
      self:numero(objetivo, "escudo", { 0.55, 0.7, 1 })
    end
    if h.buff == "bendicion"'''),
 # resucitar
 ('''  elseif h.tipo == "invocar" then
    self:invocarEsbirros(p, h)''', '''  elseif h.tipo == "resucitar" and caido then
    caido.vivo, caido.respawn = true, nil
    self:limpiarEstados(caido)
    caido.hp = math.max(1, math.floor((caido.hpMax or 1) * 0.5))
    caido.mp = math.floor((caido.mpMax or 0) * 0.3)
    caido.aturdido, caido.objetivo, caido.camino = 0, nil, nil
    for _, c in pairs(self.entidades) do
      if c.kind == "cuerpo" and c.nombre == caido.nombre and Util.dist(c.x, c.y, caido.x, caido.y) < 1.5 then c.hasta = 0 end
    end
    self:numero(caido, "¡Vuelve!", { 1, 0.95, 0.6 })
    self:mensaje("sistema", "", p.nombre .. " te ha devuelto a la vida.", caido)
    ex, ey = caido.x, caido.y
  elseif h.tipo == "invocar" then
    self:invocarEsbirros(p, h)'''),
 # comprobación previa del caído (antes de gastar maná)
 ('''  p.mp = p.mp - h.mana
  p.cds[idh] = self.tiempo + h.cd''', '''  local caido
  if h.tipo == "resucitar" then
    local md
    for _, o in pairs(self.entidades) do
      if not o.vivo and (o.kind == "jugador" or o.kind == "bot") and o ~= p and self:aliado(p, o) and self:mismoLugar(p, o) and o.x then
        local d = Util.dist(p.x, p.y, o.x, o.y)
        if d <= h.rango + 0.3 and (not md or d < md) then caido, md = o, d end
      end
    end
    if not caido then return "No hay ningún aliado caído a tu alcance." end
  end
  p.mp = p.mp - h.mana
  p.cds[idh] = self.tiempo + h.cd'''),
 # marca: daño extra recibido
 ('''  cantidad = math.max(1, math.floor(cantidad))
  if objetivo.montado and self:danarMontura''', '''  cantidad = math.max(1, math.floor(cantidad))
  if (objetivo.marcaHasta or 0) > self.tiempo then cantidad = math.max(1, math.floor(cantidad * (1 + (objetivo.marcaPct or 0.25)))) end     -- marca del cazador
  if objetivo.montado and self:danarMontura'''),
 ('  rayo_hielo = "hielo",', '''  golpe_terrestre = "corte", salto_impacto = "corte", estocada_lineal = "corte", ejecucion = "corte",
  disparo_multiple = "flecha", disparo_explosivo = "fuego", disparo_helado = "hielo", marca_cazador = "flecha",
  escudo_divino = "sagrado", cadena_sanacion = "cura", tormenta_divina = "sagrado", resurreccion = "sagrado",
  rayo_hielo = "hielo",'''),
])
print('ok')
