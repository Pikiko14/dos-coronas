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
  "mirar", "aprender", "olvidar",
}

return P
