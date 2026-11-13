using System.ComponentModel.DataAnnotations;
using Depo.Api.Models;
namespace Depo.Api.DTOs;

public record LoginDto([Required, MaxLength(256)] string Login, [Required, MaxLength(128)] string Password);
public record ProductDto([Required, StringLength(64, MinimumLength = 2)] string ProductCode, [Required, StringLength(128, MinimumLength = 2)] string Barcode, [Required, StringLength(160, MinimumLength = 2)] string Name, [MaxLength(2000)] string Description, [Range(1, int.MaxValue)] int CategoryId, [Required, MaxLength(32)] string MeasureUnit, [Range(0, 100000000)] int MinimumStock, [Range(1, int.MaxValue)] int ShelfId, bool IsActive = true);
public record StockDto([Range(1, int.MaxValue)] int ProductId, [Range(1, 10000000)] int Quantity, [Required, StringLength(1000, MinimumLength = 3)] string Description, Guid OperationId, int? ShelfId = null, [MaxLength(100)] string? BatchNumber = null, DateOnly? ExpiryDate = null, MovementType Type = MovementType.In, int? RequestId = null);
public record RequestLineDto([Range(1, int.MaxValue)] int ProductId, [Range(1, 10000000)] int Quantity);
public record CreateRequestDto(Guid ClientId, Priority Priority, [MaxLength(1000)] string Description, [Required, MinLength(1), MaxLength(100)] List<RequestLineDto> Items);
public record NameDto([Required, StringLength(100, MinimumLength = 2)] string Name);
public record WarehouseDto([Required, StringLength(100, MinimumLength = 2)] string Name, [Required, StringLength(32, MinimumLength = 1)] string Code);
public record AisleDto([Range(1, int.MaxValue)] int WarehouseId, [Required, StringLength(100, MinimumLength = 1)] string Name);
public record ShelfDto([Range(1, int.MaxValue)] int AisleId, [Required, StringLength(64, MinimumLength = 1)] string Code, [Required, StringLength(128, MinimumLength = 3)] string QrValue);
public record CreateUserDto([Required, EmailAddress, MaxLength(256)] string Email, [Required, StringLength(128, MinimumLength = 10)] string Password, [Required, StringLength(100, MinimumLength = 2)] string FullName, [Required] string Role, int? UnitId);
public record UpdateUserDto([Required, StringLength(100, MinimumLength = 2)] string FullName, [Required] string Role, int? UnitId, bool IsActive);
public record ChangePasswordDto([Required] string CurrentPassword, [Required, StringLength(128, MinimumLength = 10)] string NewPassword);
