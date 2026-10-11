$root = "C:\Users\lovelyy\.zcode\workspace\default\velorai"
$dataFile = Join-Path $root "accounts.dat"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:8899/")
$listener.Start()
$mime = @{
  ".html" = "text/html; charset=utf-8"; ".css" = "text/css; charset=utf-8"
  ".js" = "text/javascript; charset=utf-8"; ".svg" = "image/svg+xml"
  ".png" = "image/png"; ".jpg" = "image/jpeg"; ".ico" = "image/x-icon"
  ".json" = "application/json"; ".txt" = "text/plain; charset=utf-8"
}
while ($true) {
  $ctx = $listener.GetContext()
  try {
    $path = $ctx.Request.Url.AbsolutePath
    $method = $ctx.Request.HttpMethod

    # --- API: сохранить зашифрованный аккаунт (строка base64) ---
    if ($path -eq "/api/accounts/save" -and $method -eq "POST") {
      try {
        $reader = New-Object System.IO.StreamReader($ctx.Request.InputStream, [System.Text.Encoding]::UTF8)
        $body = $reader.ReadToEnd() | ConvertFrom-Json
        [System.IO.File]::AppendAllText($dataFile, $body.record + "`n", [System.Text.Encoding]::UTF8)
        $resp = [System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
        $ctx.Response.ContentType = "application/json; charset=utf-8"
        $ctx.Response.ContentLength64 = $resp.Length
        $ctx.Response.OutputStream.Write($resp, 0, $resp.Length)
      } catch {
        $ctx.Response.StatusCode = 500
        $resp = [System.Text.Encoding]::UTF8.GetBytes('{"ok":false}')
        $ctx.Response.ContentLength64 = $resp.Length
        $ctx.Response.OutputStream.Write($resp, 0, $resp.Length)
      }
      $ctx.Response.OutputStream.Close()
      continue
    }

    # --- API: отдать все зашифрованные строки аккаунтов ---
    if ($path -eq "/api/accounts" -and $method -eq "GET") {
      $txt = ""
      if (Test-Path $dataFile) { $txt = [System.IO.File]::ReadAllText($dataFile) }
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($txt)
      $ctx.Response.ContentType = "text/plain; charset=utf-8"
      $ctx.Response.ContentLength64 = $bytes.Length
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
      $ctx.Response.OutputStream.Close()
      continue
    }

    # --- Статика ---
    if ($path -eq "/") { $path = "/index.html" }
    $file = Join-Path $root ($path.TrimStart("/") -replace "/", "\")
    if (Test-Path $file -PathType Leaf) {
      $ext = [System.IO.Path]::GetExtension($file).ToLower()
      $type = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" }
      $bytes = [System.IO.File]::ReadAllBytes($file)
      $ctx.Response.ContentType = $type
      $ctx.Response.ContentLength64 = $bytes.Length
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $ctx.Response.StatusCode = 404
      $msg = [System.Text.Encoding]::UTF8.GetBytes("404 not found")
      $ctx.Response.OutputStream.Write($msg, 0, $msg.Length)
    }
  } catch {}
  try { $ctx.Response.OutputStream.Close() } catch {}
}
