local Interfaz = require("src.presentacion.interfaz")
local Sonido = require("src.presentacion.sonido")
local Util = require("compartido.dominio.util")
local Datos = require("compartido.dominio.datos")
local Dibujo = require("src.presentacion.render.dibujo")
local Ajustes = require("src.presentacion.ajustes")
local Config = require("src.infraestructura.config")

local Entrada = {}

local function beberPocion(app, tipo)
  local pj = app.jugador
  app.actuar("pocion", { id = Datos.pocionAlUsar(pj and pj.bolsa, pj and pj.nivel, tipo) })
end

function Entrada.deseo()
  if Entrada.auto then return Entrada.auto.x, Entrada.auto.y end
  if Interfaz.foco then return 0, 0 end
  local x, y = 0, 0
  if love.keyboard.isDown("w", "up") then y = y - 1 end
  if love.keyboard.isDown("s", "down") then y = y + 1 end
  if love.keyboard.isDown("a", "left") then x = x - 1 end
  if love.keyboard.isDown("d", "right") then x = x + 1 end
  local d = math.sqrt(x * x + y * y)
  if d > 0 then x, y = x / d, y / d end
  return x, y
end

function Entrada.manejar(app, id)
  if not id or id == "panel" then return end
  Sonido.tocar("click")
  local cuenta, sesion, creacion = app.cuenta, app.sesion, app.creacion
  if id == "menu_salir" then love.event.quit() return end
  if id == "menu_entrar" or id == "menu_registro" then
    app.cuenta = {
      modo = id == "menu_registro" and "crear" or "entrar",
      usuario = (id == "menu_entrar") and Ajustes.ultimoUsuario or "", clave = "", clave2 = "", error = "",
    }
    app.estado = "cuenta"
    Interfaz.portadaPanel = nil
    -- con el usuario recordado, el cursor va directo a la clave
    Interfaz.foco = (app.cuenta.usuario ~= "") and "clave" or "usuario"
    return
  end
  if id == "portada_inicio" or id == "portada_cuenta" then
    app.cuenta = app.cuenta or { usuario = "", clave = "", error = "" }
    app.cuenta.modo = "entrar"
    app.cuenta.error = ""
    app.estado = id == "portada_inicio" and "menu" or "cuenta"
    Interfaz.portadaPanel = nil
    if Interfaz.foco == "clave2" or not Interfaz.foco then
      Interfaz.foco = (app.cuenta.usuario ~= "") and "clave" or "usuario"
    end
    return
  end
  if id == "portada_ajustes" then
    Interfaz.portadaPanel = "ajustes"
    Interfaz.foco = nil
    return
  end
  if id == "cuenta_ver" then
    if app.cuenta then app.cuenta.verClave = not app.cuenta.verClave end
    return
  end
  if id == "cuenta_recuperar" then
    if app.cuenta then
      app.cuenta.error = "El servidor no recupera claves. Entra con la tuya o crea otra cuenta."
      Interfaz._toastClave = nil
    end
    return
  end
  if id == "cuenta_volver" or id == "cuenta_salir" then
    require("src.presentacion.estados.juego").soltar(app)
    app.sesion = { cuentaId = nil, usuario = "", personajes = {}, error = "" }
    app.estado = "menu"
    Interfaz.foco = nil
    return
  end
  if id == "foco_usuario" then Interfaz.foco = "usuario" return end
  if id == "foco_clave" then Interfaz.foco = "clave" return end
  if id == "cuenta_ok" then
    cuenta = app.cuenta
    cuenta.error = ""
    Interfaz._toastClave = nil
    if cuenta.modo == "crear" and (cuenta.clave2 or "") ~= (cuenta.clave or "") then
      cuenta.error = "Las claves no coinciden."
      return
    end
    if cuenta.usuario and cuenta.usuario ~= "" and cuenta.usuario ~= Ajustes.ultimoUsuario then
      Ajustes.ultimoUsuario = cuenta.usuario
      Ajustes.guardar()
    end
    require("src.presentacion.estados.juego").pedirCuenta(app, Config.red.host, {
      t = "cuenta",
      a = cuenta.modo == "crear" and "registrar" or "entrar",
      usuario = cuenta.usuario,
      clave = cuenta.clave,
    }, "personajes")
    return
  end
  if id == "pj_nuevo" then
    if not sesion.cuentaId then app.estado = "cuenta" return end
    -- Alba viene elegida de entrada, así se ven desde el principio los oficios de una facción (cambia con el botón de Umbra)
    app.creacion = { nombre = "", faccion = "albor", clase = nil, error = "" }
    app.estado = "crear"
    Interfaz.foco = "nombre"
    return
  end
  if id:sub(1, 3) == "pj_" and id ~= "pj_nuevo" then
    if not sesion.token then sesion.error = "Entra de nuevo: el servidor aún no ha validado la cuenta." return end
    app.personajeRed = tonumber(id:sub(4))
    require("src.presentacion.estados.juego").entrar(app, Config.red.host)
    return
  end
  if id == "crear_volver" then
    app.estado = sesion.cuentaId and "personajes" or "menu"
    Interfaz.foco = nil
    return
  end
  if id == "foco_nombre" then Interfaz.foco = "nombre" return end
  if id == "foco_chat" then Interfaz.foco = "chat" Interfaz.texto = "" return end
  if id:sub(1, 8) == "faccion_" then
    creacion.faccion = id:sub(9)
    -- un oficio exclusivo de la otra facción se descarta
    if creacion.clase and not Datos.claseValida(creacion.clase, creacion.faccion) then creacion.clase = nil end
    return
  end
  if id:sub(1, 6) == "clase_" then
    local clase = id:sub(7)
    if Datos.claseValida(clase, creacion.faccion) then creacion.clase = clase end
    return
  end
  if id == "crear_entrar" then
    creacion = app.creacion
    if not sesion.cuentaId then app.cuenta.error = "Regístrate para jugar." app.estado = "cuenta" return end
    if creacion.faccion and creacion.clase then
      local nombre = creacion.nombre ~= "" and creacion.nombre or "Aventurero"
      require("src.presentacion.estados.juego").pedirCuenta(app, Config.red.host, {
        t = "cuenta", a = "crear", token = sesion.token,
        nombre = nombre, faccion = creacion.faccion, clase = creacion.clase,
      }, "mundo", "crear")
    end
    return
  end
  if id == "cerrar" then Interfaz.panel = nil return end
  if id == "hud_bolsa" then Interfaz.panel = "bolsa" return end
  if id == "hud_equipo" then Interfaz.panel = "equipo" return end
  if id == "hud_arbol" then Interfaz.panel = (Interfaz.panel ~= "arbol") and "arbol" or nil return end
  if id:sub(1, 13) == "masc_adoptar_" then app.actuar("mascota_adoptar", { especie = id:sub(14) }) return end
  if id:sub(1, 9) == "masc_inv_" then app.actuar("mascota_invocar", { idx = tonumber(id:sub(10)) }) return end
  if id:sub(1, 3) == "gp_" then
    if id == "gp_acepta" then app.actuar("grupo_responder", { acepta = true })
    elseif id == "gp_rechaza" then app.actuar("grupo_responder", { acepta = false })
    elseif id == "gp_salir" then Interfaz.confirmaGrupo = nil app.actuar("grupo_salir")
    elseif id == "gp_disolver" then
      if Interfaz.confirmaGrupo then Interfaz.confirmaGrupo = nil app.actuar("grupo_disolver") else Interfaz.confirmaGrupo = true end
    elseif id == "gp_invitar" then
      local o = app.jugador and app.jugador.objetivo
      if o then app.actuar("grupo_invitar", { id = o }) end
    elseif id:sub(1, 9) == "gp_lider_" then app.actuar("grupo_lider", { id = tonumber(id:sub(10)) })
    elseif id:sub(1, 7) == "gp_exp_" then app.actuar("grupo_expulsar", { id = tonumber(id:sub(8)) })
    elseif id:sub(1, 7) == "gp_sel_" then app.actuar("objetivo", { id = tonumber(id:sub(8)), persigue = false })
    end
    return
  end
  if id:sub(1, 10) == "of_elegir_" then app.actuar("oficio_elegir", { job = id:sub(11) }) return end
  if id == "perista_vender" then app.actuar("perista_vender") return end
  if id:sub(1, 6) == "mc_c1_" then app.actuar("mercancia_comprar", { bien = id:sub(7), cant = 1 }) return end
  if id:sub(1, 6) == "mc_c5_" then app.actuar("mercancia_comprar", { bien = id:sub(7), cant = 5 }) return end
  if id:sub(1, 6) == "mc_v1_" then app.actuar("mercancia_vender", { bien = id:sub(7), cant = 1 }) return end
  if id:sub(1, 6) == "mc_vt_" then
    local bien = id:sub(7)
    local d = Interfaz.datosPanel.mercancias
    local n = 0
    for _, b in ipairs(d and d.bienes or {}) do if b.id == bien then n = b.tengo end end
    if n > 0 then app.actuar("mercancia_vender", { bien = bien, cant = n }) end
    return
  end
  if id:sub(1, 7) == "mt_alt_" then app.actuar("montura_alternar", { especie = id:sub(8) }) return end
  if id:sub(1, 7) == "mt_buy_" then app.actuar("montura_comprar", { especie = id:sub(8) }) return end
  if id:sub(1, 5) == "foco_" and id:sub(1, 9) == "foco_sub_" then Interfaz.foco = id:sub(6) return end
  if id:sub(1, 3) == "sb_" then
    local function vista()
      local c = Interfaz.subCat
      if c == "vender" or c == "mias" or c == "buzon" then c = "todo" end
      return { cat = c or "todo", pagina = Interfaz.subPag or 1 }
    end
    local function con(datos)
      local v = vista()
      datos.cat, datos.pagina = v.cat, v.pagina
      return datos
    end
    local campos = Interfaz.subCampos or { oferta = "", cant = "1", salida = "", compra = "" }
    Interfaz.subCampos = campos
    if id:sub(1, 7) == "sb_tab_" then
      Interfaz.subCat, Interfaz.subPag, Interfaz.foco = id:sub(8), 1, nil
      app.actuar("subasta_info", vista())
    elseif id:sub(1, 8) == "sb_fila_" then Interfaz.subSel = tonumber(id:sub(9))
    elseif id == "sb_prev" then Interfaz.subPag = math.max(1, (Interfaz.subPag or 1) - 1) app.actuar("subasta_info", vista())
    elseif id == "sb_next" then Interfaz.subPag = (Interfaz.subPag or 1) + 1 app.actuar("subasta_info", vista())
    elseif id == "sb_pujar" then
      local d = Interfaz.datosPanel.subastas
      local minima
      for _, s in ipairs(d and d.lista or {}) do if s.id == Interfaz.subSel then minima = s.minima end end
      local oferta = tonumber(campos.oferta) or minima
      if Interfaz.subSel and oferta then app.actuar("subasta_pujar", con({ id = Interfaz.subSel, oferta = oferta })) end
      campos.oferta, Interfaz.foco = "", nil
    elseif id == "sb_comprar" then
      if Interfaz.subSel then app.actuar("subasta_comprar", con({ id = Interfaz.subSel })) end
    elseif id == "sb_pub" then
      app.actuar("subasta_publicar", con({
        idx = Interfaz.subIdx, cant = tonumber(campos.cant) or 1, salida = tonumber(campos.salida) or 0,
        compra = tonumber(campos.compra) or 0, horas = Interfaz.subHoras or 12,
      }))
      Interfaz.subIdx, campos.salida, campos.compra, campos.cant, Interfaz.foco = nil, "", "", "1", nil
    elseif id:sub(1, 8) == "sb_item_" then
      Interfaz.subIdx = tonumber(id:sub(9))
      local slot = app.jugador and app.jugador.bolsa[Interfaz.subIdx]
      campos.cant = tostring(slot and slot.cant or 1)
    elseif id:sub(1, 7) == "sb_dur_" then Interfaz.subHoras = tonumber(id:sub(8))
    elseif id:sub(1, 10) == "sb_cancel_" then app.actuar("subasta_cancelar", con({ id = tonumber(id:sub(11)) }))
    elseif id == "sb_cobrar" then app.actuar("subasta_cobrar", vista())
    end
    return
  end
  if id == "foco_gremio_nombre" then Interfaz.foco = "gremio_nombre" return end
  if id == "foco_gremio_tag" then Interfaz.foco = "gremio_tag" return end
  if id == "gr_crear" then
    app.actuar("gremio_crear", { nombre = Interfaz.gremioNombre or "", etiqueta = Interfaz.gremioTag or "" })
    Interfaz.foco = nil
    return
  end
  if id == "gr_acepta" then app.actuar("gremio_responder", { acepta = true }) return end
  if id == "gr_rechaza" then app.actuar("gremio_responder", { acepta = false }) return end
  if id == "gr_salir" then Interfaz.confirmaDisolver = nil app.actuar("gremio_salir") return end
  if id == "gr_disolver" then
    if Interfaz.confirmaDisolver then Interfaz.confirmaDisolver = nil app.actuar("gremio_disolver")
    else Interfaz.confirmaDisolver = true end
    return
  end
  if id == "gr_invitar" then
    local o = app.jugador and app.jugador.objetivo
    if o then app.actuar("gremio_invitar", { id = o }) end
    return
  end
  if id:sub(1, 8) == "gr_sube_" then app.actuar("gremio_rango", { id = tonumber(id:sub(9)), sube = true }) return end
  if id:sub(1, 8) == "gr_baja_" then app.actuar("gremio_rango", { id = tonumber(id:sub(9)), sube = false }) return end
  if id:sub(1, 7) == "gr_exp_" then app.actuar("gremio_expulsar", { id = tonumber(id:sub(8)) }) return end
  if id:sub(1, 10) == "enc_forja_" then
    -- forjar con un pergamino del mall: sube la pieza +1 sin fallar
    local donde, ref = tostring(Interfaz.encSel or ""):match("^(%a+)_(.+)$")
    if donde then app.actuar("encantar", { donde = donde, ref = ref, pergamino = id:sub(11) }) end
    return
  end
  if id == "enc_go" then
    local donde, ref = tostring(Interfaz.encSel or ""):match("^(%a+)_(.+)$")
    if donde then app.actuar("encantar", { donde = donde, ref = ref }) end
    return
  end
  if id:sub(1, 4) == "enc_" then Interfaz.encSel = id:sub(5) return end
  if id == "arbol_reset" then app.actuar("olvidar") return end
  if id:sub(1, 4) == "arb_" then app.actuar("aprender", { id = id:sub(5) }) return end
  if id == "hud_mapa" then Interfaz.panel = "mapa" return end
  if id == "hud_ayuda" then Interfaz.panel = "ayuda" return end
  if id == "hud_menu" then Interfaz.panel = "menu" return end
  if id:sub(1, 3) == "bl_" then
    local objetivo = id:sub(4)
    local jugador, mundo = app.jugador, app.mundo
    local e = mundo and mundo.entidades[objetivo]
    if e and jugador then
      local hostil = mundo:puedeDanar(jugador, e)
      app.actuar("objetivo", { id = objetivo, persigue = hostil })
    end
    return
  end
  if id == "hud_comercio" then
    local jugador, mundo = app.jugador, app.mundo
    local obj = jugador and jugador.objetivo and mundo.entidades[jugador.objetivo]
    if obj and (obj.kind == "jugador" or obj.kind == "bot") then
      -- se manda la invitación: el otro jugador verá una alerta y, si acepta, se abre el comercio
      app.actuar("comercio_invitar", { id = obj.id })
    else
      mundo:mensaje("sistema", "", "Selecciona a un aventurero cercano y pulsa T.", jugador)
    end
    return
  end
  if id:sub(1, 4) == "hab_" then Entrada.lanzarHabilidad(app, tonumber(id:sub(5))) return end
  if id == "poc_vida" then beberPocion(app, "vida") return end
  if id == "poc_mana" then beberPocion(app, "mana") return end
  if id == "menu_autopocion" then Interfaz.panel = "autopocion" return end
  -- Lua no trata "|" como alternativa: %a+ sí reconoce vida/mana y on/menos/mas.
  local cual, orden = id:match("^auto_(%a+)_(%a+)$")
  if (cual == "vida" or cual == "mana") and (orden == "on" or orden == "menos" or orden == "mas") then
    local pj = app.jugador
    if not pj then return end
    local claveOn = cual == "mana" and "autoMana" or "autoPocion"
    local claveUmbral = cual == "mana" and "autoManaUmbral" or "autoPocionUmbral"
    local pct = math.floor(((pj[claveUmbral] or 0.5) * 100) + 0.5)
    if orden == "menos" then pct = math.max(20, pct - 10)
    elseif orden == "mas" then pct = math.min(90, pct + 10) end
    local on = pj[claveOn] and true or false
    if orden == "on" then on = not on end
    -- el panel lee el valor al momento; el servidor lo confirma en la siguiente foto
    pj[claveOn], pj[claveUmbral] = on, pct / 100
    app.actuar("autopocion", { cual = cual, on = on, umbral = pct / 100 })
    return
  end
  if id:sub(1, 6) == "canal_" then Interfaz.canal = id:sub(7) return end
  if id:sub(1, 6) == "viaje_" then app.actuar("viaje", { destino = id:sub(7) }) Interfaz.panel = nil return end
  if id:sub(1, 8) == "est_tab_" then Interfaz.establoTab, Interfaz.establoPag = id:sub(9), 1 return end
  if id:sub(1, 9) == "merc_tab_" then Interfaz.mercadoTab = id:sub(10) Interfaz.scroll = 0 return end
  if id:sub(1, 6) == "bolsa_" then
    local i = tonumber(id:sub(7))
    Interfaz.sel = i
    if Interfaz.panel == "mercado" then
      app.actuar("vender", { i = i })
    elseif Interfaz.panel == "comercio" then
      app.actuar("comercio_item", { i = i })
    elseif Interfaz.arrastre and Interfaz.arrastre ~= i then
      app.actuar("mover_bolsa", { a = Interfaz.arrastre, b = i })
      Interfaz.arrastre = nil
    elseif Interfaz.arrastre == i then
      app.actuar("equipar", { i = i })
      Interfaz.arrastre = nil
    else
      Interfaz.arrastre = i
    end
    return
  end
  if id:sub(1, 6) == "equip_" then app.actuar("desequipar", { hueco = id:sub(7) }) return end
  if id:sub(1, 7) == "compra_" then app.actuar("comprar", { id = id:sub(8) }) return end
  if id == "vender_sel" and Interfaz.sel then app.actuar("vender", { i = Interfaz.sel }) return end
  if id == "guerra_batalla" then app.actuar("guerra", { modo = "batalla" }) Interfaz.panel = nil return end
  if id == "guerra_estandarte" then app.actuar("guerra", { modo = "estandarte" }) Interfaz.panel = nil return end
  if id == "guerra_salir" then app.actuar("salir_guerra") Interfaz.panel = nil return end
  if id:sub(1, 13) == "casa_comprar_" then app.actuar("casa_comprar", { id = id:sub(14) }) return end
  if id:sub(1, 12) == "casa_entrar_" then app.actuar("casa_entrar", { id = id:sub(13) }) Interfaz.panel = "casa" return end
  if id == "casa_salir" then app.actuar("casa_salir") Interfaz.panel = nil return end
  if id:sub(1, 7) == "mueble_" then app.actuar("mueble", { tipo = id:sub(8) }) return end
  if id:sub(1, 10) == "mision_ok_" then app.actuar("mision_aceptar", { id = id:sub(11) }) return end
  if id:sub(1, 11) == "mision_fin_" then app.actuar("mision_entregar", { id = id:sub(12) }) return end
  local jugador, mundo = app.jugador, app.mundo
  if id == "oro_10" then app.actuar("comercio_oro", { oro = ((jugador.sesion and mundo.sesiones[jugador.sesion] and mundo.sesiones[jugador.sesion].oferta[jugador.id].oro) or 0) + 10 }) return end
  if id == "oro_50" then app.actuar("comercio_oro", { oro = ((jugador.sesion and mundo.sesiones[jugador.sesion] and mundo.sesiones[jugador.sesion].oferta[jugador.id].oro) or 0) + 50 }) return end
  if id == "comercio_ok" then app.actuar("comercio_ok") return end
  if id == "com_acepta" then app.actuar("comercio_responder", { acepta = true }) return end
  if id == "com_rechaza" then app.actuar("comercio_responder", { acepta = false }) return end
  if id == "alerta_fondo" then return end
  if id:sub(1, 11) == "com_quitar_" then app.actuar("comercio_quitar", { i = tonumber(id:sub(12)) }) return end
  if id:sub(1, 10) == "com_bolsa_" then app.actuar("comercio_item", { i = tonumber(id:sub(11)) }) return end
  if id == "foco_com_oro" then Interfaz.foco = "com_oro" return end
  if id == "com_oro_todo" then
    local s = jugador.sesion and mundo.sesiones[jugador.sesion]
    local mia = s and s.oferta[jugador.id]
    Interfaz.comOro = tostring((jugador.oro or 0) + ((mia and mia.oro) or 0))
    Entrada.fijarOroComercio(app)
    return
  end
  if id == "com_oro_fijar" then Entrada.fijarOroComercio(app) return end
  if id == "comercio_no" then app.actuar("comercio_no") Interfaz.panel = nil return end
  if id == "ajustes" then Interfaz.panel = "ajustes" return end
  if id == "mapa_mas" or id == "mapa_menos" then
    local g = Interfaz.mapaGeom
    if g then Interfaz.mapaZoomar(id == "mapa_mas" and 1.5 or 1 / 1.5, g.ax + g.aw / 2, g.ay + g.ah / 2) end
    return
  end
  if id == "mapa_centrar" then
    local p = app.jugador
    if p and p.modo == "mundo" then Interfaz.mapaCentrarEn(p.x, p.y, Interfaz.mapaZoom) else Interfaz.mapaCentrarEn(Datos.MAPA_W / 2, Datos.MAPA_H / 2, 1) end
    return
  end
  if id == "mapa_tab_zonas" then Interfaz.mapaTab = "zonas" return end
  if id == "mapa_tab_ciudades" then Interfaz.mapaTab = "ciudades" return end
  if id == "mapa_tab_pnj" then Interfaz.mapaTab = "pnj" return end
  if id:sub(1, 10) == "mapa_zona_" then
    local z = require("compartido.dominio.mapa").zonas(app.mundo.mapas.mundo)[tonumber(id:sub(11))]
    if z then Interfaz.mapaCentrarEn(z.x, z.y, math.max(Interfaz.mapaZoom or 1, 3)) end
    return
  end
  if id == "mapa_area" then Interfaz.mapaArrastre = true return end
  if id == "menu_mall" then Interfaz.panel = "mall" return end
  if id == "mall_tab_obj" then Interfaz.mallTab, Interfaz.mallScroll = "objetos", 0 return end
  if id == "mall_tab_forja" then Interfaz.mallTab, Interfaz.mallScroll = "forja", 0 return end
  if id == "mall_tab_add" then Interfaz.mallTab, Interfaz.mallScroll = "addons", 0 return end
  if id == "mall_tab_mont" then Interfaz.mallTab, Interfaz.mallScroll = "monturas", 0 return end
  if id:sub(1, 12) == "mall_mt_buy_" then app.actuar("mall_montura_comprar", { id = id:sub(13) }) return end
  if id:sub(1, 9) == "mall_buy_" then app.actuar("mall_comprar", { id = id:sub(10) }) return end
  if id:sub(1, 12) == "mall_ad_buy_" then app.actuar("mall_addon_comprar", { id = id:sub(13) }) return end
  if id:sub(1, 8) == "mall_ad_" then app.actuar("mall_addon", { id = id:sub(9) }) return end
  if id == "menu_oficio" then app.actuar("oficio_alternar", {}) Interfaz.panel = nil return end
  if id == "hud_diaria" then Interfaz.panel = (Interfaz.panel ~= "diaria") and "diaria" or nil return end
  if id == "diaria_reclamar" then app.actuar("diaria_reclamar", {}) return end
  if id == "hud_montura" then app.actuar("montura_alternar", {}) return end
  if id == "hud_monturas" then Interfaz.panel = (Interfaz.panel ~= "montura") and "montura" or nil return end
  if id == "est_pag_ant" then Interfaz.establoPag = math.max(1, (Interfaz.establoPag or 1) - 1) return end
  if id == "est_pag_sig" then Interfaz.establoPag = (Interfaz.establoPag or 1) + 1 return end
  if id == "mon_pag_ant" then Interfaz.monturaPag = math.max(1, (Interfaz.monturaPag or 1) - 1) return end
  if id == "mon_pag_sig" then Interfaz.monturaPag = (Interfaz.monturaPag or 1) + 1 return end
  if id == "aj_1280" then Ajustes.ancho, Ajustes.alto, Ajustes.completo = 1280, 720, false Ajustes.aplicarVentana() Ajustes.guardar() return end
  if id == "aj_1600" then Ajustes.ancho, Ajustes.alto, Ajustes.completo = 1600, 900, false Ajustes.aplicarVentana() Ajustes.guardar() return end
  if id == "aj_completo" then Ajustes.completo = not Ajustes.completo Ajustes.aplicarVentana() Ajustes.guardar() return end
  if id == "aj_tecla_interactuar" then Ajustes.esperando = "interactuar" return end
  if id == "aj_tecla_bolsa" then Ajustes.esperando = "bolsa" return end
  if id == "salir_menu" then
    if app.rol == "cliente" then require("src.presentacion.estados.juego").soltar(app) end
    app.sesion = { cuentaId = nil, usuario = "", personajes = {}, error = "" }
    app.estado = "menu"
    Interfaz.panel = nil
    return
  end
end

-- Tab: pasa al siguiente enemigo cercano (el más próximo primero) y lo persigue.
function Entrada.siguienteObjetivo(app)
  local mundo, jugador = app.mundo, app.jugador
  if not mundo or not jugador then return end
  local lista = {}
  for _, e in pairs(mundo.entidades) do
    if e.id ~= jugador.id and mundo:mismoLugar(jugador, e) and mundo:puedeDanar(jugador, e) and e.kind ~= "puerta" and e.kind ~= "estatua" then
      local d = Util.dist(jugador.x, jugador.y, e.x, e.y)
      if d < 12 then lista[#lista + 1] = { e = e, d = d } end
    end
  end
  if #lista == 0 then return end
  table.sort(lista, function(a, b) if a.d == b.d then return a.e.id < b.e.id end return a.d < b.d end)
  local sigue = 1
  for i, it in ipairs(lista) do
    if it.e.id == jugador.objetivo then sigue = i % #lista + 1 break end
  end
  app.actuar("objetivo", { id = lista[sigue].e.id, persigue = true })
end

-- Lanza un poder. Los de área sobre un punto (meteoro) caen donde está el cursor si está sobre el
-- mundo; si no, sobre el objetivo elegido (el servidor limita el alcance).
-- Los poderes de area sobre un punto (meteoro, lluvia de flechas) se apuntan: al pulsar su tecla se
-- muestra la zona habilitada (su alcance) y el area de impacto bajo el cursor; un clic (o pulsar la
-- tecla otra vez) lo lanza ahi, y Esc o clic derecho lo cancela.
function Entrada.lanzarHabilidad(app, slot)
  local p, mundo = app.jugador, app.mundo
  local datos = { slot = slot }
  local h
  if p and mundo and slot then
    local Arbol = require("compartido.dominio.arbol")
    local idh = Datos.barra[p.clase] and Datos.barra[p.clase][slot]
    h = idh and Arbol.efectiva(idh, math.max(1, Arbol.rango(p, idh) or 1))
    if h and h.tipo == "punto" and idh then
      local lista = (p.cds[idh] or 0) > mundo.tiempo or (p.mp or 0) < (h.mana or 0) or Arbol.rango(p, idh) < 1
      if not lista then
        if app.apuntando and app.apuntando.slot == slot then
          Entrada.lanzarApuntado(app)
        else
          app.apuntando = { slot = slot, rango = h.rango, aoe = h.aoe, nombre = h.nombre }
        end
        return
      end
    end
  end
  app.apuntando = nil
  app.actuar("habilidad", datos)
end

-- Lanza el poder que se esta apuntando sobre el punto del cursor (dentro de su alcance).
function Entrada.lanzarApuntado(app, mx, my)
  local ap, p, mundo = app.apuntando, app.jugador, app.mundo
  if not ap or not p or not mundo then app.apuntando = nil return end
  local datos = { slot = ap.slot }
  if not mx then mx, my = love.mouse.getPosition() end
  if Dibujo.dentroVista(mx, my) then
    local cam = Dibujo.camara(p, app.zoom, mundo:mapaDe(p))
    datos.x, datos.y = Dibujo.puntoApuntado(ap, p, cam, mx, my)
  end
  app.apuntando = nil
  app.actuar("habilidad", datos)
end

function Entrada.clicMundo(app, mx, my, boton)
  local mundo, jugador = app.mundo, app.jugador
  if not mundo or not jugador then return end
  if app.apuntando then
    if boton == 1 then Entrada.lanzarApuntado(app, mx, my) else app.apuntando = nil end
    return
  end
  if not Dibujo.dentroVista(mx, my) then return end
  local cam = Dibujo.camara(jugador, app.zoom, mundo:mapaDe(jugador))
  local x, y = Dibujo.pantallaAMundo(cam, mx, my)
  if jugador.modo == "casa" then
    local mapa = mundo:mapaDe(jugador)
    local puerta = mapa and mapa.puerta
    if puerta and Util.dist(x, y, puerta.x, puerta.y) < 0.75 then
      app.actuar("casa_salir")
      Interfaz.panel = nil
      Interfaz.muebleSel = nil
      return
    end
    local casa = jugador.casas and jugador.casas[jugador.casaId]
    local cercano, md
    if casa then
      for nombre in pairs(casa.muebles or {}) do
        local fx, fy = mundo:posMueble(casa, nombre)
        if fx then
          local d = Util.dist(x, y, fx, fy)
          if d < 0.9 and (not md or d < md) then cercano, md = nombre, d end
        end
      end
    end
    if boton == 2 then
      local tipo = cercano or Interfaz.muebleSel
      if tipo then
        app.actuar("mueble_rotar", { tipo = tipo })
        Interfaz.muebleSel = tipo
        return
      end
    elseif cercano and cercano ~= Interfaz.muebleSel then
      Interfaz.muebleSel = cercano
      return
    elseif Interfaz.muebleSel then
      app.actuar("mueble_mover", { tipo = Interfaz.muebleSel, x = x, y = y })
      return
    end
  end
  local ent = mundo:objetivoCercano(jugador, x, y, false)
  if ent and love.keyboard.isDown("lshift", "rshift") then
    app.actuar("mirar", { id = ent.id })
    return
  end
  if ent and boton == 2 and ent.kind == "jugador" and ent.id ~= jugador.id and not mundo:puedeDanar(jugador, ent) then
    -- clic derecho sobre otro jugador: menú de tratar, gremio, grupo
    app.actuar("objetivo", { id = ent.id, persigue = false })
    local esc = Interfaz.escala or 1
    Interfaz.menuJugador = { id = ent.id, x = mx / esc, y = my / esc }
    return
  end
  if ent and (boton == 1 or boton == 2) then
    local hostil = mundo:puedeDanar(jugador, ent)
    app.actuar("objetivo", { id = ent.id, persigue = hostil or boton == 2 })
    if not hostil and ent.kind == "npc" then app.actuar("interactuar") end
    -- un clic izquierdo sobre algo que no es un enemigo ni un PNJ (una caravana, otro jugador) también camina
    if hostil or ent.kind == "npc" or boton ~= 1 then return end
  end
  app.actuar("objetivo", { id = nil, persigue = false })
  app.actuar("destino", { x = x, y = y })
end

function Entrada.raton(app, mx, my, boton)
  local estado = app.estado
  if estado == "menu" or estado == "crear" or estado == "cuenta" or estado == "personajes" or (estado == "juego" and app.jugador) then
    local id = Interfaz.consumir(mx, my)
    if Interfaz.menuJugador then
      if id and id:sub(1, 4) == "ctx_" then Entrada.menuJugador(app, id) return end
      -- un clic fuera del menú lo cierra (si fue sobre el mundo, no mueve al personaje)
      Interfaz.menuJugador = nil
      if id == nil or id == "panel" then return end
    end
    if id == "mapa_area" then
      -- puede ser el inicio de un arrastre o un clic para viajar: se decide al soltar
      Interfaz.mapaArrastre = true
      Interfaz.mapaPresion = { x = mx, y = my, movido = 0 }
      return
    end
    if id then Entrada.manejar(app, id) return end
  end
  if estado == "juego" and app.jugador then
    Entrada.clicMundo(app, mx, my, boton)
  end
end

-- Acciones del menú del clic derecho (ids ctx_*).
function Entrada.menuJugador(app, id)
  local m = Interfaz.menuJugador
  Interfaz.menuJugador = nil
  if not m then return end
  if id == "ctx_trato" then app.actuar("comercio_invitar", { id = m.id })
  elseif id == "ctx_gremio" then app.actuar("gremio_invitar", { id = m.id })
  elseif id == "ctx_grupo" then app.actuar("grupo_invitar", { id = m.id })
  elseif id == "ctx_mirar" then app.actuar("mirar", { id = m.id }) end
end

-- Manda al servidor el oro escrito en el comercio (el servidor lo vuelve a validar).
function Entrada.fijarOroComercio(app)
  local p = app.jugador
  local s = p and p.sesion and app.mundo.sesiones[p.sesion]
  if not s then return end
  local mia = s.oferta[p.id]
  local disponible = (p.oro or 0) + (mia.oro or 0)
  local n = tonumber(Interfaz.comOro ~= "" and Interfaz.comOro or "0") or 0
  n = math.max(0, math.min(disponible, math.floor(n)))
  Interfaz.comOro = tostring(n)
  Interfaz.foco = nil
  app.actuar("comercio_oro", { oro = n })
end

function Entrada.moverRaton(app, x, y, dx, dy)
  local g = Interfaz.mapaGeom
  if Interfaz.panel == "mapa" and Interfaz.mapaArrastre and g and Interfaz.mapaCx then
    local esc = Interfaz.escala or 1
    local s = g.s0 * (Interfaz.mapaZoom or 1)
    if Interfaz.mapaPresion then Interfaz.mapaPresion.movido = Interfaz.mapaPresion.movido + math.abs(dx) + math.abs(dy) end
    Interfaz.mapaCx = Interfaz.mapaCx - dx / esc / s
    Interfaz.mapaCy = Interfaz.mapaCy - dy / esc / s
    Interfaz.mapaAjustar(g)
  end
end

-- Un clic corto sobre el mapa manda al personaje a ese sitio.
function Entrada.viajarPorMapa(app, mx, my)
  local g, p = Interfaz.mapaGeom, app.jugador
  if not g or not p or not Interfaz.mapaCx then return end
  local esc = Interfaz.escala or 1
  local s = g.s0 * (Interfaz.mapaZoom or 1)
  local wx = Interfaz.mapaCx + (mx / esc - (g.ax + g.aw / 2)) / s
  local wy = Interfaz.mapaCy + (my / esc - (g.ay + g.ah / 2)) / s
  if wx < 1 or wy < 1 or wx > g.mw - 1 or wy > g.mh - 1 then return end
  if p.modo ~= "mundo" or (p.z or 0) > 0 then
    Interfaz.aviso = "Solo se viaja por el mapa desde el mundo abierto."
    return
  end
  -- el mar y los otros continentes no se alcanzan a pie
  local mundoMapa = app.mundo.mapas.mundo
  local c1 = mundoMapa.cont[math.floor(p.x)] and mundoMapa.cont[math.floor(p.x)][math.floor(p.y)] or 0
  local c2 = mundoMapa.cont[math.floor(wx)] and mundoMapa.cont[math.floor(wx)][math.floor(wy)] or 0
  if c2 == 0 then
    Interfaz.aviso = "Ahí solo hay mar."
    return
  elseif c1 ~= c2 then
    Interfaz.aviso = "Ese sitio está en otro continente: usa el barquero de un puerto."
    return
  end
  app.actuar("objetivo", { id = nil, persigue = false })
  app.actuar("destino", { x = wx, y = wy })
  Interfaz.mapaDestino = { x = wx, y = wy }
end

function Entrada.soltarRaton(app, mx, my)
  local pres = Interfaz.mapaPresion
  Interfaz.mapaArrastre = false
  Interfaz.mapaPresion = nil
  if pres and pres.movido < 6 and Interfaz.panel == "mapa" and app and mx then
    Entrada.viajarPorMapa(app, mx, my)
  end
end

function Entrada.rueda(app, dy)
  -- sobre el chat, la rueda recorre los mensajes recibidos desde que entraste
  local r = Interfaz.consolaRect
  if r and app.estado == "juego" then
    local mx, my = love.mouse.getPosition()
    local esc = Interfaz.escala or 1
    mx, my = mx / esc, my / esc
    if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
      Interfaz.chatScroll = math.max(0, (Interfaz.chatScroll or 0) + (dy > 0 and 2 or -2))
      return
    end
  end
  if Interfaz.panel == "comercio" then
    local mx, my = love.mouse.getPosition()
    local esc = Interfaz.escala or 1
    mx, my = mx / esc, my / esc
    local function dentro(r) return r and mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h end
    if dentro(Interfaz.comListaA) then Interfaz.comScrollA = math.max(0, (Interfaz.comScrollA or 0) - dy)
    elseif dentro(Interfaz.comListaB) then Interfaz.comScrollB = math.max(0, (Interfaz.comScrollB or 0) - dy) end
  elseif Interfaz.panel == "mapa" and Interfaz.mapaGeom and Interfaz.mapaTab == "zonas" and Interfaz.zonasArea
    and (love.mouse.getPosition() / (Interfaz.escala or 1)) >= Interfaz.zonasArea.x then
    Interfaz.zonasScroll = math.max(0, math.min(Interfaz.zonasMax or 0, (Interfaz.zonasScroll or 0) - dy * 3))
  elseif Interfaz.panel == "mapa" and Interfaz.mapaGeom then
    local mx, my = love.mouse.getPosition()
    local esc = Interfaz.escala or 1
    Interfaz.mapaZoomar(dy > 0 and 1.25 or 1 / 1.25, mx / esc, my / esc)
  elseif Interfaz.panel == "vivienda" then
    Interfaz.casaScroll = math.max(0, math.min(Interfaz.casaScrollMax or 0, (Interfaz.casaScroll or 0) - dy))
  elseif Interfaz.panel == "mall" then
    Interfaz.mallScroll = math.max(0, math.min(Interfaz.mallScrollMax or 0, (Interfaz.mallScroll or 0) - dy * (Interfaz.mallTab == "addons" and 3 or 1)))
  elseif Interfaz.panel == "mercado" then
    Interfaz.scroll = math.max(0, Interfaz.scroll - dy)
  else
    app.zoom = math.max(1, math.min(3, app.zoom + dy * 0.25))
  end
end

function Entrada.texto(app, t)
  if Interfaz.foco == "nombre" then
    if #app.creacion.nombre < 16 then app.creacion.nombre = app.creacion.nombre .. t end
  elseif Interfaz.foco == "usuario" then
    if #app.cuenta.usuario < 16 and t:match("^[%w_]$") then app.cuenta.usuario = app.cuenta.usuario .. t end
  elseif Interfaz.foco == "clave" or Interfaz.foco == "clave2" then
    local campo = Interfaz.foco == "clave2" and "clave2" or "clave"
    app.cuenta[campo] = app.cuenta[campo] or ""
    if #app.cuenta[campo] < 64 and t:byte() >= 32 then app.cuenta[campo] = app.cuenta[campo] .. t end
  elseif Interfaz.foco == "chat" then
    if #Interfaz.texto < 120 then Interfaz.texto = Interfaz.texto .. t end
  elseif Interfaz.foco and Interfaz.foco:sub(1, 4) == "sub_" then
    local clave = Interfaz.foco:sub(5)
    Interfaz.subCampos = Interfaz.subCampos or { oferta = "", cant = "1", salida = "", compra = "" }
    if t:match("^%d$") and #(Interfaz.subCampos[clave] or "") < 9 then Interfaz.subCampos[clave] = (Interfaz.subCampos[clave] or "") .. t end
  elseif Interfaz.foco == "com_oro" then
    -- solo cifras y nunca más oro del que tienes
    if t:match("^%d$") then
      local actual = Interfaz.comOro or ""
      if actual == "0" then actual = "" end
      if #actual < 10 then
        local p = app.jugador
        local s = p and p.sesion and app.mundo.sesiones[p.sesion]
        local disponible = p and ((p.oro or 0) + ((s and s.oferta[p.id].oro) or 0)) or 0
        local n = math.min(tonumber(actual .. t) or 0, disponible)
        Interfaz.comOro = tostring(n)
      end
    end
  elseif Interfaz.foco == "gremio_nombre" then
    Interfaz.gremioNombre = Interfaz.gremioNombre or ""
    if #Interfaz.gremioNombre < 24 and t:byte() >= 32 then Interfaz.gremioNombre = Interfaz.gremioNombre .. t end
  elseif Interfaz.foco == "gremio_tag" then
    Interfaz.gremioTag = Interfaz.gremioTag or ""
    if #Interfaz.gremioTag < 4 and t:match("^%w$") then Interfaz.gremioTag = Interfaz.gremioTag .. t:upper() end
  end
end

function Entrada.tecla(app, tecla)
  if tecla == "escape" and app.apuntando then app.apuntando = nil return end
  -- en el formulario de cuenta, Tab salta entre usuario y clave (Mayús + Tab, al revés)
  if tecla == "tab" and (app.estado == "cuenta" or app.estado == "menu") then
    local crear = app.estado == "cuenta" and app.cuenta and app.cuenta.modo == "crear"
    if crear then
      if Interfaz.foco == "usuario" then Interfaz.foco = "clave"
      elseif Interfaz.foco == "clave" then Interfaz.foco = "clave2"
      else Interfaz.foco = "usuario" end
    elseif Interfaz.foco == "usuario" then Interfaz.foco = "clave"
    else Interfaz.foco = "usuario" end
    return
  end
  if tecla == "escape" then
    if Interfaz.menuJugador then Interfaz.menuJugador = nil return end
    if Ajustes.esperando then Ajustes.esperando = nil return end
    if app.estado == "cuenta" then app.estado = "menu" Interfaz.foco = nil return end
    if app.estado == "conectando" then
      local espera, origen = app.espera, app.origen
      local token = app.sesion and app.sesion.token
      require("src.presentacion.estados.juego").soltar(app)
      if espera == "personajes" or not token then app.estado = "cuenta"
      elseif origen == "crear" then app.estado = "crear"
      else app.estado = "personajes" end
      return
    end
    if app.estado == "personajes" then
      require("src.presentacion.estados.juego").soltar(app)
      app.sesion = { cuentaId = nil, usuario = "", personajes = {}, error = "" }
      app.estado = "menu"
      Interfaz.foco = nil
      return
    end
    if Interfaz.foco then Interfaz.foco = nil return end
    if Interfaz.panel then Interfaz.panel = nil return end
    if Interfaz.muebleSel then Interfaz.muebleSel = nil return end
    if app.estado == "juego" and app.jugador and app.jugador.objetivo then
      app.actuar("objetivo", { id = nil, persigue = false })
      return
    end
    if app.estado == "juego" then Interfaz.panel = "menu" return end
  end
  if tecla == "backspace" then
    if Interfaz.foco == "nombre" then app.creacion.nombre = Util.popUtf8(app.creacion.nombre)
    elseif Interfaz.foco == "usuario" then app.cuenta.usuario = Util.popUtf8(app.cuenta.usuario or "")
    elseif Interfaz.foco == "clave" then app.cuenta.clave = Util.popUtf8(app.cuenta.clave or "")
    elseif Interfaz.foco == "clave2" then app.cuenta.clave2 = Util.popUtf8(app.cuenta.clave2 or "")
    elseif Interfaz.foco == "chat" then Interfaz.texto = Util.popUtf8(Interfaz.texto or "")
    elseif Interfaz.foco == "com_oro" then Interfaz.comOro = Util.popUtf8(Interfaz.comOro or "")
    elseif Interfaz.foco and Interfaz.foco:sub(1, 4) == "sub_" then
      local clave = Interfaz.foco:sub(5)
      if Interfaz.subCampos then Interfaz.subCampos[clave] = Util.popUtf8(Interfaz.subCampos[clave] or "") end
    elseif Interfaz.foco == "gremio_nombre" then Interfaz.gremioNombre = Util.popUtf8(Interfaz.gremioNombre or "")
    elseif Interfaz.foco == "gremio_tag" then Interfaz.gremioTag = Util.popUtf8(Interfaz.gremioTag or "") end
    return
  end
  if tecla == "return" or tecla == "kpenter" then
    if app.estado == "juego" and Interfaz.foco == "com_oro" then Entrada.fijarOroComercio(app) return end
    if app.estado == "cuenta" or app.estado == "menu" then Entrada.manejar(app, "cuenta_ok") return end
    if app.estado == "crear" then Entrada.manejar(app, "crear_entrar") return end
    if app.estado == "juego" and Interfaz.foco == "chat" then
      app.actuar("chat", { texto = Interfaz.texto })
      Interfaz.texto = ""
      Interfaz.foco = nil
      return
    end
    if app.estado == "juego" and (Interfaz.foco == "gremio_nombre" or Interfaz.foco == "gremio_tag" or (Interfaz.foco and Interfaz.foco:sub(1, 4) == "sub_")) then
      Interfaz.foco = nil
      return
    end
    if app.estado == "juego" and not Interfaz.foco then
      Interfaz.foco = "chat"
      Interfaz.texto = ""
      return
    end
  end
  if app.estado == "juego" and Ajustes.esperando and tecla ~= "escape" and tecla ~= "f3" and tecla ~= "f11" then
    Ajustes.teclas[Ajustes.esperando] = tecla
    Ajustes.esperando = nil
    Ajustes.guardar()
    return
  end
  if tecla == "tab" and app.estado == "juego" and not Interfaz.foco then Entrada.siguienteObjetivo(app) return end
  if tecla == "f3" and app.estado == "juego" then app.depurar = not app.depurar return end
  if tecla == "f11" then
    Ajustes.completo = not Ajustes.completo
    Ajustes.aplicarVentana()
    Ajustes.guardar()
    return
  end
  if app.estado ~= "juego" or Interfaz.foco then return end
  local bolsa = (Ajustes.teclas and Ajustes.teclas.bolsa) or "i"
  local interactuar = (Ajustes.teclas and Ajustes.teclas.interactuar) or "e"
  if tecla == bolsa then Interfaz.panel = (Interfaz.panel ~= "bolsa") and "bolsa" or nil end
  if tecla == "p" or tecla == "c" then Interfaz.panel = (Interfaz.panel ~= "equipo") and "equipo" or nil end
  if tecla == "n" then
    local p = app.jugador
    local idx = p and (p.mascotaActiva or (p.mascotas and #p.mascotas > 0 and 1))
    if idx then app.actuar("mascota_invocar", { idx = idx }) end
  end
  if tecla == "j" then Interfaz.panel = (Interfaz.panel ~= "grupo") and "grupo" or nil end
  if tecla == "o" then app.actuar("montura_alternar", {}) end
  if tecla == "l" then Interfaz.panel = (Interfaz.panel ~= "mall") and "mall" or nil end
  if tecla == "y" then app.actuar("oficio_alternar", {}) end
  if tecla == "u" then Interfaz.panel = (Interfaz.panel ~= "montura") and "montura" or nil end
  if tecla == "r" then Interfaz.panel = (Interfaz.panel ~= "autopocion") and "autopocion" or nil end
  if tecla == "b" then
    -- robar: el objetivo elegido o la caravana / comerciante más cercano
    local p = app.jugador
    local mejor, md
    local o = p and p.objetivo and app.mundo.entidades[p.objetivo]
    if o and (o.kind == "caravana" or o.kind == "jugador") then mejor = o end
    if p and not mejor then
      for _, e in pairs(app.mundo.entidades) do
        if e.kind == "caravana" and e.vivo ~= false then
          local d = math.sqrt((e.x - p.x) ^ 2 + (e.y - p.y) ^ 2)
          if d < 4 and (not md or d < md) then mejor, md = e, d end
        end
      end
    end
    if mejor then app.actuar("robar", { id = mejor.id }) end
  end
  if tecla == "g" then
    if Interfaz.panel == "gremio" then Interfaz.panel = nil
    else
      Interfaz.pidiendoGremio = true
      app.actuar("gremio_info")
    end
  end
  if tecla == "k" then Interfaz.panel = (Interfaz.panel ~= "arbol") and "arbol" or nil end
  if tecla == "m" then Interfaz.panel = (Interfaz.panel ~= "mapa") and "mapa" or nil end
  if tecla == interactuar then app.actuar("interactuar") end
  if tecla == "t" then Entrada.manejar(app, "hud_comercio") end
  if tecla == "f1" then Interfaz.panel = "ayuda" end
  if tecla == "f2" then Interfaz.panel = (Interfaz.panel ~= "diaria") and "diaria" or nil end
  if tecla == "1" or tecla == "2" or tecla == "3" or tecla == "4" or tecla == "5" or tecla == "6" then
    Entrada.lanzarHabilidad(app, tonumber(tecla))
  end
  if tecla == "7" then beberPocion(app, "vida") end
  if tecla == "8" then beberPocion(app, "mana") end
end

return Entrada
