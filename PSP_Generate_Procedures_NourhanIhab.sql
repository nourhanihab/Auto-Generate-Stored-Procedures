use Northwind
go
Create PROCEDURE PSP_Generate_Procedures
	@TableName sysname 
AS
BEGIN


	Declare @insertSPName Varchar(50), @updateSPName Varchar(50), @deleteSPName Varchar(50), @selectSPName Varchar(50),@selectAllSPName Varchar(50) ;
	Declare @tablColumnParameters   Varchar(max);
	Declare @tableColumns           Varchar(max)
	Declare @tableColumnVariables   Varchar(max);
	Declare @tablColumnParametersUpdate Varchar(max);
	Declare @tableCols	    Varchar(max);
	Declare @space			Varchar(50)  ;
	Declare @colName 		Varchar(100) ;
	Declare @colVariable	Varchar(100) ;
	Declare @colParameter	Varchar(100) ;
	Declare @colIdentity	bit			 ;
	Declare @strSpText		Varchar(max);
	Declare @updCols		Varchar(max);
	Declare @selectCols		Varchar(max);
	Declare @delParamCols	Varchar(max);
	Declare @whereCols		Varchar(max);

	----------------------------------------
	--Naming for the stored procedures names
	----------------------------------------
	Set		@insertSPName      = '[dbo].[Psp_Insert_' + @TableName +']' ;
	Set		@updateSPName      = '[dbo].[Psp_Update_' + @TableName +']' ;
	Set		@deleteSPName      = '[dbo].[Psp_Delete_' + @TableName +']' ;
	Set		@selectSPName      = '[dbo].[Psp_Select_' + @TableName +']' ;
	Set		@selectAllSPName   = '[dbo].[Psp_SelectAll_' + @TableName +']' ;
	-----------------------------------------------

	Set		@space				  = '    ';
	Set		@tablColumnParameters = '' ;
	Set		@tableColumns		  = '' ;
	Set		@tableColumnVariables = '' ;
	Set		@strSPText			  = '' ;
	Set		@tableCols			  = '' ;
	Set		@updCols			  = '' ;
	Set     @selectCols           = '' ;
	Set		@delParamCols		  = '' ;
	Set		@whereCols			  = '' ;
	Set		@tablColumnParametersUpdate = '' ;
	SET NOCOUNT ON 

	-- Get all columns & data types for a table 
	--Declare @TableName Varchar(max);
	--Set @TableName = 'Employees'
	-- select * from sys.columns
	SELECT distinct
			COLUMNPROPERTY(syscolumns.id, syscolumns.name, 'IsIdentity') as 'IsIdentity',
			sysobjects.name as 'Table', 
			syscolumns.colid ,
			'[' + syscolumns.name + ']' as 'ColumnName',
			'@'+syscolumns.name  as 'ColumnVariable',
	--INTERNET BASED HELP AND WHEN I REMOVE THOSE NUMBERS I GET COLUMN WIDTH ERROR--
			
	systypes.name + 	
	Case  When  systypes.xusertype in (165,167,175,231,239 ) Then '(' + REPLACE(Convert(varchar(10),syscolumns.prec),'-1','max')  +')' Else '' end as 'DataType' ,
			'@'+syscolumns.name  + '  ' + systypes.name +
	Case  When  systypes.xusertype in (165,167,175,231,239 ) Then '(' + REPLACE(Convert(varchar(10),syscolumns.prec),'-1','max') +')' Else '' end as 'ColumnParameter'

	Into	my_temp_table	
	From	sysobjects , syscolumns ,  systypes
	Where	sysobjects.id			 = syscolumns.id
			and syscolumns.xusertype = systypes.xusertype
			and sysobjects.xtype	 = 'u'
			and sysobjects.name		 = @TableName
			and systypes.xusertype not in (189)
	Order by syscolumns.colid


	--print (systypes.xusertype)
------------------------------------------
	--Select * from my_temp_table
-------------------------------------------
	-- Get all Primary KEY columns & data types for a table 
	SELECT		t.name as 'Table', 
				c.colid ,
				'[' + c.name + ']' as 'ColumnName',
				'@'+c.name  as 'ColumnVariable',
				systypes.name + 
		Case  When  systypes.xusertype in (165,167,175,231,239 ) Then '(' + Convert(varchar(10),c.length) +')' Else '' end as 'DataType' ,
				'@'+c.name  + '  ' + systypes.name + 
		Case  When  systypes.xusertype in (165,167,175,231,239 ) Then '(' + Convert(varchar(10),c.length) +')' Else '' end as 'ColumnParameter'
	Into	my_temp_pk_table 	
	FROM    sysindexes i, sysobjects t, sysindexkeys k, syscolumns c, systypes
	WHERE	i.id = t.id	 AND
			i.indid = k.indid  AND i.id = k.ID And
			c.id = t.id    AND c.colid = k.colid AND  
			i.indid BETWEEN 1 And 254  AND 
			c.xusertype = systypes.xusertype AND
			(i.status & 2048) = 2048 AND t.id = OBJECT_ID(@TableName)



-------------------------------------------------------
-- CHECKING THE TABLE STRUCTURE AND ADDING VARIABLES --
-------------------------------------------------------

	Declare Cursor1 Cursor For
		Select ColumnName, ColumnVariable, ColumnParameter, IsIdentity
		From my_temp_table 

	Open Cursor1

	Fetch Next From Cursor1 Into @colName,  @colVariable, @colParameter, @colIdentity
	While @@FETCH_STATUS = 0
	Begin
				--IF IT IS NOT IDENTITY--
		If (@colIdentity=0)
		Begin
			Set @tablColumnParameters   = @tablColumnParameters + @colParameter + CHAR(13) + @space + ',' ; 
			Set @tableCols				= @tableCols + @colName +  ',' ; 		
			Set @tableColumns			= @tableColumns + @colName + CHAR(13) + @space + @space + ',' ; 		
			Set @tableColumnVariables   = @tableColumnVariables + @colVariable + CHAR(13) + @space + @space + ',' ; 
			Set @updCols				= @updCols + @colName + ' = ' + @colVariable + CHAR(13) + @space + @space + ',' ; 
		End
		Set @tablColumnParametersUpdate   = @tablColumnParametersUpdate + @colParameter + CHAR(13) + @space + ',' ; 

	    Fetch Next From Cursor1 Into @colName,  @colVariable, @colParameter , @colIdentity
	End

	Close Cursor1
	Deallocate Cursor1

	-- CHECK PRIMARY KEYS--
	Declare Cursor2 Cursor For
		Select ColumnName, ColumnVariable, ColumnParameter
		From my_temp_pk_table 

	Open Cursor2

	Fetch Next From Cursor2 Into @colName,  @colVariable, @colParameter
	While @@FETCH_STATUS = 0
	Begin
		Set @delParamCols   = @delParamCols + @colParameter + CHAR(13) + @space + ',' ; 
		Set @whereCols		= @whereCols + @colName + ' = ' + @colVariable + ' AND '  ; 
	    Fetch Next From Cursor2 Into @colName,  @colVariable, @colParameter 
	End

	Close Cursor2
	Deallocate Cursor2

	-- PROCEDUREEEEEEE --
	If (LEN(@tablColumnParameters)>0)
	Begin 
		Set @tablColumnParameters	= LEFT(@tablColumnParameters,LEN(@tablColumnParameters)-1) ;
		Set @tablColumnParametersUpdate	= LEFT(@tablColumnParametersUpdate,LEN(@tablColumnParametersUpdate)-1) ;
		Set @tableColumnVariables	= LEFT(@tableColumnVariables,LEN(@tableColumnVariables)-1) ;
		Set @tableColumns			= LEFT(@tableColumns,LEN(@tableColumns)-1) ;
		Set @tableCols				= LEFT(@tableCols,LEN(@tableCols)-1) ;
		Set @updCols				= LEFT(@updCols,LEN(@updCols)-1) ;

		If (LEN(@whereCols)>0)
		Begin 
			Set @whereCols			= 'WHERE ' + LEFT(@whereCols,LEN(@whereCols)-4) ;
			Set @delParamCols		= LEFT(@delParamCols,LEN(@delParamCols)-1) ;
		End



				
			-- Create SELECT stored procedure for the table if it does not exist 
		IF  Not EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(@selectALLSPName) AND OBJECTPROPERTY(id,N'IsProcedure') = 1)
		Begin
			Set @strSPText = ''
			Set @strSPText = @strSPText +  CHAR(13) + 'CREATE PROCEDURE ' + @selectALLSPName
	--		Set @strSPText = @strSPText +  CHAR(13) + @space + ' ' + @delParamCols
			Set @strSPText = @strSPText +  CHAR(13) + 'AS'
			Set @strSPText = @strSPText +  CHAR(13) + 'BEGIN'
			Set @strSPText = @strSPText +  CHAR(13) + ''
			Set @strSPText = @strSPText +  CHAR(13) + @space + 'SELECT * FROM '+@TableName 
 --			Set @strSPText = @strSPText +  CHAR(13) + @space + @whereCols +';'
			Set @strSPText = @strSPText +  CHAR(13) + ''
			Set @strSPText = @strSPText +  CHAR(13) + 'END'
			Set @strSPText = @strSPText +  CHAR(13) + ''
			Set @strSPText = @strSPText +  CHAR(13) + ''
		--	Print @strSPText ;
			Exec(@strSPText);

			if (@@ERROR=0) 
				Print 'Procedure ' + @selectALLSPName + ' Created!!!!!!!!!!!!!! '

		End
		Else
		Begin
			Print '  ' + @selectALLSPName + ' Already exists!!'
		End


		
		
		-- Create INSERT stored procedure 
		IF  Not EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(@insertSPName) AND OBJECTPROPERTY(id,N'IsProcedure') = 1)
		Begin
			Set @strSPText = ''
			Set @strSPText = @strSPText +  CHAR(13) + 'CREATE PROCEDURE ' + @insertSPName
			Set @strSPText = @strSPText +  CHAR(13) + @space + ' ' + @tablColumnParameters
			Set @strSPText = @strSPText +  CHAR(13) + 'AS'
			Set @strSPText = @strSPText +  CHAR(13) + 'BEGIN'
			Set @strSPText = @strSPText +  CHAR(13) + ''
			Set @strSPText = @strSPText +  CHAR(13) + @space + 'INSERT INTO '+@TableName  
			Set @strSPText = @strSPText +  CHAR(13) + @space + '( ' 
			Set @strSPText = @strSPText +  CHAR(13) + @space + @space + ' ' + @tableColumns  
			Set @strSPText = @strSPText +  CHAR(13) + @space + ')'
			Set @strSPText = @strSPText +  CHAR(13) + @space + 'VALUES'
			Set @strSPText = @strSPText +  CHAR(13) + @space + '('
			Set @strSPText = @strSPText +  CHAR(13) + @space + @space + ' ' + @tableColumnVariables
			Set @strSPText = @strSPText +  CHAR(13) + @space + ')'
			Set @strSPText = @strSPText +  CHAR(13) + 'END'
			Set @strSPText = @strSPText +  CHAR(13) + ''
			Set @strSPText = @strSPText +  CHAR(13) + ''
			Set @strSPText = @strSPText +  CHAR(13) + ''
--			Print @strSPText ;

			Exec(@strSPText);

			if (@@ERROR=0) 
				Print 'Procedure ' + @insertSPName + ' Created!!!!!!!!!!!!!!'

		End
		Else
		Begin
			Print '  ' + @insertSPName + ' Already exists!! '
		End




		-- Create SELECT stored procedure 
		IF  Not EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(@selectSPName) AND OBJECTPROPERTY(id,N'IsProcedure') = 1)
		Begin
			Set @strSPText =''
			Set @strSPText = @strSPText +  CHAR(13) + 'CREATE PROCEDURE ' + @selectSPName
			Set @strSPText = @strSPText +  CHAR(13) + @space + ' ' + @delParamCols
			Set @strSPText = @strSPText +  CHAR(13) + 'AS'
			Set @strSPText = @strSPText +  CHAR(13) + 'BEGIN'
			Set @strSPText = @strSPText +  CHAR(13) + ''
			Set @strSPText = @strSPText +  CHAR(13) + @space + 'SELECT * FROM '+@TableName
			Set @strSPText = @strSPText +  CHAR(13) + @space + @whereCols +';'
			Set @strSPText = @strSPText +  CHAR(13) + ''
			Set @strSPText = @strSPText +  CHAR(13) + 'END'
			Set @strSPText = @strSPText +  CHAR(13) + ''
			Set @strSPText = @strSPText +  CHAR(13) + ''
			-- Print @strSPText ;
			Exec(@strSPText);

			if (@@ERROR=0) 
				Print 'Procedure ' + @selectSPName + ' Created!!!!!!!!!!!!!!'

		End
		Else
		Begin
			Print '  ' + @selectSPName + ' Already exists!! '
		End

		
		



		-- Create UPDATE stored procedure 
		IF  Not EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(@updateSPName) AND OBJECTPROPERTY(id,N'IsProcedure') = 1)
		Begin
			Set @strSPText = ''
			Set @strSPText = @strSPText +  CHAR(13) + 'CREATE PROCEDURE ' + @updateSPName
			Set @strSPText = @strSPText +  CHAR(13) + @space + ' ' + @tablColumnParametersUpdate
			Set @strSPText = @strSPText +  CHAR(13) + 'AS'
			Set @strSPText = @strSPText +  CHAR(13) + 'BEGIN'
			Set @strSPText = @strSPText +  CHAR(13) + ''
			Set @strSPText = @strSPText +  CHAR(13) + @space + 'UPDATE '+@TableName 
			Set @strSPText = @strSPText +  CHAR(13) + @space + 'SET ' 
			Set @strSPText = @strSPText +  CHAR(13) + @space + @space + ' ' + @updCols  
			Set @strSPText = @strSPText +  CHAR(13) + @space + @whereCols
			Set @strSPText = @strSPText +  CHAR(13) + ''
			Set @strSPText = @strSPText +  CHAR(13) + 'END'
			Set @strSPText = @strSPText +  CHAR(13) + ''
			Set @strSPText = @strSPText +  CHAR(13) + ''
--			Print @strSPText ;
			Exec(@strSPText);

			if (@@ERROR=0) 
				Print 'Procedure ' + @updateSPName + ' Created!!!!!!!!!!!!!! '
		End
		Else
		Begin
			Print '  ' + @updateSPName + ' Already exists!! '
		End
		--  Create DELETE stored procedure 
		IF  Not EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(@deleteSPName) AND OBJECTPROPERTY(id,N'IsProcedure') = 1)
		Begin
			Set @strSPText = ''
			Set @strSPText = @strSPText +  CHAR(13) + 'CREATE PROCEDURE ' + @deleteSPName
			Set @strSPText = @strSPText +  CHAR(13) + @space + ' ' + @delParamCols
			Set @strSPText = @strSPText +  CHAR(13) + 'AS'
			Set @strSPText = @strSPText +  CHAR(13) + 'BEGIN'
			Set @strSPText = @strSPText +  CHAR(13) + ''
			Set @strSPText = @strSPText +  CHAR(13) + @space + 'DELETE FROM '+@TableName 
			Set @strSPText = @strSPText +  CHAR(13) + @space + @whereCols
			Set @strSPText = @strSPText +  CHAR(13) + ''
			Set @strSPText = @strSPText +  CHAR(13) + 'END'
			Set @strSPText = @strSPText +  CHAR(13) + ''
			Set @strSPText = @strSPText +  CHAR(13) + ''
		--		Print @strSPText ;
		--	Print 'EMPTY!!' + @whereCols;
			Exec(@strSPText);

			if (@@ERROR=0) 
				Print 'Procedure ' + @deleteSPName + ' Created!!!!!!!!!!!!!! '
		End
		Else
		Begin
			Print '  ' + @deleteSPName + ' Already exists!! '
		End
		
		
		

	
	End
	Drop table my_temp_table 
	Drop table my_temp_pk_table 

END

Exec PSP_Generate_Procedures 'Region'

