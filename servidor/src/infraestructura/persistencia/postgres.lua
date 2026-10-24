-- Adaptador de PostgreSQL para el puerto de almacén (cuentas y personajes).
local Pg = require("src.infraestructura.persistencia.pg")
local Util = require("compartido.dominio.util")
local Datos = require("compartido.dominio.datos")
local Config = require("src.infraestructura.config")
local Credenciales = require("src.aplicacion.credenciales")
local aleatorio = require("src.infraestructura.aleatorio")
local Sanciones = require("compartido.dominio.sanciones")

local M = { nombre = "postgres" }

M.host = Config.postgres.host
M.puerto = Config.postgres.puerto
M.usuario = Config.postgres.usuario
M.base = Config.postgres.base
M.clave = Config.postgres.clave

local usuarioValido, nombreValido = Credenciales.usuarioValido, Credenciales.nombreValido

local function salNueva()
  return aleatorio(16)
end

-- ---------------------------------------------------------------------------
-- Personaje normalizado: una fila en `personajes` y una tabla por cada lista
-- (equipo, bolsa, misiones, casas, cofres, cacería). Se guarda entero en un solo
-- mensaje a Postgres, que lo ejecuta como una transacción: o queda todo o nada.
-- ---------------------------------------------------------------------------
local function entero(v)
  v = tonumber(v) or 0
  if v ~= v or v == math.huge or v == -math.huge then return 0 end
  return math.floor(v)
end

local function real(v)
  v = tonumber(v) or 0
  if v ~= v or v == math.huge or v == -math.huge then return 0 end
  return string.format("%.4f", v)
end

local function ordenadas(t)
  local claves = {}
  for k in pairs(t or {}) do claves[#claves + 1] = tostring(k) end
  table.sort(claves)
  return claves
end

-- `ex` es lo que exporta el mundo (Mundo:exportar); hp y mp pueden faltar.
local function sentenciasDe(pid, ex, hp, mp)
  pid = tonumber(pid)
  local q = {}
  local function cada(tabla, columnas, filas)
    q[#q + 1] = "DELETE FROM " .. tabla .. " WHERE personaje_id = " .. pid
    if #filas > 0 then
      q[#q + 1] = "INSERT INTO " .. tabla .. " (personaje_id, " .. columnas .. ") VALUES " .. table.concat(filas, ",")
    end
  end
  local v = type(ex.vinculo) == "table" and ex.vinculo or {}
  local sets = {
    "nivel=" .. entero(ex.nivel or 1), "xp=" .. entero(ex.xp), "oro=" .. entero(ex.oro), "monedas=" .. entero(ex.monedas), "regalo_mall=" .. Pg.literal(ex.regaloMall and true or false),
    "x=" .. real(ex.x), "y=" .. real(ex.y), "z=" .. entero(ex.z),
    "modo=" .. Pg.literal(ex.modo or "mundo"),
    "vinculo_modo=" .. (v.x and Pg.literal(v.ciudad and ("ciudad:" .. v.ciudad) or v.modo or "mundo") or "NULL"),
    "vinculo_x=" .. (v.x and real(v.x) or "NULL"), "vinculo_y=" .. (v.y and real(v.y) or "NULL"),
    "guardado=TRUE",
    "diaria_ultimo=" .. ((type(ex.diaria) == "table" and ex.diaria.ultimo) and Pg.literal(ex.diaria.ultimo) or "NULL"),
    "diaria_racha=" .. entero(type(ex.diaria) == "table" and ex.diaria.racha or 0),
    "autopocion=" .. Pg.literal(ex.autoPocion and true or false),
    "autopocion_umbral=" .. entero((tonumber(ex.autoPocionUmbral) or 0.5) * 100 + 0.5),
    "automana=" .. Pg.literal(ex.autoMana and true or false),
    "automana_umbral=" .. entero((tonumber(ex.autoManaUmbral) or 0.5) * 100 + 0.5),
  }
  if hp then sets[#sets + 1] = "hp=" .. entero(hp) end
  if mp then sets[#sets + 1] = "mp=" .. entero(mp) end
  q[#q + 1] = "UPDATE personajes SET " .. table.concat(sets, ", ") .. " WHERE id=" .. pid

  local filas = {}
  for _, hueco in ipairs(ordenadas(ex.equipo)) do
    filas[#filas + 1] = "(" .. pid .. "," .. Pg.literal(hueco) .. "," .. Pg.literal(ex.equipo[hueco]) .. "," ..
      entero(ex.encantos and ex.encantos[hueco]) .. ")"
  end
  cada("personaje_equipo", "hueco, item_id, enc", filas)

  filas = {}
  for i, s in ipairs(ex.bolsa or {}) do
    filas[#filas + 1] = "(" .. pid .. "," .. i .. "," .. Pg.literal(s.id) .. "," .. math.max(1, entero(s.cant or 1)) ..
      "," .. entero(s.enc) .. ")"
  end
  cada("personaje_bolsa", "ranura, item_id, cant, enc", filas)

  filas = {}
  for _, id in ipairs(ordenadas(ex.misiones)) do
    local m = ex.misiones[id]
    filas[#filas + 1] = "(" .. pid .. "," .. Pg.literal(id) .. "," .. entero(m.progreso) .. "," ..
      Pg.literal(m.aceptada and true or false) .. "," .. Pg.literal(m.entregada and true or false) .. ")"
  end
  cada("personaje_mision", "mision_id, progreso, aceptada, entregada", filas)

  if ex.mascotas then
    filas = {}
    for i, m in ipairs(ex.mascotas) do
      filas[#filas + 1] = "(" .. pid .. "," .. i .. "," .. Pg.literal(m.especie) .. "," .. math.max(1, entero(m.nivel)) .. "," ..
        entero(m.xp) .. "," .. Pg.literal(ex.mascotaActiva == i or ex.recolectoraActiva == i) .. ")"
    end
    cada("personaje_mascota", "slot, especie, nivel, xp, activa", filas)
  end

  if ex.oficios or ex.job then
    filas = {}
    for _, id in ipairs(ordenadas(ex.oficios)) do
      local o = ex.oficios[id]
      filas[#filas + 1] = "(" .. pid .. "," .. Pg.literal(id) .. "," .. math.max(1, entero(o.nivel)) .. "," .. entero(o.xp) .. "," ..
        Pg.literal(ex.job == id) .. ")"
    end
    cada("personaje_oficio", "oficio, nivel, xp, actual", filas)
    filas = {}
    for _, bien in ipairs(ordenadas(ex.carga)) do
      if entero(ex.carga[bien]) > 0 then filas[#filas + 1] = "(" .. pid .. "," .. Pg.literal(bien) .. "," .. entero(ex.carga[bien]) .. ",FALSE)" end
    end
    for _, bien in ipairs(ordenadas(ex.cargaRobada)) do
      if entero(ex.cargaRobada[bien]) > 0 then filas[#filas + 1] = "(" .. pid .. "," .. Pg.literal(bien) .. "," .. entero(ex.cargaRobada[bien]) .. ",TRUE)" end
    end
    cada("personaje_carga", "bien, cant, robado", filas)
    filas = {}
    for _, tipo in ipairs(ex.monturas or {}) do
      filas[#filas + 1] = "(" .. pid .. "," .. Pg.literal(tipo) .. "," .. Pg.literal(ex.monturaPreferida == tipo) .. ")"
    end
    cada("personaje_montura", "tipo, preferida", filas)
  end

  -- item mall: addons comprados y bonos con su fin (hora Unix)
  filas = {}
  for _, id in ipairs(ordenadas(ex.addons)) do
    filas[#filas + 1] = "(" .. pid .. "," .. Pg.literal(id) .. "," .. Pg.literal(ex.addonActivo == id) .. ")"
  end
  cada("personaje_addon", "addon, activo", filas)
  filas = {}
  for _, r in ipairs(ordenadas(ex.aparienciaSlots)) do
    filas[#filas + 1] = "(" .. pid .. "," .. Pg.literal(r) .. "," .. Pg.literal(ex.aparienciaSlots[r]) .. ")"
  end
  cada("personaje_apariencia", "ranura, set_id", filas)
  filas = {}
  for _, id in ipairs(ordenadas(ex.bonos)) do
    filas[#filas + 1] = "(" .. pid .. "," .. Pg.literal(id) .. "," .. entero(ex.bonos[id]) .. ")"
  end
  cada("personaje_bono", "bono, fin", filas)

  if ex.habilidades then
    filas = {}
    for _, id in ipairs(ordenadas(ex.habilidades)) do
      filas[#filas + 1] = "(" .. pid .. "," .. Pg.literal(id) .. "," .. math.max(1, entero(ex.habilidades[id])) .. ")"
    end
    cada("personaje_habilidad", "habilidad_id, rango", filas)
  end

  filas = {}
  for id, n in pairs(ex.caceria or {}) do
    filas[#filas + 1] = "(" .. pid .. "," .. Pg.literal(id) .. "," .. entero(n) .. ")"
  end
  cada("personaje_caceria", "monstruo_id, cantidad", filas)

  -- Las casas se reescriben enteras; borrar personaje_casa arrastra muebles y cofre.
  q[#q + 1] = "DELETE FROM personaje_casa WHERE personaje_id = " .. pid
  local muebles, cofres = {}, {}
  local casas = {}
  for _, parcela in ipairs(ordenadas(ex.casas)) do
    local c = ex.casas[parcela]
    casas[#casas + 1] = "(" .. pid .. "," .. Pg.literal(parcela) .. ")"
    for _, mueble in ipairs(ordenadas(c.muebles)) do
      local v = c.muebles[mueble]
      local x, y, rot = "NULL", "NULL", 0
      if type(v) == "table" then
        x, y, rot = real(v.x), real(v.y), entero(v.rot) % 4
      end
      muebles[#muebles + 1] = "(" .. pid .. "," .. Pg.literal(parcela) .. "," .. Pg.literal(mueble) .. "," .. x .. "," .. y .. "," .. rot .. ")"
    end
    for i, s in ipairs(c.cofre or {}) do
      cofres[#cofres + 1] = "(" .. pid .. "," .. Pg.literal(parcela) .. "," .. i .. "," ..
        Pg.literal(s.id) .. "," .. math.max(1, entero(s.cant or 1)) .. "," .. entero(s.enc) .. ")"
    end
  end
  if #casas > 0 then
    q[#q + 1] = "INSERT INTO personaje_casa (personaje_id, parcela_id) VALUES " .. table.concat(casas, ",")
  end
  if #muebles > 0 then
    q[#q + 1] = "INSERT INTO casa_mueble (personaje_id, parcela_id, mueble, x, y, rot) VALUES " .. table.concat(muebles, ",")
  end
  if #cofres > 0 then
    q[#q + 1] = "INSERT INTO casa_cofre (personaje_id, parcela_id, ranura, item_id, cant, enc) VALUES " .. table.concat(cofres, ",")
  end
  return table.concat(q, ";\n")
end

-- Personajes guardados con la versión antigua (todo en la columna `datos`, en JSON)
-- se pasan a las tablas la primera vez. La columna `datos` se deja como copia.
local migrado = false
function M.migrar(conn)
  if migrado then return end
  local filas = conn:consulta("SELECT id, datos FROM personajes WHERE guardado = FALSE AND datos <> '{}' AND datos <> ''")
  if not filas then return end
  for _, row in ipairs(filas) do
    local ex = Util.jsonDec(row.datos)
    if type(ex) == "table" and next(ex) then
      local _, err = conn:consulta(sentenciasDe(row.id, ex))
      if err then require("compartido.infraestructura.log").warn("migración del personaje " .. row.id .. ": " .. err) end
    end
  end
  migrado = true
end
function M.abrir()
  local conn, err = Pg.conectar(M.host, M.puerto, M.usuario, M.base, M.clave)
  if not conn then return nil, err end
  local _, e = conn:consulta([[
    CREATE TABLE IF NOT EXISTS cuentas (
      id BIGSERIAL PRIMARY KEY,
      usuario TEXT UNIQUE NOT NULL,
      sal TEXT NOT NULL,
      clave TEXT NOT NULL,
      creada TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS personajes (
      id BIGSERIAL PRIMARY KEY,
      cuenta_id BIGINT NOT NULL REFERENCES cuentas(id) ON DELETE CASCADE,
      nombre TEXT UNIQUE NOT NULL,
      faccion TEXT NOT NULL,
      clase TEXT NOT NULL,
      nivel INT NOT NULL DEFAULT 1,
      xp INT NOT NULL DEFAULT 0,
      oro INT NOT NULL DEFAULT 140,
      x DOUBLE PRECISION NOT NULL DEFAULT 0,
      y DOUBLE PRECISION NOT NULL DEFAULT 0,
      hp INT NOT NULL DEFAULT 1,
      mp INT NOT NULL DEFAULT 1,
      datos TEXT NOT NULL DEFAULT '{}',
      creada TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    ALTER TABLE cuentas ADD COLUMN IF NOT EXISTS rol TEXT;
    ALTER TABLE cuentas ADD COLUMN IF NOT EXISTS ban_desde BIGINT;
    ALTER TABLE cuentas ADD COLUMN IF NOT EXISTS ban_hasta BIGINT;
    ALTER TABLE cuentas ADD COLUMN IF NOT EXISTS ban_motivo TEXT;
    ALTER TABLE cuentas ADD COLUMN IF NOT EXISTS ban_por TEXT;
    ALTER TABLE personajes ADD COLUMN IF NOT EXISTS diaria_ultimo TEXT;
    ALTER TABLE personajes ADD COLUMN IF NOT EXISTS diaria_racha INT NOT NULL DEFAULT 0;
    ALTER TABLE personajes ADD COLUMN IF NOT EXISTS guardado BOOLEAN NOT NULL DEFAULT FALSE;
    ALTER TABLE personajes ADD COLUMN IF NOT EXISTS modo TEXT NOT NULL DEFAULT 'mundo';
    ALTER TABLE personajes ADD COLUMN IF NOT EXISTS z INT NOT NULL DEFAULT 0;
    ALTER TABLE personajes ADD COLUMN IF NOT EXISTS monedas INT NOT NULL DEFAULT 0;
    ALTER TABLE personajes ADD COLUMN IF NOT EXISTS regalo_mall BOOLEAN NOT NULL DEFAULT FALSE;
    ALTER TABLE personajes ADD COLUMN IF NOT EXISTS autopocion BOOLEAN NOT NULL DEFAULT FALSE;
    ALTER TABLE personajes ADD COLUMN IF NOT EXISTS autopocion_umbral INT NOT NULL DEFAULT 50;
    ALTER TABLE personajes ADD COLUMN IF NOT EXISTS automana BOOLEAN NOT NULL DEFAULT FALSE;
    ALTER TABLE personajes ADD COLUMN IF NOT EXISTS automana_umbral INT NOT NULL DEFAULT 50;
    CREATE TABLE IF NOT EXISTS personaje_addon (
      personaje_id BIGINT NOT NULL REFERENCES personajes(id) ON DELETE CASCADE,
      addon TEXT NOT NULL,
      activo BOOLEAN NOT NULL DEFAULT FALSE,
      PRIMARY KEY (personaje_id, addon)
    );
    CREATE TABLE IF NOT EXISTS personaje_apariencia (
      personaje_id BIGINT NOT NULL REFERENCES personajes(id) ON DELETE CASCADE,
      ranura TEXT NOT NULL,
      set_id TEXT NOT NULL,
      PRIMARY KEY (personaje_id, ranura)
    );
    CREATE TABLE IF NOT EXISTS personaje_bono (
      personaje_id BIGINT NOT NULL REFERENCES personajes(id) ON DELETE CASCADE,
      bono TEXT NOT NULL,
      fin BIGINT NOT NULL,
      PRIMARY KEY (personaje_id, bono)
    );
    ALTER TABLE personajes ADD COLUMN IF NOT EXISTS genero TEXT NOT NULL DEFAULT 'h';
    ALTER TABLE personajes ADD COLUMN IF NOT EXISTS vinculo_modo TEXT;
    ALTER TABLE personajes ADD COLUMN IF NOT EXISTS vinculo_x DOUBLE PRECISION;
    ALTER TABLE personajes ADD COLUMN IF NOT EXISTS vinculo_y DOUBLE PRECISION;
    CREATE TABLE IF NOT EXISTS personaje_equipo (
      personaje_id BIGINT NOT NULL REFERENCES personajes(id) ON DELETE CASCADE,
      hueco TEXT NOT NULL,
      item_id TEXT NOT NULL,
      PRIMARY KEY (personaje_id, hueco)
    );
    CREATE TABLE IF NOT EXISTS personaje_bolsa (
      personaje_id BIGINT NOT NULL REFERENCES personajes(id) ON DELETE CASCADE,
      ranura INT NOT NULL CHECK (ranura >= 1),
      item_id TEXT NOT NULL,
      cant INT NOT NULL DEFAULT 1 CHECK (cant >= 1),
      PRIMARY KEY (personaje_id, ranura)
    );
    CREATE TABLE IF NOT EXISTS personaje_mision (
      personaje_id BIGINT NOT NULL REFERENCES personajes(id) ON DELETE CASCADE,
      mision_id TEXT NOT NULL,
      progreso INT NOT NULL DEFAULT 0,
      aceptada BOOLEAN NOT NULL DEFAULT TRUE,
      entregada BOOLEAN NOT NULL DEFAULT FALSE,
      PRIMARY KEY (personaje_id, mision_id)
    );
    CREATE TABLE IF NOT EXISTS personaje_casa (
      personaje_id BIGINT NOT NULL REFERENCES personajes(id) ON DELETE CASCADE,
      parcela_id TEXT NOT NULL,
      PRIMARY KEY (personaje_id, parcela_id)
    );
    CREATE TABLE IF NOT EXISTS casa_mueble (
      personaje_id BIGINT NOT NULL,
      parcela_id TEXT NOT NULL,
      mueble TEXT NOT NULL,
      x DOUBLE PRECISION,
      y DOUBLE PRECISION,
      rot INT NOT NULL DEFAULT 0,
      PRIMARY KEY (personaje_id, parcela_id, mueble),
      FOREIGN KEY (personaje_id, parcela_id) REFERENCES personaje_casa ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS casa_cofre (
      personaje_id BIGINT NOT NULL,
      parcela_id TEXT NOT NULL,
      ranura INT NOT NULL CHECK (ranura >= 1),
      item_id TEXT NOT NULL,
      cant INT NOT NULL DEFAULT 1 CHECK (cant >= 1),
      PRIMARY KEY (personaje_id, parcela_id, ranura),
      FOREIGN KEY (personaje_id, parcela_id) REFERENCES personaje_casa ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS personaje_habilidad (
      personaje_id BIGINT NOT NULL REFERENCES personajes(id) ON DELETE CASCADE,
      habilidad_id TEXT NOT NULL,
      rango INT NOT NULL CHECK (rango >= 1),
      PRIMARY KEY (personaje_id, habilidad_id)
    );
    CREATE TABLE IF NOT EXISTS personaje_mascota (
      personaje_id BIGINT NOT NULL REFERENCES personajes(id) ON DELETE CASCADE,
      slot INT NOT NULL CHECK (slot >= 1),
      especie TEXT NOT NULL,
      nivel INT NOT NULL DEFAULT 1,
      xp INT NOT NULL DEFAULT 0,
      activa BOOLEAN NOT NULL DEFAULT FALSE,
      PRIMARY KEY (personaje_id, slot)
    );
    CREATE TABLE IF NOT EXISTS personaje_oficio (
      personaje_id BIGINT NOT NULL REFERENCES personajes(id) ON DELETE CASCADE,
      oficio TEXT NOT NULL CHECK (oficio IN ('trader', 'hunter', 'thief')),
      nivel INT NOT NULL DEFAULT 1,
      xp INT NOT NULL DEFAULT 0,
      actual BOOLEAN NOT NULL DEFAULT FALSE,
      PRIMARY KEY (personaje_id, oficio)
    );
    CREATE TABLE IF NOT EXISTS personaje_carga (
      personaje_id BIGINT NOT NULL REFERENCES personajes(id) ON DELETE CASCADE,
      bien TEXT NOT NULL,
      cant INT NOT NULL CHECK (cant >= 1),
      robado BOOLEAN NOT NULL DEFAULT FALSE,
      PRIMARY KEY (personaje_id, bien, robado)
    );
    CREATE TABLE IF NOT EXISTS personaje_montura (
      personaje_id BIGINT NOT NULL REFERENCES personajes(id) ON DELETE CASCADE,
      tipo TEXT NOT NULL,
      preferida BOOLEAN NOT NULL DEFAULT FALSE,
      PRIMARY KEY (personaje_id, tipo)
    );
    CREATE TABLE IF NOT EXISTS personaje_caceria (
      personaje_id BIGINT NOT NULL REFERENCES personajes(id) ON DELETE CASCADE,
      monstruo_id TEXT NOT NULL,
      cantidad INT NOT NULL DEFAULT 0,
      PRIMARY KEY (personaje_id, monstruo_id)
    );
    CREATE TABLE IF NOT EXISTS evento_diario (
      personaje_id BIGINT NOT NULL REFERENCES personajes(id) ON DELETE CASCADE,
      tipo TEXT NOT NULL,
      dia DATE NOT NULL,
      PRIMARY KEY (personaje_id, tipo, dia)
    );
    CREATE TABLE IF NOT EXISTS sesion_juego (
      token TEXT PRIMARY KEY,
      cuenta_id BIGINT NOT NULL REFERENCES cuentas(id) ON DELETE CASCADE,
      expira TIMESTAMPTZ NOT NULL
    );
    CREATE TABLE IF NOT EXISTS intento_login (
      usuario TEXT PRIMARY KEY,
      fallos INT NOT NULL DEFAULT 0,
      hasta TIMESTAMPTZ
    );
    CREATE TABLE IF NOT EXISTS gremio (
      id BIGINT PRIMARY KEY,
      nombre TEXT UNIQUE NOT NULL,
      etiqueta TEXT UNIQUE NOT NULL,
      faccion TEXT NOT NULL,
      creado TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS gremio_miembro (
      gremio_id BIGINT NOT NULL REFERENCES gremio(id) ON DELETE CASCADE,
      personaje_id BIGINT PRIMARY KEY REFERENCES personajes(id) ON DELETE CASCADE,
      rango TEXT NOT NULL CHECK (rango IN ('lider', 'oficial', 'miembro'))
    );
    CREATE TABLE IF NOT EXISTS subasta (
      id BIGINT PRIMARY KEY,
      vendedor_id BIGINT NOT NULL REFERENCES personajes(id) ON DELETE CASCADE,
      vendedor_nombre TEXT NOT NULL,
      item_id TEXT NOT NULL,
      cant INT NOT NULL CHECK (cant >= 1),
      enc INT NOT NULL DEFAULT 0,
      salida BIGINT NOT NULL,
      compra BIGINT,
      oferta BIGINT NOT NULL DEFAULT 0,
      postor_id BIGINT,
      postor_nombre TEXT,
      creada BIGINT NOT NULL,
      termina BIGINT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS subasta_buzon (
      id BIGSERIAL PRIMARY KEY,
      personaje_id BIGINT NOT NULL REFERENCES personajes(id) ON DELETE CASCADE,
      item_id TEXT,
      cant INT,
      enc INT NOT NULL DEFAULT 0,
      oro BIGINT NOT NULL DEFAULT 0,
      nota TEXT
    );
    ALTER TABLE personaje_equipo ADD COLUMN IF NOT EXISTS enc INT NOT NULL DEFAULT 0;
    ALTER TABLE personaje_bolsa ADD COLUMN IF NOT EXISTS enc INT NOT NULL DEFAULT 0;
    ALTER TABLE casa_cofre ADD COLUMN IF NOT EXISTS enc INT NOT NULL DEFAULT 0;
    ALTER TABLE casa_mueble ADD COLUMN IF NOT EXISTS x DOUBLE PRECISION;
    ALTER TABLE casa_mueble ADD COLUMN IF NOT EXISTS y DOUBLE PRECISION;
    ALTER TABLE casa_mueble ADD COLUMN IF NOT EXISTS rot INT NOT NULL DEFAULT 0;
  ]])
  if e then conn:cerrar() return nil, e end
  M.migrar(conn)
  return conn
end

local function con(fn)
  local conn, err = M.abrir()
  if not conn then return nil, err end
  local a, b, c = fn(conn)
  conn:cerrar()
  return a, b, c
end

local function tokenNuevo()
  return aleatorio(24)
end

local function abrirSesion(conn, cuentaId)
  local token = tokenNuevo()
  local filas, err = conn:consulta(
    "INSERT INTO sesion_juego (token, cuenta_id, expira) VALUES (" ..
    Pg.literal(token) .. "," .. tonumber(cuentaId) .. ", now() + interval '12 hours')"
  )
  if not filas then return nil, err end
  return token
end

function M.registrar(usuario, clave)
  if not usuarioValido(usuario) then return nil, "El usuario usa 3 a 16 letras, números o _." end
  if type(clave) ~= "string" or #clave < 4 or #clave > 64 then return nil, "La clave necesita entre 4 y 64 caracteres." end
  return con(function(conn)
    local ya = conn:consulta("SELECT id FROM cuentas WHERE usuario = " .. Pg.literal(usuario))
    if not ya then return nil, "No se pudo crear la cuenta." end
    if ya[1] then return nil, "Ese usuario ya está registrado." end
    local sal = salNueva()
    local hash = Credenciales.cifrar(clave, sal)
    local filas, err = conn:consulta(
      "INSERT INTO cuentas (usuario, sal, clave) VALUES (" ..
      Pg.literal(usuario) .. "," .. Pg.literal(sal) .. "," .. Pg.literal(hash) .. ") RETURNING id"
    )
    if not filas or not filas[1] then return nil, err or "No se pudo crear la cuenta." end
    local token, terr = abrirSesion(conn, filas[1].id)
    if not token then return nil, terr or "No se pudo abrir la sesión." end
    return tonumber(filas[1].id), token
  end)
end

function M.entrar(usuario, clave)
  if not usuarioValido(usuario) then return nil, "Usuario o clave incorrectos." end
  return con(function(conn)
    local bloque = conn:consulta(
      "SELECT fallos FROM intento_login WHERE usuario = " .. Pg.literal(usuario) ..
      " AND fallos >= 5 AND hasta IS NOT NULL AND hasta > now()"
    )
    if not bloque then return nil, "No se pudo comprobar la cuenta." end
    if bloque[1] then return nil, "Demasiados intentos. Espera un minuto." end
    local filas, err = conn:consulta("SELECT id, sal, clave, ban_desde, ban_hasta, ban_motivo, ban_por FROM cuentas WHERE usuario = " .. Pg.literal(usuario))
    if not filas then return nil, err end
    local row = filas[1]
    local acepta, migrar = false, false
    if row then acepta, migrar = Credenciales.acepta(row.clave, row.sal, clave or "") end
    if not acepta then
      conn:consulta(
        "INSERT INTO intento_login (usuario, fallos, hasta) VALUES (" .. Pg.literal(usuario) .. [[, 1, NULL)
        ON CONFLICT (usuario) DO UPDATE SET
          fallos = intento_login.fallos + 1,
          hasta = CASE WHEN intento_login.fallos + 1 >= 5 THEN now() + interval '60 seconds' ELSE NULL END]]
      )
      return nil, "Usuario o clave incorrectos."
    end
    conn:consulta(
      "INSERT INTO intento_login (usuario, fallos, hasta) VALUES (" .. Pg.literal(usuario) ..
      ", 0, NULL) ON CONFLICT (usuario) DO UPDATE SET fallos = 0, hasta = NULL"
    )
    if row.ban_desde and row.ban_desde ~= "" then
      local ban = { hasta = tonumber(row.ban_hasta) or 0, motivo = row.ban_motivo, por = row.ban_por }
      if Sanciones.vigente(ban) then return nil, Sanciones.mensaje(ban) end
      conn:consulta("UPDATE cuentas SET ban_desde = NULL, ban_hasta = NULL, ban_motivo = NULL, ban_por = NULL WHERE id = " .. tonumber(row.id))
    end
    if migrar then
      conn:consulta("UPDATE cuentas SET clave = " .. Pg.literal(Credenciales.cifrar(clave, row.sal)) .. " WHERE id = " .. tonumber(row.id))
    end
    local token, terr = abrirSesion(conn, row.id)
    if not token then return nil, terr or "No se pudo abrir la sesión." end
    return tonumber(row.id), token
  end)
end

function M.listar(cuentaId)
  return con(function(conn)
    local filas, err = conn:consulta(
      "SELECT id, nombre, faccion, clase, genero, nivel, " ..
      "(SELECT addon FROM personaje_addon a WHERE a.personaje_id = personajes.id AND a.activo LIMIT 1) AS addon " ..
      "FROM personajes WHERE cuenta_id = " .. tonumber(cuentaId) .. " ORDER BY id"
    )
    if not filas then return nil, err end
    local lista = {}
    for _, row in ipairs(filas) do
      lista[#lista + 1] = {
        id = tonumber(row.id), nombre = row.nombre, faccion = row.faccion,
        clase = row.clase, genero = row.genero == "m" and "m" or "h", nivel = tonumber(row.nivel) or 1,
        addon = (row.addon and row.addon ~= "") and row.addon or nil,
      }
    end
    return lista
  end)
end

function M.crearPersonaje(cuentaId, nombre, faccion, clase, genero)
  genero = genero == "m" and "m" or "h"
  if not nombreValido(nombre) then
    return nil, "El nombre del personaje usa 3 a 16 letras."
  end
  if faccion ~= "albor" and faccion ~= "umbra" then return nil, "Elige una facción." end
  if not Datos.claseValida(clase, faccion) then
    return nil, "Elige un oficio de tu facción."
  end
  return con(function(conn)
    local cuenta = tonumber(cuentaId)
    if not cuenta then return nil, "Sesión no válida." end
    local n = conn:consulta("SELECT count(*) AS n FROM personajes WHERE cuenta_id = " .. cuenta)
    if n and n[1] and tonumber(n[1].n) >= 4 then return nil, "Esta cuenta ya tiene 4 personajes." end
    local filas, err = conn:consulta(
      "INSERT INTO personajes (cuenta_id, nombre, faccion, clase, genero) VALUES (" ..
      tonumber(cuenta) .. "," .. Pg.literal(nombre) .. "," .. Pg.literal(faccion) .. "," .. Pg.literal(clase) .. "," .. Pg.literal(genero) ..
      ") RETURNING id"
    )
    if not filas or not filas[1] then
      if err and err:find("personajes_nombre") then return nil, "Ese nombre ya existe." end
      return nil, err or "No se pudo crear el personaje."
    end
    return tonumber(filas[1].id)
  end)
end

function M.cargar(personajeId)
  return con(function(conn)
    local filas, err = conn:consulta(
      "SELECT id, nombre, faccion, clase, genero, nivel, xp, oro, monedas, regalo_mall, autopocion, autopocion_umbral, automana, automana_umbral, x, y, z, modo, hp, mp, guardado, diaria_ultimo, diaria_racha, " ..
      "vinculo_modo, vinculo_x, vinculo_y FROM personajes WHERE id = " .. tonumber(personajeId)
    )
    if not filas or not filas[1] then return nil, err or "No está ese personaje." end
    local row = filas[1]
    local pid = tonumber(row.id)
    local datos = {
      nombre = row.nombre, faccion = row.faccion, clase = row.clase, genero = row.genero == "m" and "m" or "h",
      nivel = tonumber(row.nivel) or 1, xp = tonumber(row.xp) or 0, oro = tonumber(row.oro) or 0, monedas = tonumber(row.monedas) or 0, regaloMall = row.regalo_mall == "t",
      autoPocion = row.autopocion == "t", autoPocionUmbral = (tonumber(row.autopocion_umbral) or 50) / 100,
      autoMana = row.automana == "t", autoManaUmbral = (tonumber(row.automana_umbral) or 50) / 100,
      x = tonumber(row.x), y = tonumber(row.y),
      hp = tonumber(row.hp), mp = tonumber(row.mp), dbId = pid,
    }
    if row.diaria_ultimo and row.diaria_ultimo ~= "" then
      datos.diaria = { ultimo = row.diaria_ultimo, racha = tonumber(row.diaria_racha) or 0 }
    end
    -- Un personaje recién creado aún no se guardó: conserva el equipo inicial del mundo.
    if row.guardado == "t" then
      datos.guardado = true
      datos.z = tonumber(row.z) or 0
      datos.modo = row.modo or "mundo"
      if row.vinculo_x and row.vinculo_y then
        local vm = row.vinculo_modo or "mundo"
        local cid = vm:match("^ciudad:(.+)$")
        datos.vinculo = { x = tonumber(row.vinculo_x), y = tonumber(row.vinculo_y), modo = cid and "mundo" or vm, ciudad = cid }
      end
      local function lista(sql)
        local r = conn:consulta(sql)
        return r or {}
      end
      datos.equipo, datos.encantos = {}, {}
      for _, r in ipairs(lista("SELECT hueco, item_id, enc FROM personaje_equipo WHERE personaje_id = " .. pid)) do
        datos.equipo[r.hueco] = r.item_id
        if (tonumber(r.enc) or 0) > 0 then datos.encantos[r.hueco] = tonumber(r.enc) end
      end
      datos.bolsa = {}
      for _, r in ipairs(lista("SELECT item_id, cant, enc FROM personaje_bolsa WHERE personaje_id = " .. pid .. " ORDER BY ranura")) do
        datos.bolsa[#datos.bolsa + 1] = { id = r.item_id, cant = tonumber(r.cant) or 1, enc = (tonumber(r.enc) or 0) > 0 and tonumber(r.enc) or nil }
      end
      datos.misiones = {}
      for _, r in ipairs(lista("SELECT mision_id, progreso, aceptada, entregada FROM personaje_mision WHERE personaje_id = " .. pid)) do
        for _, def in ipairs(Datos.misiones) do
          if def.id == r.mision_id then
            datos.misiones[def.id] = {
              titulo = def.titulo, monstruo = def.monstruo, cantidad = def.cantidad,
              oro = def.oro, xp = def.xp, ciudad = def.ciudad,
              progreso = tonumber(r.progreso) or 0, aceptada = r.aceptada == "t", entregada = r.entregada == "t",
            }
          end
        end
      end
      -- sin filas = personaje anterior al árbol: el mundo le da el poder inicial
      local hab = lista("SELECT habilidad_id, rango FROM personaje_habilidad WHERE personaje_id = " .. pid)
      if #hab > 0 then
        datos.habilidades = {}
        for _, r in ipairs(hab) do datos.habilidades[r.habilidad_id] = tonumber(r.rango) or 1 end
      end
      datos.oficios, datos.carga, datos.cargaRobada, datos.monturas = {}, {}, {}, {}
      for _, r in ipairs(lista("SELECT oficio, nivel, xp, actual FROM personaje_oficio WHERE personaje_id = " .. pid)) do
        datos.oficios[r.oficio] = { nivel = tonumber(r.nivel) or 1, xp = tonumber(r.xp) or 0 }
        if r.actual == "t" then datos.job = r.oficio end
      end
      for _, r in ipairs(lista("SELECT bien, cant, robado FROM personaje_carga WHERE personaje_id = " .. pid)) do
        local destino = r.robado == "t" and datos.cargaRobada or datos.carga
        destino[r.bien] = tonumber(r.cant) or 0
      end
      for _, r in ipairs(lista("SELECT tipo, preferida FROM personaje_montura WHERE personaje_id = " .. pid .. " ORDER BY tipo")) do
        datos.monturas[#datos.monturas + 1] = r.tipo
        if r.preferida == "t" then datos.monturaPreferida = r.tipo end
      end
      datos.mascotas = {}
      for _, r in ipairs(lista("SELECT slot, especie, nivel, xp, activa FROM personaje_mascota WHERE personaje_id = " .. pid .. " ORDER BY slot")) do
        datos.mascotas[#datos.mascotas + 1] = { especie = r.especie, nivel = tonumber(r.nivel) or 1, xp = tonumber(r.xp) or 0 }
        if r.activa == "t" then
          if require("compartido.dominio.mascotas").esRecolectora(r.especie) then datos.recolectoraActiva = #datos.mascotas
          else datos.mascotaActiva = #datos.mascotas end
        end
      end
      datos.addons, datos.bonos = {}, {}
      for _, r in ipairs(lista("SELECT addon, activo FROM personaje_addon WHERE personaje_id = " .. pid)) do
        datos.addons[r.addon] = true
        if r.activo == "t" then datos.addonActivo = r.addon end
      end
      datos.aparienciaSlots = {}
      for _, r in ipairs(lista("SELECT ranura, set_id FROM personaje_apariencia WHERE personaje_id = " .. pid)) do
        datos.aparienciaSlots[r.ranura] = r.set_id
      end
      for _, r in ipairs(lista("SELECT bono, fin FROM personaje_bono WHERE personaje_id = " .. pid)) do
        datos.bonos[r.bono] = tonumber(r.fin) or 0
      end
      datos.caceria = {}
      for _, r in ipairs(lista("SELECT monstruo_id, cantidad FROM personaje_caceria WHERE personaje_id = " .. pid)) do
        datos.caceria[r.monstruo_id] = tonumber(r.cantidad) or 0
      end
      datos.casas = {}
      for _, r in ipairs(lista("SELECT parcela_id FROM personaje_casa WHERE personaje_id = " .. pid)) do
        datos.casas[r.parcela_id] = { muebles = {}, cofre = {} }
      end
      for _, r in ipairs(lista("SELECT parcela_id, mueble, x, y, rot FROM casa_mueble WHERE personaje_id = " .. pid)) do
        local casa = datos.casas[r.parcela_id]
        if casa then
          local x, y = tonumber(r.x), tonumber(r.y)
          if x and y then casa.muebles[r.mueble] = { x = x, y = y, rot = (tonumber(r.rot) or 0) % 4 }
          else casa.muebles[r.mueble] = true end
        end
      end
      for _, r in ipairs(lista("SELECT parcela_id, item_id, cant, enc FROM casa_cofre WHERE personaje_id = " .. pid .. " ORDER BY parcela_id, ranura")) do
        local c = datos.casas[r.parcela_id]
        if c then c.cofre[#c.cofre + 1] = { id = r.item_id, cant = tonumber(r.cant) or 1, enc = (tonumber(r.enc) or 0) > 0 and tonumber(r.enc) or nil } end
      end
    end
    local hoy = os.date("%Y-%m-%d")
    local ev = conn:consulta(
      "SELECT tipo FROM evento_diario WHERE personaje_id = " .. tonumber(personajeId) .. " AND dia = " .. Pg.literal(hoy)
    )
    datos.eventosDia = {}
    for _, e in ipairs(ev or {}) do datos.eventosDia[e.tipo] = hoy end
    return datos
  end)
end

function M.cuentaDeToken(token)
  if type(token) ~= "string" or #token < 16 then return nil, "Falta la sesión." end
  return con(function(conn)
    local ses, e = conn:consulta(
      "SELECT s.cuenta_id, c.usuario, c.rol, c.ban_desde, c.ban_hasta, c.ban_motivo, c.ban_por FROM sesion_juego s " ..
      "JOIN cuentas c ON c.id = s.cuenta_id WHERE s.token = " .. Pg.literal(token) .. " AND s.expira > now()"
    )
    if not ses then return nil, e end
    if not ses[1] then return nil, "La sesión caducó. Entra de nuevo." end
    local f = ses[1]
    if f.ban_desde and f.ban_desde ~= "" then
      local ban = { hasta = tonumber(f.ban_hasta) or 0, motivo = f.ban_motivo, por = f.ban_por }
      if Sanciones.vigente(ban) then return nil, Sanciones.mensaje(ban) end
    end
    local rol = (f.rol and f.rol ~= "") and f.rol or nil
    return tonumber(f.cuenta_id), f.usuario, rol
  end)
end

function M.cargarAutorizado(token, personajeId)
  if type(token) ~= "string" or #token < 16 then return nil, "Falta la sesión." end
  local pid = tonumber(personajeId)
  if not pid then return nil, "Falta el personaje." end
  local ok, err = con(function(conn)
    local ses, e = conn:consulta(
      "SELECT cuenta_id FROM sesion_juego WHERE token = " .. Pg.literal(token) .. " AND expira > now()"
    )
    if not ses then return nil, e end
    if not ses[1] then return nil, "La sesión caducó. Entra de nuevo." end
    local due, e2 = conn:consulta("SELECT cuenta_id FROM personajes WHERE id = " .. pid)
    if not due then return nil, e2 end
    if not due[1] or tonumber(due[1].cuenta_id) ~= tonumber(ses[1].cuenta_id) then
      return nil, "Ese personaje no es de esta cuenta."
    end
    return true
  end)
  if not ok then return nil, err end
  return M.cargar(pid)
end

function M.guardar(p, exportado)
  if not p or not p.dbId then return nil, "Sin personaje." end
  exportado = exportado or {}
  return con(function(conn)
    -- La posición sale de lo exportado (dentro de una casa o un campo de batalla es
    -- la del mundo al que volvería), no de las coordenadas del mapa interior.
    local ex = {}
    for k, v in pairs(exportado) do ex[k] = v end
    ex.nivel, ex.xp, ex.oro = p.nivel, p.xp, p.oro
    ex.x, ex.y = exportado.x or p.x, exportado.y or p.y
    local _, err = conn:consulta(sentenciasDe(p.dbId, ex, p.hp or 1, p.mp or 1))
    if err then return nil, err end
    return true
  end)
end

function M.marcarEvento(personajeId, tipo)
  local idn = tonumber(personajeId)
  if not idn then return nil, "Sin personaje." end
  local hoy = os.date("%Y-%m-%d")
  return con(function(conn)
    local _, err = conn:consulta(
      "INSERT INTO evento_diario (personaje_id, tipo, dia) VALUES (" ..
      tonumber(idn) .. "," .. Pg.literal(tipo) .. "," .. Pg.literal(hoy) ..
      ") ON CONFLICT DO NOTHING"
    )
    if err then return nil, err end
    return true
  end)
end

-- Gremios: se cargan todos al arrancar y se guardan completos al cambiar.
function M.cargarGremios()
  return con(function(conn)
    local filas, err = conn:consulta(
      "SELECT g.id, g.nombre, g.etiqueta, g.faccion, m.personaje_id, m.rango, p.nombre AS jugador " ..
      "FROM gremio g JOIN gremio_miembro m ON m.gremio_id = g.id JOIN personajes p ON p.id = m.personaje_id " ..
      "ORDER BY g.id, m.personaje_id"
    )
    if not filas then return nil, err end
    local lista, porId = {}, {}
    for _, r in ipairs(filas) do
      local id = tonumber(r.id)
      local g = porId[id]
      if not g then
        g = { id = id, nombre = r.nombre, etiqueta = r.etiqueta, faccion = r.faccion, miembros = {} }
        porId[id] = g
        lista[#lista + 1] = g
      end
      g.miembros[#g.miembros + 1] = { id = tonumber(r.personaje_id), nombre = r.jugador, rango = r.rango }
    end
    return lista
  end)
end

function M.guardarGremio(g)
  return con(function(conn)
    local q = {
      "INSERT INTO gremio (id, nombre, etiqueta, faccion) VALUES (" .. tonumber(g.id) .. "," .. Pg.literal(g.nombre) .. "," ..
        Pg.literal(g.etiqueta) .. "," .. Pg.literal(g.faccion) .. ") ON CONFLICT (id) DO UPDATE SET nombre = EXCLUDED.nombre, " ..
        "etiqueta = EXCLUDED.etiqueta, faccion = EXCLUDED.faccion",
      "DELETE FROM gremio_miembro WHERE gremio_id = " .. tonumber(g.id),
    }
    local filas = {}
    for dbId, m in pairs(g.miembros) do
      filas[#filas + 1] = "(" .. tonumber(g.id) .. "," .. tonumber(dbId) .. "," .. Pg.literal(m.rango) .. ")"
    end
    if #filas > 0 then
      q[#q + 1] = "INSERT INTO gremio_miembro (gremio_id, personaje_id, rango) VALUES " .. table.concat(filas, ",")
    end
    local _, err = conn:consulta(table.concat(q, ";\n"))
    if err then return nil, err end
    return true
  end)
end

function M.borrarGremio(id)
  return con(function(conn)
    local _, err = conn:consulta("DELETE FROM gremio WHERE id = " .. tonumber(id))
    if err then return nil, err end
    return true
  end)
end

-- Subastas y buzones: se cargan todos al arrancar y se guardan al cambiar.
function M.cargarSubastas()
  return con(function(conn)
    local filas, err = conn:consulta("SELECT * FROM subasta ORDER BY id")
    if not filas then return nil, err end
    local lista = {}
    for _, r in ipairs(filas) do
      lista[#lista + 1] = {
        id = tonumber(r.id), vendedor = tonumber(r.vendedor_id), vendedorNombre = r.vendedor_nombre, item = r.item_id,
        cant = tonumber(r.cant) or 1, enc = (tonumber(r.enc) or 0) > 0 and tonumber(r.enc) or nil,
        salida = tonumber(r.salida), compra = r.compra and tonumber(r.compra) or nil, oferta = tonumber(r.oferta) or 0,
        postor = r.postor_id and tonumber(r.postor_id) or nil, postorNombre = r.postor_nombre,
        creada = tonumber(r.creada), termina = tonumber(r.termina),
      }
    end
    local buzones = {}
    local filasB = conn:consulta("SELECT * FROM subasta_buzon ORDER BY id") or {}
    for _, r in ipairs(filasB) do
      local dbId = tonumber(r.personaje_id)
      buzones[dbId] = buzones[dbId] or {}
      local b = buzones[dbId]
      b[#b + 1] = {
        item = r.item_id, cant = r.cant and tonumber(r.cant) or nil, enc = (tonumber(r.enc) or 0) > 0 and tonumber(r.enc) or nil,
        oro = tonumber(r.oro) or 0, nota = r.nota,
      }
    end
    return lista, buzones
  end)
end

function M.guardarSubasta(s)
  return con(function(conn)
    local _, err = conn:consulta(
      "INSERT INTO subasta (id, vendedor_id, vendedor_nombre, item_id, cant, enc, salida, compra, oferta, postor_id, postor_nombre, creada, termina) VALUES (" ..
      tonumber(s.id) .. "," .. tonumber(s.vendedor) .. "," .. Pg.literal(s.vendedorNombre) .. "," .. Pg.literal(s.item) .. "," ..
      entero(s.cant) .. "," .. entero(s.enc) .. "," .. entero(s.salida) .. "," .. (s.compra and entero(s.compra) or "NULL") .. "," ..
      entero(s.oferta) .. "," .. (s.postor and tonumber(s.postor) or "NULL") .. "," .. Pg.literal(s.postorNombre) .. "," ..
      entero(s.creada) .. "," .. entero(s.termina) .. ") ON CONFLICT (id) DO UPDATE SET oferta = EXCLUDED.oferta, " ..
      "postor_id = EXCLUDED.postor_id, postor_nombre = EXCLUDED.postor_nombre, termina = EXCLUDED.termina"
    )
    if err then return nil, err end
    return true
  end)
end

function M.borrarSubasta(id)
  return con(function(conn)
    local _, err = conn:consulta("DELETE FROM subasta WHERE id = " .. tonumber(id))
    if err then return nil, err end
    return true
  end)
end

function M.guardarBuzon(dbId, lista)
  return con(function(conn)
    local q = { "DELETE FROM subasta_buzon WHERE personaje_id = " .. tonumber(dbId) }
    local filas = {}
    for _, e in ipairs(lista or {}) do
      filas[#filas + 1] = "(" .. tonumber(dbId) .. "," .. (e.item and Pg.literal(e.item) or "NULL") .. "," ..
        (e.cant and entero(e.cant) or "NULL") .. "," .. entero(e.enc) .. "," .. entero(e.oro) .. "," .. Pg.literal(e.nota) .. ")"
    end
    if #filas > 0 then
      q[#q + 1] = "INSERT INTO subasta_buzon (personaje_id, item_id, cant, enc, oro, nota) VALUES " .. table.concat(filas, ",")
    end
    local _, err = conn:consulta(table.concat(q, ";\n"))
    if err then return nil, err end
    return true
  end)
end

-- Roles (GM y CM) y baneos por cuenta. El usuario se busca sin distinguir mayúsculas.
function M.rolDeCuenta(cuentaId)
  return con(function(conn)
    local f = conn:consulta("SELECT rol FROM cuentas WHERE id = " .. tonumber(cuentaId))
    if not f or not f[1] or not f[1].rol or f[1].rol == "" then return nil end
    return f[1].rol
  end)
end

function M.fijarRol(usuario, rol)
  if not Sanciones.rolValido(rol) then return nil, "Rol desconocido: usa gm, cm o ninguno." end
  return con(function(conn)
    local f, err = conn:consulta(
      "UPDATE cuentas SET rol = " .. (rol and Pg.literal(rol) or "NULL") ..
      " WHERE lower(usuario) = lower(" .. Pg.literal(tostring(usuario or "")) .. ") RETURNING usuario"
    )
    if not f then return nil, err end
    if not f[1] then return nil, "No existe esa cuenta." end
    return f[1].usuario
  end)
end

function M.listarRoles()
  return con(function(conn)
    local f, err = conn:consulta("SELECT usuario, rol FROM cuentas WHERE rol IS NOT NULL AND rol <> '' ORDER BY usuario")
    if not f then return nil, err end
    local lista = {}
    for _, r in ipairs(f) do lista[#lista + 1] = { usuario = r.usuario, rol = r.rol } end
    return lista
  end)
end

function M.banear(usuario, hasta, motivo, por)
  return con(function(conn)
    local f, err = conn:consulta(
      "UPDATE cuentas SET ban_desde = " .. os.time() .. ", ban_hasta = " .. math.floor(tonumber(hasta) or 0) ..
      ", ban_motivo = " .. Pg.literal(tostring(motivo or "")) .. ", ban_por = " .. Pg.literal(tostring(por or "")) ..
      " WHERE lower(usuario) = lower(" .. Pg.literal(tostring(usuario or "")) .. ") RETURNING id, usuario"
    )
    if not f then return nil, err end
    if not f[1] then return nil, "No existe esa cuenta." end
    conn:consulta("DELETE FROM sesion_juego WHERE cuenta_id = " .. tonumber(f[1].id))
    return f[1].usuario
  end)
end

function M.desbanear(usuario)
  return con(function(conn)
    local f, err = conn:consulta(
      "UPDATE cuentas SET ban_desde = NULL, ban_hasta = NULL, ban_motivo = NULL, ban_por = NULL " ..
      "WHERE lower(usuario) = lower(" .. Pg.literal(tostring(usuario or "")) .. ") AND ban_desde IS NOT NULL RETURNING usuario"
    )
    if not f then return nil, err end
    if not f[1] then return nil, "Esa cuenta no existe o no está baneada." end
    return f[1].usuario
  end)
end

function M.estadoBan(cuentaId)
  return con(function(conn)
    local f = conn:consulta("SELECT ban_hasta, ban_motivo, ban_por FROM cuentas WHERE id = " .. tonumber(cuentaId) .. " AND ban_desde IS NOT NULL")
    if not f or not f[1] then return nil end
    local ban = { hasta = tonumber(f[1].ban_hasta) or 0, motivo = f[1].ban_motivo, por = f[1].ban_por }
    if not Sanciones.vigente(ban) then return nil end
    return ban
  end)
end

function M.listarBaneos()
  return con(function(conn)
    local f, err = conn:consulta("SELECT usuario, ban_hasta, ban_motivo, ban_por FROM cuentas WHERE ban_desde IS NOT NULL ORDER BY usuario")
    if not f then return nil, err end
    local lista = {}
    for _, r in ipairs(f) do
      local ban = { hasta = tonumber(r.ban_hasta) or 0 }
      if Sanciones.vigente(ban) then lista[#lista + 1] = { usuario = r.usuario, hasta = ban.hasta, motivo = r.ban_motivo, por = r.ban_por } end
    end
    return lista
  end)
end

function M.borrarUsuario(usuario)
  return con(function(conn)
    return conn:consulta("DELETE FROM cuentas WHERE usuario = " .. Pg.literal(usuario))
  end)
end

return M
