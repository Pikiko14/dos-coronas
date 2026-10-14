# Cambia el icono de un .exe de Windows por el de un archivo .ico, con las funciones de recursos de Windows
# (BeginUpdateResource / UpdateResource), sin programas externos. Lo usa construir.ps1 sobre una copia de love.exe
# ANTES de pegarle el juego (los recursos de un .exe se reescriben y no conviene tocar uno que ya lleva datos añadidos).
#   . .\recursos\PonerIcono.ps1 ; Poner-Icono "C:\ruta\love-copia.exe" "recursos\DosCoronas.ico"
# Sustituye el grupo de iconos 1 y sus imágenes (love.exe trae 6, en el idioma 1033); el .ico debe traer 6 tamaños o menos.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class RecursosExe {
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern IntPtr BeginUpdateResource(string f, bool borrar);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool UpdateResource(IntPtr h, IntPtr tipo, IntPtr nombre, ushort idioma, byte[] datos, uint largo);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool EndUpdateResource(IntPtr h, bool descartar);
}
"@

function Poner-Icono([string]$Exe, [string]$Ico) {
  $b = [System.IO.File]::ReadAllBytes((Resolve-Path $Ico).Path)
  $n = [BitConverter]::ToUInt16($b, 4)
  if ([BitConverter]::ToUInt16($b, 2) -ne 1 -or $n -lt 1) { throw "No es un .ico válido: $Ico" }
  $h = [RecursosExe]::BeginUpdateResource((Resolve-Path $Exe).Path, $false)
  if ($h -eq [IntPtr]::Zero) { throw "No se pudo abrir $Exe para cambiar sus recursos." }
  try {
    $idioma = 1033
    $grupo = New-Object System.Collections.Generic.List[byte]
    $grupo.AddRange([byte[]](0, 0, 1, 0)); $grupo.AddRange([BitConverter]::GetBytes([uint16]$n))
    for ($i = 0; $i -lt $n; $i++) {
      $e = 6 + 16 * $i
      $tam = [BitConverter]::ToUInt32($b, $e + 8)
      $off = [BitConverter]::ToUInt32($b, $e + 12)
      $img = New-Object byte[] $tam
      [Array]::Copy($b, $off, $img, 0, $tam)
      $id = $i + 1
      if (-not [RecursosExe]::UpdateResource($h, [IntPtr]3, [IntPtr]$id, $idioma, $img, $tam)) { throw "UpdateResource (imagen $id) falló." }
      # entrada del grupo: ancho, alto, colores, 0, planos, bits, tamaño y número de imagen
      $grupo.AddRange([byte[]]$b[$e..($e + 7)])
      $grupo.AddRange([BitConverter]::GetBytes([uint32]$tam))
      $grupo.AddRange([BitConverter]::GetBytes([uint16]$id))
    }
    $datos = $grupo.ToArray()
    if (-not [RecursosExe]::UpdateResource($h, [IntPtr]14, [IntPtr]1, $idioma, $datos, $datos.Length)) { throw "UpdateResource (grupo) falló." }
    if (-not [RecursosExe]::EndUpdateResource($h, $false)) { throw "EndUpdateResource falló." }
  } catch {
    [void][RecursosExe]::EndUpdateResource($h, $true)
    throw
  }
}
