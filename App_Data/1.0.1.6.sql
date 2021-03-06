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