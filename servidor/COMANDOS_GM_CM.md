# Comandos de GM y CM

Se escriben en el chat del juego y empiezan por `/admin`. Para usarlos la cuenta necesita un rol (se lee al **entrar al mundo**, así que hay que volver a entrar tras cambiarlo).

## Roles

| Rol | Qué puede hacer |
| --- | --- |
| **GM** | Todo. |
| **CM** (gestor de comunidad) | Moderar y ayudar. No puede repartir objetos, oro ni experiencia, invocar criaturas, activar el modo dios ni cambiar roles. Sus baneos duran 72 horas como máximo. |

Además, las cuentas listadas en el `.env` del servidor (`admins`) son GM.
Un CM no puede sancionar al personal; un GM no puede sancionar a otros GM.
Las criaturas (monstruos) **no atacan** a GM ni CM.

Asignar el rol por base de datos:

```sql
UPDATE cuentas SET rol = 'gm' WHERE usuario = 'miusuario';   -- 'gm', 'cm' o NULL
```

## Comandos para GM y CM

| Comando | Qué hace |
| --- | --- |
| `/admin ayuda` | Lista de comandos. |
| `/admin curar [jugador]` | Restaura vida y maná (a ti si no pones nombre). |
| `/admin revivir [jugador]` | Revive. |
| `/admin tp <x> <y>` | Te teletransporta a unas coordenadas. |
| `/admin tp <jugador>` | Te lleva junto a un jugador. |
| `/admin traer <jugador>` | Trae a un jugador a tu posición. |
| `/admin ciudad <id>` | Te lleva a una ciudad. |
| `/admin limpiar [radio]` | Quita las criaturas cercanas. |
| `/admin evento <estandarte\|batalla> <iniciar\|fin\|estado> [todos]` | Controla los eventos del mundo. |
| `/admin anuncio <texto>` | Aviso a todo el mundo. |
| `/admin jugadores` | Quién está conectado. |
| `/admin kick <jugador> [motivo]` | Expulsa a un jugador. |
| `/admin silenciar <jugador> <minutos>` | Silencia el chat (0 lo quita). |
| `/admin ban <usuario\|jugador> <30m\|2h\|3d\|perm> <motivo>` | Banea la cuenta (el CM: máximo 72 h, sin `perm`). |
| `/admin desban <usuario>` | Quita un baneo. |
| `/admin baneos` | Lista de cuentas baneadas. |

## Comandos solo para GM

| Comando | Qué hace |
| --- | --- |
| `/admin mob <id> [cantidad] [nivel]` | Invoca criaturas a tu lado (máx. 20). |
| `/admin mobs` | Lista de ids de criaturas. |
| `/admin item <id> [cantidad] [jugador]` | Da objetos (máx. 999). |
| `/admin items [texto]` | Lista de ids de objetos (filtra por texto). |
| `/admin oro <n> [jugador]` | Da oro. |
| `/admin xp <n> [jugador]` | Da experiencia. |
| `/admin nivel <n> [jugador]` | Fija el nivel. |
| `/admin monedas <n> [jugador]` | Da Monedas Corona del mall. |
| `/admin dios` | Invulnerable (activar/desactivar). |
| `/admin rol <usuario> <gm\|cm\|ninguno>` | Asigna el rol de una cuenta. |
| `/admin roles` | Lista quién tiene rol. |

## Notas

- Los baneos expulsan al jugador si está conectado y le impiden entrar hasta que caducan (o se quitan con `desban`).
- El código de los comandos está en `compartido/dominio/admin.lua`.
