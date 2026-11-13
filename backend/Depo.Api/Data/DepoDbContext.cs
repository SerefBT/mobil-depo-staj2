using Depo.Api.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
namespace Depo.Api.Data;

public class DepoDbContext(DbContextOptions<DepoDbContext> options) : IdentityDbContext<AppUser, IdentityRole<Guid>, Guid>(options)
{
    public DbSet<Unit> Units => Set<Unit>(); public DbSet<Warehouse> Warehouses => Set<Warehouse>(); public DbSet<Aisle> Aisles => Set<Aisle>(); public DbSet<Shelf> Shelves => Set<Shelf>(); public DbSet<Category> Categories => Set<Category>();
    public DbSet<Product> Products => Set<Product>(); public DbSet<Stock> Stocks => Set<Stock>(); public DbSet<StockMovement> StockMovements => Set<StockMovement>(); public DbSet<MaterialRequest> Requests => Set<MaterialRequest>(); public DbSet<RequestItem> RequestItems => Set<RequestItem>();
    public DbSet<ProductBatch> ProductBatches => Set<ProductBatch>(); public DbSet<BatchAllocation> BatchAllocations => Set<BatchAllocation>(); public DbSet<Notification> Notifications => Set<Notification>();
    protected override void OnModelCreating(ModelBuilder b)
    {
        base.OnModelCreating(b);
        b.Entity<AppUser>().ToTable("Users");
        b.Entity<IdentityRole<Guid>>().ToTable("Roles");
        b.Entity<IdentityUserRole<Guid>>().ToTable("UserRoles");
        b.Entity<Unit>().HasIndex(x => x.Name).IsUnique();
        b.Entity<Category>().HasIndex(x => x.Name).IsUnique();
        b.Entity<Warehouse>().HasIndex(x => x.Code).IsUnique();
        b.Entity<Aisle>().HasIndex(x => new { x.WarehouseId, x.Name }).IsUnique();
        b.Entity<Shelf>().HasIndex(x => x.Code).IsUnique();
        b.Entity<Shelf>().HasIndex(x => x.QrValue).IsUnique();
        b.Entity<Product>().HasIndex(x => x.Barcode).IsUnique();
        b.Entity<Product>().HasIndex(x => x.ProductCode).IsUnique();
        b.Entity<Product>().HasIndex(x => x.Name);
        b.Entity<Product>().HasIndex(x => x.CreatedAt);
        b.Entity<Product>().HasOne(x => x.Stock).WithOne(x => x.Product).HasForeignKey<Stock>(x => x.ProductId);
        b.Entity<MaterialRequest>().HasIndex(x => new { x.Status, x.CreatedAt });
        b.Entity<MaterialRequest>().HasIndex(x => x.ClientId).IsUnique();
        b.Entity<RequestItem>().HasIndex(x => new { x.RequestId, x.ProductId }).IsUnique();
        b.Entity<StockMovement>().HasIndex(x => new { x.ProductId, x.CreatedAt });
        b.Entity<StockMovement>().HasIndex(x => x.CreatedAt);
        b.Entity<StockMovement>().HasIndex(x => x.OperationId).IsUnique();
        b.Entity<ProductBatch>().HasIndex(x => new { x.ProductId, x.BatchNumber }).IsUnique();
        b.Entity<ProductBatch>().HasIndex(x => x.ExpiryDate);
        b.Entity<Notification>().HasIndex(x => new { x.UserId, x.CreatedAt });
        b.Entity<Notification>().HasIndex(x => new { x.UserId, x.DedupKey }).IsUnique();
        b.Entity<Product>().ToTable(t => t.HasCheckConstraint("CK_Product_Minimum", "\"MinimumStock\" >= 0"));
        b.Entity<Stock>().ToTable(t => t.HasCheckConstraint("CK_Stock_NonNegative", "\"Quantity\" >= 0"));
        b.Entity<ProductBatch>().ToTable(t => t.HasCheckConstraint("CK_Batch_NonNegative", "\"Quantity\" >= 0"));
        b.Entity<RequestItem>().ToTable(t => t.HasCheckConstraint("CK_RequestItem_Positive", "\"Quantity\" > 0"));
        b.Entity<StockMovement>().ToTable(t => t.HasCheckConstraint("CK_Movement_Balance", "\"NextStock\" = \"PreviousStock\" + \"Quantity\" AND \"NextStock\" >= 0 AND \"Quantity\" <> 0"));
        foreach (var entity in b.Model.GetEntityTypes())
        {
            foreach (var fk in entity.GetForeignKeys())
                fk.DeleteBehavior = DeleteBehavior.Restrict;
            foreach (var prop in entity.GetProperties().Where(x => x.ClrType == typeof(string) && x.GetMaxLength() == null))
                prop.SetMaxLength(2000);
        }
    }
}
