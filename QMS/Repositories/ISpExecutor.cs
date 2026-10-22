using Dapper;

namespace QMS.Repositories;

/// <summary>
/// Dapper wala wrapper: sirf stored procedure chalata hai, koi logic nahi.
/// Connection har call par khulta aur band hota hai (pooling SqlClient khud sambhalta hai).
/// </summary>
public interface ISpExecutor
{
    Task<IReadOnlyList<T>> QueryAsync<T>(string procedure, object? parameters = null, CancellationToken ct = default);
    Task<T?> QueryFirstOrDefaultAsync<T>(string procedure, object? parameters = null, CancellationToken ct = default);
    Task<int> ExecuteAsync(string procedure, object? parameters = null, CancellationToken ct = default);
    Task<T> QueryMultipleAsync<T>(string procedure, object? parameters, Func<SqlMapper.GridReader, Task<T>> read, CancellationToken ct = default);
}
