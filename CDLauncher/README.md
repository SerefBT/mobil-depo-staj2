# Windows64 CD başlatıcıları

Başlatıcılar, paketlenmiş API/web, SDK içermeyen .NET10runtime ve PostgreSQL bin/lib/share ile çalışır. Bütün çalışma verisi `%LOCALAPPDATA%/SerafettinStaj/MobilDepo` altında tutulur; CD’ye yazılmaz. API5081, PostgreSQL54331 yalnız127.0.0.1 üzerinde açılır. Yeni DB parolası ve JWT anahtarı ilk çalıştırmada üretilir; kaynakta veya CD’de gerçek sır yoktur. Durdurucu PID+başlangıç zamanı+kurulum kimliği ile yalnız kendi oturumunu kapatır.

Uygulama dizini derlenmiş dağıtım olduğundan Git deposuna yüklenmez. Android kaynakları `mobile`, API `backend/Depo.Api` altındadır; standart SDK kurulum adımları ana README’dedir.
