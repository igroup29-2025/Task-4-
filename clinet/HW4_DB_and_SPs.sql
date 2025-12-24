CREATE TABLE dbo.UsersTable
(
    Id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Name NVARCHAR(60) NOT NULL,
    Email NVARCHAR(120) NOT NULL UNIQUE,
    [Password] NVARCHAR(120) NOT NULL,
    Active BIT NOT NULL DEFAULT(1)
);
GO

CREATE TABLE dbo.MealsTable
(
    Id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Name NVARCHAR(120) NOT NULL,
    Category NVARCHAR(60) NULL,
    Area NVARCHAR(60) NULL,
    Instructions NVARCHAR(MAX) NULL,
    Image NVARCHAR(400) NULL,
    Video NVARCHAR(400) NULL,
    Source NVARCHAR(400) NULL
);
GO

CREATE TABLE dbo.UsersMealsTable
(
    UserId INT NOT NULL,
    MealId INT NOT NULL,
    CONSTRAINT PK_UsersMeals PRIMARY KEY(UserId, MealId),
    CONSTRAINT FK_UsersMeals_User FOREIGN KEY(UserId) REFERENCES dbo.UsersTable(Id) ON DELETE CASCADE,
    CONSTRAINT FK_UsersMeals_Meal FOREIGN KEY(MealId) REFERENCES dbo.MealsTable(Id) ON DELETE CASCADE
);
GO

CREATE TABLE dbo.IngredientTable
(
    MealId INT NOT NULL,
    IngredientName NVARCHAR(120) NOT NULL,
    CONSTRAINT PK_Ingredients PRIMARY KEY(MealId, IngredientName),
    CONSTRAINT FK_Ingredients_Meal FOREIGN KEY(MealId) REFERENCES dbo.MealsTable(Id) ON DELETE CASCADE
);
GO

CREATE OR ALTER PROCEDURE dbo.spUsers_SelectAll
AS
BEGIN
    SELECT * FROM dbo.UsersTable;
END
GO

CREATE OR ALTER PROCEDURE dbo.spUsers_SelectById
    @Id INT
AS
BEGIN
    SELECT * FROM dbo.UsersTable WHERE Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE dbo.spUsers_Insert
    @Name NVARCHAR(60),
    @Email NVARCHAR(120),
    @Password NVARCHAR(120),
    @Active BIT,
    @NewId INT OUTPUT
AS
BEGIN
    INSERT INTO dbo.UsersTable(Name, Email, [Password], Active)
    VALUES(@Name, @Email, @Password, @Active);

    SET @NewId = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE dbo.spUsers_Update
    @Id INT,
    @Name NVARCHAR(60),
    @Email NVARCHAR(120),
    @Password NVARCHAR(120),
    @Active BIT
AS
BEGIN
    UPDATE dbo.UsersTable
    SET Name=@Name,
        Email=@Email,
        [Password]=@Password,
        Active=@Active
    WHERE Id=@Id;

    SELECT @@ROWCOUNT AS AffectedRows;
END
GO

CREATE OR ALTER PROCEDURE dbo.spUsers_Delete
    @Id INT
AS
BEGIN
    DELETE FROM dbo.UsersTable WHERE Id=@Id;
    SELECT @@ROWCOUNT AS AffectedRows;
END
GO

CREATE OR ALTER PROCEDURE dbo.spUsers_Login
    @Email NVARCHAR(120),
    @Password NVARCHAR(120)
AS
BEGIN
    SELECT TOP 1 *
    FROM dbo.UsersTable
    WHERE Email=@Email AND [Password]=@Password AND Active=1;
END
GO

CREATE OR ALTER PROCEDURE dbo.spMeals_SelectAllWithIngredients
    @Name NVARCHAR(120) = NULL
AS
BEGIN
    SELECT m.*, i.IngredientName
    FROM dbo.MealsTable m
    LEFT JOIN dbo.IngredientTable i ON i.MealId = m.Id
    WHERE (@Name IS NULL OR m.Name LIKE '%' + @Name + '%')
    ORDER BY m.Id;
END
GO

CREATE OR ALTER PROCEDURE dbo.spMeals_SelectByIdWithIngredients
    @Id INT
AS
BEGIN
    SELECT m.*, i.IngredientName
    FROM dbo.MealsTable m
    LEFT JOIN dbo.IngredientTable i ON i.MealId = m.Id
    WHERE m.Id=@Id;
END
GO

CREATE OR ALTER PROCEDURE dbo.spMeals_Insert
    @Name NVARCHAR(120),
    @Category NVARCHAR(60)=NULL,
    @Area NVARCHAR(60)=NULL,
    @Instructions NVARCHAR(MAX)=NULL,
    @Image NVARCHAR(400)=NULL,
    @Video NVARCHAR(400)=NULL,
    @Source NVARCHAR(400)=NULL,
    @IngredientsCsv NVARCHAR(MAX)=NULL,
    @NewId INT OUTPUT
AS
BEGIN
    INSERT INTO dbo.MealsTable(Name, Category, Area, Instructions, Image, Video, Source)
    VALUES(@Name, @Category, @Area, @Instructions, @Image, @Video, @Source);

    SET @NewId = SCOPE_IDENTITY();

    -- Insert ingredients (if provided)
    IF (@IngredientsCsv IS NOT NULL AND LEN(LTRIM(RTRIM(@IngredientsCsv))) > 0)
    BEGIN
        INSERT INTO dbo.IngredientTable(MealId, IngredientName)
        SELECT @NewId, LTRIM(RTRIM(value))
        FROM STRING_SPLIT(@IngredientsCsv, ',')
        WHERE LTRIM(RTRIM(value)) <> '';
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.spMeals_Update
    @Id INT,
    @Name NVARCHAR(120),
    @Category NVARCHAR(60)=NULL,
    @Area NVARCHAR(60)=NULL,
    @Instructions NVARCHAR(MAX)=NULL,
    @Image NVARCHAR(400)=NULL,
    @Video NVARCHAR(400)=NULL,
    @Source NVARCHAR(400)=NULL,
    @IngredientsCsv NVARCHAR(MAX)=NULL
AS
BEGIN
    UPDATE dbo.MealsTable
    SET Name=@Name,
        Category=@Category,
        Area=@Area,
        Instructions=@Instructions,
        Image=@Image,
        Video=@Video,
        Source=@Source
    WHERE Id=@Id;

    -- Replace ingredients
    DELETE FROM dbo.IngredientTable WHERE MealId=@Id;

    IF (@IngredientsCsv IS NOT NULL AND LEN(LTRIM(RTRIM(@IngredientsCsv))) > 0)
    BEGIN
        INSERT INTO dbo.IngredientTable(MealId, IngredientName)
        SELECT @Id, LTRIM(RTRIM(value))
        FROM STRING_SPLIT(@IngredientsCsv, ',')
        WHERE LTRIM(RTRIM(value)) <> '';
    END

    SELECT @@ROWCOUNT AS AffectedRows;
END
GO

CREATE OR ALTER PROCEDURE dbo.spMeals_Delete
    @Id INT
AS
BEGIN
    DELETE FROM dbo.MealsTable WHERE Id=@Id;
    SELECT @@ROWCOUNT AS AffectedRows;
END
GO

-- Distinct ingredients
CREATE OR ALTER PROCEDURE dbo.spIngredients_SelectDistinct
AS
BEGIN
    SELECT DISTINCT IngredientName
    FROM dbo.IngredientTable
    ORDER BY IngredientName;
END
GO

-- Meals that contain ALL given ingredients
CREATE OR ALTER PROCEDURE dbo.spMeals_SelectByIngredientsWithIngredients
    @IngredientsCsv NVARCHAR(MAX)
AS
BEGIN
    DECLARE @t TABLE (IngredientName NVARCHAR(120));
    INSERT INTO @t(IngredientName)
    SELECT DISTINCT LTRIM(RTRIM(value))
    FROM STRING_SPLIT(@IngredientsCsv, ',')
    WHERE LTRIM(RTRIM(value)) <> '';

    DECLARE @cnt INT = (SELECT COUNT(*) FROM @t);

    SELECT m.*, i.IngredientName
    FROM dbo.MealsTable m
    LEFT JOIN dbo.IngredientTable i ON i.MealId = m.Id
    WHERE m.Id IN
    (
        SELECT MealId
        FROM dbo.IngredientTable
        WHERE IngredientName IN (SELECT IngredientName FROM @t)
        GROUP BY MealId
        HAVING COUNT(DISTINCT IngredientName) = @cnt
    )
    ORDER BY m.Id;
END
GO
CREATE OR ALTER PROCEDURE dbo.spUsersMeals_GetUserMeals
    @UserId INT,
    @Name NVARCHAR(120)=NULL
AS
BEGIN
    SELECT m.*, i.IngredientName
    FROM dbo.UsersMealsTable um
    INNER JOIN dbo.MealsTable m ON m.Id = um.MealId
    LEFT JOIN dbo.IngredientTable i ON i.MealId = m.Id
    WHERE um.UserId = @UserId
      AND (@Name IS NULL OR m.Name LIKE '%' + @Name + '%')
    ORDER BY m.Id;
END
GO

CREATE OR ALTER PROCEDURE dbo.spUsersMeals_AddMealToUser
    @UserId INT,
    @MealId INT,
    @IngredientsCsv NVARCHAR(MAX)=NULL
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.UsersMealsTable WHERE UserId=@UserId AND MealId=@MealId)
    BEGIN
        INSERT INTO dbo.UsersMealsTable(UserId, MealId)
        VALUES(@UserId, @MealId);
    END

    -- Insert ingredients if provided (requirement)
    IF (@IngredientsCsv IS NOT NULL AND LEN(LTRIM(RTRIM(@IngredientsCsv))) > 0)
    BEGIN
        INSERT INTO dbo.IngredientTable(MealId, IngredientName)
        SELECT @MealId, LTRIM(RTRIM(value))
        FROM STRING_SPLIT(@IngredientsCsv, ',') s
        WHERE LTRIM(RTRIM(value)) <> ''
          AND NOT EXISTS (
              SELECT 1 FROM dbo.IngredientTable it
              WHERE it.MealId=@MealId AND it.IngredientName=LTRIM(RTRIM(s.value))
          );
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.spUsersMeals_RemoveMealFromUser
    @UserId INT,
    @MealId INT
AS
BEGIN
    DELETE FROM dbo.UsersMealsTable WHERE UserId=@UserId AND MealId=@MealId;
    SELECT @@ROWCOUNT AS AffectedRows;
END
GO

select * 
from UsersTable
