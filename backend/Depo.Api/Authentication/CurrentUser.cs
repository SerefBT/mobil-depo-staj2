using System.Security.Claims;
using Depo.Api.Models;
namespace Depo.Api.Authentication;

public class CurrentUser(IHttpContextAccessor accessor)
{
    private ClaimsPrincipal User => accessor.HttpContext!.User;
    public Guid Id => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    public bool IsUnit => User.IsInRole(Roles.Unit);
}
