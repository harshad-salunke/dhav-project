# Run from inside the backend/ folder after: railway login && railway init
# Usage: cd backend; .\railway_env_setup.ps1

Write-Host "Setting Railway environment variables..." -ForegroundColor Cyan

# Firebase service account (piped via stdin to avoid shell-escaping the private key)
$fbJson = python -c "import json; print(json.dumps(json.load(open('../backend/firebase-service-account.json'))))"
$fbJson | railway variable set FIREBASE_SERVICE_ACCOUNT_JSON --stdin --skip-deploys
Write-Host "  [OK] FIREBASE_SERVICE_ACCOUNT_JSON" -ForegroundColor Green

$vars = @{
    FIREBASE_PROJECT_ID              = "dhav-quick-commerce"
    FIREBASE_DATABASE_URL            = "https://dhav-quick-commerce-default-rtdb.firebaseio.com"
    FIREBASE_STORAGE_BUCKET          = "dhav-quick-commerce.appspot.com"
    BROADCAST_WAVE1_RADIUS_KM        = "1.0"
    BROADCAST_WAVE1_TIMEOUT_SECONDS  = "45"
    BROADCAST_WAVE2_RADIUS_KM        = "2.0"
    BROADCAST_WAVE2_TIMEOUT_SECONDS  = "45"
    BROADCAST_WAVE3_RADIUS_KM        = "3.0"
    BROADCAST_WAVE3_TIMEOUT_SECONDS  = "60"
    GEOHASH_PRECISION                = "6"
    DEFAULT_CITY_LAT                 = "18.5204"
    DEFAULT_CITY_LNG                 = "73.8567"
    PLATFORM_FEE_PERCENTAGE          = "5.0"
    BASE_DELIVERY_FEE                = "10.0"
    DELIVERY_FEE_PER_KM              = "5.0"
    ONBOARDING_GRACE_DAYS            = "30"
    MAX_STRIKES_BEFORE_SUSPEND       = "3"
    MAX_TOTAL_STRIKES_BEFORE_BAN     = "5"
    SUSPENSION_DAYS                  = "7"
    AUTO_FAIL_HOURS                  = "3"
    SETTLEMENT_DAY                   = "MONDAY"
}

foreach ($key in $vars.Keys) {
    railway variable set "$key=$($vars[$key])" --skip-deploys
    Write-Host "  [OK] $key" -ForegroundColor Green
}

Write-Host ""
Write-Host "All variables set. Now run: railway up" -ForegroundColor Yellow
