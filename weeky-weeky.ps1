# ---------------------------------------------------------
# --- Gronjos' shell script for week number and weather ---
# ---------------------------------------------------------

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -------------------- SETTINGS --------------------
$marginX = 4
$marginY = 4

$widgetWidth  = 40
$widgetHeight = 25
$bgOpacity    = 0.40

# Veldhoven
$lat = 51.42
$lon = 5.40

# Weather refresh period
$weatherRefreshMinutes = 10

# -------------------- HELPERS --------------------
function Get-WeekNumber {
    (Get-Culture).Calendar.GetWeekOfYear(
        (Get-Date),
        (Get-Culture).DateTimeFormat.CalendarWeekRule,
        (Get-Culture).DateTimeFormat.FirstDayOfWeek
    )
}

function U([int]$codePoint) {
    # Unicode char from code point (safe even if file encoding is ANSI)
    [System.Char]::ConvertFromUtf32($codePoint)
}

function Get-WeatherIcon([int]$code) {
    # WMO weather interpretation codes as used by Open-Meteo weather_code [1](https://open-meteo.com/en/docs)[2](https://worksonmymachine.de/2023/02/its-raining-codes-and-docs-wmo-weather-interpretation-code-mapping-and-translation-for-english-and-german/)
    switch ($code) {
        0  { U 0x2600 }              # ☀ clear
        1  { U 0x1F324 }             # 🌤 mainly clear
        2  { U 0x26C5 }              # ⛅ partly cloudy
        3  { U 0x2601 }              # ☁ overcast
        45 { U 0x1F32B }             # 🌫 fog
        48 { U 0x1F32B }             # 🌫 rime fog

        51 { U 0x1F326 }             # 🌦 drizzle
        53 { U 0x1F326 }             # 🌦 drizzle
        55 { U 0x1F327 }             # 🌧 heavy drizzle
        56 { U 0x1F327 }             # 🌧 freezing drizzle
        57 { U 0x1F327 }             # 🌧 freezing drizzle

        61 { U 0x1F327 }             # 🌧 rain
        63 { U 0x1F327 }             # 🌧 rain
        65 { U 0x1F327 }             # 🌧 heavy rain
        66 { U 0x1F327 }             # 🌧 freezing rain
        67 { U 0x1F327 }             # 🌧 freezing rain

        71 { U 0x1F328 }             # 🌨 snow
        73 { U 0x1F328 }             # 🌨 snow
        75 { U 0x2744 }              # ❄ heavy snow
        77 { U 0x1F328 }             # 🌨 snow grains

        80 { U 0x1F326 }             # 🌦 rain showers
        81 { U 0x1F326 }             # 🌦 rain showers
        82 { U 0x1F327 }             # 🌧 violent showers

        85 { U 0x1F328 }             # 🌨 snow showers
        86 { U 0x2744 }              # ❄ heavy snow showers

        95 { U 0x26C8 }              # ⛈ thunderstorm
        96 { U 0x26C8 }              # ⛈ thunderstorm hail
        99 { U 0x26C8 }              # ⛈ thunderstorm heavy hail
        default { "?" }
    }
}

function Get-WeatherNow {
    try {
        # Build URL safely (no literal '&' in a pasted string)
        # Open-Meteo current: temperature_2m and weather_code [1](https://open-meteo.com/en/docs)
        $ub = [System.UriBuilder]::new("https://api.open-meteo.com/v1/forecast")
        $params = @{
            latitude          = $lat
            longitude         = $lon
            current           = "temperature_2m,weather_code"
            temperature_unit  = "celsius"
            timezone          = "auto"
        }
        $query = ($params.GetEnumerator() | ForEach-Object {
            "{0}={1}" -f $_.Key, [System.Uri]::EscapeDataString([string]$_.Value)
        }) -join "&"
        $ub.Query = $query

        $data = Invoke-RestMethod -Uri $ub.Uri.AbsoluteUri -TimeoutSec 5

        $temp = [int][math]::Round([double]$data.current.temperature_2m, 0)
        $code = [int]$data.current.weather_code

        [pscustomobject]@{ TempC = $temp; Code = $code }
    } catch {
        [pscustomobject]@{ TempC = $null; Code = $null }
    }
}

function Snap-Form([System.Windows.Forms.Form]$f) {
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $x  = $wa.Right  - $f.Width  - $marginX
    $y  = $wa.Bottom - $f.Height - $marginY
    $f.Location = New-Object System.Drawing.Point($x, $y)
}

# -------------------- UI --------------------
$form = New-Object System.Windows.Forms.Form
$form.Size            = New-Object System.Drawing.Size($widgetWidth, $widgetHeight)
$form.TopMost         = $true
$form.FormBorderStyle = "None"
$form.ShowInTaskbar   = $false
$form.BackColor       = [System.Drawing.Color]::Black
$form.Opacity         = $bgOpacity

$label = New-Object System.Windows.Forms.Label
$label.Dock      = "Fill"
$label.TextAlign = "MiddleCenter"
$label.ForeColor = [System.Drawing.Color]::White
$label.Font      = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($label)

# -------------------- DRAG + RIGHT-CLICK RESNAP --------------------
$script:dragging   = $false
$script:mouseStart = $null
$script:formStart  = $null
$script:manualPos  = $false   # when true, auto-snap won't override your position

$onMouseDown = {
    param($sender, $e)

    # Right-click: re-enable snap and snap immediately
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
        $script:dragging  = $false
        $script:manualPos = $false
        Snap-Form $form
        return
    }

    # Left-click: start dragging
    if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }

    $script:dragging   = $true
    $script:manualPos  = $true
    $script:mouseStart = [System.Drawing.Point][System.Windows.Forms.Cursor]::Position
    $script:formStart  = [System.Drawing.Point]$form.Location

    # Capture mouse so dragging keeps working even if cursor moves fast
    $form.Capture = $true
}

$onMouseMove = {
    param($sender, $e)
    if (-not $script:dragging) { return }

    $p  = [System.Windows.Forms.Cursor]::Position
    $dx = $p.X - $script:mouseStart.X
    $dy = $p.Y - $script:mouseStart.Y

    $newX = $script:formStart.X + $dx
    $newY = $script:formStart.Y + $dy

    $form.Location = New-Object System.Drawing.Point($newX, $newY)
}

$onMouseUp = {
    param($sender, $e)
    $script:dragging = $false
    $form.Capture = $false
}

# Attach to BOTH the form and the label (label covers the form)
$form.Add_MouseDown($onMouseDown)
$form.Add_MouseMove($onMouseMove)
$form.Add_MouseUp($onMouseUp)

$label.Add_MouseDown($onMouseDown)
$label.Add_MouseMove($onMouseMove)
$label.Add_MouseUp($onMouseUp)

# -------------------- UPDATE LOOP --------------------
$deg = [char]0x00B0
$nl  = [Environment]::NewLine

$script:lastWeatherUpdate = Get-Date "1900-01-01"
$script:weather = [pscustomobject]@{ TempC = $null; Code = $null }
$script:icon = "?"
$script:tempText = "?"

function Refresh-WeatherIfNeeded {
    $now = Get-Date
    if (($now - $script:lastWeatherUpdate).TotalMinutes -ge $weatherRefreshMinutes) {
        $script:weather = Get-WeatherNow
        if ($script:weather.Code -ne $null) { $script:icon = Get-WeatherIcon $script:weather.Code } else { $script:icon = "?" }
        if ($script:weather.TempC -ne $null) { $script:tempText = "{0}{1}C" -f $script:weather.TempC, $deg } else { $script:tempText = "?"+$deg+"C" }
        $script:lastWeatherUpdate = $now
    }
}

function Refresh-UI {
    $week = Get-WeekNumber
    Refresh-WeatherIfNeeded
    $label.Text = ("W{0}  {1}{2}" -f $week, $script:icon, $script:tempText)

    if (-not $script:manualPos) { Snap-Form $form }
}

# Initial paint
Refresh-WeatherIfNeeded
Refresh-UI

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 60000  # 1 minute
$timer.Add_Tick({ Refresh-UI })
$timer.Start()

[System.Windows.Forms.Application]::Run($form)
