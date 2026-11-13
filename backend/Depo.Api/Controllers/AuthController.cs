using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Depo.Api.Authentication;
using Depo.Api.Data;
using Depo.Api.DTOs;
using Depo.Api.Helpers;
using Depo.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
namespace Depo.Api.Controllers;

[ApiController, Route("api/auth")]
public class AuthController(UserManager<AppUser> users, DepoDbContext db, IConfiguration config, CurrentUser current) : ControllerBase
{
    [HttpPost("login"), AllowAnonymous, EnableRateLimiting("login")]
    public async Task<object> Login(LoginDto dto)
    {
        var login = dto.Login.Trim();
        var user = await users.FindByEmailAsync(login) ?? await users.FindByNameAsync(login);
        if (user == null || !user.IsActive || await users.IsLockedOutAsync(user))
            throw new ApiException(401, "Kullanıcı adı veya şifre hatalı ya da hesap geçici olarak kilitli.");
        if (!await users.CheckPasswordAsync(user, dto.Password))
        {
            await users.AccessFailedAsync(user);
            throw new ApiException(401, "Kullanıcı adı veya şifre hatalı.");
        }
        await users.ResetAccessFailedCountAsync(user);
        var roles = await users.GetRolesAsync(user);
        var expires = DateTime.UtcNow.AddHours(8);
        var claims = new List<Claim> { new(ClaimTypes.NameIdentifier, user.Id.ToString()), new(ClaimTypes.Name, user.FullName), new("stamp", user.SecurityStamp ?? ""), new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()) };
        claims.AddRange(roles.Select(r => new Claim(ClaimTypes.Role, r)));
        var jwt = new JwtSecurityToken(config["Jwt:Issuer"], config["Jwt:Audience"], claims, expires: expires, signingCredentials: new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(config["Jwt:Key"]!)), SecurityAlgorithms.HmacSha256));
        return new
        {
            Token = new JwtSecurityTokenHandler().WriteToken(jwt),
            ExpiresAt = expires,
            User = await Profile(user, roles)
        };
    }
    private async Task<object> Profile(AppUser user, IList<string> roles) => new { user.Id, user.Email, user.FullName, user.UnitId, Unit = user.UnitId == null ? null : await db.Units.Where(x => x.Id == user.UnitId).Select(x => x.Name).SingleAsync(), Role = roles.FirstOrDefault() };
    [HttpGet("me"), Authorize]
    public async Task<object> Me()
    {
        var user = (await users.FindByIdAsync(current.Id.ToString()))!;
        return await Profile(user, await users.GetRolesAsync(user));
    }
    [HttpPost("logout"), Authorize]
    public async Task<IActionResult> Logout()
    {
        await users.UpdateSecurityStampAsync((await users.FindByIdAsync(current.Id.ToString()))!);
        return NoContent();
    }
    [HttpPut("password"), Authorize]
    public async Task<IActionResult> Password(ChangePasswordDto dto)
    {
        var result = await users.ChangePasswordAsync((await users.FindByIdAsync(current.Id.ToString()))!, dto.CurrentPassword, dto.NewPassword);
        if (!result.Succeeded)
            throw new ApiException(400, "Mevcut şifre hatalı veya yeni şifre kurallara uygun değil (10 karakter, büyük/küçük harf, rakam ve simge).");
        return NoContent();
    }
}
