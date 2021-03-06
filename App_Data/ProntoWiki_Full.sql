SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Attachments]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[Attachments](
	[AttachmentID] [uniqueidentifier] ROWGUIDCOL  NOT NULL CONSTRAINT [DF_Attachments_AttachmentID]  DEFAULT (newid()),
	[PageName] [varchar](50) NOT NULL,
	[AttachmentName] [varchar](256) NOT NULL,
	[AttachmentData] [image] NOT NULL,
	[Extension] [varchar](4) NULL,
	[ChangedBy] [nvarchar](256) NULL,
	[Modified] [timestamp] NULL,
 CONSTRAINT [PK_Attachments_1] PRIMARY KEY CLUSTERED 
(
	[AttachmentID] ASC
)WITH (IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Wiki]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[Wiki](
	[PageName] [varchar](50) NOT NULL,
	[PageText] [text] NOT NULL,
	[Version] [int] NOT NULL,
	[ChangedBy] [nvarchar](256) NOT NULL,
	[CreatedTime] [datetime] NOT NULL,
	[HitCount] [int] NOT NULL,
 CONSTRAINT [PK_Wiki] PRIMARY KEY CLUSTERED 
(
	[PageName] ASC
)WITH (IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[Wiki]') AND name = N'IDX_PageName')
CREATE NONCLUSTERED INDEX [IDX_PageName] ON [dbo].[Wiki] 
(
	[PageName] ASC
)WITH (IGNORE_DUP_KEY = OFF) ON [PRIMARY]
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[History]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[History](
	[PageName] [varchar](50) NOT NULL,
	[PageText] [text] NOT NULL,
	[Version] [int] NOT NULL,
	[ChangedBy] [nvarchar](256) NOT NULL,
	[CreatedTime] [datetime] NOT NULL,
	[HitCount] [int] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[w_UpdatePage]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[w_UpdatePage]
	(
	@PageName varchar(50),
	@PageText text,
	@UserID	nvarchar(256)
	)
	
AS
	Declare @Version int

	--Update the Version History	

	Select @Version = w.Version From Wiki w Where PageName = @PageName	

	INSERT into History
		SELECT PageName, PageText, Version, ChangedBy, CreatedTime, HitCount FROM Wiki WHERE Wiki.PageName=@PageName
	
	--Now update the Wiki
	
	Update Wiki Set 
		PageText = @PageText,
		ChangedBy = @UserID,
		Version = @Version + 1,
		CreatedTime = GetDate()
	WHERE PageName = @PageName


	RETURN
' 
END
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[w_GetLinks]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[w_GetLinks]
AS
	SELECT PageName From Wiki
	RETURN
' 
END
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[w_GetHistory]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[w_GetHistory]
	(
	@PageName varchar(50)
	)

AS
    SELECT PageName, Version, ChangedBy, CreatedTime, HitCount FROM Wiki
        WHERE PageName = @PageName
	UNION
	SELECT PageName, Version, ChangedBy, CreatedTime, HitCount FROM History
        WHERE PageName = @PageName     
        ORDER BY Version DESC
	RETURN
' 
END
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[w_InsertPage]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[w_InsertPage] 
	(
	@PageName varchar(50),
	@PageText text,
	@User nvarchar(256)
	)
AS
	
	Declare @Version int
	Declare @HitCount int

	--If the page was deleted, we must get the last version from the history
	If Exists(Select PageName From History Where PageName = @PageName)
		Select Top 1 @Version = Version + 1, @HitCount = HitCount From History Where PageName = @PageName Order By Version Desc		
	Else
	BEGIN
		Set @Version = 0
		Set @HitCount = 0
	END

	Insert into Wiki (PageName, PageText, Version, ChangedBy, CreatedTime, HitCount)
		VALUES (@PageName, @PageText, @Version, @User, GetDate(), @HitCount)

	RETURN
' 
END
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[w_GetPage]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[w_GetPage]
	
	(
		@PageName varchar(50),
		@IncrementHitCount bit	
	)
	
AS
	Declare @HitCount int
	
	IF EXISTS(SELECT * from Wiki Where PageName = @PageName)
	BEGIN
		if @IncrementHitCount > 0
		BEGIN
			Select @HitCount = HitCount From Wiki Where PageName = @PageName		
			Update Wiki Set HitCount = (@HitCount + 1) WHERE PageName = @PageName 
		END
		Select PageName, PageText, Version, ChangedBy, CreatedTime, HitCount FROM Wiki Where PageName = @PageName
	End
	
	RETURN	
' 
END
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[w_DeletePage]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[w_DeletePage] 
	(
	@PageName varchar(50)
	)
	
AS
	--move the current version into the history table
	INSERT into History
	SELECT PageName, PageText, Version, ChangedBy, CreatedTime, HitCount FROM Wiki WHERE Wiki.PageName=@PageName
		
	--Remove from the list of wikis
	Delete from Wiki Where PageName = @PageName		
	 
	RETURN
' 
END
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[w_SearchSimpleTerm]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'Create PROCEDURE [dbo].[w_SearchSimpleTerm]

	(
	@parameter varchar(50)
	
	)
	
AS	
	Select PageName, PageText from wiki where pagename Like @parameter OR PageText LIKE @parameter order by hitcount desc  
	
	RETURN
' 
END
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[w_GetPageByVersion]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[w_GetPageByVersion]
	(
	@PageName varchar(50),
	@Version int
	)
AS
	if Not Exists(Select * From Wiki Where PageName = @PageName And Version = @Version)
		Select * from History Where PageName = @PageName And Version = @Version
	Else
		Select * From Wiki Where PageName = @PageName And Version = @Version
	
	RETURN
' 
END
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Tags]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[Tags](
	[PageName] [varchar](50) NOT NULL,
	[Tag] [varchar](64) NOT NULL,
	[UserName] [nvarchar](256) NULL
) ON [PRIMARY]
END
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[w_GetTags]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[w_GetTags] 	
	(
		@PageName VarChar(50),
		@UserName nvarchar(256)
	)	
AS
	if (@UserName = '''')
		Select Distinct Tag From Tags Where PageName = @PageName
	else
		Select Distinct Tag from Tags Where PageName = @PageName and UserName = @UserName
	
' 
END
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[w_GetPageNamesByTag]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[w_GetPageNamesByTag]
	(
	@Tag varchar(50),
	@MaxFontSize int,
	@MinFontSize int
	)
AS
	Declare @topCount int;
	Declare @pageCount int;
	Declare @weight float(10);
	Set @topCount = (Select top 1 count(*) from Tags where Tag = @Tag group by PageName order by count(*) desc)
	set @weight = (Select ((cast(@MaxFontSize-@MinFontSize as float))/@topCount))	
	
	Select PageName, (@weight * count(*) + @MinFontSize) as WeightedScore 
	from Tags
	where Tag = @Tag  	 
	group by PageName
	order by (NewId())
	' 
END
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[w_GetTagsByPage]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[w_GetTagsByPage]
	(
	@PageName varchar(50),
	@MaxFontSize int,
	@MinFontSize int
	)
AS
	Declare @topCount int;
	Declare @tagCount int;
	Declare @weight float(10);
	Set @topCount = (Select top 1 count(*) from Tags where PageName = @PageName group by Tag order by count(*) desc)
	set @weight = (Select ((cast(@MaxFontSize-@MinFontSize as float))/@topCount))	
	
	Select Tag, (@weight * count(*) + @MinFontSize) as WeightedScore 
	from Tags
	where PageName = @PageName  	 
	group by Tag
	order by (NewId())
	' 
END
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[w_GetTagsByUser]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[w_GetTagsByUser]
	(
	@UserName nvarchar(256),
	@MaxFontSize int,
	@MinFontSize int
	)
AS
	--weighting seems off here...
	Declare @topCount int;
	Declare @tagCount int;
	Declare @weight float(10);
	Set @topCount = (Select top 1 count(*) from Tags Where Tag In (Select Tag From Tags Where UserName = @UserName) group by Tag order by count(*) desc)
	set @weight = (Select ((cast(@MaxFontSize-@MinFontSize as float))/@topCount))	
	
	Select Tag, (@weight * count(*) + @MinFontSize) as WeightedScore 
	from Tags
	where UserName = @UserName  	 
	group by Tag
	order by Tag
	' 
END
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[w_DeleteTag]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[w_DeleteTag] 
	(
		@PageName VarChar(50),
		@Tag VarChar(64),
		@UserName nvarchar(256),
		@DeleteAll bit
	)
AS
	if (@DeleteAll = 1)
		Delete from Tags Where PageName = @PageName And Tag = @Tag
	else
		Delete from Tags Where PageName = @PageName And Tag = @Tag and UserName = @UserName;
	RETURN
' 
END
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[w_AddTag]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[w_AddTag] 
	(
	@PageName VarChar(50),
	@Tag VarChar(64),
	@UserName nvarchar(256)
	)
AS
	--only insert a record if the user has not already tagged this page
	If (Select count(*) from Tags Where PageName = @PageName And Tag = @Tag And UserName = @UserName) = 0 
		Insert into Tags (PageName, Tag, UserName) VALUES (@PageName, @Tag, @UserName)	
	
	RETURN
' 
END