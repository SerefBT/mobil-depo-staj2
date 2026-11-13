# Ücretsiz yayın planı: Render + Neon

28.10.2026 tarihinde resmi dokümantasyon üzerinden kontrol edildi. Şu anda bu plan yalnızca hazırlanmıştır; hesaplara bağlantı ve kaynak aktarımı yapılmadı. Önce yerel siteyi inceleyip tasarım değişikliklerini tamamlayabilirsiniz.

## Şimdi siteye bakma

1. `Start-Demo.cmd` ile sunucuyu başlatın (zaten açıksa tekrar başlatmaya gerek yok).
2. Tarayıcıda **http://127.0.0.1:5080** adresini açın.
3. Yönetici: `admin@demo.local` / `Admin12345!`.
4. Görünümünü değiştirmek istediğiniz ekranın adını ve istediğiniz değişikliği belirtin.

## Ücretsiz seçenek

- **Render Free Web Service:** Tek Docker servisi web arayüzünü ve ASP.NET Core API'yi birlikte sunar. Otomatik HTTPS ve Render alt alan adı kullanılır; kendi alan adınızı satın almanız gerekmez.
- **Neon Free:** PostgreSQL veritabanı. Resmi fiyat sayfasında ücretsiz plan için 1 GB veritabanı ve proje başına aylık 100 CU-saat belirtilir. Ücretsiz planda kredi kartı gerekmez.
- **Kaynak deposu:** Render'ın erişebildiği GitHub/GitLab/Bitbucket deposu gerekir. Kaynak aktarımı, hedef depo ve hesap bağlantısı netleştikten sonra yapılır. Yerel sırlar ve geliştirme araçları gönderilmez.

Render'ın kendi ücretsiz PostgreSQL servisi 30 gün sonunda sona erdiği için bu planda veritabanı Neon'da tutulur. Hiçbir ücretli servis tanımlanmadı. Ücretsiz plan sınırları aşıldığında hizmet kısıtlanabilir; plan yükseltmesi bu kurulumun parçası değildir.

## Sınırlamalar

Render ücretsiz web servisi 15 dakika isteksiz kaldığında uyur; sonraki ilk açılış yaklaşık bir dakika sürebilir. Neon da boşta kaldığında compute'u durdurur. Dolayısıyla sunumdan önce siteyi açıp servisin hazır olmasını beklemek gerekir. Veritabanı Neon'da tutulduğu için Render servisi yeniden başladığında stok kayıtları servis diskiyle birlikte kaybolmaz.

Uygulama backend'i uyurken SKT işçisi de çalışmaz; sunucu tekrar başladığında kontrol devam eder. Android ilk bağlantısı soğuk başlangıca denk gelirse bağlantı hatasından sonra yeniden denemek gerekebilir.

## Hazırlanan dosyalar

- Kökteki `Dockerfile`: Flutter Linux SDK'nın SHA256 değerini doğrular, web kaynaklarını ve .NET API'yi derler; son imaja yalnızca çalışan web/API çıktısını koyar.
- `.dockerignore`: Yerel şifreleri, SDK'ları, veritabanı dosyalarını ve APK'ları Docker bağlamından çıkarır.
- `render.yaml`: Yalnızca `plan: free` bir web servisi tanımlar; otomatik sonraki yayınlar kapalıdır.
- `deploy/render-entrypoint.sh`: Render'ın verdiği PORT'u kullanır. Şifre ve JWT anahtarını ortamdaki değerlerden alır, loga yazmaz.

## Hesaplar bağlandıktan sonraki adımlar

1. Neon'da **Free** planında boş bir PostgreSQL projesi oluşturun. Mümkünse Render ile yakın bölge seçin.
2. Connect bölümünden .NET/Npgsql bağlantı ayarını alın. İlk kurulum ve migration için pooler içermeyen doğrudan endpoint kullanın. Örnek biçim:

   ```text
   Host=YOUR_NEON_HOST;Port=5432;Database=neondb;Username=YOUR_USER;Password=YOUR_PASSWORD;SSL Mode=VerifyFull;Maximum Pool Size=10
   ```

   Gerçek değer yalnızca Render'ın `ConnectionStrings__Database` gizli ortam değişkenine girilir. Sohbette veya Git deposunda tutulmaz.
3. Rastgele en az 48 bayt uzunluğunda bir JWT anahtarını `Jwt__Key` ortam değişkenine girin. Yayın sırasında bu değer güvenli şekilde üretilebilir. Render'ın varsayılan 256-bit base64 otomatik değeri 44 karakter olduğundan bu uygulamanın 48 bayt alt sınırını tek başına karşılamaz.
4. Hazır kaynak deposundan Render Blueprint oluşturup `render.yaml` dosyasını seçin. `plan: free` kaldığını kontrol edin; iki gizli ortam değişkenini tanımlayın.
5. Docker derlemesi Flutter web'i ve API'yi oluşturur. Uygulama açılışında migration ve sentetik demo seed uygulanır. Bu açıkça **demo ortamıdır**; Development ve Demo__Seed=true demo hesapları için kullanılır.
6. Yayın sonrası `/health`, yönetici girişi ve 100 → 80 stok senaryosu doğrulanır. Android uygulamasındaki Sunucu bağlantısı alanına `https://YOUR_SERVICE.onrender.com/api` yazılır.

Hesaplar henüz bağlı olmadığından bulut Docker imajı build/push edilmedi ve çevrim içi uçtan uca kontrol yapılmadı. Yerel APK/web için mevcut doğrulama kaydı docs/VALIDATION.md içindedir.

## Kaynaklar

- [Render ücretsiz servis koşulları](https://render.com/docs/free)
- [Render .NET/Docker desteği](https://render.com/docs/faq)
- [Render Blueprint yapılandırması](https://render.com/docs/blueprint-spec)
- [Neon ücretsiz planı](https://neon.com/pricing)
