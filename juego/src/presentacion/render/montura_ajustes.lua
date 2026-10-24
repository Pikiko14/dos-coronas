-- Ajustes a mano del asiento del jinete (px de pantalla), por montura y hoja de dirección (0 frente, 1 espalda, 2 espalda-izquierda, 3 izquierda,
-- 4 frente-izquierda). Lo escribe src/presentacion/ajuste_montura.lua (F9 en el juego).
return {
  mnt_001 = { [0] = { -1, 3 }, [1] = { 0, 10.5 }, [2] = { 5, -1.5 }, [3] = { 6, 1 }, [4] = { 2.5, 0.5 } },
  mnt_027 = { [1] = { 1, 5.5 }, [2] = { 4, 2 }, [3] = { 8, 1 }, [4] = { 3, -1.5 } },
  mnt_037 = { [4] = { 9.5, -4 } },
  mnt_039 = { [0] = { -0.5, -6 }, [3] = { 1, -3 }, [4] = { -0.5, -6 } },
}
