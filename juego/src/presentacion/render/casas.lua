-- Detalle de las casas por código: aleros con sombra, tejas con su cumbrera, vigas y zócalo de piedra, ventanas con postigos
-- y brillo, y puerta con dintel, escalones y farol. Todo se hornea en el bloque de terreno (no se mueve).
local M = {}
local TILE = 32

local function hash(x, y, sal)
  local n = (x * 73856093 + y * 19349663 + (sal or 0) * 83492791) % 2147483647
  n = (n * 1103515245 + 12345) % 2147483647
  return (n % 10007) / 10007
end

local PALETA = {
  albor = {
    viga = { 0.34, 0.21, 0.11 }, vigaLuz = { 0.55, 0.38, 0.2 }, postigo = { 0.28, 0.46, 0.30 }, brillo = { 1, 0.84, 0.42 },
    zocalo = { 0.45, 0.43, 0.4 }, farol = { 1, 0.85, 0.4 },
  },
  umbra = {
    viga = { 0.16, 0.15, 0.21 }, vigaLuz = { 0.34, 0.32, 0.44 }, postigo = { 0.30, 0.22, 0.42 }, brillo = { 0.62, 0.52, 1 },
    zocalo = { 0.3, 0.3, 0.36 }, farol = { 0.6, 0.55, 1 },
  },
}

local function rect(c, a, x, y, w, h)
  love.graphics.setColor(c[1], c[2], c[3], a)
  love.graphics.rectangle("fill", x, y, w, h)
end

-- Sombra con degradado que baja desde arriba / sube desde abajo de la casilla.
local function sombraArriba(px, py, alto, a)
  for i = 0, alto - 1 do
    love.graphics.setColor(0.04, 0.02, 0.02, a * (1 - i / alto))
    love.graphics.rectangle("fill", px, py + i, TILE, 1)
  end
end

local function sombraAbajo(px, py, alto, a)
  for i = 0, alto - 1 do
    love.graphics.setColor(0.04, 0.02, 0.02, a * (1 - i / alto))
    love.graphics.rectangle("fill", px, py + TILE - 1 - i, TILE, 1)
  end
end

function M.fachada(e, ox, oy, solido, esTecho, cima, filasTecho, puertaX, puertaY)
  local pal = PALETA[e.faccion] or PALETA.albor
  local tienda = e.tienda ~= nil
  for fy = 0, e.h - 1 do
    for fx = 0, e.w - 1 do
      if solido(fx, fy) then
        local px = (e.x + fx) * TILE - ox
        local py = (e.y + fy) * TILE - oy
        local techo = esTecho(fx, fy)
        local arriba = solido(fx, fy - 1) and esTecho(fx, fy - 1)
        local abajo = solido(fx, fy + 1) and esTecho(fx, fy + 1)
        local izq, der = solido(fx - 1, fy), solido(fx + 1, fy)
        if techo then
          -- hiladas de tejas: junta horizontal cada 8 px y juntas verticales alternadas
          for k = 0, 3 do
            love.graphics.setColor(0, 0, 0, 0.16)
            love.graphics.rectangle("fill", px, py + k * 8 + 7, TILE, 1)
            love.graphics.setColor(1, 1, 1, 0.07)
            love.graphics.rectangle("fill", px, py + k * 8, TILE, 1)
            local off = (k % 2) * 8
            for jx = off, TILE - 1, 16 do
              love.graphics.setColor(0, 0, 0, 0.12)
              love.graphics.rectangle("fill", px + jx, py + k * 8, 1, 7)
            end
          end
          -- veteado: algunas tejas más claras u oscuras
          local r = hash(e.x + fx, e.y + fy, 11)
          if r < 0.3 then
            love.graphics.setColor(0, 0, 0, 0.09)
            love.graphics.rectangle("fill", px + (r * 90) % 20, py + 8 * math.floor(r * 40 % 4), 12, 8)
          elseif r > 0.8 then
            love.graphics.setColor(1, 0.9, 0.7, 0.08)
            love.graphics.rectangle("fill", px + (r * 70) % 18, py + 8 * math.floor(r * 40 % 4), 12, 8)
          end
          -- cumbrera y alero
          if not e.techoSur and not arriba then
            love.graphics.setColor(1, 0.95, 0.85, 0.30)
            love.graphics.rectangle("fill", px, py, TILE, 2)
            love.graphics.setColor(0, 0, 0, 0.25)
            love.graphics.rectangle("fill", px, py + 2, TILE, 1)
          end
          if e.techoSur and not abajo then
            love.graphics.setColor(0, 0, 0, 0.25)
            love.graphics.rectangle("fill", px, py + TILE - 3, TILE, 3)
            love.graphics.setColor(1, 0.95, 0.85, 0.18)
            love.graphics.rectangle("fill", px, py + TILE - 4, TILE, 1)
          end
          if not e.techoSur and not (solido(fx, fy + 1) and esTecho(fx, fy + 1)) then
            -- canto inferior del alero: oscuro, con su filo de luz
            love.graphics.setColor(0, 0, 0, 0.32)
            love.graphics.rectangle("fill", px, py + TILE - 3, TILE, 3)
            love.graphics.setColor(1, 0.9, 0.8, 0.15)
            love.graphics.rectangle("fill", px, py + TILE - 4, TILE, 1)
          end
          if not izq then
            love.graphics.setColor(0, 0, 0, 0.22)
            love.graphics.rectangle("fill", px, py, 2, TILE)
          end
          if not der then
            love.graphics.setColor(0, 0, 0, 0.28)
            love.graphics.rectangle("fill", px + TILE - 2, py, 2, TILE)
          end
        else
          -- pared: sombra del alero justo debajo del tejado
          if (not e.techoSur) and solido(fx, fy - 1) and esTecho(fx, fy - 1) then sombraArriba(px, py, 9, 0.5) end
          if e.techoSur and solido(fx, fy + 1) and esTecho(fx, fy + 1) then sombraAbajo(px, py, 9, 0.5) end
          -- vigas de las esquinas
          if not izq then
            rect(pal.viga, 1, px, py, 5, TILE)
            rect(pal.vigaLuz, 0.8, px + 1, py, 1, TILE)
          end
          if not der then
            rect(pal.viga, 1, px + TILE - 5, py, 5, TILE)
            rect(pal.vigaLuz, 0.6, px + TILE - 4, py, 1, TILE)
          end
          -- zócalo de piedra en la última fila
          if fy == e.h - 1 then
            rect(pal.zocalo, 1, px, py + TILE - 7, TILE, 7)
            love.graphics.setColor(0, 0, 0, 0.28)
            for k = 0, 1 do love.graphics.rectangle("fill", px + k * 16 + ((fx + e.x) % 2) * 5, py + TILE - 7, 1, 7) end
            love.graphics.rectangle("fill", px, py + TILE - 4, TILE, 1)
            love.graphics.setColor(1, 1, 1, 0.22)
            love.graphics.rectangle("fill", px, py + TILE - 7, TILE, 1)
          end
          -- manchas de humedad, con moderación
          local r = hash(e.x + fx, e.y + fy, 23)
          if r < 0.18 and fy ~= puertaY then
            love.graphics.setColor(0, 0, 0, 0.08)
            love.graphics.rectangle("fill", px + 6 + r * 40, py + 4, 8 + r * 20, 14)
          end
        end
      end
    end
  end
  -- friso: una viga horizontal entre las dos filas de fachada de las casas (las tiendas llevan rótulo y quedan limpias)
  if not tienda and not e.techoSur then
    for fx = 0, e.w - 1 do
      local fy = (e.cima and e.cima[fx + 1] or 0) + filasTecho
      if solido(fx, fy) and solido(fx, fy + 1) and not esTecho(fx, fy) then
        local px = (e.x + fx) * TILE - ox
        local py = (e.y + fy) * TILE - oy + TILE - 2
        rect(pal.viga, 0.9, px, py, TILE, 3)
        rect(pal.vigaLuz, 0.6, px, py, TILE, 1)
      end
    end
  end
  -- sombra proyectada a la derecha del edificio, como si la luz viniera de la izquierda
  for fy = 0, e.h - 1 do
    if solido(e.w - 1, fy) and not solido(e.w, fy) then
      local px = (e.x + e.w) * TILE - ox
      local py = (e.y + fy) * TILE - oy
      for i = 0, 5 do
        love.graphics.setColor(0, 0, 0, 0.16 * (1 - i / 6))
        love.graphics.rectangle("fill", px + i, py + 6, 1, TILE)
      end
    end
  end
end

-- Ventanas: postigos de madera, alféizar y un brillo cálido dentro del cristal.
function M.ventanas(e, ox, oy, solido, cima, filasTecho, puertaX)
  local pal = PALETA[e.faccion] or PALETA.albor
  for _, fx in ipairs({ 1, e.w - 2 }) do
    local fy = (e.cima and e.cima[fx + 1] or 0) + filasTecho
    if fx ~= puertaX and solido(fx, fy) and fy < e.h then
      local px = (e.x + fx) * TILE - ox
      local py = (e.y + fy) * TILE - oy
      love.graphics.setColor(pal.brillo[1], pal.brillo[2], pal.brillo[3], 0.20)
      love.graphics.rectangle("fill", px + 9, py + 7, 14, 14)
      love.graphics.setColor(1, 1, 1, 0.13)
      love.graphics.rectangle("fill", px + 10, py + 8, 5, 5)
      for lado = 0, 1 do
        local hx = px + (lado == 0 and 1 or 24)
        rect(pal.postigo, 1, hx, py + 5, 7, 18)
        love.graphics.setColor(0, 0, 0, 0.3)
        for k = 0, 3 do love.graphics.rectangle("fill", hx + 1, py + 7 + k * 4, 5, 1) end
        love.graphics.rectangle("line", hx + 0.5, py + 5.5, 6, 17)
        love.graphics.setColor(1, 1, 1, 0.18)
        love.graphics.rectangle("fill", hx + 1, py + 6, 5, 1)
      end
      rect(pal.zocalo, 1, px + 6, py + 23, 20, 3)
      rect({ 1, 1, 1 }, 0.25, px + 6, py + 23, 20, 1)
      rect({ 0, 0, 0 }, 0.3, px + 6, py + 26, 20, 1)
    end
  end
end

-- Puerta: jambas y dintel de piedra, escalones, felpudo y un farol al lado.
function M.puerta(e, dx, dy)
  local pal = PALETA[e.faccion] or PALETA.albor
  if e.estilo == "establo" then return end
  rect(pal.zocalo, 1, dx + 3, dy + 3, 3, TILE - 3)
  rect(pal.zocalo, 1, dx + 26, dy + 3, 3, TILE - 3)
  rect(pal.zocalo, 1, dx + 2, dy + 1, 28, 4)
  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.rectangle("fill", dx + 3, dy + 5, 26, 1)
  love.graphics.setColor(1, 1, 1, 0.28)
  love.graphics.rectangle("fill", dx + 2, dy + 1, 28, 1)
  for k = 0, 2 do
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.rectangle("fill", dx + 7 + k * 8, dy + 1, 1, 4)
  end
  local sur = not e.techoSur
  local sy = sur and (dy + TILE) or (dy - 6)
  rect(pal.zocalo, 1, dx + 3, sy, 26, 3)
  rect({ 1, 1, 1 }, 0.25, dx + 3, sy, 26, 1)
  rect({ 0, 0, 0 }, 0.3, dx + 3, sy + 2, 26, 1)
  rect(pal.zocalo, 1, dx + 1, sy + (sur and 3 or -3), 30, 3)
  rect({ 0, 0, 0 }, 0.3, dx + 1, sy + (sur and 5 or -1), 30, 1)
  if e.tienda == nil then
    local f = hash(e.x, e.y, 5)
    local c = f < 0.33 and { 0.55, 0.15, 0.15 } or f < 0.66 and { 0.2, 0.35, 0.55 } or { 0.45, 0.35, 0.15 }
    rect(c, 0.9, dx + 10, sy, 12, 2)
  end
  local lx = (hash(e.x, e.y, 9) < 0.5) and (dx + 31) or (dx - 3)
  rect({ 0.12, 0.1, 0.1 }, 1, lx, dy + 6, 2, 4)
  love.graphics.setColor(pal.farol[1], pal.farol[2], pal.farol[3], 0.30)
  love.graphics.circle("fill", lx + 1, dy + 13, 7)
  love.graphics.setColor(pal.farol[1], pal.farol[2], pal.farol[3], 1)
  love.graphics.rectangle("fill", lx - 1, dy + 10, 4, 6, 1, 1)
  love.graphics.setColor(1, 1, 1, 0.7)
  love.graphics.rectangle("fill", lx, dy + 11, 1, 3)
end

-- Dónde brillan las ventanas de un edificio (casillas del mundo) y dónde está su farol: lo usa el ambiente para la luz de noche.
function M.ventanasPos(e)
  local lista = {}
  if e.estilo == "establo" then return lista end
  local filasTecho = e.techo or 2
  for _, fx in ipairs({ 1, e.w - 2 }) do
    local fy = (e.cima and e.cima[fx + 1] or 0) + filasTecho
    if fx ~= (e.puertaX - e.x) and fy < e.h and not (e.vacio and e.vacio[fx .. "," .. fy]) then
      lista[#lista + 1] = { x = e.x + fx + 0.5, y = e.y + fy + 0.5 }
    end
  end
  return lista
end

function M.farolPos(e)
  if e.estilo == "establo" then return nil end
  local lx = (hash(e.x, e.y, 9) < 0.5) and (e.puertaX * TILE + 31) or (e.puertaX * TILE - 3)
  return (lx + 1) / TILE, e.puertaY + 13 / TILE
end

-- Chimenea: solo algunas casas (no las tiendas). Devuelve su casilla (fx, fy) dentro del edificio o nil.
function M.chimenea(e)
  if e.tienda ~= nil or e.estilo == "establo" or e.techoSur or e.w < 4 then return nil end
  if hash(e.x, e.y, 31) > 0.55 then return nil end
  local fx = 1 + math.floor(hash(e.x, e.y, 32) * (e.w - 2))
  local fy = (e.cima and e.cima[fx + 1] or 0)
  return fx, fy
end

local function dibujarChimenea(e, ox, oy)
  local fx, fy = M.chimenea(e)
  if not fx then return end
  local pal = PALETA[e.faccion] or PALETA.albor
  local px = (e.x + fx) * TILE - ox + 17
  local py = (e.y + fy) * TILE - oy + 1
  rect({ 0.25, 0.2, 0.2 }, 0.35, px - 2, py + 10, 14, 5)
  rect({ 0.42, 0.28, 0.24 }, 1, px, py, 10, 14)
  love.graphics.setColor(0, 0, 0, 0.25)
  love.graphics.rectangle("fill", px, py + 4, 10, 1)
  love.graphics.rectangle("fill", px, py + 9, 10, 1)
  love.graphics.rectangle("fill", px + 5, py + 5, 1, 4)
  love.graphics.rectangle("fill", px + 2, py + 10, 1, 4)
  rect({ 1, 1, 1 }, 0.2, px, py, 1, 14)
  rect(pal.zocalo, 1, px - 1, py - 2, 12, 3)
  rect({ 0.05, 0.04, 0.04 }, 1, px + 2, py - 1, 6, 2)
end
M.dibujarChimenea = dibujarChimenea

-- Humo de las chimeneas cercanas (se dibuja cada cuadro, no va en el bloque horneado).
function M.humo(mapa, cam, tiempo, jx, jy, radio)
  for _, e in ipairs(mapa.edificios or {}) do
    if math.abs(e.x + e.w / 2 - jx) < radio + 4 and math.abs(e.y + e.h / 2 - jy) < radio + 4 then
      local fx, fy = M.chimenea(e)
      if fx then
        local bx = (e.x + fx) * TILE + 22 - cam.x
        local by = (e.y + fy) * TILE - 4 - cam.y
        for k = 0, 4 do
          local t = ((tiempo * 0.35) + k / 5 + hash(e.x, e.y, 40) ) % 1
          local x = bx + math.sin(t * 6 + k) * 3 + t * 9
          local y = by - t * 34
          love.graphics.setColor(0.85, 0.85, 0.88, 0.45 * (1 - t))
          love.graphics.circle("fill", x, y, 2.5 + t * 5)
        end
      end
    end
  end
end

return M
