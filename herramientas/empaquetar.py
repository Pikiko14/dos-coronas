"""Protege el paquete del juego antes de comprimirlo (lo llaman construir.ps1 y despliegue/ubuntu/publicar_parche.ps1).

  python -I -X utf8 herramientas/empaquetar.py <carpeta_stage> --love <carpeta de LÖVE> [--parche]

Sobre la carpeta (una copia temporal del juego, nunca el repositorio):
  - todo el .lua se compila a bytecode con el LuaJIT de LÖVE (herramientas/compilar_lua);
  - el código, los xml y demás datos se meten en un zip que se cifra como datos.dat (parche.dat en un parche);
  - el arte (png, jpg, ttf) se cifra archivo a archivo, en su sitio (arte/icono.png queda en claro: lo necesita conf.lua antes de montar nada);
  - main.lua pasa a ser un cargador mínimo (bytecode) que descifra y monta datos.dat; el main.lua original queda dentro como arranque.lua.
Formato cifrado: "DCX1" + semilla (4 bytes) + datos XOR un bloque de 4096 bytes que sale de la clave (recursos/clave_cifrado.txt) y la semilla.
Es una barrera contra abrir el paquete con WinRAR/7-Zip y copiar código o arte, no criptografía fuerte: la clave tiene que ir en el cliente."""
import argparse
import io
import os
import secrets
import subprocess
import sys
import tempfile
import zipfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARCHIVO_CLAVE = os.path.join(RAIZ, "recursos", "clave_cifrado.txt")
ACTIVOS = {".png", ".jpg", ".ttf"}
EN_CLARO = {"arte/icono.png"}
M32 = 0xFFFFFFFF

CARGADOR = '''-- Cargador del juego: descifra datos.dat (código y datos) y lo monta; el arte se descifra al vuelo (ver arranque.lua).
local ffi, bit = require("ffi"), require("bit")
local K = { %d, %d, %d, %d }
local bxor, lshift, rshift, band = bit.bxor, bit.lshift, bit.rshift, bit.band
local function xs(x) x = bxor(x, lshift(x, 13)); x = bxor(x, rshift(x, 17)); return bxor(x, lshift(x, 5)) end
local function bloque(semilla)
  local st = bxor(semilla, K[1])
  for i = 1, 4 do
    st = xs(bxor(st, K[i]))
    if st == 0 then st = 19088743 end
  end
  local blk = ffi.new("uint8_t[4096]")
  for i = 0, 1023 do
    st = xs(st)
    blk[4 * i], blk[4 * i + 1], blk[4 * i + 2], blk[4 * i + 3] = band(st, 255), band(rshift(st, 8), 255), band(rshift(st, 16), 255), band(rshift(st, 24), 255)
  end
  return blk
end
function DC_DESCIFRAR(s)
  if type(s) ~= "string" or #s < 8 or s:sub(1, 4) ~= "DCX1" then return nil end
  local a, b, c, d = s:byte(5, 8)
  local blk = bloque(a + b * 256 + c * 65536 + d * 16777216)
  local n = #s - 8
  local src = ffi.cast("const uint8_t*", s)
  local out = ffi.new("uint8_t[?]", n)
  for i = 0, n - 1 do out[i] = bxor(src[i + 8], blk[band(i, 4095)]) end
  return ffi.string(out, n)
end
local bruto = love.filesystem.read("datos.dat")
local plano = bruto and DC_DESCIFRAR(bruto)
if not plano then error("Paquete dañado: vuelve a descargar el juego.") end
DC_DATOS = love.filesystem.newFileData(plano, "datos.zip")
if not love.filesystem.mount(DC_DATOS, "", false) then error("No se pudo abrir el paquete del juego.") end
love.filesystem.load("arranque.lua")()
'''


def clave():
    if not os.path.exists(ARCHIVO_CLAVE):
        with open(ARCHIVO_CLAVE, "w") as f:
            f.write(secrets.token_hex(16) + "\n")
        print("Clave nueva en recursos/clave_cifrado.txt (haz commit: los parches futuros tienen que usar la misma)")
    h = open(ARCHIVO_CLAVE).read().strip()
    b = bytes.fromhex(h)
    if len(b) != 16:
        raise SystemExit("recursos/clave_cifrado.txt debe tener 32 caracteres hexadecimales")
    return [int.from_bytes(b[i:i + 4], "little") for i in range(0, 16, 4)]


def xs(x):
    x ^= (x << 13) & M32
    x ^= x >> 17
    x ^= (x << 5) & M32
    return x


def bloque(K, semilla):
    st = semilla ^ K[0]
    for i in range(4):
        st = xs(st ^ K[i])
        if st == 0:
            st = 19088743
    out = bytearray()
    for _ in range(1024):
        st = xs(st)
        out += st.to_bytes(4, "little")
    return bytes(out)


def cifrar(K, datos):
    semilla = secrets.randbits(32)
    blk = bloque(K, semilla)
    n = len(datos)
    clave_larga = (blk * (n // 4096 + 1))[:n]
    x = int.from_bytes(datos, "little") ^ int.from_bytes(clave_larga, "little")
    return b"DCX1" + semilla.to_bytes(4, "little") + x.to_bytes(n, "little")


def compilar(love, archivos):
    """archivos: [(ruta_real, nombre_en_el_paquete)]; se sustituyen por su bytecode."""
    with tempfile.TemporaryDirectory() as t:
        lista, res = os.path.join(t, "lista.txt"), os.path.join(t, "res.txt")
        with open(lista, "w", encoding="utf-8") as f:
            for ruta, nombre in archivos:
                f.write(ruta + "\t" + nombre + "\n")
        exe = os.path.join(love, "love.exe")
        herr = os.path.join(RAIZ, "herramientas", "compilar_lua")
        subprocess.run([exe, herr, lista, res], check=False, timeout=600)
        r = open(res, encoding="utf-8").read() if os.path.exists(res) else "sin resultado"
        if not r.startswith("OK"):
            raise SystemExit("No se pudo compilar el Lua: " + r)
        print("Lua compilado a bytecode: " + r[3:] + " archivos")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("stage")
    ap.add_argument("--love", required=True)
    ap.add_argument("--parche", action="store_true")
    a = ap.parse_args()
    stage = os.path.abspath(a.stage)
    K = clave()
    todos = []
    for d, _, fs in os.walk(stage):
        for f in fs:
            ruta = os.path.join(d, f)
            todos.append((ruta, os.path.relpath(ruta, stage).replace("\\", "/")))
    if not a.parche:
        os.replace(os.path.join(stage, "main.lua"), os.path.join(stage, "arranque.lua"))
        todos = [(r, "arranque.lua" if n == "main.lua" else n) for r, n in todos]
        todos = [(r if n != "arranque.lua" else os.path.join(stage, "arranque.lua"), n) for r, n in todos]
        cargador = os.path.join(stage, "main.lua")
        with open(cargador, "w", encoding="utf-8", newline="\n") as f:
            f.write(CARGADOR % tuple(K))
        todos.append((cargador, "main.lua"))
    luas = [(r, n) for r, n in todos if n.endswith(".lua")]
    compilar(a.love, luas)
    nombre_dat = "parche.dat" if a.parche else "datos.dat"
    buf = io.BytesIO()
    nblob = narte = 0
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        for ruta, n in todos:
            if n in ("main.lua", "conf.lua") and not a.parche:
                continue                                              # se quedan sueltos (bytecode): LÖVE los lee antes de montar nada
            ext = os.path.splitext(n)[1].lower()
            if ext in ACTIVOS:
                if n in EN_CLARO:
                    continue
                datos = open(ruta, "rb").read()
                open(ruta, "wb").write(cifrar(K, datos))
                narte += 1
                continue
            z.write(ruta, n)
            os.remove(ruta)
            nblob += 1
    open(os.path.join(stage, nombre_dat), "wb").write(cifrar(K, buf.getvalue()))
    for d, ds, fs in os.walk(stage, topdown=False):                  # (carpetas que se quedaron vacías)
        if d != stage and not os.listdir(d):
            os.rmdir(d)
    print("%s: %d archivos de código/datos (%.1f MB comprimido), %d de arte cifrados" % (nombre_dat, nblob, len(buf.getvalue()) / 2**20, narte))


main()
