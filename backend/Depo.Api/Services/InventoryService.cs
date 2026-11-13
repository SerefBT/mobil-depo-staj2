using Depo.Api.Data;
using Depo.Api.DTOs;
using Depo.Api.Helpers;
using Depo.Api.Models;
using Microsoft.EntityFrameworkCore;
namespace Depo.Api.Services;

public class InventoryService(DepoDbContext db, NotificationService notifications)
{
    public async Task<StockMovement> Change(StockDto dto, bool inbound, Guid userId)
    {
        if (dto.OperationId == Guid.Empty)
            throw new ApiException(400, "İşlem kimliği zorunludur.");
        if (dto.RequestId != null)
            throw new ApiException(400, "Talebe bağlı çıkış için talebin Teslim et işlemini kullanın.");
        var allowed = inbound ? new[] { MovementType.In, MovementType.Return, MovementType.Correction, MovementType.Count } : new[] { MovementType.Out, MovementType.Correction, MovementType.Count };
        if (!allowed.Contains(dto.Type))
            throw new ApiException(400, "Bu işlem için hareket türü geçersiz.");
        await using var tx = await db.Database.BeginTransactionAsync();
        await Lock(dto.ProductId);
        var existing = await db.StockMovements.SingleOrDefaultAsync(x => x.OperationId == dto.OperationId);
        if (existing != null)
        {
            if (existing.ProductId != dto.ProductId || existing.Quantity != (inbound ? dto.Quantity : -dto.Quantity) || existing.Type != dto.Type || existing.UserId != userId)
                throw new ApiException(409, "Bu işlem kimliği farklı bir işlemde kullanılmış.");
            await tx.CommitAsync();
            return existing;
        }
        var movement = await Apply(dto.ProductId, inbound ? dto.Quantity : -dto.Quantity, dto.Type, userId, dto.Description, null, dto.OperationId, dto.BatchNumber, dto.ExpiryDate, dto.ShelfId);
        await db.SaveChangesAsync();
        await tx.CommitAsync();
        return movement;
    }
    public async Task Lock(int productId)
    {
        var stock = await db.Stocks.FromSqlInterpolated($"SELECT * FROM \"Stocks\" WHERE \"ProductId\" = {productId} FOR UPDATE").SingleOrDefaultAsync();
        if (stock == null)
            throw new ApiException(404, "Ürün bulunamadı.");
    }
    // Caller owns a transaction and holds the product's Stock row lock.
    public async Task<StockMovement> Apply(int productId, int delta, MovementType type, Guid userId, string description, int? requestId = null, Guid? operationId = null, string? batchNumber = null, DateOnly? expiryDate = null, int? shelfId = null)
    {
        var product = await db.Products.Include(x => x.Stock).SingleAsync(x => x.Id == productId);
        if (!product.IsActive)
            throw new ApiException(409, "Pasif ürün üzerinde stok işlemi yapılamaz.");
        if (delta == 0 || Math.Abs((long)delta) > 10000000)
            throw new ApiException(400, "Miktar geçersiz.");
        var before = product.Stock.Quantity;
        if (delta < 0 && before < -delta)
            throw new ApiException(409, $"Yetersiz stok. Mevcut stok miktarı: {before}");
        if ((long)before + delta > 100000000)
            throw new ApiException(400, "Maksimum stok sınırı aşıldı.");
        var movement = new StockMovement { ProductId = productId, Quantity = delta, PreviousStock = before, NextStock = before + delta, Type = type, UserId = userId, Description = description, RequestId = requestId, OperationId = operationId };
        var today = DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById("Europe/Istanbul")));
        if (delta > 0)
        {
            if (expiryDate < today)
                throw new ApiException(400, "Son kullanma tarihi geçmiş parti kabul edilemez.");
            if (shelfId != null)
            {
                if (!await db.Shelves.AnyAsync(s => s.Id == shelfId))
                    throw new ApiException(400, "Raf bulunamadı.");
                if (shelfId != product.ShelfId && before > 0)
                    throw new ApiException(409, "Ürünün mevcut stoğu başka rafta. Önce ürün düzenleme ekranından tüm stoğun konumunu değiştirin.");
                product.ShelfId = shelfId.Value;
            }
            batchNumber = string.IsNullOrWhiteSpace(batchNumber) ? $"GIR-{Guid.NewGuid():N}" : batchNumber.Trim();
            var batch = await db.ProductBatches.SingleOrDefaultAsync(x => x.ProductId == productId && x.BatchNumber == batchNumber);
            if (batch == null)
            {
                batch = new ProductBatch { ProductId = productId, BatchNumber = batchNumber, ExpiryDate = expiryDate };
                db.ProductBatches.Add(batch);
            }
            else if (batch.ExpiryDate != expiryDate)
                throw new ApiException(409, "Aynı partinin son kullanma tarihi farklı olamaz.");
            batch.Quantity += delta;
            movement.Allocations.Add(new BatchAllocation { ProductBatch = batch, Quantity = delta });
        }
        else
        {
            var includeExpired = type == MovementType.Correction || type == MovementType.Count;
            var batches = await db.ProductBatches.Where(x => x.ProductId == productId && x.Quantity > 0 && (includeExpired || x.ExpiryDate == null || x.ExpiryDate >= today)).OrderBy(x => x.ExpiryDate == null).ThenBy(x => x.ExpiryDate).ThenBy(x => x.CreatedAt).ThenBy(x => x.Id).ToListAsync();
            var available = batches.Sum(x => (long)x.Quantity);
            if (available < -delta)
                throw new ApiException(409, $"Kullanılabilir stok yetersiz: {available}. SKT geçen partiler teslim edilemez.");
            var remaining = -delta;
            foreach (var batch in batches)
            {
                var take = Math.Min(remaining, batch.Quantity);
                batch.Quantity -= take;
                remaining -= take;
                movement.Allocations.Add(new BatchAllocation { ProductBatch = batch, Quantity = -take });
                if (remaining == 0)
                    break;
            }
        }
        product.Stock.Quantity += delta;
        product.UpdatedAt = DateTime.UtcNow;
        db.StockMovements.Add(movement);
        if (before >= product.MinimumStock && product.Stock.Quantity < product.MinimumStock)
            await notifications.Operators("Kritik stok", $"{product.Name}: {product.Stock.Quantity} {product.MeasureUnit} / minimum {product.MinimumStock}");
        return movement;
    }
}
