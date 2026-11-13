# Mimari

```mermaid
flowchart LR
  U[Android kullanıcı] --> F[Flutter / Material 3]
  F --> S[Provider / AppState]
  S --> T[Secure Storage / JWT]
  S --> A[Dio / REST API]
  C[Kamera / QR ve barkod] --> F
  A --> AUTH[JWT / Role Authorization]
  AUTH --> CTRL[ASP.NET Core Controllers]
  CTRL --> SERVICE[Inventory / Request / Notification Services]
  CTRL --> REPO[Product Repository / EF sorguları]
  SERVICE --> DB[(PostgreSQL)]
  REPO --> DB
  WORKER[SKT BackgroundService] --> DB
  DB --> N[Notifications]
  N --> A
  F --> LOCAL[Android local notifications]
```

## Veri modeli

```mermaid
erDiagram
  Users }o--o| Units : belongs_to
  Users ||--o{ UserRoles : has
  Roles ||--o{ UserRoles : grants
  Warehouses ||--o{ Aisles : contains
  Aisles ||--o{ Shelves : contains
  Shelves ||--o{ Products : locates
  Categories ||--o{ Products : groups
  Products ||--|| Stocks : balance
  Products ||--o{ ProductBatches : contains
  Products ||--o{ StockMovements : records
  Users ||--o{ StockMovements : executes
  Units ||--o{ Requests : submits
  Users ||--o{ Requests : creates
  Requests ||--o{ RequestItems : includes
  Products ||--o{ RequestItems : requested
  Requests o|--o{ StockMovements : fulfills
  StockMovements ||--o{ BatchAllocations : allocates
  ProductBatches ||--o{ BatchAllocations : consumes
  Users ||--o{ Notifications : receives
  Users { uuid Id PK
    string Email UK
    string PasswordHash
    string SecurityStamp
    int UnitId FK
    bool IsActive
  }
  Roles { uuid Id PK
    string Name UK
  }
  UserRoles { uuid UserId PK,FK
    uuid RoleId PK,FK
  }
  Units { int Id PK
    string Name UK
  }
  Warehouses { int Id PK
    string Code UK
    string Name
  }
  Aisles { int Id PK
    int WarehouseId FK
    string Name
  }
  Shelves { int Id PK
    int AisleId FK
    string Code UK
    string QrValue UK
  }
  Categories { int Id PK
    string Name UK
  }
  Products { int Id PK
    string ProductCode UK
    string Barcode UK
    string Name
    int CategoryId FK
    int ShelfId FK
    int MinimumStock
    bool IsActive
    datetime CreatedAt
    datetime UpdatedAt
  }
  Stocks { int Id PK
    int ProductId FK,UK
    int Quantity
  }
  ProductBatches { int Id PK
    int ProductId FK
    string BatchNumber
    int Quantity
    date ExpiryDate
    datetime CreatedAt
  }
  Requests { int Id PK
    uuid ClientId UK
    int UnitId FK
    uuid UserId FK
    int Status
    int Priority
    datetime CreatedAt
    datetime UpdatedAt
  }
  RequestItems { int Id PK
    int RequestId FK
    int ProductId FK
    int Quantity
  }
  StockMovements { bigint Id PK
    int ProductId FK
    uuid UserId FK
    int RequestId FK
    uuid OperationId UK
    int Type
    int Quantity
    int PreviousStock
    int NextStock
    datetime CreatedAt
  }
  BatchAllocations { bigint Id PK
    bigint StockMovementId FK
    int ProductBatchId FK
    int Quantity
  }
  Notifications { bigint Id PK
    uuid UserId FK
    string Title
    string Message
    string DedupKey
    bool IsRead
    datetime CreatedAt
  }
```

Identity'nin claim, login ve token tabloları da EF Identity altyapısı tarafından oluşturulur. Kullanıcı başına API üzerinden tek operasyonel rol atanır. Bir ürün bir stok satırına ve bir raf konumuna sahiptir. Bu karar ekranları ve stok/parti invariantlarını sade tutar; aynı ürünün aynı anda farklı raflarda tutulması ayrı StockLocations/transfer modeli gerektirir.

## Teslim işlemi

```mermaid
sequenceDiagram
  participant F as Flutter
  participant R as RequestService
  participant P as PostgreSQL
  F->>R: PUT /requests/id/deliver
  R->>P: BEGIN
  R->>P: Request FOR UPDATE
  R->>R: Durum = Preparing kontrolü
  loop Artan ProductId
    R->>P: Stock FOR UPDATE
    R->>P: Kullanılabilir parti ve FEFO kontrolü
    R->>P: Stok/parti düş, hareket ve dağıtım oluştur
  end
  R->>P: Request=Delivered, Notification ekle
  alt Bütün adımlar başarılı
    R->>P: COMMIT
    R-->>F: 204
  else Herhangi bir hata
    R->>P: ROLLBACK
    R-->>F: 409 / güvenli hata
  end
```

Read Committed + açık satır kilitleri kullanılır. Teslim edilen veya iptal edilen talep tekrar değişmez. Stok hareketi `NextStock = PreviousStock + Quantity` ve negatif olmama CHECK kısıtlarıyla doğrulanır. Her giriş ve çıkışın parti dağıtımı kaydedilir. SKU/barkod/QR/istek kimlikleri benzersiz indekslerle korunur.
