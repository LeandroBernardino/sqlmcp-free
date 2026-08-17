# sqlmcp-free

Free, minimal MCP server for SQL Server on Windows. One PowerShell script runs T-SQL through `sqlcmd`. No paid service or subscription required — just your own SQL Server and `sqlcmd`.

## What you need

- Windows + [sqlcmd](https://learn.microsoft.com/sql/tools/sqlcmd/sqlcmd-utility) on your PATH (SQL command-line tools or SSMS)
- Cursor (or any MCP client that can start a local command)

## How to use it

You do **not** need to clone this whole repository as a project.

1. **Download** [`sqlmcp-free.ps1`](./sqlmcp-free.ps1) to a folder on your PC (for example `C:\Tools\sqlmcp-free\sqlmcp-free.ps1`).
2. **Configure** your MCP client with that path and your SQL connection settings.

### Cursor example

Add (or merge) this into your MCP config (user or project `mcp.json`). Change the script path and the `env` values:

```json
{
  "mcpServers": {
    "sqlmcp-free": {
      "command": "powershell.exe",
      "args": [
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "C:\\Tools\\sqlmcp-free\\sqlmcp-free.ps1"
      ],
      "env": {
        "SQL_SERVER": "localhost",
        "SQL_USER": "myuser",
        "SQL_PWD": "mysecret",
        "SQL_DB": "mydatabase",
        "SQL_TRUST_CERT": "1"
      }
    }
  }
}
```

| Variable | Meaning |
| --- | --- |
| `SQL_SERVER` | SQL Server host (default `localhost`) |
| `SQL_USER` / `SQL_PWD` | SQL auth. Leave `SQL_USER` empty to use Windows auth (`sqlcmd -E`) |
| `SQL_DB` | Optional default database |
| `SQL_TRUST_CERT` | Set to `1` only if you need `sqlcmd -C` |

3. Restart Cursor (or reload MCP). Ask the agent to run SQL — it uses the `execute_sql` tool.

## Tool

- **`execute_sql`** — parameters: `sql` (required), `database` (optional override for `SQL_DB`)

## Notes

- Keep passwords in your local MCP config, not in a committed file.
- Without `sqlcmd` installed, the server may start but every query will fail.
- For a fuller example (`.env`, file runner, extra docs), see [sql-mcp-powershell](https://github.com/LeandroBernardino/sql-mcp-powershell).
