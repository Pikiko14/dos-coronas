def ed(f, pairs):
    s = open(f, encoding='utf-8', newline='').read()
    crlf = '\r\n' in s
    s = s.replace('\r\n', '\n')
    for a, b in pairs:
        assert a in s, (f, a[:70])
        s = s.replace(a, b, 1)
    open(f, 'w', encoding='utf-8', newline='').write(s.replace('\n', '\r\n') if crlf else s)

ed('servidor/src/pruebas/pruebas.lua', [
 ('local esperado = (clase == "lancero" or clase == "nigromante") and 6 or 10\n      fallar(errores, clase .. " tiene " .. esperado .. " poderes", activas == esperado)',
  'fallar(errores, clase .. " tiene 10 poderes", activas == 10)'),
 ('    for _, clase in ipairs({ "guerrero", "cazador", "clerigo", "mago" }) do\n      fallar(errores, "la barra de " .. clase .. " tiene 10 poderes", #Datos.barra[clase] == 10)\n    end',
  '''    for _, clase in ipairs(Datos.ORDEN_CLASES) do
      fallar(errores, "la barra de " .. clase .. " tiene 10 poderes", #Datos.barra[clase] == 10)
    end
    -- lancero: el pulso terrestre aturde, el torbellino de lanzas golpea varias veces siguiéndote, el juicio final cae tres veces
    do
      local mundo, p = nuevo("lancero")
      local m = mundo:spawnMonstruo("pinguino_aprendiz", p.x + 2, p.y, { x = p.x, y = p.y })
      m.hp, m.hpMax = 1e6, 1e6
      p.cds = {}
      local err = mundo:usarHabilidad(p, slotDe("lancero", "pulso_terrestre"))
      fallar(errores, "el pulso terrestre daña y aturde", err == nil and m.hp < m.hpMax and (m.aturdido or 0) > 0, tostring(err))
      m.hp, m.aturdido = m.hpMax, 0
      p.cds = {}
      err = mundo:usarHabilidad(p, slotDe("lancero", "torbellino_lanzas"))
      local h1 = m.hp
      fallar(errores, "el torbellino de lanzas golpea al lanzarse", err == nil and h1 < m.hpMax, tostring(err))
      for _ = 1, 20 do mundo:actualizar(0.1) end
      fallar(errores, "y vuelve a golpear mientras gira", m.hp < h1 - (m.hpMax - h1) * 1.5, h1 .. " " .. m.hp)
      m.hp = m.hpMax
      p.cds, p.mp = {}, 9999
      mundo.pulsos = {}
      err = mundo:usarHabilidad(p, slotDe("lancero", "juicio_final"), m.x, m.y)
      fallar(errores, "el juicio final programa sus otras dos caídas", err == nil and #mundo.pulsos == 2, tostring(err) .. " " .. #mundo.pulsos)
    end
    -- nigromante: nova oscura, explosión cadavérica, lluvia profana y apocalipsis
    do
      local mundo, p = nuevo("nigromante", "umbra")
      local m = mundo:spawnMonstruo("pinguino_aprendiz", p.x + 2, p.y, { x = p.x, y = p.y })
      m.hp, m.hpMax = 1e6, 1e6
      for _, id in ipairs({ "nova_oscura", "explosion_cadaverica", "lluvia_profana", "apocalipsis_necromantico" }) do
        m.hp = m.hpMax
        p.cds, p.mp, p.objetivo = {}, 9999, m.id
        local e = mundo:usarHabilidad(p, slotDe("nigromante", id), m.x, m.y)
        fallar(errores, id .. " se lanza y daña", e == nil and m.hp < m.hpMax, tostring(e))
      end
    end'''),
])
print('ok')
