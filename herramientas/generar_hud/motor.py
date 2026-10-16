"""Motor de dibujo de iconos con volumen (elipsoides, cápsulas y polígonos sombreados con luz arriba a la izquierda, brillo y contorno oscuro) sobre un
lienzo supermuestreado. Lo usa iconos.py para los iconos del HUD."""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

LUZ = np.array([-0.55, -0.65, 0.52]); LUZ = LUZ / np.linalg.norm(LUZ)


class Lienzo:
    def __init__(self, tam=64, ss=6):
        self.tam, self.ss = tam, ss
        n = tam * ss
        self.rgb = np.zeros((n, n, 3), dtype=np.float32)
        self.a = np.zeros((n, n), dtype=np.float32)
        yy, xx = np.mgrid[0:n, 0:n]
        self.xx = xx.astype(np.float32) / ss
        self.yy = yy.astype(np.float32) / ss

    def _pintar(self, mask, nx, ny, nz, color, brillo=0.5, oscuro=0.5, alfa=1.0):
        c = np.array(color[:3], dtype=np.float32)
        sombra = np.clip(c * oscuro * np.array([0.9, 0.85, 1.15]), 0, 255)
        d = np.clip(nx * LUZ[0] + ny * LUZ[1] + nz * LUZ[2], 0, 1)
        base = sombra[None, None, :] + (c * 1.12 - sombra)[None, None, :] * (d ** 0.9)[..., None]
        h = np.array([LUZ[0], LUZ[1], LUZ[2] + 1.0]); h /= np.linalg.norm(h)
        base = base + (np.clip(nx * h[0] + ny * h[1] + nz * h[2], 0, 1) ** 24 * brillo)[..., None] * 190.0
        base = np.clip(base, 0, 255)
        m = (mask * alfa)[..., None]
        self.rgb = self.rgb * (1 - m) + base * m
        self.a = np.maximum(self.a, mask * alfa)

    def elipsoide(self, cx, cy, rx, ry, color, giro=0.0, **kw):
        c, s = math.cos(giro), math.sin(giro)
        dx, dy = self.xx - cx, self.yy - cy
        u = (dx * c + dy * s) / rx
        v = (-dx * s + dy * c) / ry
        r2 = u * u + v * v
        mask = np.clip((1 - r2) * min(rx, ry) * self.ss * 0.9, 0, 1)
        z = np.sqrt(np.clip(1 - r2, 0, 1))
        nx, ny = (u * c - v * s) * 0.92, (u * s + v * c) * 0.92
        n = np.sqrt(nx * nx + ny * ny + z * z) + 1e-6
        self._pintar(mask, nx / n, ny / n, z / n, color, **kw)

    def capsula(self, p0, p1, r0, r1, color, **kw):
        (x0, y0), (x1, y1) = p0, p1
        vx, vy = x1 - x0, y1 - y0
        l2 = vx * vx + vy * vy + 1e-6
        t = np.clip(((self.xx - x0) * vx + (self.yy - y0) * vy) / l2, 0, 1)
        px, py = x0 + t * vx, y0 + t * vy
        r = r0 + (r1 - r0) * t
        dx, dy = self.xx - px, self.yy - py
        d = np.sqrt(dx * dx + dy * dy)
        mask = np.clip((r - d) * self.ss * 0.9, 0, 1)
        q = np.clip(d / np.maximum(r, 1e-3), 0, 1)
        z = np.sqrt(np.clip(1 - q * q, 0, 1))
        nx, ny = dx / np.maximum(r, 1e-3) * 0.95, dy / np.maximum(r, 1e-3) * 0.95
        n = np.sqrt(nx * nx + ny * ny + z * z) + 1e-6
        self._pintar(mask, nx / n, ny / n, z / n, color, **kw)

    def poligono(self, pts, color, curvatura=0.6, **kw):
        im = Image.new("L", (self.tam * self.ss, self.tam * self.ss), 0)
        ImageDraw.Draw(im).polygon([(x * self.ss, y * self.ss) for x, y in pts], fill=255)
        suave = np.asarray(im.filter(ImageFilter.GaussianBlur(self.ss * 1.6)), dtype=np.float32) / 255.0
        gy, gx = np.gradient(suave)
        k = 5.0 * curvatura * self.ss
        nx, ny = -gx * k, -gy * k
        nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0.05, 1))
        n = np.sqrt(nx * nx + ny * ny + nz * nz)
        mask = np.asarray(im.filter(ImageFilter.GaussianBlur(self.ss * 0.4)), dtype=np.float32) / 255.0
        self._pintar(mask, nx / n, ny / n, nz / n, color, **kw)

    def mancha(self, cx, cy, rx, ry, color, alfa=0.9, suave=0.5):
        u, v = (self.xx - cx) / rx, (self.yy - cy) / ry
        m = np.clip((1 - np.sqrt(u * u + v * v)) / max(suave, 1e-3), 0, 1) * alfa * (self.a > 0.5)
        self.rgb = self.rgb * (1 - m[..., None]) + np.array(color[:3], dtype=np.float32) * m[..., None]

    def brillo(self, cx, cy, r, alfa=0.9):
        """Destello blanco suave (sobre lo ya dibujado)."""
        u, v = (self.xx - cx) / r, (self.yy - cy) / r
        m = np.clip(1 - np.sqrt(u * u + v * v), 0, 1) ** 1.6 * alfa * (self.a > 0.3)
        self.rgb = self.rgb * (1 - m[..., None]) + 255.0 * m[..., None]

    def contorno(self, grosor=1.3, color=(24, 18, 34)):
        solido = (self.a > 0.6).astype(np.float32)
        im = Image.fromarray((solido * 255).astype(np.uint8))
        k = max(3, int(grosor * self.ss) | 1)
        dil = np.asarray(im.filter(ImageFilter.MaxFilter(k)), dtype=np.float32) / 255.0
        anillo = np.asarray(Image.fromarray((np.clip(dil - solido, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(self.ss * 0.3)), dtype=np.float32) / 255.0
        libre = (1 - self.a)
        self.rgb = self.rgb * (1 - (anillo * libre)[..., None]) + np.array(color, dtype=np.float32) * (anillo * libre)[..., None]
        self.a = np.maximum(self.a, anillo * 0.95)

    def imagen(self):
        rgba = np.dstack([np.clip(self.rgb, 0, 255), np.clip(self.a, 0, 1) * 255]).astype(np.uint8)
        return Image.fromarray(rgba, "RGBA").resize((self.tam, self.tam), Image.LANCZOS)
