-- Contrato entre el servidor y el juego: un mensaje por línea, en JSON.
-- Lo usan los dos proyectos; si cambia algo aquí, cambia para ambos.
--
-- Cliente -> servidor
--   { t = "cuenta", a = "registrar" | "entrar", usuario, clave }
--   { t = "cuenta", a = "crear", token, nombre, faccion, clase }
--   { t = "hola", token, personaje }          entra al mundo con un personaje
--   { t = "act", a = <acción>, p = {...} }    acción de juego (ver ACCIONES)
--
-- Servidor -> cliente
--   { t = "sesion", token, usuario, cuenta, personajes, creado }
--   { t = "ok", id, nombre }                  entró al mundo; id es su entidad
--   { t = "snap", snap = {...} }              estado del mundo (ver Mundo:foto)
--   { t = "panel", panel, ciudad }            abre un panel (tienda, encargos...)
--   { t = "no", error }                       rechazo con motivo
local P = {}

P.CLIENTE = {
  CUENTA = "cuenta", HOLA = "hola", ACCION = "act",
}

P.SERVIDOR = {
  SESION = "sesion", OK = "ok", FOTO = "snap", PANEL = "panel", NO = "no",
}

P.CUENTA = { REGISTRAR = "registrar", ENTRAR = "entrar", CREAR = "crear" }

-- Acciones de juego que el servidor acepta (las valida Autoridad en el servidor).
-- No hay acción de guardar: el servidor guarda solo (periódicamente, al salir y al cerrar).
P.ACCIONES = {
  "deseo", "destino", "objetivo", "habilidad", "chat", "equipar", "desequipar",
  "pocion", "comprar", "vender", "interactuar", "guerra", "salir_guerra",
  "casa_comprar", "casa_entrar", "casa_salir", "mueble", "cofre_guardar",
  "cofre_sacar", "mision_aceptar", "mision_entregar", "comercio_invitar",
  "comercio_oro", "comercio_item", "comercio_ok", "comercio_no", "mover_bolsa",
  "mirar", "aprender", "olvidar", "encantar", "mascota_adoptar", "mascota_invocar",
  "gremio_info", "gremio_crear", "gremio_invitar", "gremio_responder", "gremio_salir", "gremio_expulsar",
  "gremio_rango", "gremio_disolver", "oficio_elegir", "oficio_info", "mercancia_info", "mercancia_comprar",
  "mercancia_vender", "robar", "perista_vender", "montura_comprar", "montura_alternar", "montura_info", "escoltar",
  "subasta_info", "subasta_publicar", "subasta_pujar", "subasta_comprar", "subasta_cancelar", "subasta_cobrar",
}

return P
