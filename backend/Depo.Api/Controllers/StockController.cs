using Depo.Api.Authentication;
using Depo.Api.Data;
using Depo.Api.DTOs;
using Depo.Api.Models;
using Depo.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
namespace Depo.Api.Controllers;

[ApiController, Route("api/stock"), Authorize(Roles = Roles.Operators)]
public class StockController(InventoryService inventory, CurrentUser current, DepoDbContext db) : ControllerBase
{
    [HttpPost("in")]
    public async Task<object> In(StockDto dto)
    {
        var m = await inventory.Change(dto, true, current.Id);
        return new
        {
            m.Id,
            m.ProductId,
            m.Quantity,
            m.PreviousStock,
            m.NextStock
        };
    }
    [HttpPost("out")]
    public async Task<object> Out(StockDto dto)
    {
        var m = await inventory.Change(dto, false, current.Id);
        return new
        {
            m.Id,
            m.ProductId,
            m.Quantity,
            m.PreviousStock,
            m.NextStock
        };
    }
    [HttpGet("movements/{productId:int}")]
    public async Task<object> Movements(int productId, int page = 1, int pageSize = 50)
    {
        var q = db.StockMovements.AsNoTracking().Where(x => x.ProductId == productId);
        return new
        {
            Total = await q.CountAsync(),
            Items = await q.OrderByDescending(x => x.Id).Skip((Math.Clamp(page, 1, 1000000) - 1) * Math.Clamp(pageSize, 1, 100)).Take(Math.Clamp(pageSize, 1, 100)).Select(x => new { x.Id, x.ProductId, Product = x.Product.Name, x.Type, x.Quantity, x.PreviousStock, x.NextStock, User = x.User.FullName, x.CreatedAt, x.Description, x.RequestId, Allocations = x.Allocations.Select(a => new { a.ProductBatchId, a.ProductBatch.BatchNumber, a.Quantity }) }).ToListAsync()
        };
    }
}
