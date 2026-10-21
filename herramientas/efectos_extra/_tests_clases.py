def ed(f, pairs):
    s = open(f, encoding='utf-8', newline='').read()
    crlf = '\r\n' in s
    s = s.replace('\r\n', '\n')
    for a, b in pairs:
        assert a in s, (f, a[:70])
        s = s.replace(a, b, 1)
    open(f, 'w', encoding='utf-8', newline='').write(s.replace('\n', '\r\n') if crlf else s)

ed('servidor/src/pruebas/pruebas.lua', [
 ('fallar(errores, clase .. " tiene " .. (clase == "mago" and "diez" or "seis") .. " poderes", activas == (clase == "mago" and 10 or 6))',
  'local esperado = (clase == "lancero" or clase == "nigromante") and 6 or 10\n      fallar(errores, clase .. " tiene " .. esperado .. " poderes", activas == esperado)'),
 ('''        local ents0 = 0
        for _ in pairs(mundo.entidades) do ents0 = ents0 + 1 end
        local err = mundo:usarHabilidad(p, slot, p.x + 2, p.y)''', '''        if h.tipo == "resucitar" then
          local c = mundo:crearPersonaje({ nombre = "Caido", faccion = faccion, clase = "guerrero", nivel = 10 })
          c.x, c.y, c.modo = p.x + 1, p.y, p.modo
          mundo:morir(c, nil)
        end
        local ents0 = 0
        for _ in pairs(mundo.entidades) do ents0 = ents0 + 1 end
        local err = mundo:usarHabilidad(p, slot, p.x + 2, p.y)'''),
 ('''  paso("recompensa diaria: con la bolsa llena explica''', '''  paso("poderes 7-10 de guerrero, cazador y clérigo: salto, aturdimiento, ejecución, marca, escudo, cadena, tormenta y resurrección", function()
    local function nuevo(clase, faccion)
      local mundo = Mundo.nuevo()
      local p = mundo:crearPersonaje({ nombre = "Prueba" .. clase, faccion = faccion or "albor", clase = clase, nivel = 30 })
      for _, id in ipairs(Datos.barra[clase]) do p.habilidades[id] = 1 end
      p.hp, p.hpMax, p.mp, p.mpMax, p.ultimoGolpe = 99999, 99999, 9999, 9999, -99
      mundo.tiempo = 100
      return mundo, p
    end
    local function slotDe(clase, id) for i, b in ipairs(Datos.barra[clase]) do if b == id then return i end end end
    for _, clase in ipairs({ "guerrero", "cazador", "clerigo", "mago" }) do
      fallar(errores, "la barra de " .. clase .. " tiene 10 poderes", #Datos.barra[clase] == 10)
    end
    -- guerrero: salto de impacto (se mueve y daña al caer), golpe terrestre (aturde), ejecución (más daño con poca vida)
    local mundo, p = nuevo("guerrero")
    local m = mundo:spawnMonstruo("pinguino_aprendiz", p.x + 4, p.y, { x = p.x, y = p.y })
    m.hp, m.hpMax = 1e6, 1e6
    local x0 = p.x
    p.cds = {}
    local err = mundo:usarHabilidad(p, slotDe("guerrero", "salto_impacto"), m.x, m.y)
    fallar(errores, "el salto de impacto te lleva al punto y daña", err == nil and p.x > x0 + 1.5 and m.hp < m.hpMax, tostring(err) .. " " .. (p.x - x0))
    m.hp = m.hpMax
    p.cds = {}
    err = mundo:usarHabilidad(p, slotDe("guerrero", "golpe_terrestre"), m.x, m.y)
    fallar(errores, "el golpe terrestre aturde", err == nil and (m.aturdido or 0) > 0 and m.hp < m.hpMax, tostring(err))
    m.x, m.y, p.x, p.y = p.x + 1, p.y, p.x, p.y
    m.x, m.y = p.x + 1, p.y
    m.hp, m.hpMax = 1e6, 1e6
    p.cds, p.objetivo, m.vivo = {}, m.id, true
    local hpA = m.hp
    mundo:usarHabilidad(p, slotDe("guerrero", "ejecucion"), m.x, m.y)
    local danoSano = hpA - m.hp
    m.hp = m.hpMax * 0.2
    local hpB = m.hp
    p.cds = {}
    mundo:usarHabilidad(p, slotDe("guerrero", "ejecucion"), m.x, m.y)
    fallar(errores, "la ejecución daña mucho más a quien tiene poca vida", (hpB - m.hp) > danoSano * 1.5, danoSano .. " vs " .. (hpB - m.hp))
    -- cazador: la marca aumenta el daño recibido
    mundo, p = nuevo("cazador")
    m = mundo:spawnMonstruo("pinguino_aprendiz", p.x + 3, p.y, { x = p.x, y = p.y })
    m.hp, m.hpMax = 1e6, 1e6
    p.objetivo, p.cds = m.id, {}
    fallar(errores, "la marca del cazador se lanza", mundo:usarHabilidad(p, slotDe("cazador", "marca_cazador")) == nil and (m.marcaHasta or 0) > mundo.tiempo)
    local h0 = m.hp
    mundo:danar(m, 1000, p, false)
    local conMarca = h0 - m.hp
    m.marcaHasta = nil
    h0 = m.hp
    mundo:danar(m, 1000, p, false)
    fallar(errores, "el marcado recibe un 25% más de daño", conMarca > (h0 - m.hp) * 1.2, conMarca .. " vs " .. (h0 - m.hp))
    -- clérigo: escudo, cadena de sanación, tormenta y resurrección
    mundo, p = nuevo("clerigo")
    local a1 = mundo:crearPersonaje({ nombre = "Aliado1", faccion = "albor", clase = "guerrero", nivel = 10 })
    local a2 = mundo:crearPersonaje({ nombre = "Aliado2", faccion = "albor", clase = "guerrero", nivel = 10 })
    a1.x, a1.y, a2.x, a2.y = p.x + 2, p.y, p.x + 3.5, p.y
    a1.hp, a2.hp = 10, 10
    p.objetivo, p.cds = a1.id, {}
    fallar(errores, "la cadena de sanación se lanza", mundo:usarHabilidad(p, slotDe("clerigo", "cadena_sanacion")) == nil)
    fallar(errores, "la cadena cura al objetivo y salta al otro aliado", a1.hp > 10 and a2.hp > 10, a1.hp .. "/" .. a2.hp)
    p.cds = {}
    fallar(errores, "el escudo divino se lanza", mundo:usarHabilidad(p, slotDe("clerigo", "escudo_divino")) == nil and mundo:tieneBuff(a1, "escudo") ~= nil)
    a2.vivo = false
    p.cds, p.objetivo = {}, nil
    p.mp = 9999
    fallar(errores, "la resurrección devuelve a la vida a un aliado caído", mundo:usarHabilidad(p, slotDe("clerigo", "resurreccion")) == nil and a2.vivo and a2.hp > 1, tostring(a2.hp))
    p.cds = {}
    fallar(errores, "sin caídos la resurrección no gasta maná", (function() local mp = p.mp; local e = mundo:usarHabilidad(p, slotDe("clerigo", "resurreccion")); return e ~= nil and p.mp == mp end)())
    local mt = mundo:spawnMonstruo("pinguino_aprendiz", p.x + 3, p.y, { x = p.x, y = p.y })
    mt.hp, mt.hpMax = 1e6, 1e6
    a1.hp = 5
    p.cds = {}
    local hpT = mt.hp
    fallar(errores, "la tormenta divina se lanza", mundo:usarHabilidad(p, slotDe("clerigo", "tormenta_divina"), mt.x, mt.y) == nil)
    for _ = 1, 25 do mundo:actualizar(0.1) end
    fallar(errores, "la tormenta divina daña al enemigo y cura al aliado", mt.hp < hpT and a1.hp > 5)
  end)
  paso("recompensa diaria: con la bolsa llena explica'''),
])
print('ok')
