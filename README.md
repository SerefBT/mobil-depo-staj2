# Mobil Depo — Staj 2

Şerafettin Bayat tarafından geliştirilen Türkçe depo, raf ve stok takip uygulaması. Flutter web ve Android istemcileri aynı ASP.NET Core API ve PostgreSQL veritabanıyla çalışır. Örnek kurum ve ürün verileri kullanılır.

## Özellikler

- Depo, koridor, raf, kategori ve ürün yönetimi.
- Giriş, çıkış, iade ve sayım farklarının hareket geçmişiyle izlenmesi.
- Birim talepleri, onay/hazırlama/teslim ve rol bazlı erişim.
- Yetersiz stok ve tekrarlanan teslim denetimi; işlemlerin veritabanında birlikte tamamlanması.
- Parti, son kullanma tarihi, FEFO, kritik stok ve uygulama içi bildirimler.
- Arama, rapor ve CSV dışa aktarımı; barkod/QR alanı ve elle kod girişi.

## Roller ve yerel demo hesapları

| Rol | E-posta | Yalnız demo için parola |
|---|---|---|
| Yönetici | admin@demo.local | Admin12345! |
| Depo personeli | depo@demo.local | Depo12345! |
| Birim yetkilisi | birim@demo.local | Birim12345! |

Bu hesaplar yalnız Development ortamında `Demo:Seed=true` ile oluşturulan kurmaca demo verilerine aittir. İnternet yayını için gerçek ortam ayarları ve ayrı hesaplar kullanılmalıdır; gerçek anahtarlar kaynak depoya eklenmez.

## Kaynaktan çalıştırma

Doğrulanan araç sürümleri `toolchain.json` içindedir: .NET SDK 10.0.403, Flutter 3.47.8 / Dart 3.13.7 ve PostgreSQL 18.6. Android için JDK 21 ve SDK 36 gerekir; en düşük sürüm Android 7.0 (API 24).

Windows üzerinde araçları proje içine hazırlayan yol:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Setup-Tools.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Build-Web.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Start-Demo.ps1
```

Kaynak kurulumunda web adresi `http://127.0.0.1:5080`, API `/api`, Swagger `/swagger` ve sağlık kontrolü `/health` olur. İlk bağımlılık/araç kurulumu için internet gerekir. Veritabanı ve yerel ayarlar Git dışında oluşturulur. Kendi PostgreSQL sunucusu için `.env.example`, `docs/database.sql` ve backend ortam değişkenleri incelenmelidir.

## Android Studio ve APK

Android Studio'da `mobile` klasörünü açın; Flutter ve Dart eklentilerini etkinleştirin. Kaynaktan yeniden APK üretme:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Build-Apk.ps1 -Mode release
```

Uygulamanın giriş ekranından API adresi değiştirilebilir. Emülatör için `http://10.0.2.2:5080/api`; USB cihaz için `adb reverse tcp:5080 tcp:5080` sonrasında `http://127.0.0.1:5080/api` kullanılır. APK kayıt işlemleri için çalışan API'ye ihtiyaç duyar. Gerçek cihazda kamera ve bildirim denemeleri ayrıca yapılmalıdır.

## Testler

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test.ps1
```

Sunucu testleri ayrı PostgreSQL test veritabanlarıyla işlem, stok ve yetki kurallarını denetler. Mobil testler `mobile/test` içindedir. Teknik açıklamalar `docs` klasöründe; veritabanı değişiklikleri `backend/Depo.Api/Migrations` altındadır.

## CD teslim sürümü

Hazır CD paketi, kaynak kodun yanında release APK ve Windows 64 bit için taşınabilir API/web/PostgreSQL çalışma araçlarını içerir. CD kökündeki `1_KUR_VE_BASLAT.cmd`, uygulamayı yazılabilir yerel alana kopyalar ve tarayıcıyı açar. CD demosunun adresi `http://127.0.0.1:5081`; hesaplar `GIRIS_BILGILERI.txt` içindedir. `2_DURDUR.cmd` yalnız bu demo süreçlerini kapatır. Bu depodaki `CDLauncher` dosyaları o hazır paketin başlatıcı kaynaklarıdır; büyük çalışma araçları bu kaynak depoda tutulmaz.

## Kapsam

Web ve Android ortak API/veri modelini kullanır. Sunucu ve veritabanı için internet barındırması bu depoyla kendiliğinden kurulmaz. Uygulama kapalıyken uzaktan push ve çevrimdışı kayıt eşitleme mevcut kapsamın dışındadır. Android release paketi gösterim amaçlıdır; mağaza dağıtımı ayrı bir aşamadır.
