using Depo.Api.Authentication;
using Depo.Api.Data;
using Depo.Api.DTOs;
using Depo.Api.Helpers;
using Depo.Api.Models;
using Microsoft.EntityFrameworkCore;
namespace Depo.Api.Services;

public class RequestService(DepoDbContext db, CurrentUser current, InventoryService inventory, NotificationService notifications)
{
    public IQueryable<MaterialRequest> Visible => current.IsUnit ? db.Requests.Where(x => x.UserId == current.Id) : db.Requests;
    public static IQueryable<object> Project(IQueryable<MaterialRequest> q) => q.Select(r => new
    {
        r.Id,
        r.UnitId,
        Unit = r.Unit.Name,
        r.UserId,
        User = r.User.FullName,
        r.Priority,
        r.Status,
        r.Description,
        r.CreatedAt,
        r.UpdatedAt,
        Items = r.Items.Select(i => new { i.Id, i.ProductId, Product = i.Product.Name, i.Product.MeasureUnit, i.Quantity, Available = i.Product.Stock.Quantity, Shelf = i.Product.Shelf.Code })
    });
    public async Task<int> Create(CreateRequestDto dto)
    {
        if (dto.ClientId == Guid.Empty || !Enum.IsDefined(dto.Priority))
            throw new ApiException(400, "Talep kimliği veya öncelik geçersiz.");
        if (dto.Items.Count != dto.Items.Select(x => x.ProductId).Distinct().Count())
            throw new ApiException(400, "Aynı ürün bir talepte bir kez seçilebilir.");
        var previous = await db.Requests.SingleOrDefaultAsync(x => x.ClientId == dto.ClientId);
        if (previous != null)
        {
            if (previous.UserId != current.Id)
                throw new ApiException(409, "Talep kimliği kullanımda.");
            return previous.Id;
        }
        var user = await db.Users.SingleAsync(x => x.Id == current.Id);
        if (user.UnitId == null)
            throw new ApiException(400, "Talep oluşturmak için birime atanmalısınız.");
        var ids = dto.Items.Select(x => x.ProductId).ToArray();
        if (await db.Products.CountAsync(x => ids.Contains(x.Id) && x.IsActive) != ids.Length)
            throw new ApiException(400, "Ürünlerden biri bulunamadı veya pasif.");
        await using var tx = await db.Database.BeginTransactionAsync();
        var request = new MaterialRequest { ClientId = dto.ClientId, UnitId = user.UnitId.Value, UserId = current.Id, Priority = dto.Priority, Description = dto.Description, Items = dto.Items.Select(x => new RequestItem { ProductId = x.ProductId, Quantity = x.Quantity }).ToList() };
        db.Requests.Add(request);
        await db.SaveChangesAsync();
        await notifications.Operators("Yeni malzeme talebi", $"Talep #{request.Id} • {dto.Items.Count} ürün • {(dto.Priority == Priority.Urgent ? "Acil" : "Normal")}");
        await db.SaveChangesAsync();
        await tx.CommitAsync();
        return request.Id;
    }
    public async Task Transition(int id, string action)
    {
        await using var tx = await db.Database.BeginTransactionAsync();
        var r = await db.Requests.FromSqlInterpolated($"SELECT * FROM \"Requests\" WHERE \"Id\" = {id} FOR UPDATE").SingleOrDefaultAsync() ?? throw new ApiException(404, "Talep bulunamadı.");
        if (current.IsUnit && (r.UserId != current.Id || action != "cancel"))
            throw new ApiException(403, "Bu talep üzerinde yetkiniz yok.");
        if (r.Status is RequestStatus.Delivered or RequestStatus.Cancelled)
            throw new ApiException(409, "Tamamlanmış talep tekrar işleme alınamaz.");
        var next = action switch
        {
            "approve" when r.Status == RequestStatus.Pending => RequestStatus.Approved,
            "prepare" when r.Status is RequestStatus.Pending or RequestStatus.Approved => RequestStatus.Preparing,
            "deliver" when r.Status == RequestStatus.Preparing => RequestStatus.Delivered,
            "cancel" when !current.IsUnit || r.Status == RequestStatus.Pending => RequestStatus.Cancelled,
            _ => throw new ApiException(409, "Talebin mevcut durumu bu işlem için uygun değil.")
        };
        if (next == RequestStatus.Delivered)
        {
            var items = await db.RequestItems.Where(x => x.RequestId == id).OrderBy(x => x.ProductId).ToListAsync();
            foreach (var item in items)
            {
                await inventory.Lock(item.ProductId);
                await inventory.Apply(item.ProductId, -item.Quantity, MovementType.Delivery, current.Id, $"Talep #{id} teslimi", id);
            }
        }
        r.Status = next;
        r.UpdatedAt = DateTime.UtcNow;
        var label = next switch
        {
            RequestStatus.Approved => "onaylandı",
            RequestStatus.Preparing => "hazırlanıyor",
            RequestStatus.Delivered => "teslim edildi",
            _ => "iptal edildi"
        };
        await notifications.Send(r.UserId, $"Talep {label}", $"#{id} numaralı talebiniz {label}.");
        await db.SaveChangesAsync();
        await tx.CommitAsync();
    }
}
