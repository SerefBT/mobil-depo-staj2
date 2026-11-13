namespace Depo.Api.Helpers;

public class ApiException(int status, string message) : Exception(message)
{
    public int Status { get; } = status;
}
