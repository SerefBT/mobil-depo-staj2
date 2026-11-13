# API dokümantasyonu

Taban adres: `http://127.0.0.1:5080/api`. JSON alanları camelCase; enum değerleri İngilizce sabit adlardır. Türkçe etiketleri mobil uygulama gösterir. Canlı Swagger `/swagger`, dışa aktarılmış şema [openapi.json](openapi.json) dosyasındadır.

Giriş dışındaki `/api` endpointleri `Authorization: Bearer TOKEN` gerektirir. Yönetici: `Admin`; depo personeli: `Warehouse`; birim yetkilisi: `Unit`. Operator aşağıda Admin veya Warehouse anlamına gelir.

## Yetki özeti

- Ürün/depo/raf/kategori okuma: giriş yapan herkes.
- Ürün oluşturma/düzenleme, stok, teslim ve genel raporlar: Operator.
- Kullanıcı ve yapısal kayıt oluşturma: Admin.
- Talep oluşturma: Unit; birim ve kullanıcı kimliği sunucudaki oturumdan alınır.
- Unit, talep listesi ve detayında yalnızca kendi kayıtlarına erişir. Diğer kullanıcıların talepleri 404 döner.
- Bildirimler yalnızca oturum sahibine aittir.

## Endpoint listesi

| Yöntem | Yol | Açıklama |
|---|---|---|
| GET | `/api/admin/roles` | Yönetim (Admin) |
| GET | `/api/admin/users` | Yönetim (Admin) |
| POST | `/api/admin/users` | Yönetim (Admin) |
| PUT | `/api/admin/users/{id}` | Yönetim (Admin) |
| POST | `/api/auth/login` | Giriş / oturum |
| GET | `/api/auth/me` | Giriş / oturum |
| POST | `/api/auth/logout` | Giriş / oturum |
| PUT | `/api/auth/password` | Giriş / oturum |
| GET | `/api/units` | Depo / raf / tanımlar |
| POST | `/api/units` | Depo / raf / tanımlar |
| GET | `/api/categories` | Depo / raf / tanımlar |
| POST | `/api/categories` | Depo / raf / tanımlar |
| GET | `/api/warehouses` | Depo / raf / tanımlar |
| POST | `/api/warehouses` | Depo / raf / tanımlar |
| GET | `/api/aisles` | Depo / raf / tanımlar |
| POST | `/api/aisles` | Depo / raf / tanımlar |
| GET | `/api/shelves` | Depo / raf / tanımlar |
| POST | `/api/shelves` | Depo / raf / tanımlar |
| GET | `/api/shelves/{id}/products` | Depo / raf / tanımlar |
| GET | `/api/shelves/qr/{value}` | Depo / raf / tanımlar |
| GET | `/health` | Depo.Api |
| GET | `/api/dashboard` | Dashboard / rapor / bildirim |
| GET | `/api/reports/critical-stock` | Dashboard / rapor / bildirim |
| GET | `/api/reports/stock-movements` | Dashboard / rapor / bildirim |
| GET | `/api/reports/summary` | Dashboard / rapor / bildirim |
| GET | `/api/reports/stock-movements.csv` | Dashboard / rapor / bildirim |
| GET | `/api/notifications` | Dashboard / rapor / bildirim |
| PUT | `/api/notifications/{id}/read` | Dashboard / rapor / bildirim |
| PUT | `/api/notifications/read-all` | Dashboard / rapor / bildirim |
| GET | `/api/products` | Ürün yönetimi |
| POST | `/api/products` | Ürün yönetimi |
| GET | `/api/products/{id}` | Ürün yönetimi |
| PUT | `/api/products/{id}` | Ürün yönetimi |
| GET | `/api/products/barcode/{barcode}` | Ürün yönetimi |
| GET | `/api/products/{id}/batches` | Ürün yönetimi |
| GET | `/api/requests` | Talep akışı |
| POST | `/api/requests` | Talep akışı |
| GET | `/api/requests/{id}` | Talep akışı |
| PUT | `/api/requests/{id}/approve` | Talep akışı |
| PUT | `/api/requests/{id}/prepare` | Talep akışı |
| PUT | `/api/requests/{id}/deliver` | Talep akışı |
| PUT | `/api/requests/{id}/cancel` | Talep akışı |
| POST | `/api/stock/in` | Stok işlemleri (Operator) |
| POST | `/api/stock/out` | Stok işlemleri (Operator) |
| GET | `/api/stock/movements/{productId}` | Stok işlemleri (Operator) |

## Giriş

```http
POST /api/auth/login
Content-Type: application/json

{"login":"depo@demo.local","password":"Depo12345!"}
```

Başarılı cevap: `token`, `expiresAt`, `user: {id,email,fullName,unitId,unit,role}`. Token 8 saat geçerlidir. `POST /api/auth/logout` ve `PUT /api/auth/password`, mevcut oturum tokenlarını geçersiz kılar. Şifre değişimi: `{"currentPassword":"...","newPassword":"..."}`.

## Ürün

```json
{
  "productCode": "SUNUM-001",
  "barcode": "SUNUM-BARKOD-001",
  "name": "Sunum Malzemesi",
  "description": "Örnek malzeme",
  "categoryId": 1,
  "measureUnit": "Adet",
  "minimumStock": 90,
  "shelfId": 7,
  "isActive": true
}
```

`POST /api/products` 201 döner; başlangıç stoğu sıfırdır. Güncelleme `PUT /api/products/{id}` aynı alanları alır. Stok miktarı bu DTO'ya konulamaz.

`GET /api/products?search=eldiven&categoryId=1&warehouseId=1&shelfId=7&critical=true&outOfStock=false&page=1&pageSize=40`. Opsiyonel filtreleri ihtiyaca göre gönderin. `includeInactive=true` yalnızca Operator için etkilidir. Cevap `{total,page,pageSize,items}`; sayfa boyutu en fazla 100.

`GET /api/products/barcode/{value}` barkod veya ürün kodu çözer. Raf QR çözümü `/api/shelves/qr/{value}`, raf ürünleri `/api/shelves/{id}/products`.

## Stok girişi / çıkışı

```json
{
  "productId": 21,
  "quantity": 100,
  "description": "Yeni sevkiyat",
  "operationId": "b71579de-a6b0-45dc-9a40-a9e6d081217a",
  "type": "In",
  "shelfId": 7,
  "batchNumber": "SUNUM-P1",
  "expiryDate": "2027-12-31"
}
```

Giriş `/api/stock/in`, çıkış `/api/stock/out`. Çıkışta `type="Out"`, miktar pozitif gönderilir; sunucu negatif hareket oluşturur. Giriş türleri In/Return/Correction/Count; çıkış türleri Out/Correction/Count. Miktar 1–10.000.000 arasında tam sayıdır. Açıklama en az 3 karakterdir. `operationId` zorunlu UUID; bağlantı hatasında **aynı işlem için aynı değeri tekrar kullanın**. Başarılı cevap `{id,productId,quantity,previousStock,nextStock}`.

Parti ve SKT girişte isteğe bağlıdır. Talebe bağlı stok düşümü manuel çıkıştan yapılmaz; talebin `/deliver` işlemini kullanın. `requestId` manuel stok DTO'sunda verilirse 400 döner.

## Talep

```json
{
  "clientId": "c883f1c0-565a-4ae7-b88b-dc5f3acb6c76",
  "priority": "Normal",
  "description": "Birim ihtiyacı",
  "items": [{"productId": 21, "quantity": 20}]
}
```

`POST /api/requests` 201 ve talep detayını döner. `clientId` zorunlu UUID'dir. Aynı ürün bir talepte yalnızca bir kez bulunabilir; en fazla 100 kalem. `priority`: Normal/Urgent.

`GET /api/requests?status=Pending&priority=Urgent&unitId=1&page=1&pageSize=40`.

Durumlar: Pending, Approved, Preparing, Delivered, Cancelled. `PUT /approve`, `/prepare`, `/deliver`, `/cancel` işlem gövdesi gerektirmez; başarılı sonuç 204. Unit kendi Pending talebini iptal edebilir. Operator teslim/iptal tamamlanmış talebi değiştiremez. Teslim için Preparing durumu gerekir.

## Yönetim gövdeleri

| İşlem | JSON alanları |
|---|---|
| POST /api/units | name |
| POST /api/categories | name |
| POST /api/warehouses | name, code |
| POST /api/aisles | warehouseId, name |
| POST /api/shelves | aisleId, code, qrValue |
| POST /api/admin/users | email, password, fullName, role, unitId |
| PUT /api/admin/users/{id} | fullName, role, unitId, isActive |

Unit rolünde birim zorunludur. Kullanıcılar bir operasyonel rol alır. Yönetici kendi hesabını pasifleştiremez veya kendi yönetici rolünü kaldıramaz.

## Rapor / bildirim

`/api/reports/summary?from=2026-10-01&to=2026-10-28` günlük hareket, en çok kullanılanlar, birimlere göre talep ve SKT listelerini döner. Tarih aralığı hareket ve talep oluşturma zamanına uygulanır. SKT listesi her zaman bugünden itibaren 30 gün içinde bitecek ve süresi geçmiş, miktarı pozitif partileri gösterir.

`/api/reports/stock-movements` aynı tarih parametreleri yanında page/pageSize alır. `/api/reports/stock-movements.csv` UTF-8 BOM içeren CSV dosyası döner. `/api/notifications?page=1` `{unread,items}` döner; sayfa başına 50 kayıt. `/read` ve `/read-all` 204 döner.

## Hatalar

| Kod | Anlam |
|---|---|
| 400 | Geçersiz alan, miktar, rol veya ilişkili kayıt |
| 401 | Yanlış giriş veya geçersiz / süresi bitmiş token |
| 403 | Rol veya işlem yetkisi yok |
| 404 | Kayıt yok veya kullanıcının kapsamı dışında |
| 409 | Yetersiz stok, geçersiz durum geçişi, tekrar teslim veya benzersizlik çakışması |
| 429 | Giriş denemeleri hız sınırını aştı |
| 500 | Ayrıntıları sunucu günlüğüne yazılan beklenmeyen hata |

İş kuralı hata cevabı: `{"title":"Yetersiz stok. Mevcut stok miktarı: 20","status":409,"traceId":"..."}`. Authentication/authorization katmanında gövdesiz 401/403 de dönebilir; mobil istemci bunları Türkçe mesaja çevirir.
