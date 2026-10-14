-- Interfaz de las misiones: el tablón de cada PNJ, el diario (tecla Q), el rastreador de la misión que sigues y las marcas de
-- destino en el minimapa, el mapa del mundo y sobre el personaje. Se instala dentro de Interfaz (ver el final de interfaz.lua).
local Datos = require("compartido.dominio.datos")
local Misiones = require("compartido.dominio.misiones")
local Monturas = require("compartido.dominio.monturas")
local Mall = require("compartido.dominio.mall")
local Dibujo = require("src.presentacion.render.dibujo")

local U = {}

local COLOR_ESTADO = {
  lista = { 0.55, 1, 0.55 }, activa = { 0.95, 0.9, 0.75 }, nueva = { 0.7, 0.78, 0.95 }, entregada = { 0.5, 0.5, 0.5 },
}
local ETIQUETA_ESTADO = { lista = "Lista para entregar", activa = "En curso", nueva = "Disponible", entregada = "Entregada" }
local ORDEN_ESTADO = { lista = 1, activa = 2, nueva = 3 }
local TIPO_TEXTO = { cazar = "Cazar", recolectar = "Recolectar", entregar = "Entregar" }

local function nombreMonstruo(id)
  local d = Datos.monstruo(id)
  return d and d.nombre or tostring(id)
end

local function nombreItem(id)
  local d = Datos.item(id)
  return d and d.nombre or tostring(id)
end

local PUNTOS = { "E", "SE", "S", "SO", "O", "NO", "N", "NE" }
-- "230 casillas al NE"
local function direccion(p, x, y)
  local dx, dy = x - p.x, y - p.y
  local d = math.sqrt(dx * dx + dy * dy)
  local ang = math.atan2(dy, dx)               -- 0 = este, y crece hacia el sur
  local idx = math.floor((ang + math.pi / 8) / (math.pi / 4)) % 8
  return math.floor(d + 0.5), PUNTOS[idx + 1]
end

-- Texto de la recompensa de una misión (la experiencia ya ajustada al nivel de quien mira).
local function textoRecompensa(p, q)
  local xp = Misiones.xpFinal(p, q)
  local t = "+" .. xp .. " exp  ·  +" .. (q.oro or 0) .. " oro"
  for _, pr in ipairs(q.premios or {}) do t = t .. "  ·  " .. pr.cant .. " " .. nombreItem(pr.id) end
  if q.monedas and q.monedas > 0 then t = t .. "  ·  " .. q.monedas .. " " .. Mall.MONEDA end
  return t
end

local function textoEspecial(q)
  local lista = {}
  if q.addon and Mall.ADDONS[q.addon] then lista[#lista + 1] = "Addon: " .. Mall.ADDONS[q.addon].nombre end
  if q.montura and Monturas.especies[q.montura] then lista[#lista + 1] = "Montura: " .. (Monturas.especies[q.montura].nombre or q.montura) end
  return #lista > 0 and table.concat(lista, "   ") or nil
end

local function textoObjetivo(q)
  if q.tipo == "cazar" then
    return "Derrotar " .. q.cantidad .. " × " .. nombreMonstruo(q.monstruo)
  elseif q.tipo == "recolectar" then
    return "Reunir " .. q.cantidad .. " × " .. nombreItem(q.item) .. " (los suelta " .. nombreMonstruo(q.de) .. ")"
  end
  local destino = Misiones.npcs[q.destino]
  return "Entregar " .. nombreItem(q.item) .. " a " .. Misiones.nombreNpc(q.destino) .. (destino and (" (" .. destino.lugar .. ")") or "")
end

function U.instalar(I, H)
  local caja, texto = H.caja, H.texto

  local function raton()
    local mx, my = love.mouse.getPosition()
    local s = I.escala or 1
    return mx / s, my / s
  end
  local function sobre(x, y, w, h)
    local mx, my = raton()
    return mx >= x and mx <= x + w and my >= y and my <= y + h
  end

  -- Destinos de la misión seguida (se recalculan dos veces por segundo: el jugador se mueve y cambia lo más cercano).
  local cacheDestinos = { t = -1 }
  function I.destinosSeguidos(p)
    local id = Misiones.seguida
    local q = id and Misiones.por_id[id]
    if not q or p.modo ~= "mundo" then return nil, nil end
    local est, st = Misiones.estado(p, q)
    if est == "entregada" or (est == "nueva") then
      Misiones.seguida = nil
      return nil, nil
    end
    local ahora = love.timer.getTime()
    if cacheDestinos.id ~= id or cacheDestinos.est ~= est or ahora - cacheDestinos.t > 0.5 then
      cacheDestinos = { t = ahora, id = id, est = est, lista = Misiones.destinos(p, q, st) }
    end
    return cacheDestinos.lista, q
  end

  Dibujo.flechaMision = function(p, px, py) U.flechaMision(p, I, px, py) end

  -- ---------------------------------------------------------------------------------------------- detalle de una misión
  -- Dibuja el detalle (descripción, objetivo, dónde ir, recompensa) en el rectángulo; devuelve la y donde terminó.
  local function detalle(p, q, x, y, w)
    local est, st = Misiones.estado(p, q)
    local dc = Misiones.COLOR_DIF[q.dif] or Misiones.COLOR_DIF.normal
    local f = love.graphics.getFont()
    love.graphics.setColor(1, 0.9, 0.55)
    love.graphics.printf(q.titulo, x, y, w, "left")
    y = y + f:getHeight() + 2
    love.graphics.setColor(dc[1], dc[2], dc[3])
    love.graphics.print(Misiones.NOMBRE_DIF[q.dif] .. "  ·  " .. (TIPO_TEXTO[q.tipo] or "") .. "  ·  Nivel " .. (q.nivel or 1), x, y)
    y = y + f:getHeight() + 6
    love.graphics.setColor(0.85, 0.85, 0.8)
    local _, lineas = f:getWrap(q.texto or "", w)
    love.graphics.printf(q.texto or "", x, y, w, "left")
    y = y + #lineas * f:getHeight() + 8
    -- objetivo y progreso
    love.graphics.setColor(0.7, 0.85, 1)
    love.graphics.print("Objetivo", x, y)
    y = y + f:getHeight() + 1
    local prog = Misiones.progreso(p, q, st)
    local c = (est == "lista") and { 0.55, 1, 0.55 } or { 0.9, 0.9, 0.9 }
    love.graphics.setColor(c[1], c[2], c[3])
    local objetivo = textoObjetivo(q) .. (q.tipo ~= "entregar" and ("   [" .. prog .. "/" .. q.cantidad .. "]") or "")
    local _, l2 = f:getWrap(objetivo, w)
    love.graphics.printf(objetivo, x, y, w, "left")
    y = y + #l2 * f:getHeight() + 6
    -- dónde
    love.graphics.setColor(0.7, 0.85, 1)
    love.graphics.print("Dónde", x, y)
    y = y + f:getHeight() + 1
    love.graphics.setColor(0.9, 0.9, 0.9)
    local destinos = Misiones.destinos(p, q, st)
    if #destinos == 0 then
      local pista = q.pista or "Recorre las zonas de nivel parecido: puede aparecer en cualquier parte del mundo."
      local _, l3 = f:getWrap(pista, w)
      love.graphics.printf(pista, x, y, w, "left")
      y = y + #l3 * f:getHeight()
    else
      for i, d in ipairs(destinos) do
        local dist, punto = direccion(p, d.x, d.y)
        local linea = (d.tipo == "npc" and "• " or "• ") .. d.texto .. (d.lugar and (" en " .. d.lugar) or "") .. " — a " .. dist .. " casillas al " .. punto
        local _, l3 = f:getWrap(linea, w)
        love.graphics.printf(linea, x, y, w, "left")
        y = y + #l3 * f:getHeight()
      end
    end
    y = y + 8
    -- recompensa
    love.graphics.setColor(1, 0.85, 0.3)
    love.graphics.print("Recompensa", x, y)
    y = y + f:getHeight() + 1
    love.graphics.setColor(0.95, 0.88, 0.6)
    local rec = textoRecompensa(p, q)
    local _, l4 = f:getWrap(rec, w)
    love.graphics.printf(rec, x, y, w, "left")
    y = y + #l4 * f:getHeight()
    local esp = textoEspecial(q)
    if esp then
      y = y + 2
      love.graphics.setColor(1, 0.55, 0.9)
      local _, l5 = f:getWrap(esp, w)
      love.graphics.printf(esp, x, y, w, "left")
      y = y + #l5 * f:getHeight()
    end
    return y + 8
  end

  -- lista con scroll de misiones (cada fila es clicable); devuelve cuántas filas caben
  local function lista(p, filas, x, y, w, h, selId, scrollClave)
    local alto = 44
    local visibles = math.max(1, math.floor(h / alto))
    local maxScroll = math.max(0, #filas - visibles)
    I[scrollClave] = math.max(0, math.min(maxScroll, I[scrollClave] or 0))
    I.misScrollMax = maxScroll
    local ini = I[scrollClave]
    for i = ini + 1, math.min(#filas, ini + visibles) do
      local q = filas[i]
      local est = Misiones.estado(p, q)
      local yy = y + (i - ini - 1) * alto
      local dc = Misiones.COLOR_DIF[q.dif] or Misiones.COLOR_DIF.normal
      local hover = sobre(x, yy, w, alto - 4)
      love.graphics.setColor(selId == q.id and 0.2 or (hover and 0.16 or 0.1), selId == q.id and 0.28 or (hover and 0.2 or 0.13), selId == q.id and 0.5 or (hover and 0.34 or 0.24), 0.95)
      love.graphics.rectangle("fill", x, yy, w, alto - 4, 6, 6)
      love.graphics.setColor(dc[1], dc[2], dc[3], 1)
      love.graphics.rectangle("fill", x, yy, 4, alto - 4, 3, 3)
      local ce = COLOR_ESTADO[est] or COLOR_ESTADO.nueva
      love.graphics.setColor(ce[1], ce[2], ce[3])
      local tit = q.titulo
      local f = love.graphics.getFont()
      while f:getWidth(tit) > w - 84 and #tit > 4 do tit = tit:sub(1, #tit - 2) end
      if tit ~= q.titulo then tit = tit .. "…" end
      love.graphics.print(tit, x + 10, yy + 3)
      love.graphics.setColor(0.65, 0.7, 0.8)
      local prog = Misiones.progreso(p, q, p.misiones and p.misiones[q.id])
      local sub = "Nv " .. (q.nivel or 1) .. " · " .. (TIPO_TEXTO[q.tipo] or "") .. (est == "activa" and (" · " .. prog .. "/" .. q.cantidad) or "")
      love.graphics.print(sub, x + 10, yy + 21)
      love.graphics.setColor(ce[1], ce[2], ce[3], 0.9)
      local et = ETIQUETA_ESTADO[est] or ""
      love.graphics.print(et, x + w - f:getWidth(et) - 8, yy + 21)
      if Misiones.seguida == q.id then
        love.graphics.setColor(1, 0.85, 0.2)
        love.graphics.print("◆", x + w - 20, yy + 3)
      end
      I.registrar(x, yy, w, alto - 4, "mision_sel_" .. q.id)
    end
    if maxScroll > 0 then
      love.graphics.setColor(0.65, 0.62, 0.55)
      love.graphics.print("Rueda del ratón para ver más (" .. (ini + 1) .. "-" .. math.min(#filas, ini + visibles) .. " de " .. #filas .. ")", x, y + visibles * alto)
    end
  end

  local function ordenar(filas, p)
    table.sort(filas, function(a, b)
      local ea, eb = ORDEN_ESTADO[Misiones.estado(p, a)] or 9, ORDEN_ESTADO[Misiones.estado(p, b)] or 9
      if ea ~= eb then return ea < eb end
      if (a.nivel or 1) ~= (b.nivel or 1) then return (a.nivel or 1) < (b.nivel or 1) end
      return a.id < b.id
    end)
  end

  -- ---------------------------------------------------------------------------------------------- tablón de un PNJ
  function I.panelMisiones(mundo, p, w, h)
    local npc = I.npcMision
    local info = npc and Misiones.npcs[npc]
    local bw, bh = 820, 540
    local px, py = w / 2 - bw / 2, math.max(20, (h - bh) / 2 - 10)
    caja(px, py, bw, bh, info and (info.nombre .. " — " .. info.lugar) or "Encargos")
    I.boton(px + bw - 70, py + 8, 60, 28, "Cerrar", "cerrar")
    local filas, bloqueadas = {}, 0
    for _, q in ipairs(Misiones.lista) do
      local est = Misiones.estado(p, q)
      local ofrece = q.npc == npc
      local recibe = q.destino == npc
      if est == "nueva" then
        if ofrece then
          local prev = q.requiere and p.misiones and p.misiones[q.requiere]
          if q.requiere and not (prev and prev.entregada) then bloqueadas = bloqueadas + 1 else filas[#filas + 1] = q end
        end
      elseif est ~= "entregada" and (ofrece or recibe) then
        filas[#filas + 1] = q
      end
    end
    ordenar(filas, p)
    local listaW = 330
    local yTop = py + 52
    local alto = bh - 52 - 40
    if #filas == 0 then
      love.graphics.setColor(0.75, 0.75, 0.7)
      love.graphics.printf("No tengo encargos para ti ahora mismo." .. (bloqueadas > 0 and (" Termina otras misiones y vuelve: me quedan " .. bloqueadas .. " más.") or ""), px + 20, yTop + 10, bw - 40, "left")
      return
    end
    -- la selección debe seguir en la lista
    local sel
    for _, q in ipairs(filas) do if q.id == I.misSel then sel = q end end
    if not sel then sel = filas[1] I.misSel = sel.id end
    lista(p, filas, px + 14, yTop, listaW, alto, sel.id, "misScroll")
    -- detalle y botones
    local dx = px + 14 + listaW + 16
    local dw = bw - listaW - 14 - 14 - 16
    local fin = detalle(p, sel, dx, yTop, dw)
    local est = Misiones.estado(p, sel)
    local by = py + bh - 52
    if est == "nueva" and sel.npc == npc then
      local motivo = Misiones.puedeAceptar(p, sel)
      I.boton(dx, by, 150, 34, "Aceptar", "mision_ok_" .. sel.id, motivo == nil, motivo)
    elseif est == "lista" and sel.destino == npc then
      I.boton(dx, by, 150, 34, "Entregar", "mision_fin_" .. sel.id)
    elseif est == "lista" then
      love.graphics.setColor(0.8, 0.8, 0.6)
      love.graphics.print("Entrégala a " .. Misiones.nombreNpc(sel.destino) .. ".", dx, by + 8)
    end
    if est == "activa" or est == "lista" then
      local siguiendo = Misiones.seguida == sel.id
      I.boton(dx + 160, by, 160, 34, siguiendo and "Dejar de seguir" or "Seguir en el mapa", siguiendo and "mision_noseguir" or ("mision_seguir_" .. sel.id))
    end
    if bloqueadas > 0 then
      love.graphics.setColor(0.6, 0.62, 0.7)
      love.graphics.print(bloqueadas .. " más se desbloquean al completar otras.", px + 14, py + bh - 30)
    end
  end

  -- ---------------------------------------------------------------------------------------------- diario (tecla Q)
  function I.panelDiario(mundo, p, w, h)
    local bw, bh = 820, 540
    local px, py = w / 2 - bw / 2, math.max(20, (h - bh) / 2 - 10)
    caja(px, py, bw, bh, "Diario de misiones")
    I.boton(px + bw - 70, py + 8, 60, 28, "Cerrar", "cerrar")
    local filas, hechas = {}, 0
    for id, st in pairs(p.misiones or {}) do
      local q = Misiones.por_id[id]
      if q then
        if st.entregada then hechas = hechas + 1
        elseif st.aceptada then filas[#filas + 1] = q end
      end
    end
    ordenar(filas, p)
    local listaW = 330
    local yTop = py + 52
    local alto = bh - 52 - 40
    love.graphics.setColor(0.7, 0.75, 0.85)
    love.graphics.print(#filas .. " en curso · " .. hechas .. " completadas · máximo " .. Misiones.MAX_ACTIVAS, px + 14, py + bh - 30)
    if #filas == 0 then
      love.graphics.setColor(0.75, 0.75, 0.7)
      love.graphics.printf("No tienes misiones en curso. Habla con los PNJ de las ciudades y de los puestos del mapa (los reconoces por el símbolo ! sobre su cabeza, y por los rombos del mapa).", px + 20, yTop + 10, bw - 40, "left")
      return
    end
    local sel
    for _, q in ipairs(filas) do if q.id == I.misSelDiario then sel = q end end
    if not sel then sel = filas[1] I.misSelDiario = sel.id end
    lista(p, filas, px + 14, yTop, listaW, alto, sel.id, "misScrollDiario")
    local dx = px + 14 + listaW + 16
    local dw = bw - listaW - 14 - 14 - 16
    detalle(p, sel, dx, yTop, dw)
    local by = py + bh - 52
    local siguiendo = Misiones.seguida == sel.id
    I.boton(dx, by, 150, 34, siguiendo and "Dejar de seguir" or "Seguir", siguiendo and "mision_noseguir" or ("mision_seguir_" .. sel.id))
    I.boton(dx + 158, by, 130, 34, "Ver en el mapa", "mision_mapa_" .. sel.id)
    local confirma = I.misAband == sel.id
    I.boton(dx + 296, by, 140, 34, confirma and "¿Seguro?" or "Abandonar", "mision_aband_" .. sel.id)
  end

  -- ---------------------------------------------------------------------------------------------- rastreador en pantalla
  -- Cuadro pequeño bajo tus barras con la misión que sigues, su avance y hacia dónde ir.
  function I.rastreoMision(mundo, p, x, y)
    local lista, q = I.destinosSeguidos(p)
    if not q then return end
    local est, st = Misiones.estado(p, q)
    local prog = Misiones.progreso(p, q, st)
    local f = love.graphics.getFont()
    local linea1 = q.titulo
    local linea2 = (est == "lista") and ("Entrega a " .. Misiones.nombreNpc(q.destino)) or ((q.tipo == "entregar") and ("Entrega a " .. Misiones.nombreNpc(q.destino)) or (textoObjetivo(q):gsub(" %(los suelta.*%)", "") .. "  [" .. prog .. "/" .. q.cantidad .. "]"))
    local linea3
    local d = lista and lista[1]
    if d then
      local dist, punto = direccion(p, d.x, d.y)
      linea3 = "→ " .. dist .. " casillas al " .. punto
    end
    local ancho = math.max(f:getWidth(linea1), f:getWidth(linea2), linea3 and f:getWidth(linea3) or 0) + 18
    ancho = math.min(ancho, 340)
    local alto = 22 + f:getHeight() * (linea3 and 3 or 2)
    love.graphics.setColor(0.04, 0.06, 0.12, 0.82)
    love.graphics.rectangle("fill", x, y, ancho, alto, 7, 7)
    love.graphics.setColor(1, 0.85, 0.3, 0.9)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, ancho - 1, alto - 1, 7, 7)
    love.graphics.setColor(1, 0.9, 0.55)
    love.graphics.print("◆ " .. linea1, x + 8, y + 4)
    love.graphics.setColor(est == "lista" and 0.55 or 0.9, est == "lista" and 1 or 0.9, est == "lista" and 0.55 or 0.9)
    love.graphics.print(linea2, x + 8, y + 4 + f:getHeight())
    if linea3 then
      love.graphics.setColor(0.7, 0.88, 1)
      love.graphics.print(linea3, x + 8, y + 4 + f:getHeight() * 2)
    end
    I.registrar(x, y, ancho, alto, "hud_diario")
  end

  -- ---------------------------------------------------------------------------------------------- marcas
  local function marca(tipo, x, y, r, pulso)
    if tipo == "npc" then
      love.graphics.setColor(0, 0, 0, 0.9)
      love.graphics.circle("fill", x, y, r + 1.5)
      love.graphics.setColor(1, 0.85, 0.2, 0.55 + 0.4 * pulso)
      love.graphics.circle("fill", x, y, r)
      love.graphics.setColor(0.1, 0.07, 0, 1)
      love.graphics.print("!", x - 2, y - 6)
    else
      love.graphics.setColor(0, 0, 0, 0.9)
      love.graphics.circle("line", x, y, r + 1.5)
      love.graphics.setColor(1, 0.3, 0.25, 0.6 + 0.4 * pulso)
      love.graphics.setLineWidth(2)
      love.graphics.circle("line", x, y, r)
      love.graphics.line(x - r - 2, y, x - r + 3, y)
      love.graphics.line(x + r - 3, y, x + r + 2, y)
      love.graphics.line(x, y - r - 2, x, y - r + 3)
      love.graphics.line(x, y + r - 3, x, y + r + 2)
      love.graphics.setLineWidth(1)
    end
  end

  -- Minimapa: la marca del destino si cae dentro, o una flecha dorada en el borde hacia donde queda.
  function I.marcasMinimapa(p, x, y, lado, x0, y0, k)
    local destinos = I.destinosSeguidos(p)
    if not destinos then return end
    local pulso = 0.5 + 0.5 * math.sin(love.timer.getTime() * 5)
    local cx, cy = x + lado / 2, y + lado / 2
    for _, d in ipairs(destinos) do
      local ex, ey = x + (d.x - x0) * k, y + (d.y - y0) * k
      if ex > x + 4 and ex < x + lado - 4 and ey > y + 4 and ey < y + lado - 4 then
        marca(d.tipo, ex, ey, 4 + pulso, pulso)
      else
        local ang = math.atan2(ey - cy, ex - cx)
        local ax, ay = cx + math.cos(ang) * (lado / 2 - 6), cy + math.sin(ang) * (lado / 2 - 6)
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.polygon("fill", ax + math.cos(ang) * 7, ay + math.sin(ang) * 7, ax + math.cos(ang + 2.5) * 6, ay + math.sin(ang + 2.5) * 6, ax + math.cos(ang - 2.5) * 6, ay + math.sin(ang - 2.5) * 6)
        love.graphics.setColor(1, 0.85, 0.2, 0.7 + 0.3 * pulso)
        love.graphics.polygon("fill", ax + math.cos(ang) * 5, ay + math.sin(ang) * 5, ax + math.cos(ang + 2.5) * 4, ay + math.sin(ang + 2.5) * 4, ax + math.cos(ang - 2.5) * 4, ay + math.sin(ang - 2.5) * 4)
      end
      break    -- en el minimapa solo el destino más cercano
    end
  end

  -- Mapa del mundo: todos los destinos de la misión seguida, con su nombre.
  function I.marcasMapa(p, aP)
    local destinos, q = I.destinosSeguidos(p)
    if not destinos then return end
    local pulso = 0.5 + 0.5 * math.sin(love.timer.getTime() * 5)
    local f = love.graphics.getFont()
    for _, d in ipairs(destinos) do
      local ex, ey = aP(d.x, d.y)
      marca(d.tipo, ex, ey, 7 + 2 * pulso, pulso)
      love.graphics.setColor(0, 0, 0, 0.75)
      local t = d.texto
      love.graphics.rectangle("fill", ex + 11, ey - 8, f:getWidth(t) + 8, f:getHeight() + 2, 4, 4)
      love.graphics.setColor(1, 0.92, 0.6)
      love.graphics.print(t, ex + 15, ey - 7)
    end
  end

  -- Selección y acciones de los botones (las llama Entrada.manejar). Devuelve true si el id era de misiones.
end

-- Flecha sobre el personaje hacia el destino de la misión seguida (se dibuja dentro de la vista del mundo, en píxeles de mundo).
function U.flechaMision(p, I, px, py)
  local destinos = I.destinosSeguidos and I.destinosSeguidos(p)
  if not destinos or not destinos[1] then return end
  local d = destinos[1]
  local dx, dy = d.x - p.x, d.y - p.y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 9 then return end
  local ang = math.atan2(dy, dx)
  local t = love.timer.getTime()
  local r = 46 + 2 * math.sin(t * 4)
  local ax, ay = px + math.cos(ang) * r, py - 10 + math.sin(ang) * r * 0.75
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.polygon("fill", ax + math.cos(ang) * 11, ay + math.sin(ang) * 11, ax + math.cos(ang + 2.4) * 8, ay + math.sin(ang + 2.4) * 8, ax + math.cos(ang - 2.4) * 8, ay + math.sin(ang - 2.4) * 8)
  love.graphics.setColor(1, 0.85, 0.2, 0.95)
  love.graphics.polygon("fill", ax + math.cos(ang) * 9, ay + math.sin(ang) * 9, ax + math.cos(ang + 2.4) * 6, ay + math.sin(ang + 2.4) * 6, ax + math.cos(ang - 2.4) * 6, ay + math.sin(ang - 2.4) * 6)
  local f = love.graphics.getFont()
  local txt = math.floor(dist + 0.5) .. ""
  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.print(txt, ax - f:getWidth(txt) / 2 + 1, ay + 11)
  love.graphics.setColor(1, 0.95, 0.7, 1)
  love.graphics.print(txt, ax - f:getWidth(txt) / 2, ay + 10)
end

U.direccion = direccion
return U
