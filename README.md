# QMS: Qist (Installment) Management Software

Electronics dukaan ke liye qist ka hisaab. Poori specification: `QMS-Docment.pdf`.

**Stack:** ASP.NET Core 10 Web API, Dapper + Stored Procedures (EF Core nahi), SQL Server, HTML5 + Bootstrap 5 + jQuery (wwwroot), JWT + Roles/Permissions.

## Faislay jo is repo mein lagu hain
- Har table ka primary key `INT IDENTITY(1,1)` (GUID kahin nahi, junction tables mein bhi `Id` + unique constraint).
- `RequestKey` (double-submit se bachao) GUID column nahi, `NVARCHAR(64)` random text hai.
- Sara hisaab sirf stored procedures mein; C# sirf call karta hai. SP ki ghalti `THROW 50xxx` se aati hai aur user ko saaf message ke saath 400 milta hai.
- Tareekhen PKT (UTC+5): `dbo.fn_PktNow()` / `dbo.fn_PktToday()`.
- Purani Tables/Seed script kabhi nahi badalni; tabdeeli ke liye nayi numbered script (`004_...sql`). SP/Function scripts (`CREATE OR ALTER`) badal sakte hain, runner khud dobara chalata hai.

## Pehli baar chalane ka tareeqa (Development)
1. SQL Server Developer Edition install ho (default instance `localhost`). Instance alag ho to `QMS/appsettings.Development.json` ki connection strings badlein.
2. Secrets set karein (git mein nahi jate):
   ```bash
   cd QMS
   dotnet user-secrets set "Jwt:Key" "<kam az kam 32 harf ka lamba random text>"
   dotnet user-secrets set "Bootstrap:OwnerPassword" "<Owner ka password, kam az kam 8 harf>"
   ```
3. `dotnet run` chalayein. Pehli run par app khud `QistDB` banati hai, `Database/` ki scripts chalati hai aur Owner user (`owner`) banati hai.
4. Browser mein `https://localhost:7229` kholein aur `owner` + upar wale password se login karein. Phir **Shop Profile** mein apni dukaan ka naam likhein.
5. Check: `/health` par `Healthy` aana chahiye. Database ka haath se test: `QMS/Database/Tests/Phase1_Smoke.sql`.

## Folder structure (`QMS/`)
| Folder | Kaam |
|---|---|
| `Controllers/` | Input lena, permission check, HTTP code. Hisaab nahi |
| `Services/` | SP call karna, DTO mapping |
| `Repositories/` | Dapper SP executor, koi logic nahi |
| `Security/` | JWT, permissions, policies |
| `Infrastructure/` | Global error handler, health check |
| `Startup/` | Scripts runner (`DbMigrator`), pehla Owner |
| `Database/` | `Functions/`, `Tables/`, `StoredProcedures/`, `Seed/`, `Tests/` |
| `wwwroot/` | HTML pages, `js/api.js` (ek hi `$.ajax` wrapper), `js/app.js` (menu, layout) |

## Development plan (spec section 10)
- [x] **Marhala 1**: project setup, scripts runner, tables, roles/permissions, login (+refresh token), Shop Profile, `usp_Number_Next`
- [ ] Marhala 2: Branches, Customers, Guarantors, Products, Payment Methods
- [ ] Marhala 3: Suppliers, Purchases, StockTransactions
- [ ] Marhala 4: Markup Rules, Sale Preview/Create
- [ ] Marhala 5: Payments, Dashboard
- [ ] baqi marahil: spec ke mutabiq
