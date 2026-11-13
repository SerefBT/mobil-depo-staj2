using System.Text;
using Depo.Api.Authentication;
using Depo.Api.Data;
using Depo.Api.Helpers;
using Depo.Api.Models;
using Depo.Api.Repositories;
using Depo.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
namespace Depo.Api.Controllers;

[ApiController, Route("api"), Authorize]
public class InsightsController(DepoDbContext db, CurrentUser current, RequestService requests) : ControllerBase
{
    private static readonly TimeZoneInfo Istanbul = TimeZoneInfo.FindSystemTimeZoneById("Europe/Istanbul");
    [HttpGet("dashboard")]
    public async Task<object> Dashboard()
    {
        var local = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, Istanbul).Date;
        var start = TimeZoneInfo.ConvertTimeToUtc(local, Istanbul);
        var end = start.AddDays(1);
        var q = db.Products.Where(x => x.IsActive);
        var movements = db.StockMovements.Where(x => x.CreatedAt >= start && x.CreatedAt < end);
        return new
        {
            TotalProducts = await q.CountAsync(),
            TotalStock = await q.SumAsync(x => (long?)x.Stock.Quantity) ?? 0,
            CriticalStock = await q.CountAsync(x => x.Stock.Quantity < x.MinimumStock),
            PendingRequests = await requests.Visible.CountAsync(x => x.Status == RequestStatus.Pending || x.Status == RequestStatus.Approved || x.Status == RequestStatus.Preparing),
            TodayIn = current.IsUnit ? 0 : await movements.Where(x => x.Quantity > 0).SumAsync(x => (long?)x.Quantity) ?? 0,
            TodayOut = current.IsUnit ? 0 : -(await movements.Where(x => x.Quantity < 0).SumAsync(x => (long?)x.Quantity) ?? 0),
            CriticalProducts = await ProductRepository.Project(q.Where(x => x.Stock.Quantity < x.MinimumStock).OrderBy(x => x.Stock.Quantity).Take(6)).ToListAsync(),
            RecentMovements = current.IsUnit ? new List<object>() : await MovementProjection(db.StockMovements.OrderByDescending(x => x.Id).Take(8)).ToListAsync()
        };
    }
    public static IQueryable<object> MovementProjection(IQueryable<StockMovement> q) => q.Select(x => new { x.Id, x.ProductId, Product = x.Product.Name, x.Product.MeasureUnit, x.Type, x.Quantity, x.PreviousStock, x.NextStock, x.CreatedAt, User = x.User.FullName, x.Description, x.RequestId });
    [HttpGet("reports/critical-stock"), Authorize(Roles = Roles.Operators)] public async Task<object> Critical() => await ProductRepository.Project(db.Products.Where(x => x.IsActive && x.Stock.Quantity < x.MinimumStock).OrderBy(x => x.Stock.Quantity)).ToListAsync();
    private IQueryable<StockMovement> MovementQuery(DateOnly? from, DateOnly? to)
    {
        if (from > to)
            throw new ApiException(400, "Başlangıç tarihi bitişten sonra olamaz.");
        var q = db.StockMovements.AsNoTracking();
        if (from != null)
        {
            var d = TimeZoneInfo.ConvertTimeToUtc(from.Value.ToDateTime(TimeOnly.MinValue), Istanbul);
            q = q.Where(x => x.CreatedAt >= d);
        }
        if (to != null)
        {
            var d = TimeZoneInfo.ConvertTimeToUtc(to.Value.AddDays(1).ToDateTime(TimeOnly.MinValue), Istanbul);
            q = q.Where(x => x.CreatedAt < d);
        }
        return q;
    }
    [HttpGet("reports/stock-movements"), Authorize(Roles = Roles.Operators)]
    public async Task<object> Movements(DateOnly? from, DateOnly? to, int page = 1, int pageSize = 50)
    {
        var q = MovementQuery(from, to);
        return new
        {
            Total = await q.CountAsync(),
            Items = await MovementProjection(q.OrderByDescending(x => x.Id).Skip((Math.Clamp(page, 1, 1000000) - 1) * Math.Clamp(pageSize, 1, 100)).Take(Math.Clamp(pageSize, 1, 100))).ToListAsync()
        };
    }
    private IQueryable<MaterialRequest> RequestDateQuery(DateOnly? from, DateOnly? to)
    {
        var q = db.Requests.AsNoTracking();
        if (from != null)
        {
            var start = TimeZoneInfo.ConvertTimeToUtc(from.Value.ToDateTime(TimeOnly.MinValue), Istanbul);
            q = q.Where(x => x.CreatedAt >= start);
        }
        if (to != null)
        {
            var end = TimeZoneInfo.ConvertTimeToUtc(to.Value.AddDays(1).ToDateTime(TimeOnly.MinValue), Istanbul);
            q = q.Where(x => x.CreatedAt < end);
        }
        return q;
    }
    [HttpGet("reports/summary"), Authorize(Roles = Roles.Operators)]
    public async Task<object> Summary(DateOnly? from, DateOnly? to)
    {
        var q = MovementQuery(from, to);
        var today = DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, Istanbul));
        var daily = await q.GroupBy(x => x.CreatedAt.AddHours(3).Date).Select(g => new { Date = g.Key, In = g.Where(x => x.Quantity > 0).Sum(x => (long)x.Quantity), Out = -g.Where(x => x.Quantity < 0).Sum(x => (long)x.Quantity) }).OrderByDescending(x => x.Date).Take(31).ToListAsync();
        return new
        {
            Daily = daily,
            TopProducts = await q.Where(x => x.Quantity < 0).GroupBy(x => new { x.ProductId, x.Product.Name }).Select(g => new { g.Key.ProductId, g.Key.Name, Quantity = -g.Sum(x => (long)x.Quantity) }).OrderByDescending(x => x.Quantity).Take(10).ToListAsync(),
            ByUnit = await RequestDateQuery(from, to).GroupBy(x => x.Unit.Name).Select(g => new { Unit = g.Key, Count = g.Count(), Pending = g.Count(x => x.Status != RequestStatus.Delivered && x.Status != RequestStatus.Cancelled) }).ToListAsync(),
            Expiring = await db.ProductBatches.Where(x => x.Quantity > 0 && x.ExpiryDate != null && x.ExpiryDate <= today.AddDays(30)).OrderBy(x => x.ExpiryDate).Select(x => new { x.Id, Product = x.Product.Name, x.BatchNumber, x.Quantity, x.ExpiryDate, DaysLeft = x.ExpiryDate!.Value.DayNumber - today.DayNumber }).ToListAsync()
        };
    }
    private static string Cell(string? s)
    {
        s ??= "";
        if (s.Length > 0 && "=+-@\t\r".Contains(s[0]))
            s = "'" + s;
        return "\"" + s.Replace("\"", "\"\"") + "\"";
    }
    [HttpGet("reports/stock-movements.csv"), Authorize(Roles = Roles.Operators)]
    public async Task<IActionResult> Csv(DateOnly? from, DateOnly? to)
    {
        var rows = await MovementQuery(from, to).Include(x => x.Product).Include(x => x.User).OrderByDescending(x => x.Id).Take(50000).ToListAsync();
        var b = new StringBuilder("Id;Ürün;Tür;Miktar;Önceki;Sonraki;Tarih;Kullanıcı;Açıklama\r\n");
        foreach (var x in rows)
            b.AppendLine(string.Join(';', x.Id.ToString(), Cell(x.Product.Name), Cell(x.Type.ToString()), x.Quantity.ToString(), x.PreviousStock.ToString(), x.NextStock.ToString(), Cell(TimeZoneInfo.ConvertTimeFromUtc(x.CreatedAt, Istanbul).ToString("dd.MM.yyyy HH:mm")), Cell(x.User.FullName), Cell(x.Description)));
        var bytes = Encoding.UTF8.GetPreamble().Concat(Encoding.UTF8.GetBytes(b.ToString())).ToArray();
        return File(bytes, "text/csv; charset=utf-8", "stok-hareketleri.csv");
    }
    [HttpGet("notifications")] public async Task<object> Notifications(int page = 1) => new { Unread = await db.Notifications.CountAsync(x => x.UserId == current.Id && !x.IsRead), Items = await db.Notifications.AsNoTracking().Where(x => x.UserId == current.Id).OrderByDescending(x => x.Id).Skip((Math.Clamp(page, 1, 1000000) - 1) * 50).Take(50).Select(x => new { x.Id, x.Title, x.Message, x.CreatedAt, x.IsRead }).ToListAsync() };
    [HttpPut("notifications/{id:long}/read")]
    public async Task<IActionResult> Read(long id)
    {
        await db.Notifications.Where(x => x.Id == id && x.UserId == current.Id).ExecuteUpdateAsync(s => s.SetProperty(x => x.IsRead, true));
        return NoContent();
    }
    [HttpPut("notifications/read-all")]
    public async Task<IActionResult> ReadAll()
    {
        await db.Notifications.Where(x => x.UserId == current.Id && !x.IsRead).ExecuteUpdateAsync(s => s.SetProperty(x => x.IsRead, true));
        return NoContent();
    }
}
