using Depo.Api.Models;
using Depo.Api.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
namespace Depo.Api.Data;

public static class SeedData
{
    public static async Task Initialize(IServiceProvider services)
    {
        var db = services.GetRequiredService<DepoDbContext>();
        await using var tx = await db.Database.BeginTransactionAsync();
        await db.Database.ExecuteSqlRawAsync("SELECT pg_advisory_xact_lock(87654218)");
        if (await db.Users.AnyAsync())
        {
            await tx.CommitAsync();
            return;
        }
        var roles = services.GetRequiredService<RoleManager<IdentityRole<Guid>>>();
        var users = services.GetRequiredService<UserManager<AppUser>>();
        foreach (var role in Models.Roles.All)
            await roles.CreateAsync(new IdentityRole<Guid>(role));
        var units = new[] { "İdari Hizmetler", "Teknik Hizmetler", "Destek Hizmetleri", "Eğitim Birimi", "Satın Alma" }.Select(n => new Unit { Name = n }).ToArray();
        db.Units.AddRange(units);
        var categories = new[] { "Sarf Malzeme", "Temizlik", "Kırtasiye", "Teknik Malzeme", "Koruyucu Ekipman" }.Select(n => new Category { Name = n }).ToArray();
        db.Categories.AddRange(categories);
        var wh = new[] { new Warehouse { Name = "A Deposu", Code = "A" }, new Warehouse { Name = "B Deposu", Code = "B" } };
        db.Warehouses.AddRange(wh);
        await db.SaveChangesAsync();
        async Task<AppUser> User(string mail, string name, string role, string password, Unit? unit = null)
        {
            var u = new AppUser { UserName = mail, Email = mail, FullName = name, EmailConfirmed = true, UnitId = unit?.Id };
            var r = await users.CreateAsync(u, password);
            if (!r.Succeeded)
                throw new InvalidOperationException(string.Join(';', r.Errors.Select(e => e.Description)));
            await users.AddToRoleAsync(u, role);
            return u;
        }
        await User("admin@demo.local", "Demo Yönetici", Models.Roles.Admin, "Admin12345!");
        var staff = await User("depo@demo.local", "Demo Depo Personeli", Models.Roles.Warehouse, "Depo12345!");
        var unitUsers = new List<AppUser>();
        for (var i = 0; i < 5; i++)
            unitUsers.Add(await User(i == 0 ? "birim@demo.local" : $"birim{i + 1}@demo.local", $"Demo {units[i].Name}", Models.Roles.Unit, "Birim12345!", units[i]));
        var aisles = new[] { new Aisle { Warehouse = wh[0], Name = "Koridor 1" }, new Aisle { Warehouse = wh[0], Name = "Koridor 2" }, new Aisle { Warehouse = wh[1], Name = "Koridor 1" }, new Aisle { Warehouse = wh[1], Name = "Koridor 2" } };
        db.Aisles.AddRange(aisles);
        var shelfCodes = new[] { "A01", "A02", "A03", "B01", "B02", "B03", "B04", "C01", "C02", "C03", "D01", "D02" };
        var shelves = shelfCodes.Select((code, i) => { var a = i < 3 ? 0 : i < 7 ? 1 : i < 10 ? 2 : 3; return new Shelf { Code = code, Aisle = aisles[a], QrValue = $"DEPO-{(a < 2 ? "A" : "B")}-K{(a % 2) + 1}-{code}" }; }).ToArray();
        db.Shelves.AddRange(shelves);
        string[] names = ["Tek Kullanımlık Eldiven", "Cerrahi Maske", "El Dezenfektanı", "A4 Fotokopi Kağıdı", "Tükenmez Kalem", "Yüzey Temizleyici", "Kağıt Havlu", "Çöp Poşeti", "Koruyucu Gözlük", "FFP2 Maske", "Kablo Bağı", "Priz Çoklayıcı", "Paket Bandı", "Dosya Klasörü", "Etiket Rulosu", "Sıvı Sabun", "Mikrofiber Bez", "İş Eldiveni", "Pil AA", "LED Ampul"];
        int[] cats = [0, 4, 1, 2, 2, 1, 0, 1, 4, 4, 3, 3, 2, 2, 2, 1, 1, 4, 3, 3];
        var products = new List<Product>();
        var now = DateTime.UtcNow;
        for (var i = 0; i < 20; i++)
        {
            var qty = i % 5 == 0 ? 12 : 80 + i * 7;
            var p = new Product { Name = names[i], ProductCode = $"MLZ-{i + 1:000}", Barcode = $"8690000{i + 1:00000}", Description = "Staj projesi için oluşturulmuş örnek malzeme.", Category = categories[cats[i]], MeasureUnit = i < 2 ? "Kutu" : "Adet", MinimumStock = 30, Shelf = shelves[i % shelves.Length], Stock = new Stock { Quantity = qty }, CreatedAt = now.AddDays(-14), UpdatedAt = now };
            products.Add(p);
            db.Products.Add(p);
            var batch = new ProductBatch { Product = p, BatchNumber = $"DEMO-{i + 1:000}", Quantity = qty, ExpiryDate = i % 4 == 0 ? DateOnly.FromDateTime(now.AddDays(i == 0 ? 7 : i == 4 ? 15 : 30)) : null, CreatedAt = now.AddDays(-14) };
            db.ProductBatches.Add(batch);
            var incoming = new StockMovement { Product = p, Type = MovementType.In, Quantity = qty + 10, PreviousStock = 0, NextStock = qty + 10, UserId = staff.Id, Description = "Demo açılış sevkiyatı", CreatedAt = now.AddDays(-3), Allocations = [new BatchAllocation { ProductBatch = batch, Quantity = qty + 10 }] };
            var outgoing = new StockMovement { Product = p, Type = MovementType.Out, Quantity = -10, PreviousStock = qty + 10, NextStock = qty, UserId = staff.Id, Description = "Demo birim tüketimi", CreatedAt = now.AddHours(-2), Allocations = [new BatchAllocation { ProductBatch = batch, Quantity = -10 }] };
            db.StockMovements.AddRange(incoming, outgoing);
        }
        await db.SaveChangesAsync();
        var inventory = services.GetRequiredService<InventoryService>();
        for (var i = 0; i < 10; i++)
        {
            var r = new MaterialRequest { ClientId = Guid.NewGuid(), UnitId = units[i % 5].Id, UserId = unitUsers[i % 5].Id, Priority = i % 3 == 0 ? Priority.Urgent : Priority.Normal, Description = "Demo malzeme talebi", CreatedAt = now.AddHours(-i * 3), Status = i < 4 ? RequestStatus.Pending : i < 6 ? RequestStatus.Preparing : i < 8 ? RequestStatus.Approved : i == 8 ? RequestStatus.Delivered : RequestStatus.Cancelled, Items = [new RequestItem { Product = products[(i + 1) % 20], Quantity = 3 }, new RequestItem { Product = products[(i + 3) % 20], Quantity = 2 }] };
            db.Requests.Add(r);
            await db.SaveChangesAsync();
            if (r.Status == RequestStatus.Delivered)
                foreach (var item in r.Items.OrderBy(x => x.ProductId))
                {
                    await inventory.Lock(item.ProductId);
                    await inventory.Apply(item.ProductId, -item.Quantity, MovementType.Delivery, staff.Id, $"Talep #{r.Id} teslimi", r.Id);
                }
        }
        var notification = services.GetRequiredService<NotificationService>();
        foreach (var p in products.Where(p => p.Stock.Quantity < p.MinimumStock))
            await notification.Operators("Kritik stok", $"{p.Name}: {p.Stock.Quantity} / minimum {p.MinimumStock}");
        await db.SaveChangesAsync();
        await tx.CommitAsync();
    }
}
