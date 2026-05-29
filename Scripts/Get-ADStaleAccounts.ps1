# ============================================================
# Get-ADStaleAccounts.ps1
# HersheyLab IT Ops Platform
# ============================================================

$ReportFolder = "C:\Reports"
$Date         = Get-Date -Format "yyyy-MM-dd"
$HTMLReport   = "$ReportFolder\StaleAccounts_$Date.html"
$CSVReport    = "$ReportFolder\StaleAccounts_$Date.csv"

if (-not (Test-Path $ReportFolder)) {
    New-Item -ItemType Directory -Path $ReportFolder | Out-Null
    Write-Host "Created folder: $ReportFolder" -ForegroundColor Cyan
}

Write-Host "Pulling AD users..." -ForegroundColor Cyan

$Users = Get-ADUser -Filter * -Properties GivenName, Surname, SamAccountName, Department,
    Enabled, LastLogonTimestamp, PasswordLastSet, WhenCreated |
    Select-Object @{N="DisplayName"; E={"$($_.GivenName) $($_.Surname)"}},
        SamAccountName, Department, Enabled, WhenCreated, PasswordLastSet,
        @{N="LastLogon"; E={
            if ($_.LastLogonTimestamp) {
                [datetime]::FromFileTime($_.LastLogonTimestamp)
            } else { $null }
        }},
        @{N="DaysSinceLogin"; E={
            if ($_.LastLogonTimestamp) {
                (New-TimeSpan -Start ([datetime]::FromFileTime($_.LastLogonTimestamp)) -End (Get-Date)).Days
            } else { 999 }
        }},
        @{N="Status"; E={
            $days = if ($_.LastLogonTimestamp) {
                (New-TimeSpan -Start ([datetime]::FromFileTime($_.LastLogonTimestamp)) -End (Get-Date)).Days
            } else { 999 }
            if (-not $_.Enabled)        { "Disabled" }
            elseif ($days -ge 90)       { "Stale 90+" }
            elseif ($days -ge 60)       { "Stale 60+" }
            elseif ($days -ge 30)       { "Stale 30+" }
            else                        { "Active" }
        }}

$Users | Export-Csv -Path $CSVReport -NoTypeInformation
Write-Host "CSV exported: $CSVReport" -ForegroundColor Green

$TotalUsers    = $Users.Count
$ActiveUsers   = ($Users | Where-Object Status -eq "Active").Count
$Stale30       = ($Users | Where-Object Status -eq "Stale 30+").Count
$Stale60       = ($Users | Where-Object Status -eq "Stale 60+").Count
$Stale90       = ($Users | Where-Object Status -eq "Stale 90+").Count
$DisabledUsers = ($Users | Where-Object Status -eq "Disabled").Count

$Rows = foreach ($User in $Users | Sort-Object DaysSinceLogin -Descending) {
    $Color = switch ($User.Status) {
        "Active"     { "#1a1a2e" }
        "Stale 30+"  { "#2d2a00" }
        "Stale 60+"  { "#2d1500" }
        "Stale 90+"  { "#2d0000" }
        "Disabled"   { "#1a1a1a" }
        default      { "#1a1a2e" }
    }
    $Badge = switch ($User.Status) {
        "Active"    { '<span style="background:#00b894;color:#fff;padding:3px 10px;border-radius:12px;font-size:12px">Active</span>' }
        "Stale 30+" { '<span style="background:#fdcb6e;color:#000;padding:3px 10px;border-radius:12px;font-size:12px">Stale 30+</span>' }
        "Stale 60+" { '<span style="background:#e17055;color:#fff;padding:3px 10px;border-radius:12px;font-size:12px">Stale 60+</span>' }
        "Stale 90+" { '<span style="background:#d63031;color:#fff;padding:3px 10px;border-radius:12px;font-size:12px">Stale 90+</span>' }
        "Disabled"  { '<span style="background:#636e72;color:#fff;padding:3px 10px;border-radius:12px;font-size:12px">Disabled</span>' }
        default     { $User.Status }
    }
    $LastLogonDisplay = if ($User.LastLogon) { $User.LastLogon.ToString("yyyy-MM-dd") } else { "Never" }
    $EnabledDisplay   = if ($User.Enabled) { "Yes" } else { "No" }

    "<tr style='background:$Color'>
        <td>$($User.DisplayName)</td>
        <td>$($User.SamAccountName)</td>
        <td>$($User.Department)</td>
        <td>$LastLogonDisplay</td>
        <td>$($User.DaysSinceLogin)</td>
        <td>$Badge</td>
        <td>$EnabledDisplay</td>
    </tr>"
}

$HTML = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset='UTF-8'>
    <title>AD Stale Account Report - $Date</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Segoe UI', sans-serif; background: #0f0f1a; color: #e0e0e0; padding: 30px; }
        h1 { color: #00cec9; font-size: 28px; margin-bottom: 5px; }
        .subtitle { color: #888; font-size: 14px; margin-bottom: 30px; }
        .cards { display: flex; gap: 15px; margin-bottom: 30px; flex-wrap: wrap; }
        .card { background: #1a1a2e; border-radius: 12px; padding: 20px 25px; min-width: 140px; text-align: center; border: 1px solid #2a2a4a; }
        .card .num { font-size: 36px; font-weight: bold; }
        .card .label { font-size: 12px; color: #888; margin-top: 5px; }
        .active .num  { color: #00b894; }
        .stale30 .num { color: #fdcb6e; }
        .stale60 .num { color: #e17055; }
        .stale90 .num { color: #d63031; }
        .disabled .num{ color: #636e72; }
        .total .num   { color: #74b9ff; }
        table { width: 100%; border-collapse: collapse; background: #1a1a2e; border-radius: 12px; overflow: hidden; }
        th { background: #12122a; color: #00cec9; padding: 14px 16px; text-align: left; font-size: 13px; text-transform: uppercase; letter-spacing: 1px; }
        td { padding: 12px 16px; font-size: 14px; border-bottom: 1px solid #2a2a4a; }
        tr:last-child td { border-bottom: none; }
        tr:hover td { background: rgba(255,255,255,0.03); }
        .footer { margin-top: 20px; color: #555; font-size: 12px; text-align: center; }
    </style>
</head>
<body>
    <h1>AD Stale Account Report</h1>
    <div class='subtitle'>Generated: $Date &nbsp;|&nbsp; Domain: corp.itops.local &nbsp;|&nbsp; HersheyLab IT Ops</div>
    <div class='cards'>
        <div class='card total'><div class='num'>$TotalUsers</div><div class='label'>Total Users</div></div>
        <div class='card active'><div class='num'>$ActiveUsers</div><div class='label'>Active</div></div>
        <div class='card stale30'><div class='num'>$Stale30</div><div class='label'>Stale 30+</div></div>
        <div class='card stale60'><div class='num'>$Stale60</div><div class='label'>Stale 60+</div></div>
        <div class='card stale90'><div class='num'>$Stale90</div><div class='label'>Stale 90+</div></div>
        <div class='card disabled'><div class='num'>$DisabledUsers</div><div class='label'>Disabled</div></div>
    </div>
    <table>
        <thead>
            <tr>
                <th>Display Name</th>
                <th>Username</th>
                <th>Department</th>
                <th>Last Logon</th>
                <th>Days Inactive</th>
                <th>Status</th>
                <th>Enabled</th>
            </tr>
        </thead>
        <tbody>
            $($Rows -join "`n")
        </tbody>
    </table>
    <div class='footer'>HersheyLab IT Ops Platform | $Date</div>
</body>
</html>
"@

$HTML | Out-File -FilePath $HTMLReport -Encoding UTF8
Write-Host "HTML report exported: $HTMLReport" -ForegroundColor Green

Write-Host ""
Write-Host "====== REPORT SUMMARY ======" -ForegroundColor Cyan
Write-Host "Total Users:    $TotalUsers"
Write-Host "Active:         $ActiveUsers" -ForegroundColor Green
Write-Host "Stale 30+:      $Stale30"     -ForegroundColor Yellow
Write-Host "Stale 60+:      $Stale60"     -ForegroundColor DarkYellow
Write-Host "Stale 90+:      $Stale90"     -ForegroundColor Red
Write-Host "Disabled:       $DisabledUsers" -ForegroundColor Gray
Write-Host "============================"
Write-Host "Reports saved to $ReportFolder" -ForegroundColor Cyan
