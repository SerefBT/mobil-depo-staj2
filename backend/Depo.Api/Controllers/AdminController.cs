using Depo.Api.Authentication;
using Depo.Api.Data;
using Depo.Api.DTOs;
using Depo.Api.Helpers;
using Depo.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
namespace Depo.Api.Controllers;

[ApiController, Route("api/admin"), Authorize(Roles = Roles.Admin)]
public class AdminController(DepoDbContext db, UserManager<AppUser> users, CurrentUser current) : ControllerBase
{
    [HttpGet("roles")] public object GetRoles() => Roles.All;
    [HttpGet("users")]
    public async Task<object> List()
    {
        var result = new List<object>();
        foreach (var u in await db.Users.AsNoTracking().Include(x => x.Unit).OrderBy(x => x.FullName).ToListAsync())
            result.Add(new
            {
                u.Id,
                u.Email,
                u.FullName,
                u.UnitId,
                Unit = u.Unit?.Name,
                u.IsActive,
                Role = (await users.GetRolesAsync(u)).FirstOrDefault()
            });
        return result;
    }
    private async Task Validate(string role, int? unitId)
    {
        if (!Roles.All.Contains(role))
            throw new ApiException(400, "Rol geçersiz.");
        if (role == Roles.Unit && unitId == null)
            throw new ApiException(400, "Birim yetkilisi için birim seçin.");
        if (unitId != null && !await db.Units.AnyAsync(x => x.Id == unitId))
            throw new ApiException(400, "Birim bulunamadı.");
    }
    [HttpPost("users")]
    public async Task<object> Create(CreateUserDto d)
    {
        await Validate(d.Role, d.UnitId);
        await using var tx = await db.Database.BeginTransactionAsync();
        var u = new AppUser { UserName = d.Email, Email = d.Email, FullName = d.FullName, UnitId = d.UnitId, EmailConfirmed = true };
        var result = await users.CreateAsync(u, d.Password);
        if (!result.Succeeded)
            throw new ApiException(400, "Kullanıcı oluşturulamadı. E-posta benzersiz olmalı; şifre en az 10 karakter, büyük/küçük harf, rakam ve simge içermeli.");
        var role = await users.AddToRoleAsync(u, d.Role);
        if (!role.Succeeded)
            throw new ApiException(400, "Rol atanamadı.");
        await tx.CommitAsync();
        return new
        {
            u.Id,
            u.Email,
            u.FullName
        };
    }
    [HttpPut("users/{id:guid}")]
    public async Task<IActionResult> Update(Guid id, UpdateUserDto d)
    {
        await Validate(d.Role, d.UnitId);
        if (id == current.Id && (!d.IsActive || d.Role != Roles.Admin))
            throw new ApiException(400, "Kendi yönetici yetkinizi kaldıramaz veya hesabınızı pasifleştiremezsiniz.");
        await using var tx = await db.Database.BeginTransactionAsync();
        var u = await users.FindByIdAsync(id.ToString()) ?? throw new ApiException(404, "Kullanıcı bulunamadı.");
        u.FullName = d.FullName;
        u.UnitId = d.UnitId;
        u.IsActive = d.IsActive;
        var result = await users.UpdateAsync(u);
        if (!result.Succeeded)
            throw new ApiException(400, "Kullanıcı güncellenemedi.");
        await users.RemoveFromRolesAsync(u, await users.GetRolesAsync(u));
        await users.AddToRoleAsync(u, d.Role);
        await users.UpdateSecurityStampAsync(u);
        await tx.CommitAsync();
        return NoContent();
    }
}
