# Changelog

## v1.0
- Check inicial para Intel I219-V: Energía ultrabaja, EEE, Velocidad y
  dúplex, búferes de transmisión/recepción.

## v2.0
- Selección de adaptador corregida: en vez de coger el primer adaptador
  activo (podía coger dongles tipo Xbox Wireless), ahora usa el que
  tiene puerta de enlace real (gateway).
- Velocidad/dúplex generalizado para aceptar cualquier velocidad forzada
  (no solo 1Gbps), pensado para NICs 2.5G/5G/10G futuras.
- Búferes generalizados: compara contra el máximo real que soporta cada
  tarjeta en vez de un número fijo.

## v3.0
- Soporte WiFi añadido: detecta si el adaptador activo es Ethernet o
  WiFi y aplica los checks correspondientes (ahorro de energía, banda
  preferida, potencia de transmisión).
- Patrones ampliados para cubrir Intel, Realtek, Broadcom, Marvell/
  Aquantia y Killer, no solo Intel.
- Nuevos checks en Ethernet: reducción de velocidad del enlace para
  ahorro y reducir velocidad al apagar.
- Añadida función `Remove-Diacritics` para mostrar en consola cualquier
  texto (incluidos nombres que devuelve Windows con tilde real) sin
  caracteres corruptos, independientemente del codepage de la consola.

## v3.1 - Bugfix
- **Bug:** el `-Fix` de "Velocidad y dúplex" solo exigía que el valor
  contuviera "Gbps"/"Mbps", sin excluir Half Duplex. Como las listas de
  `ValidDisplayValues` suelen ir de menor a mayor velocidad, podía coger
  la primera opción (ej. "10 Mbps Half Duplex") en vez de la mejor.
- **Fix:** nueva función dedicada `Test-SpeedDuplex` que excluye Half
  Duplex y Auto explícitamente, y elige la opción Full Duplex de mayor
  velocidad numérica entre las disponibles.

## v3.2 - Bugfix
- **Bug:** el filtro de Full Duplex buscaba literalmente "Full Duplex"
  sin tilde, pero algunos drivers (Realtek en español) devuelven
  "Full Dúplex" con tilde en la ú. Al no coincidir el carácter exacto,
  el script no encontraba ninguna opción válida aunque sí existiera.
- **Fix:** patrón cambiado a `Full D.plex` con comodín para aceptar la
  vocal con o sin tilde, igual que el resto de patrones del script.

## v3.3 - Bugfix
- **Bug:** el patrón de "Ahorro de energía WiFi" (búsqueda de
  subcadena) también coincidía con "Ahorro de energía MIMO" (SMPS),
  una propiedad distinta con sus propios valores válidos, causando que
  se le aplicara la regla equivocada.
- **Fix:** añadido parámetro `ExcludePattern` a `Test-Setting` para
  evitar solapes entre propiedades con nombres parecidos. El ahorro de
  energía MIMO/SMPS pasa a mostrarse como `[i]` informativo en vez de
  `[MAL]`, ya que no existe un valor universalmente "correcto" para esa
  propiedad en todos los drivers.
