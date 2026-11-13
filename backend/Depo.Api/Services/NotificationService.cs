using Depo.Api.Data;
using Depo.Api.Models;
using Microsoft.EntityFrameworkCore;
namespace Depo.Api.Services;

public class NotificationService(DepoDbContext db)
{
    public async Task Operators(string title, string message, string? key = null)
    {
        var ids = await (from ur in db.UserRoles join role in db.Roles on ur.RoleId equals role.Id join user in db.Users on ur.UserId equals user.Id where user.IsActive && (role.Name == Models.Roles.Admin || role.Name == Models.Roles.Warehouse) select ur.UserId).Distinct().ToListAsync();
        foreach (var id in ids)
            await Send(id, title, message, key);
    }
    public async Task Send(Guid id, string title, string message, string? key = null)
    {
        if (key != null && await db.Notifications.AnyAsync(n => n.UserId == id && n.DedupKey == key))
            return;
        db.Notifications.Add(new Notification { UserId = id, Title = title, Message = message, DedupKey = key });
    }
}
public class ExpiryWorker(IServiceScopeFactory scopes, ILogger<ExpiryWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromHours(1));
        do
        {
            try
            {
                using var scope = scopes.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<DepoDbContext>();
                await using var tx = await db.Database.BeginTransactionAsync(stoppingToken);
                await db.Database.ExecuteSqlRawAsync("SELECT pg_advisory_xact_lock(87654219)", stoppingToken);
                var service = scope.ServiceProvider.GetRequiredService<NotificationService>();
                var today = DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById("Europe/Istanbul")));
                var batches = await db.ProductBatches.Include(x => x.Product).Where(x => x.Quantity > 0 && x.ExpiryDate != null && x.ExpiryDate <= today.AddDays(30)).ToListAsync(stoppingToken);
                foreach (var batch in batches)
                {
                    var days = batch.ExpiryDate!.Value.DayNumber - today.DayNumber;
                    var threshold = days < 0 ? -1 : days <= 7 ? 7 : days <= 15 ? 15 : 30;
                    await service.Operators(days < 0 ? "Son kullanma tarihi geçti" : "SKT yaklaşıyor", $"{batch.Product.Name} • {batch.BatchNumber} • {batch.ExpiryDate:dd.MM.yyyy}", $"expiry:{batch.Id}:{threshold}");
                }
                await db.SaveChangesAsync(stoppingToken);
                await tx.CommitAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception ex) { logger.LogError(ex, "SKT kontrolü başarısız"); }
        } while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
