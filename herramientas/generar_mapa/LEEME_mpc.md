
## Cómo se entra y se sale
- Entrar: el administrador escribe `/admin mapa riprap` en el chat (solo GM). Aún no hay puerta en los continentes (no se toca la generación del mundo). Candidato natural para una
  puerta futura: la costa oeste de Auroria, mirando al mar (el mapa 2 es una costa con una isla).
- Aparecer: en la casilla transitable del mayor continente de casillas del mapa más cercana al 35 % del ancho y 60 % del alto (la playa del oeste).
- Salir: pisar uno de los dos triángulos del borde (puntos 1 y 2 del .mpc; en FAO son los eventos 1 y 2, saltos a los mapas 4 y 5) o `/admin mapa salir`. Se vuelve al sitio de donde se entró.
  Morir dentro devuelve al punto de reaparición del mundo. Los pergaminos de teletransporte no funcionan dentro.

## Cómo se añade otro .mpc
1. Deja el `.mpc` en `C:\Users\User\Downloads\map\` (o apunta `FAO_MAPAS` a su carpeta) y los `.pak` de FAO en Descargas (`FAO_DESCARGAS`).
2. `python herramientas/generar_mapa/hornear_mpc.py 3` (número del mapa: `map003.mpc`): copia el .mpc a `compartido/datos/mapas_fao/`, genera `mapNNN_datos.lua` y los atlas de `juego/arte/mapas_fao/`.
3. En `compartido/dominio/mapas_fao.lua`, añade `nombre = 3` a `M.MAPAS`; el comando `/admin mapa nombre` ya sirve y la ayuda del admin lo lista.
4. Ajusta las reglas de colisión si hace falta (`reglas_mpc.py`) y vuelve a hornear.

## Qué trae el .mpc y qué se usa (ver mpc.py, que lo documenta campo por campo)
Cuadrícula de 300x186 casillas (tileset de pincel + atributo del terreno), 2083 objetos (id de `setting/mapobj.obd` + posición en px), 6 rutas, 29 registros de puntos (2 salidas,
14 puntos sueltos, 13 zonas), 14 eventos y diálogos XML. Se usan: cuadrícula, objetos, salidas. Se leen pero NO se conectan: rutas, puntos 31-44, zonas, eventos, diálogos.

## Lo que sigue sin descifrar (mejor hipótesis)
- Cabecera: `[3] = 0x00010005` (versión/flags), `[10] = 1` (versión de la sección de eventos), `[11]`, `[12]` = 0.
- Byte 3 de la celda (31..44 en 700 celdas, todas en una zona del mar al sur) y atributos 3 y 10 del byte 1 (bordes sueltos y esa misma zona del mar): sin significado conocido; se tratan como bloqueo.
- Objetos: tras `id, x, y` hay `a` (0/50/80/400), `espejo` (0/1/2; hipótesis: 2 = espejado horizontal; NO se aplica: sin referencia no se pudo comprobar), `c` (byte bajo 0xC0 = transparencia 192?
  y un byte alto 0x47/0x4e en ~126 registros) y ceros.
- Rutas (id, puntos con tipo 3/5): hipótesis, rutas de patrulla de criaturas/PNJ. Puntos 31-44: un punto cada uno, a lo largo de una diagonal (hipótesis: puntos de aparición); 71-83: zonas poligonales.
- Eventos: acciones numeradas con parámetros; solo se entiende la 3 con (4,1) / (5,1) = salto al mapa 4 / 5.
- Los ids >= 40000 del .mpc (marcas TAG de `server.obd`, generadores y PNJ de `npc.obd`) no se dibujan ni se conectan (30 ids "inertes" en map002).

## Criaturas (campamentos del editor)
Si junto al `.mpc` hay `mapNNN_campamentos.lua` (lo escribe el editor de mapas: lista de `{ monstruo, cantidad, radio, x, y, jefe?, nivel? }`, con x, y y radio en **celdas del .mpc**), `MapaMpc.cargar` lo valida
(monstruo existente en monstruos.xml, números, dentro del mapa; un campamento sobre una casilla bloqueada del juego se mueve a la libre más cercana, hasta 3 casillas) y lo deja en `mapa.campamentos`
ya en casillas del juego (2 x 2 celdas). `Mundo:poblarMapasFao()` crea las criaturas igual que `Mundo:poblar()` pero con `modo` = el nombre del mapa, así solo las ven y pelean con ellas quienes están dentro;
reaparecen en su campamento con el ciclo normal. Los mapas registrados están en `M.MAPAS` de `mapas_fao.lua` (`/admin mapa <nombre>`).

## Vista y escala
FAO dibuja sus mapas en **vista cenital** (su minimapa `shape/smap/002.png` lo demuestra: el puente llega a la isla y los muros siguen la costa). Girarlos a isométrica desarma los objetos,
así que **solo los mapas de FAO se ven en cenital**; los continentes siguen en isométrica (no se ha tocado). `D.camara` llama a `Iso.forzar(false)` cuando el mapa trae `mapa.mpc` y a `Iso.forzar(nil)` en
el resto. Escala nativa: con el zoom 2 de Dos Coronas un píxel de FAO es un píxel de pantalla; la casilla del juego (32 px de mundo) son 64 px de FAO = **2 x 2 celdas del .mpc**,
de modo que el mapa de 300x186 celdas es una cuadrícula de juego de **150x93**. Pasar el juego entero a cenital (existe `DC_ISO=0`) queda pendiente: afectaría al arte isométrico de continentes, casas y props.

## Colisiones
El byte 1 de cada celda no es un índice de tile sino el **atributo del terreno**: 0 libre, 1 obstáculo (árboles, arbustos, rocas, cajas), 2 agua o risco, 3 y 10 casos sueltos (comprobado: los árboles y
las cajas están sobre celdas 1, los destellos del agua sobre celdas 2 y las salidas sobre celdas 0). Una casilla del juego (2 x 2 celdas) se bloquea si alguna celda es obstáculo (1, 3, 10) o si
hay 2 o más celdas de agua/risco (2). Los árboles, rocas y cajas ya están en el atributo del terreno. Además cierran sus casillas los objetos grandes con ZBUFFER que FAO no marca en la cuadrícula (barcas 船, mesas 桌, puestos 攤, estantes 架,
sillas, bancos, cestas, barriles, cajas; `BLOQUEAN_OBJ` en `mapa_mpc.lua`): su casco es un rectángulo del 80 % del ancho del sprite y 1 casilla de fondo sobre el punto de apoyo. Los tablones, pilotes y bordes
(`p` = piezas de suelo) y todo lo que tenga 橋, 欄, 板 o 墩 en el nombre no bloquean nunca. Correcciones por mapa: `mapNNN_reglas.lua` opcional, `return { bloquean = { id o parte del nombre }, pasan = { ... }, huellas = { [id o nombre] = { w = casillas, d = casillas } } }`.
Los objetos altos con `z` que quedan delante del personaje y le tapan el torso se dibujan al 45 %.
Los puentes de madera (木橋) no abren paso sobre el agua todavía.
Validado con `DC_PRUEBA_MAPA_FAO=1 lovec juego --test` (`juego/capturas/mapa_fao.png`, con las casillas bloqueadas marcadas, y `mapa_fao_bloqueo.png`; `=grid` y `=catalogo` dan otras capturas).

## Suelo y objetos
Cada tileset de pincel (`brush/brush.bNN`) es una textura continua de 512x512 (la 8x8, de 256x256); cada casilla del juego toma el trozo de 64x64 que le toca por su posición
((x mod 8) * 64, (y mod 8) * 64), se dibuja a 0,5 y se funde 12 px con el vecino donde cambia el tileset. FAO usa además máscaras de mezcla (`brush.pNN`); aquí se sustituyen por un degradado simple.
Los objetos se hornean a escala 1 (atlas de 2048 px de ancho, con los cuadros de animación y las sombras) y se dibujan a 0,5 ordenados por su y con los personajes; las sombras son la silueta
negra (mismo nombre con `US` en vez de `U0`) al 40 % de opacidad.
