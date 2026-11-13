using Microsoft.AspNetCore.Identity;
namespace Depo.Api.Models;

public static class Roles
{
    public const string Admin = "Admin", Warehouse = "Warehouse", Unit = "Unit", Operators = Admin + "," + Warehouse;
    public static readonly string[] All = [Admin, Warehouse, Unit];
}
public enum RequestStatus
{
    Pending, Approved, Preparing, Delivered, Cancelled
}
public enum Priority
{
    Normal, Urgent
}
public enum MovementType
{
    In, Out, Delivery, Correction, Return, Count
}
public class AppUser : IdentityUser<Guid>
{
    public string FullName { get; set; } = ""; public int? UnitId
    {
        get; set;
    }
    public Unit? Unit
    {
        get; set;
    }
    public bool IsActive { get; set; } = true;
}
public class Unit
{
    public int Id
    {
        get; set;
    }
    public string Name { get; set; } = "";
}
public class Warehouse
{
    public int Id
    {
        get; set;
    }
    public string Name { get; set; } = ""; public string Code { get; set; } = "";
}
public class Aisle
{
    public int Id
    {
        get; set;
    }
    public int WarehouseId
    {
        get; set;
    }
    public Warehouse Warehouse { get; set; } = null!; public string Name { get; set; } = "";
}
public class Shelf
{
    public int Id
    {
        get; set;
    }
    public int AisleId
    {
        get; set;
    }
    public Aisle Aisle { get; set; } = null!; public string Code { get; set; } = ""; public string QrValue { get; set; } = "";
}
public class Category
{
    public int Id
    {
        get; set;
    }
    public string Name { get; set; } = "";
}
public class Product
{
    public int Id
    {
        get; set;
    }
    public string ProductCode { get; set; } = ""; public string Barcode { get; set; } = ""; public string Name { get; set; } = ""; public string Description { get; set; } = "";
    public int CategoryId
    {
        get; set;
    }
    public Category Category { get; set; } = null!; public string MeasureUnit { get; set; } = "Adet"; public int MinimumStock
    {
        get; set;
    }
    public int ShelfId
    {
        get; set;
    }
    public Shelf Shelf { get; set; } = null!; public Stock Stock { get; set; } = null!; public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow; public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
public class Stock
{
    public int Id
    {
        get; set;
    }
    public int ProductId
    {
        get; set;
    }
    public Product Product { get; set; } = null!; public int Quantity
    {
        get; set;
    }
}
public class StockMovement
{
    public long Id
    {
        get; set;
    }
    public int ProductId
    {
        get; set;
    }
    public Product Product { get; set; } = null!; public MovementType Type
    {
        get; set;
    }
    public int Quantity
    {
        get; set;
    }
    public int PreviousStock
    {
        get; set;
    }
    public int NextStock
    {
        get; set;
    }
    public Guid UserId
    {
        get; set;
    }
    public AppUser User { get; set; } = null!;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow; public string Description { get; set; } = ""; public int? RequestId
    {
        get; set;
    }
    public MaterialRequest? Request
    {
        get; set;
    }
    public Guid? OperationId
    {
        get; set;
    }
    public List<BatchAllocation> Allocations { get; set; } = [];
}
public class MaterialRequest
{
    public int Id
    {
        get; set;
    }
    public Guid ClientId
    {
        get; set;
    }
    public int UnitId
    {
        get; set;
    }
    public Unit Unit { get; set; } = null!; public Guid UserId
    {
        get; set;
    }
    public AppUser User { get; set; } = null!;
    public Priority Priority
    {
        get; set;
    }
    public RequestStatus Status { get; set; } = RequestStatus.Pending; public string Description { get; set; } = "";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow; public DateTime UpdatedAt { get; set; } = DateTime.UtcNow; public List<RequestItem> Items { get; set; } = [];
}
public class RequestItem
{
    public int Id
    {
        get; set;
    }
    public int RequestId
    {
        get; set;
    }
    public MaterialRequest Request { get; set; } = null!; public int ProductId
    {
        get; set;
    }
    public Product Product { get; set; } = null!; public int Quantity
    {
        get; set;
    }
}
public class ProductBatch
{
    public int Id
    {
        get; set;
    }
    public int ProductId
    {
        get; set;
    }
    public Product Product { get; set; } = null!; public string BatchNumber { get; set; } = ""; public int Quantity
    {
        get; set;
    }
    public DateOnly? ExpiryDate
    {
        get; set;
    }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
public class BatchAllocation
{
    public long Id
    {
        get; set;
    }
    public long StockMovementId
    {
        get; set;
    }
    public StockMovement StockMovement { get; set; } = null!; public int ProductBatchId
    {
        get; set;
    }
    public ProductBatch ProductBatch { get; set; } = null!; public int Quantity
    {
        get; set;
    }
}
public class Notification
{
    public long Id
    {
        get; set;
    }
    public Guid UserId
    {
        get; set;
    }
    public AppUser User { get; set; } = null!; public string Title { get; set; } = ""; public string Message { get; set; } = ""; public string? DedupKey
    {
        get; set;
    }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow; public bool IsRead
    {
        get; set;
    }
}
