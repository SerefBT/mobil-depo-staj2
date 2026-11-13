using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Depo.Api.Data;
using Depo.Api.Services;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Npgsql;
using Xunit;
[assembly: CollectionBehavior(DisableTestParallelization = true)]
namespace Depo.Tests;

public class ApiFixture : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly string maintenance = Environment.GetEnvironmentVariable("TEST_DATABASE_CONNECTION") ?? throw new InvalidOperationException("TEST_DATABASE_CONNECTION PostgreSQL bağlantısı zorunludur. scripts/Test.ps1 kullanın.");
    private readonly string name = "mobildepo_test_" + Guid.NewGuid().ToString("N");
    public HttpClient Client { get; private set; } = null!;
    public string Admin { get; private set; } = ""; public string Staff { get; private set; } = ""; public string Unit { get; private set; } = ""; public string Unit2 { get; private set; } = "";
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");
        builder.ConfigureServices(services => { var worker = services.SingleOrDefault(x => x.ServiceType == typeof(IHostedService) && x.ImplementationType == typeof(ExpiryWorker)); if (worker != null) services.Remove(worker); });
    }
    public async Task InitializeAsync()
    {
        await using var connection = new NpgsqlConnection(maintenance);
        await connection.OpenAsync();
        await using (var cmd = new NpgsqlCommand($"CREATE DATABASE \"{name}\"", connection))
            await cmd.ExecuteNonQueryAsync();
        var b = new NpgsqlConnectionStringBuilder(maintenance) { Database = name };
        Environment.SetEnvironmentVariable("ConnectionStrings__Database", b.ConnectionString);
        Environment.SetEnvironmentVariable("Demo__Seed", "true");
        Environment.SetEnvironmentVariable("Jwt__Key", Convert.ToBase64String(System.Security.Cryptography.RandomNumberGenerator.GetBytes(64)));
        Client = CreateClient();
        Admin = await Token("admin", "Admin12345!");
        Staff = await Token("depo", "Depo12345!");
        Unit = await Token("birim", "Birim12345!");
        Unit2 = await Token("birim2", "Birim12345!");
    }
    public new async Task DisposeAsync()
    {
        Client.Dispose();
        await base.DisposeAsync();
        Environment.SetEnvironmentVariable("ConnectionStrings__Database", null);
        Environment.SetEnvironmentVariable("Demo__Seed", null);
        Environment.SetEnvironmentVariable("Jwt__Key", null);
        NpgsqlConnection.ClearAllPools();
        await using var c = new NpgsqlConnection(maintenance);
        await c.OpenAsync();
        await using var cmd = new NpgsqlCommand($"DROP DATABASE IF EXISTS \"{name}\" WITH (FORCE)", c);
        await cmd.ExecuteNonQueryAsync();
    }
    public async Task<string> Token(string login, string password)
    {
        var r = await Send(HttpMethod.Post, "/api/auth/login", null, new
        {
            login = login + "@demo.local",
            password
        });
        r.EnsureSuccessStatusCode();
        return (await Json(r)).GetProperty("token").GetString()!;
    }
    public async Task<HttpResponseMessage> Send(HttpMethod method, string url, string? token = null, object? body = null)
    {
        using var request = new HttpRequestMessage(method, url);
        if (token != null)
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        if (body != null)
            request.Content = JsonContent.Create(body);
        return await Client.SendAsync(request);
    }
    public static async Task<JsonElement> Json(HttpResponseMessage r) => JsonDocument.Parse(await r.Content.ReadAsStringAsync()).RootElement.Clone();
    public async Task<int> Product(int minimum = 10)
    {
        var key = Guid.NewGuid().ToString("N");
        var r = await Send(HttpMethod.Post, "/api/products", Staff, new
        {
            productCode = "T-" + key,
            barcode = "B-" + key,
            name = "Test malzemesi " + key,
            description = "Test",
            categoryId = 1,
            measureUnit = "Adet",
            minimumStock = minimum,
            shelfId = 7,
            isActive = true
        });
        r.EnsureSuccessStatusCode();
        return (await Json(r)).GetProperty("id").GetInt32();
    }
    public Task<HttpResponseMessage> In(int id, int amount, Guid? op = null, string? batch = null, DateOnly? expiry = null) => Send(HttpMethod.Post, "/api/stock/in", Staff, new { productId = id, quantity = amount, description = "Test stok girişi", operationId = op ?? Guid.NewGuid(), type = "In", batchNumber = batch, expiryDate = expiry });
    public Task<HttpResponseMessage> Out(int id, int amount, Guid? op = null) => Send(HttpMethod.Post, "/api/stock/out", Staff, new { productId = id, quantity = amount, description = "Test stok çıkışı", operationId = op ?? Guid.NewGuid(), type = "Out" });
    public async Task<int> Quantity(int id) => (await Json(await Send(HttpMethod.Get, $"/api/products/{id}", Staff))).GetProperty("quantity").GetInt32();
    public async Task<int> Request(params (int Product, int Quantity)[] lines)
    {
        var r = await Send(HttpMethod.Post, "/api/requests", Unit, new
        {
            clientId = Guid.NewGuid(),
            priority = "Normal",
            description = "Test talebi",
            items = lines.Select(x => new { productId = x.Product, quantity = x.Quantity })
        });
        r.EnsureSuccessStatusCode();
        return (await Json(r)).GetProperty("id").GetInt32();
    }
    public async Task Prepare(int id)
    {
        var r = await Send(HttpMethod.Put, $"/api/requests/{id}/prepare", Staff);
        r.EnsureSuccessStatusCode();
    }
}
public class ApiTests(ApiFixture f) : IClassFixture<ApiFixture>
{
    [Fact]
    public async Task Login_ReturnsRoleAndToken()
    {
        var r = await f.Send(HttpMethod.Post, "/api/auth/login", null, new
        {
            login = "depo@demo.local",
            password = "Depo12345!"
        });
        Assert.Equal(HttpStatusCode.OK, r.StatusCode);
        var j = await ApiFixture.Json(r);
        Assert.Equal("Warehouse", j.GetProperty("user").GetProperty("role").GetString());
        Assert.NotEmpty(j.GetProperty("token").GetString()!);
    }
    [Fact]
    public async Task InvalidPassword_IsRejected()
    {
        var r = await f.Send(HttpMethod.Post, "/api/auth/login", null, new
        {
            login = "depo@demo.local",
            password = "wrong"
        });
        Assert.Equal(HttpStatusCode.Unauthorized, r.StatusCode);
    }
    [Fact] public async Task Anonymous_CannotReadProducts() => Assert.Equal(HttpStatusCode.Unauthorized, (await f.Send(HttpMethod.Get, "/api/products")).StatusCode);
    [Fact]
    public async Task Unit_CannotChangeStock()
    {
        var p = await f.Product();
        var r = await f.Send(HttpMethod.Post, "/api/stock/in", f.Unit, new
        {
            productId = p,
            quantity = 10,
            description = "Yetkisiz deneme",
            operationId = Guid.NewGuid(),
            type = "In"
        });
        Assert.Equal(HttpStatusCode.Forbidden, r.StatusCode);
        Assert.Equal(0, await f.Quantity(p));
    }
    [Fact] public async Task Unit_CannotCreateUsers() => Assert.Equal(HttpStatusCode.Forbidden, (await f.Send(HttpMethod.Get, "/api/admin/users", f.Unit)).StatusCode);
    [Fact]
    public async Task Unit_CannotCreateProduct()
    {
        var r = await f.Send(HttpMethod.Post, "/api/products", f.Unit, new
        {
            productCode = "NO",
            barcode = "NO",
            name = "Yetkisiz",
            description = "Test",
            categoryId = 1,
            measureUnit = "Adet",
            minimumStock = 1,
            shelfId = 1
        });
        Assert.Equal(HttpStatusCode.Forbidden, r.StatusCode);
    }
    [Fact]
    public async Task Staff_CanCreateProduct_WithZeroStock()
    {
        var id = await f.Product();
        Assert.Equal(0, await f.Quantity(id));
    }
    [Fact]
    public async Task StockIn_IncreasesAndRecordsMovement()
    {
        var p = await f.Product();
        var r = await f.In(p, 100);
        r.EnsureSuccessStatusCode();
        Assert.Equal(100, await f.Quantity(p));
        var j = await ApiFixture.Json(await f.Send(HttpMethod.Get, $"/api/stock/movements/{p}", f.Staff));
        Assert.Single(j.GetProperty("items").EnumerateArray());
        Assert.Equal(100, j.GetProperty("items")[0].GetProperty("quantity").GetInt32());
    }
    [Fact]
    public async Task StockOut_DecreasesQuantity()
    {
        var p = await f.Product();
        (await f.In(p, 100)).EnsureSuccessStatusCode();
        (await f.Out(p, 20)).EnsureSuccessStatusCode();
        Assert.Equal(80, await f.Quantity(p));
    }
    [Fact]
    public async Task InsufficientStock_DoesNotMutateLedger()
    {
        var p = await f.Product();
        await f.In(p, 20);
        var r = await f.Out(p, 30);
        Assert.Equal(HttpStatusCode.Conflict, r.StatusCode);
        Assert.Equal(20, await f.Quantity(p));
        var j = await ApiFixture.Json(await f.Send(HttpMethod.Get, $"/api/stock/movements/{p}", f.Staff));
        Assert.Equal(1, j.GetProperty("total").GetInt32());
    }
    [Fact]
    public async Task ZeroAndNegativeQuantities_AreRejected()
    {
        var p = await f.Product();
        Assert.Equal(HttpStatusCode.BadRequest, (await f.In(p, 0)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await f.Out(p, -1)).StatusCode);
    }
    [Fact]
    public async Task StockRetry_IsIdempotent()
    {
        var p = await f.Product();
        var op = Guid.NewGuid();
        (await f.In(p, 10, op)).EnsureSuccessStatusCode();
        (await f.In(p, 10, op)).EnsureSuccessStatusCode();
        Assert.Equal(10, await f.Quantity(p));
        Assert.Equal(HttpStatusCode.Conflict, (await f.In(p, 11, op)).StatusCode);
    }
    [Fact]
    public async Task CriticalStock_AppearsAndNotifies()
    {
        var p = await f.Product(50);
        await f.In(p, 100);
        await f.Out(p, 60);
        var list = await ApiFixture.Json(await f.Send(HttpMethod.Get, "/api/reports/critical-stock", f.Staff));
        Assert.Contains(list.EnumerateArray(), x => x.GetProperty("id").GetInt32() == p);
        var notifications = await ApiFixture.Json(await f.Send(HttpMethod.Get, "/api/notifications", f.Staff));
        Assert.Contains(notifications.GetProperty("items").EnumerateArray(), x => x.GetProperty("title").GetString() == "Kritik stok");
    }
    [Fact]
    public async Task Request_CanContainMultipleProducts()
    {
        var a = await f.Product();
        var b = await f.Product();
        var r = await f.Request((a, 2), (b, 3));
        var j = await ApiFixture.Json(await f.Send(HttpMethod.Get, $"/api/requests/{r}", f.Unit));
        Assert.Equal(2, j.GetProperty("items").GetArrayLength());
    }
    [Fact]
    public async Task OtherUnit_CannotReadRequest()
    {
        var p = await f.Product();
        var r = await f.Request((p, 2));
        Assert.Equal(HttpStatusCode.NotFound, (await f.Send(HttpMethod.Get, $"/api/requests/{r}", f.Unit2)).StatusCode);
    }
    [Fact]
    public async Task Delivery_100Minus20_Equals80_WithHistory()
    {
        var p = await f.Product();
        await f.In(p, 100);
        var id = await f.Request((p, 20));
        await f.Prepare(id);
        (await f.Send(HttpMethod.Put, $"/api/requests/{id}/deliver", f.Staff)).EnsureSuccessStatusCode();
        Assert.Equal(80, await f.Quantity(p));
        var request = await ApiFixture.Json(await f.Send(HttpMethod.Get, $"/api/requests/{id}", f.Unit));
        Assert.Equal("Delivered", request.GetProperty("status").GetString());
        var j = await ApiFixture.Json(await f.Send(HttpMethod.Get, $"/api/stock/movements/{p}", f.Staff));
        Assert.Contains(j.GetProperty("items").EnumerateArray(), x => x.GetProperty("quantity").GetInt32() == 100);
        Assert.Contains(j.GetProperty("items").EnumerateArray(), x => x.GetProperty("quantity").GetInt32() == -20 && x.GetProperty("requestId").GetInt32() == id);
    }
    [Fact]
    public async Task DuplicateDelivery_IsRejected()
    {
        var p = await f.Product();
        await f.In(p, 100);
        var id = await f.Request((p, 20));
        await f.Prepare(id);
        await f.Send(HttpMethod.Put, $"/api/requests/{id}/deliver", f.Staff);
        Assert.Equal(HttpStatusCode.Conflict, (await f.Send(HttpMethod.Put, $"/api/requests/{id}/deliver", f.Staff)).StatusCode);
        Assert.Equal(80, await f.Quantity(p));
    }
    [Fact]
    public async Task MultiProductDelivery_RollsBackAllOnFailure()
    {
        var a = await f.Product();
        var b = await f.Product();
        await f.In(a, 100);
        await f.In(b, 1);
        var id = await f.Request((a, 20), (b, 20));
        await f.Prepare(id);
        Assert.Equal(HttpStatusCode.Conflict, (await f.Send(HttpMethod.Put, $"/api/requests/{id}/deliver", f.Staff)).StatusCode);
        Assert.Equal(100, await f.Quantity(a));
        Assert.Equal(1, await f.Quantity(b));
        var j = await ApiFixture.Json(await f.Send(HttpMethod.Get, $"/api/requests/{id}", f.Unit));
        Assert.Equal("Preparing", j.GetProperty("status").GetString());
    }
    [Fact]
    public async Task ConcurrentOuts_CannotOversell()
    {
        var p = await f.Product();
        await f.In(p, 100);
        var results = await Task.WhenAll(f.Out(p, 80), f.Out(p, 80));
        Assert.Single(results, x => x.IsSuccessStatusCode);
        Assert.Single(results, x => x.StatusCode == HttpStatusCode.Conflict);
        Assert.Equal(20, await f.Quantity(p));
    }
    [Fact]
    public async Task ConcurrentDeliveries_OnlyOneSucceeds()
    {
        var p = await f.Product();
        await f.In(p, 100);
        var id = await f.Request((p, 20));
        await f.Prepare(id);
        var results = await Task.WhenAll(f.Send(HttpMethod.Put, $"/api/requests/{id}/deliver", f.Staff), f.Send(HttpMethod.Put, $"/api/requests/{id}/deliver", f.Staff));
        Assert.Single(results, x => x.IsSuccessStatusCode);
        Assert.Equal(80, await f.Quantity(p));
    }
    [Fact]
    public async Task Fefo_UsesEarliestBatchFirst()
    {
        var p = await f.Product();
        await f.In(p, 40, batch: "LATE", expiry: DateOnly.FromDateTime(DateTime.UtcNow.AddDays(90)));
        await f.In(p, 30, batch: "EARLY", expiry: DateOnly.FromDateTime(DateTime.UtcNow.AddDays(7)));
        await f.Out(p, 20);
        var batches = await ApiFixture.Json(await f.Send(HttpMethod.Get, $"/api/products/{p}/batches", f.Staff));
        Assert.Equal(10, batches.EnumerateArray().Single(x => x.GetProperty("batchNumber").GetString() == "EARLY").GetProperty("quantity").GetInt32());
        Assert.Equal(40, batches.EnumerateArray().Single(x => x.GetProperty("batchNumber").GetString() == "LATE").GetProperty("quantity").GetInt32());
    }
    [Fact]
    public async Task ExpiredBatches_AreNotDelivered()
    {
        var p = await f.Product();
        await f.In(p, 20, batch: "EXPIRED");
        using (var scope = Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<DepoDbContext>();
            await db.ProductBatches.Where(x => x.ProductId == p).ExecuteUpdateAsync(s => s.SetProperty(x => x.ExpiryDate, DateOnly.FromDateTime(DateTime.UtcNow.AddDays(-2))));
        }
        Assert.Equal(HttpStatusCode.Conflict, (await f.Out(p, 10)).StatusCode);
        Assert.Equal(20, await f.Quantity(p));
    }
    private IServiceProvider Services => f.Services;
    [Fact]
    public async Task BarcodeAndShelfQr_Resolve()
    {
        var p = await f.Product();
        var product = await ApiFixture.Json(await f.Send(HttpMethod.Get, $"/api/products/{p}", f.Unit));
        var barcode = product.GetProperty("barcode").GetString();
        Assert.Equal(HttpStatusCode.OK, (await f.Send(HttpMethod.Get, $"/api/products/barcode/{barcode}", f.Unit)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await f.Send(HttpMethod.Get, "/api/shelves/qr/DEPO-A-K2-B04", f.Staff)).StatusCode);
    }
    [Fact]
    public async Task InvalidStateTransition_IsRejected()
    {
        var p = await f.Product();
        var id = await f.Request((p, 1));
        Assert.Equal(HttpStatusCode.Conflict, (await f.Send(HttpMethod.Put, $"/api/requests/{id}/deliver", f.Staff)).StatusCode);
    }
    [Fact]
    public async Task UserCancellation_DoesNotChangeStock()
    {
        var p = await f.Product();
        await f.In(p, 50);
        var id = await f.Request((p, 10));
        (await f.Send(HttpMethod.Put, $"/api/requests/{id}/cancel", f.Unit)).EnsureSuccessStatusCode();
        Assert.Equal(50, await f.Quantity(p));
        Assert.Equal(HttpStatusCode.Conflict, (await f.Send(HttpMethod.Put, $"/api/requests/{id}/prepare", f.Staff)).StatusCode);
    }
    [Fact]
    public async Task Csv_ExportsWithUtf8AndHeaders()
    {
        var r = await f.Send(HttpMethod.Get, "/api/reports/stock-movements.csv", f.Staff);
        r.EnsureSuccessStatusCode();
        Assert.Equal("text/csv", r.Content.Headers.ContentType!.MediaType);
        Assert.Contains("Id;Ürün;Tür", await r.Content.ReadAsStringAsync());
    }
    [Fact]
    public async Task Logout_RevokesToken()
    {
        var token = await f.Token("birim3", "Birim12345!");
        (await f.Send(HttpMethod.Post, "/api/auth/logout", token)).EnsureSuccessStatusCode();
        Assert.Equal(HttpStatusCode.Unauthorized, (await f.Send(HttpMethod.Get, "/api/auth/me", token)).StatusCode);
    }

    [Fact]
    public async Task ExpiredIncomingBatch_IsRejected()
    {
        var p = await f.Product();
        Assert.Equal(HttpStatusCode.BadRequest, (await f.In(p, 10, batch: "OLD", expiry: DateOnly.FromDateTime(DateTime.UtcNow.AddDays(-2)))).StatusCode);
        Assert.Equal(0, await f.Quantity(p));
    }
    [Fact] public async Task Unit_CannotReadGlobalReports() => Assert.Equal(HttpStatusCode.Forbidden, (await f.Send(HttpMethod.Get, "/api/reports/summary", f.Unit)).StatusCode);
    [Fact]
    public async Task ReportDateRange_FiltersUnitRequests()
    {
        var r = await f.Send(HttpMethod.Get, "/api/reports/summary?from=2000-01-01&to=2000-01-02", f.Staff);
        r.EnsureSuccessStatusCode();
        var j = await ApiFixture.Json(r);
        Assert.Empty(j.GetProperty("byUnit").EnumerateArray());
        Assert.Empty(j.GetProperty("daily").EnumerateArray());
    }
    [Fact]
    public async Task Admin_CanCreateUnit()
    {
        var r = await f.Send(HttpMethod.Post, "/api/units", f.Admin, new
        {
            name = "Test birimi " + Guid.NewGuid().ToString("N")
        });
        r.EnsureSuccessStatusCode();
    }
    [Fact]
    public async Task Unit_CannotCancelPreparingRequest()
    {
        var p = await f.Product();
        var id = await f.Request((p, 1));
        await f.Prepare(id);
        Assert.Equal(HttpStatusCode.Conflict, (await f.Send(HttpMethod.Put, $"/api/requests/{id}/cancel", f.Unit)).StatusCode);
    }

    [Fact]
    public async Task UnknownApi_DoesNotReturnWebHtml()
    {
        var r = await f.Send(HttpMethod.Get, "/api/unknown", f.Staff);
        Assert.Equal(HttpStatusCode.NotFound, r.StatusCode);
        Assert.Contains("json", r.Content.Headers.ContentType!.MediaType!);
    }
    [Fact]
    public async Task WebRoot_ServesSharedFlutterApp()
    {
        var r = await f.Send(HttpMethod.Get, "/");
        r.EnsureSuccessStatusCode();
        Assert.Equal("text/html", r.Content.Headers.ContentType!.MediaType);
        Assert.Contains("Mobil Depo", await r.Content.ReadAsStringAsync());
    }
}
