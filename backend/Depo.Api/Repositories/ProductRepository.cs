using Depo.Api.Data;
using Depo.Api.Models;
using Microsoft.EntityFrameworkCore;
namespace Depo.Api.Repositories;

public class ProductRepository(DepoDbContext db)
{
    public IQueryable<Product> Query => db.Products.AsNoTracking();
    public static IQueryable<object> Project(IQueryable<Product> q) => q.Select(p => new
    {
        p.Id,
        p.ProductCode,
        p.Barcode,
        p.Name,
        p.Description,
        p.CategoryId,
        Category = p.Category.Name,
        p.MeasureUnit,
        p.MinimumStock,
        Quantity = p.Stock.Quantity,
        IsCritical = p.Stock.Quantity < p.MinimumStock,
        p.ShelfId,
        Shelf = p.Shelf.Code,
        QrValue = p.Shelf.QrValue,
        AisleId = p.Shelf.AisleId,
        Aisle = p.Shelf.Aisle.Name,
        WarehouseId = p.Shelf.Aisle.WarehouseId,
        Warehouse = p.Shelf.Aisle.Warehouse.Name,
        p.IsActive,
        p.CreatedAt,
        p.UpdatedAt
    });
}
