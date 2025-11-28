Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ===============================
# Versions- & Update-Konfiguration
# ===============================
$appVersion = [version]"1.0.0"     # hier später hochzählen: 1.0.1, 1.1.0, ...

$repoOwner   = "Tripl389"
$repoName    = "IPScannerGUI"
$versionFile = "version.txt"

$versionUrl  = "https://raw.githubusercontent.com/$repoOwner/$repoName/main/$versionFile"
$releaseUrl  = "https://github.com/$repoOwner/$repoName/releases/latest"

function Increment-IP {
    param ([string]$ip)
    $bytes = $ip -split '\.' | ForEach-Object {[int]$_}
    for ($i = 3; $i -ge 0; $i--) {
        if ($bytes[$i] -lt 255) {
            $bytes[$i]++
            break
        } else {
            $bytes[$i] = 0
        }
    }
    return ($bytes -join '.')
}

# Hersteller aus MAC-OUI bestimmen (vereinfachte Tabelle)
function Get-VendorFromMac {
    param([string]$mac)

    if ([string]::IsNullOrWhiteSpace($mac)) { return "Unbekannt" }

    # Normalisieren: XX-XX-XX-XX-XX-XX
    $norm = $mac.Trim().ToUpper()
    $norm = $norm -replace ":", "-"
    if ($norm.Length -lt 8) { return "Unbekannt" }
    $oui = $norm.Substring(0, 8) # z.B. "84-F3-EB"

    $vendors = @{
        "84-F3-EB" = "Shelly (Allterco)"
        "A4-C3-F0" = "Apple"
        "F0-18-98" = "Apple"
        "D8-F1-5B" = "Samsung"
        "40-16-3B" = "Samsung"
        "9C-5C-8E" = "AVM (FRITZ!Box)"
        "3C-37-86" = "AVM (FRITZ!Box)"
        "F4-EC-38" = "TP-Link"
        "50-D4-F7" = "Ubiquiti"
        "DC-A6-32" = "Ubiquiti"
        "00-1E-C9" = "Intel"
        "00-1F-3C" = "Intel"
        "00-1F-29" = "HP"
        "B4-B6-76" = "Xiaomi"
    }

    if ($vendors.ContainsKey($oui)) {
        return $vendors[$oui]
    } else {
        return "Unbekannt"
    }
}

function Check-ForUpdate {
    param(
        [version]$localVersion,
        [string]$remoteVersionUrl,
        [string]$releasePageUrl
    )

    try {
        $response = Invoke-WebRequest -Uri $remoteVersionUrl -UseBasicParsing -TimeoutSec 5
        $remoteString = $response.Content.Trim()
        if ([string]::IsNullOrWhiteSpace($remoteString)) { return }

        $remoteVersion = [version]$remoteString

        if ($remoteVersion -gt $localVersion) {
            $msg = "Es ist eine neue Version verfügbar." + "`r`n`r`n" +
                   "Installiert:  $localVersion`r`n" +
                   "Verfügbar:   $remoteVersion`r`n`r`n" +
                   "Möchtest du die GitHub-Seite mit der neuen Version öffnen?"

            $result = [System.Windows.Forms.MessageBox]::Show(
                $msg,
                "Update verfügbar",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )

            if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                [System.Diagnostics.Process]::Start($releasePageUrl) | Out-Null
            }
        }
    } catch {
        # Kein Internet / GitHub nicht erreichbar -> still ignorieren
        return
    }
}

# Ausgabe-Verzeichnis robust bestimmen (PS1 & EXE)
$script:OutputDir = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot
} else {
    [System.IO.Path]::GetDirectoryName(
        [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    )
}

# Globale Flags für Pause / Stop
$script:pauseScan  = $false
$script:cancelScan = $false

# --- Haupt-Form erstellen ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "IP Scanner"
$form.Size = New-Object System.Drawing.Size(600, 500)
$form.StartPosition = "CenterScreen"

# Icon aus EXE übernehmen (falls vorhanden)
try {
    $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon(
        [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    )
} catch { }

# Label Preset
$labelPreset = New-Object System.Windows.Forms.Label
$labelPreset.Text = "Vordefinierte Bereiche:"
$labelPreset.Location = New-Object System.Drawing.Point(20, 20)
$labelPreset.AutoSize = $true
$form.Controls.Add($labelPreset)

# ComboBox Presets
$comboRanges = New-Object System.Windows.Forms.ComboBox
$comboRanges.Location = New-Object System.Drawing.Point(170, 18)
$comboRanges.Size = New-Object System.Drawing.Size(380, 20)
$comboRanges.DropDownStyle = "DropDownList"
[void]$comboRanges.Items.Add("Benutzerdefiniert")
[void]$comboRanges.Items.Add("192.168.0.1 - 192.168.0.254")
[void]$comboRanges.Items.Add("192.168.1.1 - 192.168.1.254")
[void]$comboRanges.Items.Add("192.168.178.1 - 192.168.178.254")
$comboRanges.SelectedIndex = 2   # Standard: 192.168.1.x
$form.Controls.Add($comboRanges)

# Label & TextBox Start-IP
$labelStart = New-Object System.Windows.Forms.Label
$labelStart.Text = "Start-IP:"
$labelStart.Location = New-Object System.Drawing.Point(20, 60)
$labelStart.AutoSize = $true
$form.Controls.Add($labelStart)

$textStart = New-Object System.Windows.Forms.TextBox
$textStart.Location = New-Object System.Drawing.Point(100, 58)
$textStart.Size = New-Object System.Drawing.Size(150, 20)
$textStart.Text = "192.168.1.1"
$form.Controls.Add($textStart)

# Label & TextBox End-IP
$labelEnd = New-Object System.Windows.Forms.Label
$labelEnd.Text = "End-IP:"
$labelEnd.Location = New-Object System.Drawing.Point(20, 90)
$labelEnd.AutoSize = $true
$form.Controls.Add($labelEnd)

$textEnd = New-Object System.Windows.Forms.TextBox
$textEnd.Location = New-Object System.Drawing.Point(100, 88)
$textEnd.Size = New-Object System.Drawing.Size(150, 20)
$textEnd.Text = "192.168.1.254"
$form.Controls.Add($textEnd)

# Checkbox: CSV nach Scan öffnen
$checkOpenCsv = New-Object System.Windows.Forms.CheckBox
$checkOpenCsv.Text = "CSV nach Scan automatisch öffnen"
$checkOpenCsv.Location = New-Object System.Drawing.Point(270, 60)
$checkOpenCsv.AutoSize = $true
$checkOpenCsv.Checked = $true
$form.Controls.Add($checkOpenCsv)

# Label CSV-Modus
$labelCsvMode = New-Object System.Windows.Forms.Label
$labelCsvMode.Text = "CSV enthält:"
$labelCsvMode.Location = New-Object System.Drawing.Point(270, 90)
$labelCsvMode.AutoSize = $true
$form.Controls.Add($labelCsvMode)

# ComboBox CSV-Modus
$comboCsvMode = New-Object System.Windows.Forms.ComboBox
$comboCsvMode.Location = New-Object System.Drawing.Point(340, 88)
$comboCsvMode.Size = New-Object System.Drawing.Size(210, 20)
$comboCsvMode.DropDownStyle = "DropDownList"
[void]$comboCsvMode.Items.Add("Nur online Geräte")
[void]$comboCsvMode.Items.Add("Alle IPs (online + offline)")
$comboCsvMode.SelectedIndex = 0
$form.Controls.Add($comboCsvMode)

# Start-Button
$buttonStart = New-Object System.Windows.Forms.Button
$buttonStart.Text = "Scan starten"
$buttonStart.Location = New-Object System.Drawing.Point(20, 125)
$buttonStart.Size = New-Object System.Drawing.Size(110, 30)
$form.Controls.Add($buttonStart)

# Pause-Button
$buttonPause = New-Object System.Windows.Forms.Button
$buttonPause.Text = "Pause"
$buttonPause.Location = New-Object System.Drawing.Point(140, 125)
$buttonPause.Size = New-Object System.Drawing.Size(110, 30)
$buttonPause.Enabled = $false
$form.Controls.Add($buttonPause)

# Stop-Button
$buttonStop = New-Object System.Windows.Forms.Button
$buttonStop.Text = "Stop"
$buttonStop.Location = New-Object System.Drawing.Point(260, 125)
$buttonStop.Size = New-Object System.Drawing.Size(110, 30)
$buttonStop.Enabled = $false
$form.Controls.Add($buttonStop)

# Info-Button
$buttonInfo = New-Object System.Windows.Forms.Button
$buttonInfo.Text = "Info"
$buttonInfo.Location = New-Object System.Drawing.Point(380, 125)
$buttonInfo.Size = New-Object System.Drawing.Size(80, 30)
$form.Controls.Add($buttonInfo)

# Log-Textbox
$textLog = New-Object System.Windows.Forms.TextBox
$textLog.Location = New-Object System.Drawing.Point(20, 170)
$textLog.Size = New-Object System.Drawing.Size(540, 250)
$textLog.Multiline = $true
$textLog.ScrollBars = "Vertical"
$textLog.ReadOnly = $true
$form.Controls.Add($textLog)

# Status-Label
$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Text = "Bereit."
$labelStatus.Location = New-Object System.Drawing.Point(20, 430)
$labelStatus.AutoSize = $true
$form.Controls.Add($labelStatus)

# Credits-Label
$labelAuthor = New-Object System.Windows.Forms.Label
$labelAuthor.Text = "Entwickelt von Fabian Gebel"
$labelAuthor.Location = New-Object System.Drawing.Point(360, 430)
$labelAuthor.AutoSize = $true
$form.Controls.Add($labelAuthor)

# --- Info-Button: eigenes About-Fenster mit klickbaren Links ---
$buttonInfo.Add_Click({
    $aboutForm = New-Object System.Windows.Forms.Form
    $aboutForm.Text = "Über IP Scanner"
    $aboutForm.Size = New-Object System.Drawing.Size(420, 230)
    $aboutForm.StartPosition = "CenterParent"
    try {
        $aboutForm.Icon = $form.Icon
    } catch { }

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "IP Scanner"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(20, 20)
    $lblTitle.AutoSize = $true
    $aboutForm.Controls.Add($lblTitle)

    $lblDev = New-Object System.Windows.Forms.Label
    $lblDev.Text = "Entwickelt von Fabian Gebel"
    $lblDev.Location = New-Object System.Drawing.Point(20, 55)
    $lblDev.AutoSize = $true
    $aboutForm.Controls.Add($lblDev)

    $lblVer = New-Object System.Windows.Forms.Label
    $lblVer.Text = "Version $($appVersion.ToString())"
    $lblVer.Location = New-Object System.Drawing.Point(20, 75)
    $lblVer.AutoSize = $true
    $aboutForm.Controls.Add($lblVer)

    # Mail-Link
    $llMail = New-Object System.Windows.Forms.LinkLabel
    $llMail.Text = "E-Mail: Fabian1412@n1gebel.de"
    $llMail.Location = New-Object System.Drawing.Point(20, 105)
    $llMail.AutoSize = $true
    $llMail.Links[0].LinkData = "mailto:Fabian1412@n1gebel.de"
    $llMail.Add_LinkClicked({
        param($sender,$e)
        try {
            [System.Diagnostics.Process]::Start($e.Link.LinkData) | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Konnte das E-Mail-Programm nicht öffnen.",
                "Fehler","OK","Error"
            ) | Out-Null
        }
    })
    $aboutForm.Controls.Add($llMail)

    # Ko-fi-Link
    $llKofi = New-Object System.Windows.Forms.LinkLabel
    $llKofi.Text = "Unterstützen auf Ko-fi"
    $llKofi.Location = New-Object System.Drawing.Point(20, 135)
    $llKofi.AutoSize = $true
    $llKofi.Links[0].LinkData = "https://ko-fi.com/P5P5195MDT"
    $llKofi.Add_LinkClicked({
        param($sender,$e)
        try {
            [System.Diagnostics.Process]::Start($e.Link.LinkData) | Out-Null
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Konnte den Browser nicht öffnen.",
                "Fehler","OK","Error"
            ) | Out-Null
        }
    })
    $aboutForm.Controls.Add($llKofi)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Schließen"
    $btnClose.Location = New-Object System.Drawing.Point(300, 155)
    $btnClose.Size = New-Object System.Drawing.Size(80, 30)
    $btnClose.Add_Click({ $aboutForm.Close() })
    $aboutForm.Controls.Add($btnClose)

    [void]$aboutForm.ShowDialog($form)
})

# --- Preset-Auswahl ---
$comboRanges.Add_SelectedIndexChanged({
    switch -Wildcard ($comboRanges.SelectedItem) {
        "192.168.0.1 - 192.168.0.254" {
            $textStart.Text = "192.168.0.1"
            $textEnd.Text   = "192.168.0.254"
        }
        "192.168.1.1 - 192.168.1.254" {
            $textStart.Text = "192.168.1.1"
            $textEnd.Text   = "192.168.1.254"
        }
        "192.168.178.1 - 192.168.178.254" {
            $textStart.Text = "192.168.178.1"
            $textEnd.Text   = "192.168.178.254"
        }
        default {
            # Benutzerdefiniert -> nichts überschreiben
        }
    }
})

# --- Pause-Button ---
$buttonPause.Add_Click({
    if (-not $script:pauseScan) {
        $script:pauseScan = $true
        $buttonPause.Text = "Fortsetzen"
        $labelStatus.Text = "Pausiert."
    } else {
        $script:pauseScan = $false
        $buttonPause.Text = "Pause"
        $labelStatus.Text = "Scan läuft..."
    }
})

# --- Stop-Button ---
$buttonStop.Add_Click({
    $script:cancelScan = $true
    $labelStatus.Text = "Abbruch angefordert..."
})

# --- Scan-Logik ---
$buttonStart.Add_Click({
    $buttonStart.Enabled = $false
    $buttonPause.Enabled = $true
    $buttonStop.Enabled  = $true
    $buttonPause.Text    = "Pause"
    $script:pauseScan    = $false
    $script:cancelScan   = $false

    $textLog.Clear()
    $labelStatus.Text = "Scan läuft..."

    $startIP = $textStart.Text.Trim()
    $endIP   = $textEnd.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($startIP) -or [string]::IsNullOrWhiteSpace($endIP)) {
        [void][System.Windows.Forms.MessageBox]::Show(
            "Bitte Start- und End-IP eingeben.",
            "Fehler","OK","Error"
        )
        $buttonStart.Enabled = $true
        $buttonPause.Enabled = $false
        $buttonStop.Enabled  = $false
        $labelStatus.Text = "Fehler: Ungültige Eingabe."
        return
    }

    # ARP-Tabelle einmal holen (für MAC-Erkennung)
    $arpRaw = arp -a 2>$null

    $currentIP = $startIP
    $allDevices = @()   # Alle IPs, inkl. offline

    try {
        while ($true) {

            if ($script:cancelScan) {
                $textLog.AppendText("Scan abgebrochen.`r`n")
                break
            }

            while ($script:pauseScan -and -not $script:cancelScan) {
                [void][System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 100
            }

            $textLog.AppendText("Scanne: $currentIP`r`n")

            # 1) Ping (2 Pakete)
            $pingResults = Test-Connection -ComputerName $currentIP -Count 2 -ErrorAction SilentlyContinue
            $reachable = $false
            $avg = $null
            $hostName = "Unbekannt"
            $mac      = $null
            $vendor   = "Unbekannt"
            $httpInfo = $null

            if ($pingResults) {
                $reachable = $true
                $textLog.AppendText("  -> Erreichbar`r`n")

                # DNS-Hostname
                try {
                    $hostName = [System.Net.Dns]::GetHostEntry($currentIP).HostName
                } catch {
                    $hostName = "Unbekannt"
                }

                # Ping-Durchschnitt
                $avg = ($pingResults | Measure-Object -Property ResponseTime -Average).Average
                if ($avg -ne $null) {
                    $avg = [math]::Round($avg, 2)
                }

                # 2) MAC über ARP suchen
                if ($arpRaw) {
                    $line = $arpRaw | Where-Object { $_ -match "^\s*${currentIP}\s" }
                    if (-not $line) {
                        # Fallback: Contains-Suche
                        $line = $arpRaw | Where-Object { $_ -like "*$currentIP*" } | Select-Object -First 1
                    }
                    if ($line -and ($line -match "([0-9a-fA-F]{2}(-[0-9a-fA-F]{2}){5})")) {
                        $mac = $matches[1].ToUpper()
                        $mac = $mac -replace ":", "-"
                        $vendor = Get-VendorFromMac -mac $mac
                    }
                }

                # 3) HTTP-Banner / Title
                try {
                    $url = "http://$currentIP/"
                    $request = [System.Net.WebRequest]::Create($url)
                    $request.Timeout = 1500
                    $request.ReadWriteTimeout = 1500
                    $request.AllowAutoRedirect = $true
                    $response = $request.GetResponse()
                    $serverHeader = $response.Headers["Server"]

                    $title = $null
                    try {
                        $stream = $response.GetResponseStream()
                        $reader = New-Object System.IO.StreamReader($stream)
                        $html = $reader.ReadToEnd()
                        $reader.Close()
                        $stream.Close()

                        if ($html -match "<title>\s*(.*?)\s*</title>") {
                            $title = $matches[1]
                        }
                    } catch {
                        $title = $null
                    }

                    if ($serverHeader -or $title) {
                        $httpInfoParts = @()
                        if ($serverHeader) { $httpInfoParts += "Server=$serverHeader" }
                        if ($title)        { $httpInfoParts += "Title=$title" }
                        $httpInfo = ($httpInfoParts -join " | ")
                    } else {
                        $httpInfo = $null
                    }

                    $response.Close()
                } catch {
                    $httpInfo = $null
                }

            } else {
                $textLog.AppendText("  -> Nicht erreichbar`r`n")
            }

            $allDevices += [PSCustomObject]@{
                IPAddress = $currentIP
                HostName  = $hostName
                Reachable = $reachable
                PingAvgMs = $avg
                MAC       = $mac
                Vendor    = $vendor
                HttpInfo  = $httpInfo
            }

            if ($currentIP -eq $endIP) { break }
            $currentIP = Increment-IP $currentIP
            [void][System.Windows.Forms.Application]::DoEvents()
        }

        $onlineDevices = $allDevices | Where-Object { $_.Reachable }
        $onlineCount   = $onlineDevices.Count

        $csvMode = $comboCsvMode.SelectedItem
        if ($csvMode -like "Nur online*") {
            $export = $onlineDevices
        } else {
            $export = $allDevices
        }

        if ($export.Count -gt 0) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $outPath = Join-Path $script:OutputDir "ScanResult_$timestamp.csv"
            # Semikolon-Delimiter für Excel (DE)
            $export | Export-Csv -Path $outPath -NoTypeInformation -Encoding UTF8 -Delimiter ';'

            if ($script:cancelScan) {
                $labelStatus.Text = "Scan abgebrochen. Online: $onlineCount"
                $msg = "Scan abgebrochen.`r`nOnline-Geräte: $onlineCount`r`nDatei: $outPath"
            } else {
                $labelStatus.Text = "Scan fertig. Online: $onlineCount"
                $msg = "Scan fertig.`r`nOnline-Geräte: $onlineCount`r`nDatei: $outPath"
            }

            [void][System.Windows.Forms.MessageBox]::Show($msg,"Ergebnis","OK","Information")

            if ($checkOpenCsv.Checked -and (Test-Path $outPath)) {
                Start-Process $outPath | Out-Null
            }
        } else {
            if ($script:cancelScan) {
                $labelStatus.Text = "Scan abgebrochen. Keine Treffer."
                [void][System.Windows.Forms.MessageBox]::Show(
                    "Scan abgebrochen. Keine erreichbaren Hosts.",
                    "Ergebnis","OK","Information"
                )
            } else {
                $labelStatus.Text = "Scan fertig. Keine erreichbaren Hosts."
                [void][System.Windows.Forms.MessageBox]::Show(
                    "Scan fertig. Keine erreichbaren Hosts im Bereich.",
                    "Ergebnis","OK","Information"
                )
            }
        }
    } catch {
        $labelStatus.Text = "Fehler beim Scan."
        [void][System.Windows.Forms.MessageBox]::Show(
            "Fehler: $($_.Exception.Message)",
            "Fehler","OK","Error"
        )
    } finally {
        $buttonStart.Enabled = $true
        $buttonPause.Enabled = $false
        $buttonStop.Enabled  = $false
        $script:pauseScan    = $false
        $script:cancelScan   = $false
    }
})

# --- beim Start einmal nach Updates schauen ---
Check-ForUpdate -localVersion $appVersion -remoteVersionUrl $versionUrl -releasePageUrl $releaseUrl

[void][System.Windows.Forms.Application]::Run($form)
