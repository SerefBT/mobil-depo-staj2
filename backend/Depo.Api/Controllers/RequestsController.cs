using Depo.Api.DTOs;
using Depo.Api.Helpers;
using Depo.Api.Models;
using Depo.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
namespace Depo.Api.Controllers;

[ApiController, Route("api/requests"), Authorize]
public class RequestsController(RequestService service) : ControllerBase
{
    [HttpGet]
    public async Task<object> List(RequestStatus? status, Priority? priority, int? unitId, int page = 1, int pageSize = 40)
    {
        var q = service.Visible.AsNoTracking();
        if (status != null)
            q = q.Where(x => x.Status == status);
        if (priority != null)
            q = q.Where(x => x.Priority == priority);
        if (unitId != null)
            q = q.Where(x => x.UnitId == unitId);
        return new
        {
            Total = await q.CountAsync(),
            Items = await RequestService.Project(q.OrderByDescending(x => x.CreatedAt).Skip((Math.Clamp(page, 1, 1000000) - 1) * Math.Clamp(pageSize, 1, 100)).Take(Math.Clamp(pageSize, 1, 100))).ToListAsync()
        };
    }
    [HttpGet("{id:int}")] public async Task<object> Get(int id) => await RequestService.Project(service.Visible.AsNoTracking().Where(x => x.Id == id)).SingleOrDefaultAsync() ?? throw new ApiException(404, "Talep bulunamadı.");
    [HttpPost, Authorize(Roles = Roles.Unit)]
    public async Task<IActionResult> Create(CreateRequestDto dto)
    {
        var id = await service.Create(dto);
        return CreatedAtAction(nameof(Get), new
        {
            id
        }, await Get(id));
    }
    [HttpPut("{id:int}/approve"), Authorize(Roles = Roles.Operators)]
    public async Task<IActionResult> Approve(int id)
    {
        await service.Transition(id, "approve");
        return NoContent();
    }
    [HttpPut("{id:int}/prepare"), Authorize(Roles = Roles.Operators)]
    public async Task<IActionResult> Prepare(int id)
    {
        await service.Transition(id, "prepare");
        return NoContent();
    }
    [HttpPut("{id:int}/deliver"), Authorize(Roles = Roles.Operators)]
    public async Task<IActionResult> Deliver(int id)
    {
        await service.Transition(id, "deliver");
        return NoContent();
    }
    [HttpPut("{id:int}/cancel")]
    public async Task<IActionResult> Cancel(int id)
    {
        await service.Transition(id, "cancel");
        return NoContent();
    }
}
