-- Receipt / Sale / Contract ... ka agla number, jaise MAIN-R-2026-000123.
-- Dusre SPs ke transaction ke andar bhi chal sakta hai (apna transaction sirf tab kholta hai jab koi khula na ho).
CREATE OR ALTER PROCEDURE dbo.usp_Number_Next
    @BranchId INT,
    @SeqType  NVARCHAR(20),
    @Number   NVARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Letter NVARCHAR(3) = CASE @SeqType
        WHEN N'Receipt'         THEN N'R'
        WHEN N'Sale'            THEN N'S'
        WHEN N'Contract'        THEN N'C'
        WHEN N'Purchase'        THEN N'P'
        WHEN N'Return'          THEN N'RT'
        WHEN N'SupplierPayment' THEN N'SP'
        WHEN N'PurchaseReturn'  THEN N'PR'
    END;
    IF @Letter IS NULL THROW 50010, N'Number ki qism sahi nahi.', 1;

    DECLARE @Year    INT = YEAR(dbo.fn_PktToday());
    DECLARE @Last    INT;
    DECLARE @Prefix  NVARCHAR(30);
    DECLARE @Padding TINYINT;
    DECLARE @OwnTran BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;

    BEGIN TRY
        IF @OwnTran = 1 BEGIN TRAN;

        -- UPDLOCK + HOLDLOCK: do users ek hi waqt aayein to bhi number dohra nahi hoga
        UPDATE dbo.NumberSequences WITH (UPDLOCK, HOLDLOCK)
           SET @Last = LastNumber = LastNumber + 1,
               @Prefix = Prefix,
               @Padding = Padding
         WHERE BranchId = @BranchId AND SeqType = @SeqType AND [Year] = @Year;

        IF @@ROWCOUNT = 0
        BEGIN
            DECLARE @BranchCode NVARCHAR(10) = (SELECT Code FROM dbo.Branches WHERE Id = @BranchId);
            IF @BranchCode IS NULL THROW 50011, N'Branch nahi mili.', 1;

            SET @Prefix  = @BranchCode + N'-' + @Letter;
            SET @Padding = 6;
            SET @Last    = 1;

            INSERT dbo.NumberSequences (BranchId, SeqType, Prefix, [Year], LastNumber, Padding)
            VALUES (@BranchId, @SeqType, @Prefix, @Year, @Last, @Padding);
        END

        DECLARE @Digits NVARCHAR(10) = CAST(@Last AS NVARCHAR(10));
        SET @Number = @Prefix + N'-' + CAST(@Year AS NVARCHAR(4)) + N'-'
                    + CASE WHEN LEN(@Digits) >= @Padding THEN @Digits
                           ELSE RIGHT(REPLICATE(N'0', @Padding) + @Digits, @Padding) END;

        IF @OwnTran = 1 COMMIT;
    END TRY
    BEGIN CATCH
        IF @OwnTran = 1 AND @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO
