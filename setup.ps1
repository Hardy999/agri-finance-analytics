<#
=============================================================================
 setup.ps1 - Agri-Finance Analytics

 Takes a fresh clone to a working environment with a proven database
 connection, in one command.

 WHY THIS EXISTS
 ---------------
 A repository that requires six correctly-ordered manual commands to run is a
 repository most people will not run. Every step here is one that was done by
 hand during Phase 0, and every check here is one that caught a real problem
 that day.

 USAGE
 -----
     .\setup.ps1              normal run - safe to repeat
     .\setup.ps1 -Force       delete and rebuild .venv from scratch
     .\setup.ps1 -Latest      install from requirements.txt instead of the
                              lock file (newer patches, less tested)

 IF POWERSHELL REFUSES TO RUN THIS FILE
 --------------------------------------
 Windows blocks .ps1 scripts by default. This script cannot exempt itself -
 it is the thing being blocked. Run it this way instead:

     powershell -ExecutionPolicy Bypass -File setup.ps1

 Or allow local scripts for your user account, once:

     Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
=============================================================================
#>

[CmdletBinding()]
param(
    [switch]$Force,    # delete .venv and rebuild
    [switch]$Latest    # install from requirements.txt, not the lock file
)

# Stop on the first error rather than continuing and reporting success at the
# end having done half the job. Without this, PowerShell carries on past most
# failures - which is how a script "succeeds" and leaves you with nothing.
$ErrorActionPreference = "Stop"

# Anchor every path to the script's own location, not to whatever folder the
# user happens to be standing in. Same reasoning as Path(__file__) in db.py.
$Root = $PSScriptRoot
Set-Location $Root

$VenvDir    = Join-Path $Root ".venv"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
$Config     = Join-Path $Root "config.ini"
$Template   = Join-Path $Root "config.example.ini"

# --- small output helpers, so the run reads as a sequence of steps ----------
function Step   ($n, $m) { Write-Host ""; Write-Host "[$n/6] $m" -ForegroundColor Cyan }
function Ok     ($m)     { Write-Host "      $m" -ForegroundColor Green }
function Note   ($m)     { Write-Host "      $m" -ForegroundColor DarkGray }
function Warn   ($m)     { Write-Host "      $m" -ForegroundColor Yellow }
function Fail   ($m)     { Write-Host ""; Write-Host "FAILED: $m" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "Agri-Finance Analytics - environment setup" -ForegroundColor White
Write-Host "github.com/Hardy999/agri-finance-analytics" -ForegroundColor DarkGray


# =============================================================================
# 1. Python
# =============================================================================
# Checked first because everything below depends on it, and a clear failure
# here is worth more than an obscure one three steps later.
Step 1 "Checking Python"

$pythonCmd = $null
foreach ($candidate in @("python", "py")) {
    $found = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($found) { $pythonCmd = $candidate; break }
}
if (-not $pythonCmd) {
    # Built from an array rather than a here-string. Here-strings are fragile
    # when a .ps1 has Unix line endings, and this file may be cloned from a
    # repository that normalised them. An array of lines cannot break that way.
    Fail (@(
        "Python was not found on PATH.",
        "",
        "Install it from python.org (3.10 or later), ticking",
        "'Add python.exe to PATH' in the installer.",
        "",
        "If Python IS installed but Windows opens the Microsoft Store when",
        "you type 'python', turn off the Store alias:",
        "  Settings > Apps > Advanced app settings > App execution aliases"
    ) -join [Environment]::NewLine)
}

# Ask Python for its own version rather than parsing the banner text, which
# differs between distributions.
$verString = & $pythonCmd -c "import sys; print('%d.%d.%d' % sys.version_info[:3])"
$verParts  = $verString.Split('.')
$major = [int]$verParts[0]; $minor = [int]$verParts[1]

if ($major -lt 3 -or ($major -eq 3 -and $minor -lt 10)) {
    Fail "Python $verString found, but this project needs 3.10 or later."
}
Ok "Python $verString  (via '$pythonCmd')"

if ($major -eq 3 -and $minor -ge 14) {
    Note "Python $verString is very new. If a package below fails to install with a"
    Note "compiler error about Microsoft Visual C++, no pre-built wheel exists for"
    Note "this version yet. Rebuilding on Python 3.12 is the fix."
}


# =============================================================================
# 2. Virtual environment
# =============================================================================
# Isolation: this project's packages go here, not into your system Python.
# Two projects wanting different versions of the same package is the normal
# case, and without separate environments one of them breaks.
Step 2 "Virtual environment"

if ($Force -and (Test-Path $VenvDir)) {
    Note "-Force given, removing the existing .venv"
    Remove-Item -Recurse -Force $VenvDir
}

if (Test-Path $VenvPython) {
    Ok "Reusing the existing .venv"
    Note "(run with -Force to rebuild it from scratch)"
} else {
    Note "Creating .venv - this takes a few seconds"
    & $pythonCmd -m venv $VenvDir
    if (-not (Test-Path $VenvPython)) { Fail "venv creation did not produce $VenvPython" }
    Ok "Created .venv"
}

# Every command below calls $VenvPython by its full path rather than relying
# on activation. Activation only edits PATH for an interactive session; calling
# the interpreter directly is unambiguous and works the same in a script, in
# CI, or from any folder.
Note "Using $VenvPython"


# =============================================================================
# 3. Dependencies
# =============================================================================
# The lock file records the exact versions that were tested. That is the point
# of having one: you get the environment that is known to work, not a fresh
# resolution that has never been run anywhere.
Step 3 "Installing dependencies"

$reqFile = if ($Latest) { "requirements.txt" } else { "requirements.lock.txt" }
$reqPath = Join-Path $Root $reqFile

if (-not (Test-Path $reqPath)) {
    if (-not $Latest) {
        Warn "$reqFile not found, falling back to requirements.txt"
        $reqPath = Join-Path $Root "requirements.txt"
    }
    if (-not (Test-Path $reqPath)) { Fail "No requirements file found in $Root" }
}

Note "Source: $(Split-Path $reqPath -Leaf)"
if ($Latest) { Note "(-Latest: range pins, so newer patch releases than were tested)" }

& $VenvPython -m pip install --upgrade pip --quiet
& $VenvPython -m pip install -r $reqPath --quiet
if ($LASTEXITCODE -ne 0) { Fail "pip install failed - scroll up for the package that broke" }

# Verify by importing, not by trusting pip's exit code. On 19 September 2026 a
# command reported success and produced the wrong result five separate times;
# checking the result rather than the return value is the habit that caught it.
# One line, no here-string, for the same line-ending reason as above.
# distributions() lists what is installed, so a set difference replaces a
# try/except per package and fits on one line without losing clarity.
$pyCheck = "import importlib.metadata as md; " +
           "have = set((d.metadata['Name'] or '').lower() for d in md.distributions()); " +
           "need = ['pandas','numpy','requests','openpyxl','sqlalchemy','pyodbc','jupyterlab','matplotlib','python-dotenv']; " +
           "missing = [p for p in need if p not in have]; " +
           "print('MISSING:' + ','.join(missing) if missing else 'OK:' + md.version('pandas'))"
$check = & $VenvPython -c $pyCheck
if ($check -like "MISSING:*") { Fail "Installed, but these are not importable: $($check -replace 'MISSING:','')" }
Ok "All nine dependencies present  (pandas $($check -replace 'OK:',''))"


# =============================================================================
# 4. Database configuration
# =============================================================================
# config.ini is machine-specific and gitignored, so a fresh clone never has one.
# The two values that differ per machine are detected rather than guessed, and
# printed with their source so you can see where each came from.
Step 4 "Database configuration"

if (Test-Path $Config) {
    Ok "config.ini already exists - leaving it alone"
    Note "(delete it and re-run if you want it regenerated)"
} else {
    if (-not (Test-Path $Template)) { Fail "config.example.ini not found - cannot generate config.ini" }

    # --- ODBC driver: ask the machine which ones are actually installed -----
    $drivers = & $VenvPython -c "import pyodbc; print('|'.join(pyodbc.drivers()))"
    $sqlDrivers = $drivers.Split('|') | Where-Object { $_ -match 'ODBC Driver \d+ for SQL Server' }

    if ($sqlDrivers) {
        # Highest version number wins - 18 over 17 over anything older.
        $driver = $sqlDrivers | Sort-Object { [int]($_ -replace '\D','') } -Descending | Select-Object -First 1
        Note "ODBC driver : $driver"
        Note "              (from pyodbc.drivers(), $($sqlDrivers.Count) SQL Server driver(s) found)"
    } else {
        $driver = "ODBC Driver 17 for SQL Server"
        Warn "No SQL Server ODBC driver found on this machine."
        Warn "Defaulting to '$driver' - install it from Microsoft, or edit config.ini."
    }

    # --- Instance: read the Windows service list ---------------------------
    # MSSQLSERVER      -> default instance   -> localhost
    # MSSQL`$SQLEXPRESS -> named instance     -> localhost\SQLEXPRESS
    $svc = Get-Service -Name "MSSQL*" -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -eq "MSSQLSERVER" -or $_.Name -like "MSSQL`$*" }

    if ($svc) {
        $svc = @($svc)[0]
        if ($svc.Name -eq "MSSQLSERVER") {
            $server = "localhost"
            Note "Instance    : $($svc.Name) (default) -> server = localhost"
        } else {
            $instance = $svc.Name -replace '^MSSQL\$',''
            $server   = "localhost\$instance"
            Note "Instance    : $($svc.Name) (named) -> server = $server"
        }
        if ($svc.Status -ne "Running") {
            Warn "That service is $($svc.Status), not Running. Start it with:"
            Warn "  Start-Service $($svc.Name)"
        }
    } else {
        $server = "localhost"
        Warn "No SQL Server service found. Defaulting server to 'localhost'."
        Warn "If your instance is remote or named, edit config.ini."
    }

    # Write the template through with the detected values substituted, keeping
    # every comment. The comments are why the template is committed at all.
    $content = Get-Content $Template -Raw
    $content = $content -replace '(?m)^\s*server\s*=.*$',   "server = $server"
    $content = $content -replace '(?m)^\s*driver\s*=.*$',   "driver = $driver"
    # master, not AgriFinance: the project database is created in Phase 4 and
    # does not exist on a fresh clone. master is on every instance.
    $content = $content -replace '(?m)^\s*database\s*=.*$', "database = master"
    Set-Content -Path $Config -Value $content -Encoding ASCII

    Ok "Wrote config.ini"
    Note "database = master for now; change it once the project database exists."
}


# =============================================================================
# 5. Connection test
# =============================================================================
# A warning, not a failure. Someone without SQL Server still has a working
# Python environment, and throwing that away over the last of six steps would
# be the wrong trade.
Step 5 "Testing the database connection"

$dbScript = Join-Path $Root "src\db.py"
$connOk = $false

if (-not (Test-Path $dbScript)) {
    Warn "src\db.py not found - skipping the connection test"
} else {
    $output = & $VenvPython $dbScript 2>&1
    if ($LASTEXITCODE -eq 0) {
        $connOk = $true
        Ok "Connected"
        $output | Select-Object -First 4 | ForEach-Object { Note $_ }
    } else {
        Warn "Could not connect. The Python environment is fine; this is SQL Server."
        Warn ""
        $output | Select-Object -First 6 | ForEach-Object { Warn "  $_" }
        Warn ""
        Warn "Common causes:"
        Warn "  - SQL Server is not installed, or its service is stopped"
        Warn "  - the ODBC driver named in config.ini is not the one installed"
        Warn "  - your Windows account has no login on this SQL Server instance"
    }
}


# =============================================================================
# 6. Summary
# =============================================================================
Step 6 "Done"

Write-Host ""
if ($connOk) {
    Write-Host "  Environment ready and the database responded." -ForegroundColor Green
} else {
    Write-Host "  Python environment ready. Database connection not confirmed." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  To work in this environment, activate it:" -ForegroundColor White
Write-Host "      .venv\Scripts\activate" -ForegroundColor Gray
Write-Host ""
Write-Host "  Note: the raw data is deliberately NOT in this repository." -ForegroundColor White
Write-Host "  It is excluded for size, for source licences, and so that the" -ForegroundColor Gray
Write-Host "  ingestion scripts stay continuously proven. See docs/SOURCES.md" -ForegroundColor Gray
Write-Host "  for where each dataset comes from." -ForegroundColor Gray
Write-Host ""
