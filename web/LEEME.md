# Web de Dos Coronas

Sitio estático (HTML + CSS + JS, sin frameworks ni build) con la presentación del juego, la **guía completa** y la
**descarga del cliente de Windows**. Mismo estilo que la interfaz del juego: cristal azul oscuro con acentos dorados,
la tipografía Cinzel para los títulos y los sprites reales del juego en pixel art.

| Archivo | Qué es |
| --- | --- |
| `index.html` | Página principal: héroe, las dos coronas, clases con sus poderes, el mundo (galería), mazmorras y trampas, monturas, la guerra y la descarga. |
| `guia.html` | Guía del juego con índice lateral: primeros pasos, controles, pantalla, clases, combate, equipo, mundo, mazmorras, guerra, oficios, monturas, social, economía, consejos y problemas frecuentes. |
| `css/estilo.css`, `js/app.js` | Estilos y comportamiento (pestañas de clases, galería con visor, menú móvil, datos de la descarga). |
| `img/` | Portada, capturas del juego, sprites exportados (`img/sprites`) e iconos. |
| `descargas/` | `DosCoronas-Windows.zip` y `version.json` (los genera `publicar.ps1`; **no se suben a git**: el zip pesa ~85 MB). |
| `publicar.ps1` | Comprime el juego de `dist\` y escribe `version.json` con la versión, la fecha, el tamaño y la huella SHA-256. |

## Verla en tu PC

```powershell
cd web
python -m http.server 8099      # y abre http://localhost:8099
```

## Publicar una versión nueva del juego

1. Genera el cliente: `.\construir.ps1 -Servidor "IP_O_DOMINIO" -Puerto 30555` (cierra el juego antes, o el `.exe` de
   `dist\` estará en uso y no se podrá reconstruir).
2. Prepara la descarga: `.\web\publicar.ps1 -Version "beta 0.9"`. Si el juego de `dist\` está abierto, `-Origen` permite
   comprimir otra carpeta.
3. Sube la web al servidor (ver abajo) o copia `web\` a donde la alojes.

La página lee `descargas/version.json` y rellena sola la versión, la fecha, el tamaño y el SHA-256: no hay que editar el HTML.

## Regenerar las imágenes

- **Sprites** (clases, monturas y jefes, dibujados por el propio juego): `..\love\lovec.exe juego --web` deja los PNG
  en `juego\capturas\web\`; cópialos a `web\img\sprites\`.
- **Capturas**: `..\love\lovec.exe juego --foto` genera las de `juego\capturas\`; copia a `web\img\capturas\` las que
  quieras mostrar.

## Alojarla en el VPS (nginx)

El servidor del juego solo usa el puerto 30555; la web necesita además **80** (y **443** si pones HTTPS). En el VPS:

```bash
apt-get install -y nginx
mkdir -p /var/www/doscoronas
cat > /etc/nginx/sites-available/doscoronas <<'EOF'
server {
    listen 80;
    server_name _;            # pon aquí tu dominio cuando lo tengas
    root /var/www/doscoronas;
    index index.html;
    location / { try_files $uri $uri/ =404; }
    location /descargas/ { add_header Content-Disposition attachment; }
    gzip on; gzip_types text/css application/javascript image/svg+xml;
    location ~* \.(png|jpg|svg|css|js)$ { expires 7d; }
}
EOF
ln -sf /etc/nginx/sites-available/doscoronas /etc/nginx/sites-enabled/doscoronas
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx
ufw allow 80/tcp        # y 443/tcp si usas HTTPS
```

Subir los archivos: `.\web\publicar.ps1 -Subir root@IP_DEL_VPS` (copia `web\` a `/var/www/doscoronas`).

**HTTPS:** con un dominio apuntando al VPS, `apt-get install -y certbot python3-certbot-nginx && certbot --nginx -d tu.dominio`.
Sin HTTPS el navegador mostrará "No seguro" y algunos avisan al descargar el .exe/.zip.

## Notas

- La web enlaza Google Fonts (Cinzel y Source Sans 3); si falla, usa tipografías del sistema.
- El juego no está firmado digitalmente: Windows SmartScreen avisará la primera vez. La guía explica cómo continuar.
- Los datos de clases y monturas de `js/app.js` salen de `compartido/datos/*.xml`: si cambian las cifras del juego, actualízalos allí.
