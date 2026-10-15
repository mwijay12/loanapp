# Supabase Keep-Alive Heartbeat Script
# Pings & records heartbeat in Supabase to permanently prevent the 7-day free-tier pause

$SUPABASE_URL = "https://fzlykkwgkydswvnlryhk.supabase.co"
$ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ6bHlra3dna3lkc3d2bmxyeWhrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIwNTA1NTAsImV4cCI6MjEwNzYyNjU1MH0.5WsVDMjEPBRDIlYcUge9anedGq59p3_6Ewxfso6LWGk"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " [LIMS] Pinging Supabase Heartbeat Keep-Alive" -ForegroundColor Cyan
Write-Host " Owner: David Erick Mwijage (mwijay12)" -ForegroundColor White
Write-Host " Project: fzlykkwgkydswvnlryhk" -ForegroundColor DarkGray
Write-Host " URL: $SUPABASE_URL" -ForegroundColor DarkGray
Write-Host "=============================================" -ForegroundColor Cyan

$headers = @{
    "apikey"        = $ANON_KEY
    "Authorization" = "Bearer $ANON_KEY"
    "Content-Type"  = "application/json"
    "Prefer"        = "return=representation"
}

try {
    # 1. Read query to refresh cache
    $readEndpoint = "$SUPABASE_URL/rest/v1/products?select=id&limit=1"
    $readResponse = Invoke-RestMethod -Uri $readEndpoint -Headers $headers -Method Get

    # 2. Touch database write via heartbeat_pings table
    $pingEndpoint = "$SUPABASE_URL/rest/v1/heartbeat_pings"
    $payload = @{
        source   = "powershell-local-keepalive"
        metadata = @{
            system    = $env:COMPUTERNAME
            user      = $env:USERNAME
            timestamp = (Get-Date).ToString("o")
        }
    } | ConvertTo-Json

    $pingResponse = Invoke-RestMethod -Uri $pingEndpoint -Headers $headers -Method Post -Body $payload

    Write-Host "[SUCCESS] Supabase Database is LIVE & ACTIVE!" -ForegroundColor Green
    Write-Host "Activity timestamp : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
    Write-Host "Heartbeat Log ID   : $($pingResponse.id)" -ForegroundColor Cyan
    Write-Host "Keep-Alive Status  : Supabase 7-day inactivity pause counter has been reset." -ForegroundColor Yellow
} catch {
    Write-Host "[ERROR] Failed to ping Supabase: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "=============================================" -ForegroundColor Cyan
