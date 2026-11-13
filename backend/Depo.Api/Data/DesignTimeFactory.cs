using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
namespace Depo.Api.Data;

public class DesignTimeFactory : IDesignTimeDbContextFactory<DepoDbContext>
{
    public DepoDbContext CreateDbContext(string[] args) => new(new DbContextOptionsBuilder<DepoDbContext>().UseNpgsql(Environment.GetEnvironmentVariable("ConnectionStrings__Database") ?? "Host=localhost;Port=54329;Database=mobildepo;Username=depo").Options);
}
