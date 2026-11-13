# Gereksinim eşlemesi

Kullanıcının gönderdiği 32 bölümlük şartnameye göre uygulama karşılıkları:

| Bölüm | Uygulama karşılığı |
|---|---|
| 1 Teknolojiler | Flutter/Dart/Material 3; ASP.NET Core/EF Core; PostgreSQL; JWT; QR; local notification; OpenAPI |
| 2 Mimari | backend, mobile, docs; Controller/Service/Repository/DTO/Data/Models ve mobil modüller |
| 3 Roller | Admin, Warehouse, Unit; API izinleri ve role göre menüler |
| 4 Authentication | Identity hash, e-posta/kullanıcı adı, JWT, secure storage, logout/revocation |
| 5 Dashboard | 6 metrik, kritik ürünler, son hareketler; Unit için kendi talep kapsamı |
| 6 Ürün | Kod, barkod, kategori, ölçü, minimum, stok, raf, tarih, aktiflik; ekleme/düzenleme |
| 7 Konum | Depo/koridor/raf hiyerarşisi, benzersiz raf QR, raf ürünleri |
| 8 QR/barkod | Kamera taraması; ürün ve raf çözümü; QR etiket oluşturma; elle kod girişi |
| 9 Giriş | Pozitif stok hareketi, parti ve konum doğrulama, önceki/sonraki miktar |
| 10 Çıkış | Neden/açıklama, yetersiz stok engeli; talep çıkışı için güvenli deliver endpointi |
| 11 Hareket | In/Out/Delivery/Correction/Return/Count; kullanıcı, talep, zaman, önce/sonra ve parti dağıtımı |
| 12 Talep | Çok ürünlü kalemler, birim ve kullanıcı, öncelik, açıklama ve 5 durum |
| 13 Karşılama | Hazırlama/teslim; tek transaction ile tüm kalemlerin atomik stok düşümü |
| 14 Kritik stok | Minimumun altı, dashboard/listeler, eşik geçişinde bildirim |
| 15 Parti/SKT | Partiler, miktar, SKT, FEFO, 30/15/7 uyarıları; expired teslim engeli |
| 16 Filtreler | Ürün adı/kod/barkod/kategori/depo/raf; kritik/sıfır stok; talep durum/acil/birim |
| 17 Rapor | Günlük giriş/çıkış, kritik, tüketim, birim, hareket, SKT; CSV paylaşımı |
| 18 Bildirim | Kullanıcıya özel DB kayıtları + uygulama açıkken Android local notification |
| 19 Tablolar | İstenen 16 tablo, Identity destek tabloları ve BatchAllocations; FK/indeks/CHECK |
| 20 API | Şartnamedeki endpointler ve ilave yönetim/bildirim/parti uçları; API.md ve OpenAPI |
| 21 Ekranlar | 20 temel ekranın tamamı; ek olarak yönetici formları ve şifre değişimi |
| 22 UX | Türkçe Material 3, kartlar, sakin teal renkler, loading/error/snackbar, doğrulama, dark mode |
| 23 Demo | 7 kullanıcı/3 rol/5 birim/2 depo/4 koridor/12 raf/20 ürün/10 talep/42 hareket |
| 24 Güvenlik | Hash, JWT, rol ve sahiplik, parametreli EF, DTO, güvenli hata; sentetik veri |
| 25 Transaction | Stock ve Request satır kilitleri, sıralı ürün kilitleme, rollback, nonnegative constraints |
| 26 Test | Gerçek PostgreSQL entegrasyonu ve mobil form/rol/yerleşim testleri; VALIDATION.md |
| 27 README | Kurulum, PostgreSQL, migration, API, Flutter, emulator, cihaz, APK ve demo hesapları |
| 28 APK | Kamera/internet/bildirim izinleri, Android build ayarları, release/debug komutları |
| 29 Geliştirme | Çalışan veritabanı ve API; API'ye bağlanan Flutter; otomatik kurulum/test betikleri |
| 30 Senaryo | 100 giriş → 20 talep → 80 stok; entegrasyon testi ve DEMO.md |
| 31 Çıktılar | Kaynaklar, migration/SQL, seed, Swagger, testler, docs, config, Mermaid, APK artefaktı |
| 32 Sunum | Problem, teknik değer ve adım adım sunum belgesi DEMO.md |

## Tasarım kapsamı

- Her ürünün tek raf konumu vardır. Aynı SKU'nun birden fazla raf/depo arasında miktarlı dağılımı için ayrı stok konum/transfer modeli gerekir.
- Miktarlar tam sayıdır; kesirli ağırlık/hacim stoğu bu modelde bulunmaz.
- CSV vardır; PDF alternatifi uygulanmadı.
- Bildirimler uygulama açıkken veya yeniden öne geldiğinde kontrol edilir. Uygulama kapalıyken push için harici servis kurulumu gerekir.
- Sunucu bilgisayarda kalır. Telefon demosu USB port yönlendirmesiyle erişir; bağımsız internet kullanımı için HTTPS sunucusuna dağıtım gerekir.
- APK release derleme yerel demo anahtarı kullanır. Mağaza yayını ve gerçek kurum dağıtımı ayrıca yapılandırılır.
