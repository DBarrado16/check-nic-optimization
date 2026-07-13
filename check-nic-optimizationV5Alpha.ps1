<#
.SYNOPSIS
    Comprueba (y opcionalmente corrige) la configuracion del adaptador de red
    activo -sea Ethernet o WiFi, de cualquier fabricante- que suele causar que
    el throughput real se quede muy por debajo del LinkSpeed negociado.

.USAGE
    Solo comprobar (no cambia nada):
        .\check-nic-optimization.ps1

    Comprobar y corregir automaticamente lo que este mal:
        .\check-nic-optimization.ps1 -Fix

    Requiere PowerShell como Administrador.
#>

param(
    [switch]$Fix
)

# Quita tildes/acentos de cualquier texto antes de mostrarlo en consola.
# Windows devuelve nombres de propiedad con tildes reales (ej "Energia" con
# acento), y segun la consola/codepage eso puede salir como caracteres raros.
# Esto lo evita del todo sin tocar los patrones de busqueda, que siguen
# intactos y detectan igual los nombres originales con o sin tilde.
function Remove-Diacritics {
    param([string]$Text)
    if (-not $Text) { return $Text }
    $normalized = $Text.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $normalized.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }
    return $sb.ToString().Normalize([Text.NormalizationForm]::FormC)
}

# --- Selecciona la interfaz que realmente tiene salida a internet (gateway real) ---
# En vez de coger "el primer adaptador activo" (poco fiable: cosas como el dongle
# de Xbox Wireless tambien aparecen como activo), buscamos la que tiene puerta
# de enlace IPv4, que es la que de verdad te conecta a internet.
$ipConfig = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1

if (-not $ipConfig) {
    Write-Host "No se encontro ninguna interfaz con puerta de enlace activa (sin conexion a internet detectada)." -ForegroundColor Red
    exit 1
}

$adapter = Get-NetAdapter -InterfaceIndex $ipConfig.InterfaceIndex

if (-not $adapter) {
    Write-Host "No se pudo resolver el adaptador correspondiente a la interfaz con gateway." -ForegroundColor Red
    exit 1
}

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " Adaptador: $($adapter.Name) - $(Remove-Diacritics $adapter.InterfaceDescription)"
Write-Host " LinkSpeed actual: $($adapter.LinkSpeed)"
Write-Host "==============================================`n"

$props = Get-NetAdapterAdvancedProperty -Name $adapter.Name -AllProperties -ErrorAction SilentlyContinue

function Test-Setting {
    param(
        [string]$NamePattern,
        [string]$GoodPattern,
        [string]$Label
    )
    $matchList = $props | Where-Object { $_.DisplayName -match $NamePattern }
    if (-not $matchList) {
        Write-Host "[--] $Label : propiedad no existe en este driver (normal segun fabricante/modelo)" -ForegroundColor DarkGray
        return
    }
    foreach ($p in $matchList) {
        $cleanName = Remove-Diacritics $p.DisplayName
        $cleanValue = Remove-Diacritics $p.DisplayValue
        if ($p.DisplayValue -match $GoodPattern) {
            Write-Host "[OK] $cleanName : $cleanValue" -ForegroundColor Green
        } else {
            Write-Host "[MAL] $cleanName : $cleanValue" -ForegroundColor Red
            if ($Fix) {
                $target = $p.ValidDisplayValues | Where-Object { $_ -match $GoodPattern } | Select-Object -First 1
                if ($target) {
                    try {
                        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $p.DisplayName -DisplayValue $target -ErrorAction Stop
                        Write-Host "     -> Corregido a: $(Remove-Diacritics $target)" -ForegroundColor Cyan
                    } catch {
                        Write-Host "     -> No se pudo corregir automaticamente: $_" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "     -> No se encontro un valor valido que coincida, cambialo a mano" -ForegroundColor Yellow
                }
            }
        }
    }
}

function Test-SpeedDuplex {
    param([string]$NamePattern, [string]$Label)
    $p = $props | Where-Object { $_.DisplayName -match $NamePattern } | Select-Object -First 1
    if (-not $p) {
        Write-Host "[--] $Label : propiedad no existe en este driver" -ForegroundColor DarkGray
        return
    }
    $cleanName = Remove-Diacritics $p.DisplayName
    $cleanValue = Remove-Diacritics $p.DisplayValue

    # Candidatas validas: Full Duplex explicito, nunca Half Duplex ni Auto.
    # Antes se aceptaba cualquier valor que solo contuviera "Gbps"/"Mbps",
    # lo que podia coger "10 Mbps Half Duplex" por ser el primero de la
    # lista. Ahora se filtra Half Duplex fuera y se ordena por velocidad
    # real para quedarnos siempre con la mejor opcion Full Duplex.
    $fullDuplexOptions = $p.ValidDisplayValues | Where-Object {
        $_ -notmatch "Auto" -and $_ -match "Full D.plex|D.plex completo" -and $_ -notmatch "Half"
    }
    $best = $fullDuplexOptions | Sort-Object {
        $num = [regex]::Match($_, '[\d.,]+').Value -replace ',', '.'
        $mult = if ($_ -match "Gbps") { 1000 } else { 1 }
        if ($num) { [double]$num * $mult } else { 0 }
    } -Descending | Select-Object -First 1

    $isGood = ($p.DisplayValue -notmatch "Auto") -and ($p.DisplayValue -notmatch "Half") -and ($best -and $p.DisplayValue -eq $best)

    if ($isGood) {
        Write-Host "[OK] $cleanName : $cleanValue" -ForegroundColor Green
    } else {
        Write-Host "[MAL] $cleanName : $cleanValue" -ForegroundColor Red
        if ($Fix) {
            if ($best) {
                try {
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $p.DisplayName -DisplayValue $best -ErrorAction Stop
                    Write-Host "     -> Corregido a: $(Remove-Diacritics $best)" -ForegroundColor Cyan
                } catch {
                    Write-Host "     -> No se pudo corregir automaticamente: $_" -ForegroundColor Yellow
                }
            } else {
                Write-Host "     -> No se encontro una opcion Full Duplex valida, cambialo a mano" -ForegroundColor Yellow
            }
        }
    }
}

function Test-Buffer {
    param([string]$NamePattern, [string]$Label)
    $p = $props | Where-Object { $_.DisplayName -match $NamePattern } | Select-Object -First 1
    if (-not $p) {
        Write-Host "[--] $Label : propiedad no existe en este driver" -ForegroundColor DarkGray
        return
    }
    $cleanName = Remove-Diacritics $p.DisplayName
    $val = [int]$p.DisplayValue
    # El maximo soportado varia segun la tarjeta y fabricante, asi que en vez
    # de exigir un numero fijo, comparamos contra el tope real de ESTE driver.
    $maxVal = ($p.ValidDisplayValues | ForEach-Object { [int]$_ } | Measure-Object -Maximum).Maximum
    if (-not $maxVal) { $maxVal = $val }

    if ($val -ge $maxVal) {
        Write-Host "[OK] $cleanName : $val (maximo de esta tarjeta)" -ForegroundColor Green
    } else {
        Write-Host "[MAL] $cleanName : $val (maximo soportado: $maxVal)" -ForegroundColor Red
        if ($Fix) {
            try {
                Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $p.DisplayName -DisplayValue "$maxVal" -ErrorAction Stop
                Write-Host "     -> Corregido a: $maxVal" -ForegroundColor Cyan
            } catch {
                Write-Host "     -> No se pudo corregir automaticamente: $_" -ForegroundColor Yellow
            }
        }
    }
}

$esWifi = $adapter.PhysicalMediaType -match "802.11"

if ($esWifi) {
    Write-Host "Tipo de adaptador: WiFi`n" -ForegroundColor Cyan

    # Nombres cubiertos: Intel, Realtek, Broadcom, Killer/Rivet, Atheros
    Test-Setting -NamePattern "Power Saving Mode|Modo de ahorro de energ.a|802\.11.*Power Save" `
                 -GoodPattern "M.ximo rendimiento|Maximum Performance|Desactivad|Disabled|Off" `
                 -Label "Ahorro de energia WiFi"

    Test-Setting -NamePattern "Preferred Band|Banda preferida" `
                 -GoodPattern "5" `
                 -Label "Banda preferida (5GHz)"

    Test-Setting -NamePattern "Transmit Power|Potencia de transmisi.n" `
                 -GoodPattern "Highest|M.s alta|M.ximo|100" `
                 -Label "Potencia de transmision"

    Write-Host "`n[Nota] Aunque la banda preferida este en 5GHz, la conexion real puede seguir" -ForegroundColor DarkGray
    Write-Host "en 2.4GHz si hay poca senal (el 5GHz tiene mucho menos alcance que el 2.4GHz)." -ForegroundColor DarkGray
    Write-Host "Ademas, el cambio de banda preferida solo se aplica la proxima vez que el" -ForegroundColor DarkGray
    Write-Host "adaptador negocia desde cero, no en caliente sobre una conexion ya activa." -ForegroundColor DarkGray
    Write-Host "Para comprobar la banda real: Configuracion > Red e Internet > Wi-Fi >" -ForegroundColor DarkGray
    Write-Host "click en el nombre de la red conectada > mira el campo 'Banda de red" -ForegroundColor DarkGray
    Write-Host "(canal)'. Si sigue en 2.4GHz, desconecta y reconecta a la red para forzar" -ForegroundColor DarkGray
    Write-Host "la renegociacion; si aun asi no salta a 5GHz, es tema de distancia/senal," -ForegroundColor DarkGray
    Write-Host "acercate mas al router y repite la comprobacion." -ForegroundColor DarkGray

    Write-Host "`n[Nota] En WiFi los nombres de propiedades varian mas entre fabricantes que en" -ForegroundColor DarkGray
    Write-Host "Ethernet. Cualquier [--] no es fallo del script, solo que esa opcion no existe" -ForegroundColor DarkGray
    Write-Host "(o se llama distinto) en este driver concreto." -ForegroundColor DarkGray

} else {
    Write-Host "Tipo de adaptador: Ethernet (cable)`n" -ForegroundColor Cyan

    # Nombres cubiertos: Intel, Realtek, Broadcom, Marvell/Aquantia, Killer
    Test-Setting -NamePattern "Energ.a ultrabaja|Ultra Low Power" `
                 -GoodPattern "Deshabilitad|Disabled" `
                 -Label "Modo de Energia ultrabaja"

    Test-Setting -NamePattern "uso eficiente de energ.a|Energy.?Efficient Ethernet|Green Ethernet|^EEE$|EEE \(802" `
                 -GoodPattern "Desactivad|Disabled|Off" `
                 -Label "EEE / Green Ethernet"

    Test-Setting -NamePattern "Reducci.n de velocidad del enlace para el ahorro|Reduce Link Speed" `
                 -GoodPattern "Deshabilitad|Disabled" `
                 -Label "Reduccion de velocidad para ahorro de energia"

    Test-Setting -NamePattern "Reducir velocidad al apagar|Reduce Speed On Power Down" `
                 -GoodPattern "Deshabilitad|Disabled" `
                 -Label "Reducir velocidad al apagar"

    Test-SpeedDuplex -NamePattern "Velocidad y d.plex|Speed.*Duplex|Link Speed" -Label "Velocidad y duplex"

    Test-Buffer -NamePattern "B.fer.*transmisi.n|Transmit Buffer" -Label "Buferes de transmision"
    Test-Buffer -NamePattern "B.fer.*recepci.n|Receive Buffer"    -Label "Buferes de recepcion"
}

Write-Host "`n----------------------------------------------"
if (-not $Fix) {
    Write-Host "Ejecuta con -Fix para corregir automaticamente lo marcado en rojo." -ForegroundColor Yellow
} else {
    Write-Host "Correccion completada. Repite el speedtest para confirmar." -ForegroundColor Cyan
}