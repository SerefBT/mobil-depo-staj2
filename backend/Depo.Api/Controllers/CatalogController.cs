using Depo.Api.Data;
using Depo.Api.DTOs;
using Depo.Api.Helpers;
using Depo.Api.Models;
using Depo.Api.Repositories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
namespace Depo.Api.Controllers;

[ApiController, Route("api"), Authorize]
public class CatalogController(DepoDbContext db) : ControllerBase
{
    [HttpGet("units")] public async Task<object> Units() => await db.Units.AsNoTracking().OrderBy(x => x.Name).ToListAsync();
    [HttpGet("categories")] public async Task<object> Categories() => await db.Categories.AsNoTracking().OrderBy(x => x.Name).ToListAsync();
    [HttpGet("warehouses")] public async Task<object> Warehouses() => await db.Warehouses.AsNoTracking().OrderBy(x => x.Code).Select(x => new { x.Id, x.Name, x.Code, AisleCount = db.Aisles.Count(a => a.WarehouseId == x.Id), ProductCount = db.Products.Count(p => p.Shelf.Aisle.WarehouseId == x.Id) }).ToListAsync();
    [HttpGet("aisles")] public async Task<object> Aisles(int? warehouseId) => await db.Aisles.AsNoTracking().Where(x => warehouseId == null || x.WarehouseId == warehouseId).OrderBy(x => x.Name).Select(x => new { x.Id, x.Name, x.WarehouseId, Warehouse = x.Warehouse.Name }).ToListAsync();
    [HttpGet("shelves")] public async Task<object> Shelves(int? warehouseId, int? aisleId) => await db.Shelves.AsNoTracking().Where(x => (warehouseId == null || x.Aisle.WarehouseId == warehouseId) && (aisleId == null || x.AisleId == aisleId)).OrderBy(x => x.Code).Select(x => new { x.Id, x.Code, x.QrValue, x.AisleId, Aisle = x.Aisle.Name, WarehouseId = x.Aisle.WarehouseId, Warehouse = x.Aisle.Warehouse.Name, ProductCount = db.Products.Count(p => p.ShelfId == x.Id) }).ToListAsync();
    [HttpGet("shelves/{id:int}/products")] public async Task<object> ShelfProducts(int id) => await ProductRepository.Project(db.Products.AsNoTracking().Where(x => x.ShelfId == id && x.IsActive).OrderBy(x => x.Name)).ToListAsync();
    [HttpGet("shelves/qr/{value}")] public async Task<object> Resolve(string value) => await db.Shelves.AsNoTracking().Where(x => x.QrValue == value).Select(x => new { x.Id, x.Code, x.QrValue, Aisle = x.Aisle.Name, Warehouse = x.Aisle.Warehouse.Name }).SingleOrDefaultAsync() ?? throw new ApiException(404, "Raf QR kodu bulunamadı.");
    [HttpPost("units"), Authorize(Roles = Roles.Admin)]
    public async Task<object> AddUnit(NameDto d)
    {
        var x = new Unit { Name = d.Name.Trim() };
        db.Units.Add(x);
        await db.SaveChangesAsync();
        return x;
    }
    [HttpPost("categories"), Authorize(Roles = Roles.Admin)]
    public async Task<object> AddCategory(NameDto d)
    {
        var x = new Category { Name = d.Name.Trim() };
        db.Categories.Add(x);
        await db.SaveChangesAsync();
        return x;
    }
    [HttpPost("warehouses"), Authorize(Roles = Roles.Admin)]
    public async Task<object> AddWarehouse(WarehouseDto d)
    {
        var x = new Warehouse { Name = d.Name.Trim(), Code = d.Code.Trim().ToUpperInvariant() };
        db.Warehouses.Add(x);
        await db.SaveChangesAsync();
        return new
        {
            x.Id,
            x.Name,
            x.Code
        };
    }
    [HttpPost("aisles"), Authorize(Roles = Roles.Admin)]
    public async Task<object> AddAisle(AisleDto d)
    {
        if (!await db.Warehouses.AnyAsync(x => x.Id == d.WarehouseId))
            throw new ApiException(400, "Depo bulunamadı.");
        var a = new Aisle { Name = d.Name.Trim(), WarehouseId = d.WarehouseId };
        db.Aisles.Add(a);
        await db.SaveChangesAsync();
        return new
        {
            a.Id,
            a.Name,
            a.WarehouseId
        };
    }
    [HttpPost("shelves"), Authorize(Roles = Roles.Admin)]
    public async Task<object> AddShelf(ShelfDto d)
    {
        if (!await db.Aisles.AnyAsync(x => x.Id == d.AisleId))
            throw new ApiException(400, "Koridor bulunamadı.");
        var s = new Shelf { AisleId = d.AisleId, Code = d.Code.Trim(), QrValue = d.QrValue.Trim() };
        db.Shelves.Add(s);
        await db.SaveChangesAsync();
        return new
        {
            s.Id,
            s.AisleId,
            s.Code,
            s.QrValue
        };
    }
}
