# QMS: Qist (Installment) Management Software

Electronics dukaan ke liye qist ka hisaab. Poori specification: `QMS-Docment.pdf`.

**Stack:** ASP.NET Core 10 Web API, Dapper + Stored Procedures (EF Core nahi), SQL Server, HTML5 + Bootstrap 5 + jQuery (wwwroot), cookie login + Roles/Permissions.

## Faislay jo is repo mein lagu hain
- Har table ka primary key `INT IDENTITY(1,1)` (GUID kahin nahi, junction tables mein bhi `Id` + unique constraint).
- `RequestKey` (double-submit se bachao) GUID column nahi, `NVARCHAR(64)` random text hai.
- Login: JWT nahi, ASP.NET Core ki cookie (HttpOnly, SameSite=Strict, 10 ghante ka session). Cookie mein sirf user Id; roles/permissions har request par DB se (20 second cache), is liye user band karne ya role badalne ka asar jaldi lagta hai.
- Database: app koi migration nahi chalati. Tables/procedures ki scripts `QMS/Database/MarhalaN/` mein hain, aap SSMS mein khud chalate hain.
- Sara hisaab sirf stored procedures mein; C# sirf call karta hai. SP ki ghalti `THROW 50xxx` se aati hai aur user ko saaf message ke saath 400 milta hai.
- Tareekhen PKT (UTC+5): `dbo.fn_PktNow()` / `dbo.fn_PktToday()`.

## Pehli baar chalane ka tareeqa (Development)
1. SQL Server Developer Edition + SSMS install ho.
2. SSMS mein `QMS/Database/Phase1/` ki scripts **tarteeb se** chalayein (har ek poori select karke F5):
   `01_Tables.sql` (database `QistDB` bhi banata hai), `02_StoredProcedures.sql`, `03_SeedData.sql`.
3. Connection string: `QMS/appsettings.Development.json` mein `localhost` aur Windows login hai. Aap ka SQL Server alag instance par ho (jaise `.\SQLEXPRESS`) to `Server=` badal lein.
4. Owner ka password set karein (git mein nahi jata):
   ```bash
   cd QMS
   dotnet user-secrets set "Bootstrap:OwnerPassword" "<kam az kam 8 harf>"
   ```
5. `dotnet run` chalayein. Pehli run par app Owner user (`owner`) khud bana deti hai.
6. Browser mein `https://localhost:7229` kholein, `owner` + upar wale password se login karein, phir **Shop Profile** mein apni dukaan ka naam likhein.
7. Check: `/health` par `Healthy` aana chahiye. Haath se test: `QMS/Database/Tests/Phase1_Smoke.sql`.

Aage ke marahil ki scripts bhi isi tarah `Database/Phase2/`, `Phase3/` ... mein aayengi.

## Folder structure (`QMS/`)
| Folder | Kaam |
|---|---|
| `Controllers/` | Input lena, permission check, HTTP code. Hisaab nahi |
| `Services/` | SP call karna, DTO mapping |
| `Repositories/` | Dapper SP executor, koi logic nahi |
| `Security/` | Cookie session, permissions, policies |
| `Infrastructure/` | Global error handler, health check |
| `Startup/` | Pehla Owner user banana |
| `Database/` | `Phase1/` (01_Tables, 02_StoredProcedures, 03_SeedData), `Tests/` |
| `wwwroot/` | HTML pages, `js/api.js` (ek hi `$.ajax` wrapper), `js/app.js` (menu, layout) |

## Development plan (spec section 10)
- [x] **Marhala 1**: project setup, tables, roles/permissions, cookie login, Shop Profile, `usp_Number_Next`
- [ ] Marhala 2: Branches, Customers, Guarantors, Products, Payment Methods
- [ ] Marhala 3: Suppliers, Purchases, StockTransactions
- [ ] Marhala 4: Markup Rules, Sale Preview/Create
- [ ] Marhala 5: Payments, Dashboard
- [ ] baqi marahil: spec ke mutabiq
