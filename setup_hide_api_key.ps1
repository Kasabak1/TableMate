# Cài bộ lọc Git tự xóa API Key khi commit/push
git config filter.hide-api-key.clean "powershell -NoProfile -ExecutionPolicy Bypass -File tools/hide_api_key.ps1"
git config --unset filter.hide-api-key.smudge
git config filter.hide-api-key.required true
Write-Host "Da cai bo loc hide-api-key cho repo nay."
