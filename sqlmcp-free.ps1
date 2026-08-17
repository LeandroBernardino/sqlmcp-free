#requires -Version 5.1
# Minimal MCP stdio server: run T-SQL via sqlcmd. Free / no paid service required.
# Env: SQL_SERVER (default localhost), SQL_USER + SQL_PWD (or Windows auth if SQL_USER empty),
#      SQL_DB (optional), SQL_TRUST_CERT=1 (optional, sqlcmd -C).
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Send-Mcp([hashtable]$Object) {
  [Console]::Out.WriteLine(($Object | ConvertTo-Json -Compress -Depth 20))
}

function Invoke-Sql([string]$Sql, [string]$Database) {
  $server = if ($env:SQL_SERVER) { $env:SQL_SERVER } else { 'localhost' }
  $db = if ($Database) { $Database } elseif ($env:SQL_DB) { $env:SQL_DB } else { $null }
  $args = [System.Collections.Generic.List[string]]::new()
  [void]$args.AddRange([string[]]@('-S', $server, '-b', '-I', '-W'))
  if ($db) { [void]$args.AddRange([string[]]@('-d', $db)) }
  if ($env:SQL_TRUST_CERT -eq '1') { [void]$args.Add('-C') }
  if ($env:SQL_USER) {
    [void]$args.AddRange([string[]]@('-U', $env:SQL_USER, '-P', $(if ($null -ne $env:SQL_PWD) { $env:SQL_PWD } else { '' })))
  } else { [void]$args.Add('-E') }

  $tmp = [IO.Path]::GetTempFileName() + '.sql'
  $outF = [IO.Path]::GetTempFileName(); $errF = [IO.Path]::GetTempFileName()
  try {
    $enc = New-Object Text.UTF8Encoding $true
    [IO.File]::WriteAllText($tmp, ([char]0xFEFF + $Sql), $enc)
    [void]$args.AddRange([string[]]@('-i', $tmp))
    $p = Start-Process sqlcmd -ArgumentList $args.ToArray() -Wait -NoNewWindow -PassThru `
      -RedirectStandardOutput $outF -RedirectStandardError $errF
    $stdout = [IO.File]::ReadAllText($outF); $stderr = [IO.File]::ReadAllText($errF)
    $ok = $p.ExitCode -eq 0
    $text = "$(if ($ok) {'OK'} else {"FAILED (exit $($p.ExitCode))"})`n--- stdout ---`n$(if ($stdout) {$stdout} else {'(empty)'})`n--- stderr ---`n$(if ($stderr) {$stderr} else {'(empty)'})"
    return @{ content = @(@{ type = 'text'; text = $text }); isError = (-not $ok) }
  } finally {
    Remove-Item -LiteralPath $tmp, $outF, $errF -Force -ErrorAction SilentlyContinue
  }
}

while ($true) {
  $line = [Console]::In.ReadLine()
  if ($null -eq $line) { break }
  $trim = $line.Trim(); if (-not $trim) { continue }
  try { $msg = $trim | ConvertFrom-Json } catch { continue }
  $method = [string]$msg.method; if (-not $method -or $method.StartsWith('notifications/')) { continue }
  $hasId = $msg.PSObject.Properties.Name -contains 'id'; $rid = if ($hasId) { $msg.id } else { $null }
  try {
    if ($method -eq 'initialize' -and $hasId) {
      $pv = if ($msg.params.protocolVersion) { [string]$msg.params.protocolVersion } else { '2024-11-05' }
      Send-Mcp @{ jsonrpc = '2.0'; id = $rid; result = @{
        protocolVersion = $pv; capabilities = @{ tools = @{} }
        serverInfo = @{ name = 'sqlmcp-free'; version = '1.0.0' }
      } }; continue
    }
    if ($method -eq 'tools/list' -and $hasId) {
      Send-Mcp @{ jsonrpc = '2.0'; id = $rid; result = @{ tools = @(
        @{
          name = 'execute_sql'
          description = 'Run T-SQL via sqlcmd. Optional database overrides SQL_DB.'
          inputSchema = @{
            type = 'object'
            properties = @{
              sql = @{ type = 'string'; description = 'T-SQL batch' }
              database = @{ type = 'string'; description = 'Database (-d)' }
            }
            required = @('sql')
          }
        }
      ) } }; continue
    }
    if ($method -eq 'tools/call' -and $hasId) {
      $name = [string]$msg.params.name; $a = $msg.params.arguments
      if ($name -ne 'execute_sql') {
        Send-Mcp @{ jsonrpc = '2.0'; id = $rid; result = @{ content = @(@{ type = 'text'; text = "Unknown tool: $name" }); isError = $true } }
        continue
      }
      $sql = if ($a.sql) { [string]$a.sql } else { '' }
      $db = if ($a.database) { [string]$a.database } else { $null }
      if (-not $sql.Trim()) {
        Send-Mcp @{ jsonrpc = '2.0'; id = $rid; result = @{ content = @(@{ type = 'text'; text = 'Missing sql' }); isError = $true } }
        continue
      }
      Send-Mcp @{ jsonrpc = '2.0'; id = $rid; result = (Invoke-Sql -Sql $sql -Database $db) }; continue
    }
    if ($method -eq 'ping' -and $hasId) { Send-Mcp @{ jsonrpc = '2.0'; id = $rid; result = @{} }; continue }
    if ($hasId) { Send-Mcp @{ jsonrpc = '2.0'; id = $rid; error = @{ code = -32601; message = "Method not found: $method" } } }
  } catch {
    if ($hasId) { Send-Mcp @{ jsonrpc = '2.0'; id = $rid; error = @{ code = -32603; message = $_.Exception.Message } } }
  }
}
