# Bộ lọc Git xóa API Key trước khi commit
$stdin = [Console]::OpenStandardInput()
$ms = New-Object System.IO.MemoryStream
$stdin.CopyTo($ms)
$text = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
$clean = [regex]::Replace($text, "(geminiApiKey\s*=\s*')[^']*(')", '$1$2')
$bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($clean)
$stdout = [Console]::OpenStandardOutput()
$stdout.Write($bytes, 0, $bytes.Length)
$stdout.Flush()

