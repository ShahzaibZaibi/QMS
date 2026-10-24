using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;

namespace QMS.Repositories;

public sealed class SpExecutor : ISpExecutor
{
    private readonly string _connectionString;

    public SpExecutor(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("Default") ?? "";
        if (string.IsNullOrWhiteSpace(_connectionString))
            throw new InvalidOperationException("ConnectionStrings:Default set nahi hai.");
    }

    private static CommandDefinition Command(string procedure, object? parameters, CancellationToken ct) =>
        new(procedure, parameters, commandType: CommandType.StoredProcedure, commandTimeout: 30, cancellationToken: ct);

    private async Task<SqlConnection> OpenAsync(CancellationToken ct)
    {
        var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(ct);
        return connection;
    }

    public async Task<IReadOnlyList<T>> QueryAsync<T>(string procedure, object? parameters = null, CancellationToken ct = default)
    {
        await using var connection = await OpenAsync(ct);
        var rows = await connection.QueryAsync<T>(Command(procedure, parameters, ct));
        return rows.AsList();
    }

    public async Task<T?> QueryFirstOrDefaultAsync<T>(string procedure, object? parameters = null, CancellationToken ct = default)
    {
        await using var connection = await OpenAsync(ct);
        return await connection.QueryFirstOrDefaultAsync<T>(Command(procedure, parameters, ct));
    }

    public async Task<int> ExecuteAsync(string procedure, object? parameters = null, CancellationToken ct = default)
    {
        await using var connection = await OpenAsync(ct);
        return await connection.ExecuteAsync(Command(procedure, parameters, ct));
    }

    public async Task<T> QueryMultipleAsync<T>(string procedure, object? parameters, Func<SqlMapper.GridReader, Task<T>> read, CancellationToken ct = default)
    {
        await using var connection = await OpenAsync(ct);
        using var grid = await connection.QueryMultipleAsync(Command(procedure, parameters, ct));
        return await read(grid);
    }
}
