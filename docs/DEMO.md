# Staj sunumu ve uygulamalı demo

## Problem

Kurum depolarında stok miktarı, fiziksel raf konumu ve birim ihtiyaçları ayrı listelerle tutulduğunda malzeme bulma, talepleri izleme ve stok farklarını araştırma zorlaşır. Mobil Depo, bu işlemleri yetkili kullanıcıların Android cihazında merkezi olarak yönetir.

## Sunum akışı

1. Mimariyi gösterin: Flutter → JWT korumalı ASP.NET Core API → PostgreSQL.
2. Üç rolü açıklayın. Birim hesabında stok değişim butonlarının olmamasını gösterin; yetkilerin API'de de kontrol edildiğini belirtin.
3. Aşağıdaki 100 → 80 senaryosunu uygulayın.
4. Aynı talebe ikinci kez teslim yapılamadığını ve 30 adet stoktan 40 adet çıkışın reddedildiğini gösterin.
5. QR etiketi, raf konumu ve FEFO parti listesini açın.
6. Kritik stok, bildirim, SKT raporu ve CSV paylaşımını gösterin.
7. Test sonuçlarını açın: gerçek PostgreSQL'de transaction geri alma ve eşzamanlı çıkış testleri.

## Başarı senaryosu

1. `depo@demo.local` ile giriş yapın.
2. Ürünler → +: ürün adı **Sunum Malzemesi**, ürün kodu **SUNUM-001**, barkod **SUNUM-BARKOD-001**, kategori Sarf Malzeme, ölçü Adet, minimum stok **90**, raf **A Deposu / Koridor 2 / B04**.
3. Ürün detayından **Stok girişi**: 100, parti SUNUM-P1, isterseniz gelecek bir SKT, açıklama Yeni sevkiyat. Stok 100 görünür.
4. Stok geçmişinde +100 hareketini gösterin. Ürün QR etiketini başka bir ekrandan/kağıttan taramak için açın.
5. Hesabım → Çıkış; `birim@demo.local` ile giriş.
6. Talepler → +: Sunum Malzemesi, **20 adet**, normal öncelik; gönderin.
7. Çıkış yapıp depo hesabıyla giriş yapın; ilgili talebi açın.
8. **Talebi hazırla**, ardından **Teslim et ve stoktan düş**.
9. Talep **Teslim edildi**, ürün stoğu **80** görünür. Geçmişte +100 ve −20 aynı ürün altında görünür.
10. Minimum 90 olduğu için kritik stok ve bildirim oluşur.
11. QR tarayıcıda ürün etiketini okutun; ürün detayı açılır. Kamera olmayan ortamda SUNUM-BARKOD-001 değerini elle girin.
12. Depolar → A Deposu → B04 rafının QR etiketini açın; **DEPO-A-K2-B04** tarandığında raftaki ürünler listelenir.

Mevcut demoda aynı ürün kodu daha önce oluşturulduysa farklı kod kullanın. Gerçek kamera testini fiziksel Android cihazında yapın; USB bağlantısı ve API sunucusu açık olmalıdır.

## Teknik değer

Bu proje stok miktarını doğrudan düzenleyen bir CRUD örneğinden daha ileri gider: stok hareket defteri, parti dağıtımı, FEFO, eşzamanlı satır kilitleri, atomik çok ürünlü teslim ve sunucu tarafında kullanıcı kapsamı içerir. Ürün ve talep aramalarında sayfalama, kritik stok eşikleri ve role göre rapor erişimi uygulanır.
