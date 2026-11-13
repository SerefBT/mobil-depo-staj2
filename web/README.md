# Mobil Depo Web

Bu yayın dizini Android uygulamasıyla aynı Flutter kaynaklarından üretilir.

- Ana kaynak: ../mobile
- Üretim: ../scripts/Build-Web.ps1
- Yayın çıktısı: dist/
- Derlemede kullanılan kaynak kopyası: source/
- ASP.NET ile birlikte yerel adres: http://127.0.0.1:5080
- Ayrı frontend yayını için uygulamanın Sunucu bağlantısı ayarından HTTPS API adresi girilir.

Canlı kullanımda ASP.NET Core ve PostgreSQL sunucusu ayrıca barındırılmalıdır. Bu dizin JWT anahtarı veya veritabanı bağlantısı içermez.

## Yayın tercihi

Kullanıcı 28.10.2026 tarihinde projenin şimdilik bilgisayarında kalmasını seçti. Kaynak aktarımı veya internet yayını yapılmaz. Yerel site Start-Demo.cmd ile açılır.
