using System.Security.Claims;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using Depo.Api.Authentication;
using Depo.Api.Data;
using Depo.Api.Helpers;
using Depo.Api.Models;
using Depo.Api.Repositories;
using Depo.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using Npgsql;
var builder = WebApplication.CreateBuilder(args);
builder.Configuration.AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: false).AddEnvironmentVariables();
var jwtKey = builder.Configuration["Jwt:Key"];
if (string.IsNullOrWhiteSpace(jwtKey) || Encoding.UTF8.GetByteCount(jwtKey) < 48) throw new InvalidOperationException("Jwt:Key en az 48 bayt olmalı. scripts/Start-Demo.ps1 ile yerel yapılandırma oluşturun.");
builder.Services.AddDbContext<DepoDbContext>(o => o.UseNpgsql(builder.Configuration.GetConnectionString("Database")));
builder.Services.AddIdentityCore<AppUser>(o => { o.User.RequireUniqueEmail = true; o.Password.RequiredLength = 10; o.Lockout.MaxFailedAccessAttempts = 5; o.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(5); }).AddRoles<IdentityRole<Guid>>().AddEntityFrameworkStores<DepoDbContext>();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<CurrentUser>();
builder.Services.AddScoped<ProductRepository>();
builder.Services.AddScoped<InventoryService>();
builder.Services.AddScoped<RequestService>();
builder.Services.AddScoped<NotificationService>();
builder.Services.AddHostedService<ExpiryWorker>();
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(o =>
{
    o.TokenValidationParameters = new TokenValidationParameters { ValidateIssuer = true, ValidateAudience = true, ValidateLifetime = true, ValidateIssuerSigningKey = true, ValidIssuer = builder.Configuration["Jwt:Issuer"], ValidAudience = builder.Configuration["Jwt:Audience"], IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)), ClockSkew = TimeSpan.FromSeconds(30) };
    o.Events = new JwtBearerEvents { OnTokenValidated = async ctx => { var db = ctx.HttpContext.RequestServices.GetRequiredService<DepoDbContext>(); var id = ctx.Principal?.FindFirstValue(ClaimTypes.NameIdentifier); var stamp = ctx.Principal?.FindFirstValue("stamp"); if (!Guid.TryParse(id, out var uid) || !await db.Users.AnyAsync(u => u.Id == uid && u.IsActive && u.SecurityStamp == stamp)) ctx.Fail("Oturum sona erdi."); } };
});
builder.Services.AddAuthorization();
var corsOrigins = builder.Configuration.GetSection("Cors:Origins").Get<string[]>() ?? [];
if (corsOrigins.Length > 0) builder.Services.AddCors(o => o.AddPolicy("configured-web", p => p.WithOrigins(corsOrigins).AllowAnyHeader().AllowAnyMethod()));
builder.Services.AddControllers().AddJsonOptions(o => o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.Configure<ApiBehaviorOptions>(o => o.InvalidModelStateResponseFactory = ctx => new BadRequestObjectResult(new { Title = "Form bilgileri geçersiz. Zorunlu alanları ve miktarları kontrol edin.", Errors = ctx.ModelState.Where(x => x.Value?.Errors.Count > 0).ToDictionary(x => x.Key, x => x.Value!.Errors.Select(e => e.ErrorMessage).ToArray()) }));
builder.Services.AddRateLimiter(o => { o.RejectionStatusCode = 429; o.AddPolicy("login", ctx => RateLimitPartition.GetFixedWindowLimiter(ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown", _ => new FixedWindowRateLimiterOptions { PermitLimit = 15, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 })); });
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(o =>
{
    o.SwaggerDoc("v1", new OpenApiInfo { Title = "Mobil Depo API", Version = "v1", Description = "Demo verilerle mobil stok ve talep yönetimi." });
    o.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme { Type = SecuritySchemeType.Http, Scheme = "bearer", BearerFormat = "JWT" });
    o.AddSecurityRequirement(document => new OpenApiSecurityRequirement { [new OpenApiSecuritySchemeReference("Bearer", document)] = [] });
});
var app = builder.Build();
app.Use(async (ctx, next) => { try { await next(); } catch (Exception ex) { var status = ex switch { ApiException e => e.Status, DbUpdateException { InnerException: PostgresException { SqlState: "23505" } } => 409, DbUpdateException => 400, PostgresException { SqlState: "40P01" or "40001" or "55P03" } => 409, _ => 500 }; var message = ex is ApiException a ? a.Message : status == 409 ? "Kayıt zaten mevcut veya eşzamanlı işlem oldu. Bilgileri yenileyip tekrar deneyin." : status == 400 ? "Kayıt ilişkileri veya alanlar geçersiz." : "İşlem tamamlanamadı. Lütfen tekrar deneyin."; if (status == 500) app.Logger.LogError(ex, "Beklenmeyen API hatası {Trace}", ctx.TraceIdentifier); ctx.Response.StatusCode = status; await ctx.Response.WriteAsJsonAsync(new { Title = message, Status = status, TraceId = ctx.TraceIdentifier }); } });
app.UseDefaultFiles();
app.UseStaticFiles(new StaticFileOptions { OnPrepareResponse = ctx => { if (ctx.File.Name is "index.html" or "flutter_bootstrap.js" or "main.dart.js") ctx.Context.Response.Headers.CacheControl = "no-cache"; } });
if (corsOrigins.Length > 0) app.UseCors("configured-web");
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
if (app.Environment.IsDevelopment()) { app.UseSwagger(); app.UseSwaggerUI(); }
app.MapControllers();
app.MapFallback("/api/{**path}", () => Results.NotFound(new { Title = "API endpointi bulunamadı." })).WithOrder(int.MaxValue - 1);
app.MapFallbackToFile("index.html");
app.MapGet("/health", async (DepoDbContext db) => await db.Database.CanConnectAsync() ? Results.Ok(new { Status = "healthy" }) : Results.StatusCode(503)).AllowAnonymous();
using (var scope = app.Services.CreateScope()) { var db = scope.ServiceProvider.GetRequiredService<DepoDbContext>(); await db.Database.MigrateAsync(); if (builder.Configuration.GetValue<bool>("Demo:Seed")) { if (!app.Environment.IsDevelopment()) throw new InvalidOperationException("Demo seed yalnızca Development ortamında çalışır."); await SeedData.Initialize(scope.ServiceProvider); } }
if (!args.Contains("--migrate-only")) await app.RunAsync();
public partial class Program;
