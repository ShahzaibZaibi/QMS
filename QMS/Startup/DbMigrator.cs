using System.Data;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using Dapper;
using Microsoft.Data.SqlClient;
using QMS.Models;

namespace QMS.Startup;

/// <summary>
/// SQL scripts runner. Database/ ke folders is tarteeb se chalte hain: Functions, Tables, StoredProcedures, Seed.
/// Har folder mein files naam ki tarteeb se. Kaun si script chal chuki, dbo.SchemaVersions mein likha jata hai.
///  - Functions / StoredProcedures (CREATE OR ALTER): script badle to dobara chalti hai.
///  - Tables / Seed: sirf ek martaba. Purani script badal di jaye to ghalti (nayi script banayein).
/// Har script apne transaction mein chalti hai: fail ho to aadhi nahi lagti.
/// </summary>
public sealed class DbMigrator
{
    private static readonly string[] Folders = ["Functions", "Tables", "StoredProcedures", "Seed"];
    private static readonly HashSet<string> Rerunnable = ["Functions", "StoredProcedures"];
    private static readonly Regex GoLine = new(@"^[ \t]*GO[ \t]*(?:--[^\r\n]*)?\r?$", RegexOptions.IgnoreCase | RegexOptions.Multiline | RegexOptions.Compiled);

    private readonly IConfiguration _configuration;
    private readonly ILogger<DbMigrator> _logger;

    public DbMigrator(IConfiguration configuration, ILogger<DbMigrator> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    public async Task RunAsync(CancellationToken ct = default)
    {
        var connectionString = _configuration.GetConnectionString("Migration");
        if (string.IsNullOrWhiteSpace(connectionString)) connectionString = _configuration.GetConnectionString("Default");
        if (string.IsNullOrWhiteSpace(connectionString))
            throw new InvalidOperationException("ConnectionStrings:Migration (ya Default) set nahi hai.");

        var root = Path.Combine(AppContext.BaseDirectory, "Database");
        if (!Directory.Exists(root))
            throw new DirectoryNotFoundException($"Database scripts folder nahi mila: {root}");

        await EnsureDatabaseAsync(connectionString, ct);

        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(ct);

        await connection.ExecuteAsync(new CommandDefinition("""
            IF OBJECT_ID(N'dbo.SchemaVersions', N'U') IS NULL
            CREATE TABLE dbo.SchemaVersions (
                Id         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SchemaVersions PRIMARY KEY,
                ScriptName NVARCHAR(300) NOT NULL CONSTRAINT UQ_SchemaVersions_ScriptName UNIQUE,
                Hash       CHAR(64)      NOT NULL,
                AppliedAt  DATETIME2(0)  NOT NULL CONSTRAINT DF_SchemaVersions_AppliedAt DEFAULT (SYSUTCDATETIME())
            );
            """, cancellationToken: ct));

        var applied = (await connection.QueryAsync<AppliedScript>(new CommandDefinition(
                "SELECT ScriptName, Hash FROM dbo.SchemaVersions", cancellationToken: ct)))
            .ToDictionary(a => a.ScriptName, a => a.Hash, StringComparer.OrdinalIgnoreCase);

        var ran = 0;
        foreach (var folder in Folders)
        {
            var directory = Path.Combine(root, folder);
            if (!Directory.Exists(directory)) continue;

            foreach (var file in Directory.GetFiles(directory, "*.sql").OrderBy(f => Path.GetFileName(f), StringComparer.Ordinal))
            {
                var name = $"{folder}/{Path.GetFileName(file)}";
                var text = await File.ReadAllTextAsync(file, ct);
                var hash = Convert.ToHexStringLower(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(text)));

                var known = applied.TryGetValue(name, out var oldHash);
                if (known && oldHash == hash) continue;

                if (known && !Rerunnable.Contains(folder))
                    throw new InvalidOperationException(
                        $"Script '{name}' pehle chal chuki hai magar ab badli hui hai. " +
                        "Purani script mat badlein, tabdeeli ke liye nayi numbered script banayein.");

                await ApplyAsync(connection, name, text, hash, known, ct);
                _logger.LogInformation("DB script chali: {Script}", name);
                ran++;
            }
        }

        _logger.LogInformation("Database tayyar ({Count} nayi/badli scripts chali).", ran);
    }

    private static async Task ApplyAsync(SqlConnection connection, string name, string text, string hash, bool update, CancellationToken ct)
    {
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync(ct);
        try
        {
            foreach (var batch in GoLine.Split(text))
            {
                var sql = batch.Trim();
                if (sql.Length == 0) continue;
                await connection.ExecuteAsync(new CommandDefinition(sql, transaction: transaction, commandTimeout: 120, cancellationToken: ct));
            }

            await connection.ExecuteAsync(new CommandDefinition(
                update
                    ? "UPDATE dbo.SchemaVersions SET Hash = @hash, AppliedAt = SYSUTCDATETIME() WHERE ScriptName = @name"
                    : "INSERT dbo.SchemaVersions (ScriptName, Hash) VALUES (@name, @hash)",
                new { name, hash }, transaction, cancellationToken: ct));

            await transaction.CommitAsync(ct);
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync(CancellationToken.None);
            throw new InvalidOperationException($"DB script fail ho gayi: {name}. {ex.Message}", ex);
        }
    }

    private async Task EnsureDatabaseAsync(string connectionString, CancellationToken ct)
    {
        var builder = new SqlConnectionStringBuilder(connectionString);
        var database = builder.InitialCatalog;
        if (string.IsNullOrWhiteSpace(database))
            throw new InvalidOperationException("Connection string mein Database (Initial Catalog) likhna zaroori hai.");

        builder.InitialCatalog = "master";
        await using var master = new SqlConnection(builder.ConnectionString);
        await master.OpenAsync(ct);

        var exists = await master.ExecuteScalarAsync<int>(new CommandDefinition(
            "SELECT COUNT(*) FROM sys.databases WHERE name = @database", new { database }, cancellationToken: ct));
        if (exists == 0)
        {
            await master.ExecuteAsync(new CommandDefinition($"CREATE DATABASE [{database.Replace("]", "]]")}]", cancellationToken: ct));
            _logger.LogInformation("Database {Database} bana di.", database);
        }
    }
}
