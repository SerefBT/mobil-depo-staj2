# Doğrulama kaydı

Tarih: 28.10.2026 (Europe/Istanbul).

| Kontrol | Sonuç |
|---|---|
| ASP.NET / test projesi Release derleme | Başarılı; warnings-as-errors etkin |
| Gerçek PostgreSQL entegrasyon testleri | **34 / 34 geçti** |
| Flutter statik analiz | **No issues found** |
| Mobil / geniş ekran widget testleri | **9 / 9 geçti** |
| Flutter web release derleme | Başarılı |
| Android release APK | Başarılı |
| Android debug APK | Başarılı |
| APK imzası | apksigner verify başarılı; demo Android Debug sertifikası |
| Migration ve seed | PostgreSQL 18.6 üzerinde uygulandı |
| Demo başlangıç betiği | MigrateOnly ve normal localhost sunucu başlangıcı doğrulandı |
| Gerçek Edge tarayıcısı | Giriş, dashboard, ürünler, masaüstü ve telefon boyutu doğrulandı; JavaScript hatası yok |
| QR/barkod çözümleme API | Ürün barkodu ve raf QR çözümü entegrasyonda doğrulandı |

34 backend testi login, yanlış şifre, anonim erişim, rol yetkisi, ürün ekleme, stok giriş/çıkışı, negatif/sıfır miktar, yetersiz stok, idempotent tekrar, kritik stok ve bildirim, çok ürünlü talep, kullanıcı kapsamı, 100 → 80 teslim, tekrar teslim, atomik geri alma, eşzamanlı çıkış/teslim, FEFO, SKT, QR çözümü, iptal, CSV, token iptali, rapor tarih filtresi ve web/API yönlendirmelerini kapsar.

Ekran görüntüleri: `artifacts/screenshots/web-login.png`, `web-dashboard.png`, `web-products.png`, `mobile-products.png`. TRX: `artifacts/test-results/integration.trx`.

## Doğrulama sınırları

Bağlı Android telefon veya emülatör yoktu. Fiziksel kamera taraması ve cihaz bildirim izin ekranı gerçek cihazda test edilmedi. APK'nin imzası, paket yapısı ve derleme sonuçları doğrulandı. AndroidManifest'teki kamera/internet/bildirim izinlerine ek olarak bildirim paketinin VIBRATE, tarayıcı altyapısının ACCESS_NETWORK_STATE ve AndroidX'in uygulamaya özel korumalı alıcı izni birleştirilmiştir; depolama/konum/rehber izni yoktur.

Docker Desktop bu oturumda çalışmıyordu; taşınabilir gerçek PostgreSQL kullanıldı. İnternette backend/veritabanı dağıtımı yapılmadı. Kullanıcı proje ve web sürümünün şimdilik yalnızca bilgisayarda kalmasını istedi. Yerel web çalışır durumda; internete kaynak aktarımı ve yayın yapılmadı. İleride çevrim içi kullanım istenirse ayrıca backend ve PostgreSQL barındırması hazırlanmalıdır.

Release APK yerel demo imzası taşır. Uygulama arka planda tamamen kapalıyken push bildirimi teslimi kurulmadı; uygulama içi ve Android local bildirim akışı uygulanmıştır.
