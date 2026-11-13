using Depo.Api.Data;
using Depo.Api.DTOs;
using Depo.Api.Helpers;
using Depo.Api.Models;
using Depo.Api.Repositories;
using Depo.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
namespace Depo.Api.Controllers;

[ApiController, Route("api/products"), Authorize]
public class ProductsController(DepoDbContext db, ProductRepository repository, NotificationService notifications, InventoryService inventory) : ControllerBase
{
    [HttpGet]
    public async Task<object> List(string? search, int? categoryId, int? warehouseId, int? shelfId, bool critical = false, bool outOfStock = false, bool includeInactive = false, int page = 1, int pageSize = 40)
    {
        var q = repository.Query;
        if (!includeInactive || User.IsInRole(Roles.Unit))
            q = q.Where(x => x.IsActive);
        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = "%" + search.Trim().Replace("%", "\\%").Replace("_", "\\_") + "%";
            q = q.Where(x => EF.Functions.ILike(x.Name, s) || EF.Functions.ILike(x.ProductCode, s) || EF.Functions.ILike(x.Barcode, s) || EF.Functions.ILike(x.Category.Name, s) || EF.Functions.ILike(x.Shelf.Code, s) || EF.Functions.ILike(x.Shelf.Aisle.Warehouse.Name, s));
        }
        if (categoryId != null)
            q = q.Where(x => x.CategoryId == categoryId);
        if (warehouseId != null)
            q = q.Where(x => x.Shelf.Aisle.WarehouseId == warehouseId);
        if (shelfId != null)
            q = q.Where(x => x.ShelfId == shelfId);
        if (critical)
            q = q.Where(x => x.Stock.Quantity < x.MinimumStock);
        if (outOfStock)
            q = q.Where(x => x.Stock.Quantity == 0);
        page = Math.Clamp(page, 1, 1000000);
        pageSize = Math.Clamp(pageSize, 1, 100);
        return new
        {
            Total = await q.CountAsync(),
            Page = page,
            PageSize = pageSize,
            Items = await ProductRepository.Project(q.OrderBy(x => x.Name).Skip((page - 1) * pageSize).Take(pageSize)).ToListAsync()
        };
    }
    [HttpGet("{id:int}")] public async Task<object> Get(int id) => await ProductRepository.Project(repository.Query.Where(x => x.Id == id)).SingleOrDefaultAsync() ?? throw new ApiException(404, "Ürün bulunamadı.");
    [HttpGet("barcode/{barcode}")] public async Task<object> Barcode(string barcode) => await ProductRepository.Project(repository.Query.Where(x => x.Barcode == barcode || x.ProductCode == barcode)).FirstOrDefaultAsync() ?? throw new ApiException(404, "Bu barkoda ait ürün bulunamadı.");
    [HttpGet("{id:int}/batches")] public async Task<object> Batches(int id) => await db.ProductBatches.AsNoTracking().Where(x => x.ProductId == id).OrderBy(x => x.ExpiryDate == null).ThenBy(x => x.ExpiryDate).ThenBy(x => x.Id).Select(x => new { x.Id, x.BatchNumber, x.Quantity, x.ExpiryDate, x.CreatedAt }).ToListAsync();
    [HttpPost, Authorize(Roles = Roles.Operators)]
    public async Task<IActionResult> Create(ProductDto dto)
    {
        await Validate(dto);
        var p = new Product();
        Assign(p, dto);
        p.Stock = new Stock();
        db.Products.Add(p);
        await using var tx = await db.Database.BeginTransactionAsync();
        await db.SaveChangesAsync();
        if (p.IsActive && p.MinimumStock > 0)
            await notifications.Operators("Kritik stok", $"{p.Name}: 0 / minimum {p.MinimumStock}");
        await db.SaveChangesAsync();
        await tx.CommitAsync();
        return CreatedAtAction(nameof(Get), new
        {
            id = p.Id
        }, await Get(p.Id));
    }
    [HttpPut("{id:int}"), Authorize(Roles = Roles.Operators)]
    public async Task<object> Update(int id, ProductDto dto)
    {
        await Validate(dto);
        await using var tx = await db.Database.BeginTransactionAsync();
        await inventory.Lock(id);
        var p = await db.Products.Include(x => x.Stock).SingleOrDefaultAsync(x => x.Id == id) ?? throw new ApiException(404, "Ürün bulunamadı.");
        var wasCritical = p.IsActive && p.Stock.Quantity < p.MinimumStock;
        Assign(p, dto);
        p.UpdatedAt = DateTime.UtcNow;
        if (!wasCritical && p.IsActive && p.Stock.Quantity < p.MinimumStock)
            await notifications.Operators("Kritik stok", $"{p.Name}: {p.Stock.Quantity} / minimum {p.MinimumStock}");
        await db.SaveChangesAsync();
        await tx.CommitAsync();
        return await Get(id);
    }
    private async Task Validate(ProductDto dto)
    {
        if (!await db.Categories.AnyAsync(x => x.Id == dto.CategoryId) || !await db.Shelves.AnyAsync(x => x.Id == dto.ShelfId))
            throw new ApiException(400, "Kategori veya raf geçersiz.");
    }
    private static void Assign(Product p, ProductDto d)
    {
        p.ProductCode = d.ProductCode.Trim();
        p.Barcode = d.Barcode.Trim();
        p.Name = d.Name.Trim();
        p.Description = d.Description;
        p.CategoryId = d.CategoryId;
        p.MeasureUnit = d.MeasureUnit.Trim();
        p.MinimumStock = d.MinimumStock;
        p.ShelfId = d.ShelfId;
        p.IsActive = d.IsActive;
    }
}
