# check-nic-optimization

Script de PowerShell que revisa (y opcionalmente corrige) la configuración
del adaptador de red activo -Ethernet o WiFi, de cualquier fabricante- que
suele causar que el throughput real se quede muy por debajo del LinkSpeed
negociado. Cubre bugs conocidos de EEE/Green Ethernet, modos de ahorro de
energía, dúplex mal negociado y búferes de transmisión/recepción por
debajo del máximo soportado.

## Uso rápido

1. Descarga `check-nic-optimizationV6Beta.ps1`
2. Abre PowerShell **como administrador**
3. Ve a la carpeta donde lo tienes:
   ```powershell
   cd C:\ruta\donde\lo\tengas
   ```
4. Permite ejecutar scripts en esta sesión:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   ```
5. Ejecuta:
   - Solo comprobar (no cambia nada):
     ```powershell
     .\check-nic-optimizationV6Beta.ps1
     ```
   - Comprobar y corregir automáticamente:
     ```powershell
     .\check-nic-optimizationV6Beta.ps1 -Fix
     ```

Si prefieres no repetir el paso 4 cada sesión, ejecuta una vez (no
requiere admin):
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Qué comprueba

**Ethernet:**
- Modo de Energía ultrabaja
- EEE / Green Ethernet
- Reducción de velocidad del enlace para el ahorro de energía
- Reducir velocidad al apagar
- Velocidad y dúplex (fuerza la opción Full Duplex de mayor velocidad,
  nunca Half Duplex ni Auto Negotiation)
- Búferes de transmisión/recepción (los sube al máximo que soporte la
  tarjeta concreta)

**WiFi:**
- Ahorro de energía WiFi (Power Saving Mode)
- Banda preferida (recomienda 5GHz si está disponible)
- Potencia de transmisión
- Ahorro de energía MIMO / SMPS (solo informativo, no hay un valor
  universalmente "correcto" aquí)

## Cómo leer el resultado

| Símbolo | Significado |
|---|---|
| `[OK]` verde | La propiedad ya está en el valor óptimo |
| `[MAL]` rojo | Está mal puesta; con `-Fix` se corrige sola si hay una opción válida |
| `[--]` gris | Esa propiedad no existe en este driver concreto (normal, no es un fallo) |
| `[i]` amarillo | Informativo, no se marca como error |

## Notas importantes

- **WiFi y proximidad al router:** aunque la banda preferida esté en
  5GHz, la conexión real puede seguir en 2.4GHz si hay poca señal (el
  5GHz tiene mucho menos alcance). El cambio de banda preferida solo se
  aplica la próxima vez que el adaptador negocia desde cero, no en
  caliente. Desconecta y reconecta la red para forzar la renegociación.

- **Actualizaciones de driver:** si Windows o tú actualizáis el driver
  de red, estos ajustes pueden resetearse a los valores de fábrica.
  Vuelve a correr el script tras cualquier actualización de driver o
  reinstalación de Windows.

- **VPN activa durante el test:** si tienes una VPN (OpenVPN,
  Tailscale...) conectada al hacer el speedtest, la velocidad puede
  estar limitada por el servidor VPN, no por tu red. Desconéctala para
  una medición limpia.

- **Revisa el código antes de ejecutarlo**, sobre todo con `-Fix`, ya
  que modifica configuración real del adaptador de red. Es buena
  práctica con cualquier script descargado de internet, incluido este.

## Contribuir

Si tu driver expone alguna propiedad que el script no detecta o detecta
mal (nombres varían bastante entre fabricantes, especialmente en WiFi),
abre un issue con:
- Fabricante y modelo del adaptador
- Nombre exacto de la propiedad tal como aparece en Windows
- Salida del script

Pull requests bienvenidas.

## Licencia

MIT
