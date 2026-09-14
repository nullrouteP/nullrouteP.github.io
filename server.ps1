param(
    [int]$Port = 5500,
    [string]$Root = $PSScriptRoot
)

$ip = [System.Net.IPAddress]::Loopback
$listener = New-Object System.Net.Sockets.TcpListener($ip, $Port)

try {
    $listener.Start()
    Write-Output "HTTP server running at http://localhost:$Port/"
    
    while ($true) {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream)
        
        $requestLine = $reader.ReadLine()
        if (-not $requestLine) {
            $client.Close()
            continue
        }
        
        $parts = $requestLine.Split(' ')
        if ($parts.Length -ge 2) {
            $rawPath = $parts[1].Split('?')[0].TrimStart('/')
            if ([string]::IsNullOrWhiteSpace($rawPath)) {
                $rawPath = "index.html"
            }
            
            $filePath = Join-Path $Root $rawPath
            if (-not (Test-Path $filePath -PathType Leaf)) {
                $altPath = Join-Path $Root "index"
                if (Test-Path $altPath -PathType Leaf) {
                    $filePath = $altPath
                }
            }
            
            if (Test-Path $filePath -PathType Leaf) {
                $bytes = [System.IO.File]::ReadAllBytes($filePath)
                $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
                $contentType = switch ($ext) {
                    ".html" { "text/html; charset=utf-8" }
                    ".htm"  { "text/html; charset=utf-8" }
                    ".css"  { "text/css; charset=utf-8" }
                    ".js"   { "application/javascript; charset=utf-8" }
                    ".json" { "application/json; charset=utf-8" }
                    ".png"  { "image/png" }
                    ".jpg"  { "image/jpeg" }
                    ".svg"  { "image/svg+xml" }
                    default { "text/html; charset=utf-8" }
                }
                
                $header = "HTTP/1.1 200 OK`r`n" +
                          "Content-Type: $contentType`r`n" +
                          "Content-Length: $($bytes.Length)`r`n" +
                          "Connection: close`r`n`r`n"
                $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
                $stream.Write($headerBytes, 0, $headerBytes.Length)
                $stream.Write($bytes, 0, $bytes.Length)
            } else {
                $notFound = [System.Text.Encoding]::UTF8.GetBytes("<h1>404 Not Found</h1>")
                $header = "HTTP/1.1 404 Not Found`r`n" +
                          "Content-Type: text/html; charset=utf-8`r`n" +
                          "Content-Length: $($notFound.Length)`r`n" +
                          "Connection: close`r`n`r`n"
                $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
                $stream.Write($headerBytes, 0, $headerBytes.Length)
                $stream.Write($notFound, 0, $notFound.Length)
            }
        }
        $stream.Flush()
        $client.Close()
    }
}
catch {
    Write-Error $_
}
finally {
    if ($listener) { $listener.Stop() }
}
