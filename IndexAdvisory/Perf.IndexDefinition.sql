USE [PerformanceLogging]
GO

/****** Object:  Table [perf].[IndexAdvisory]    Script Date: 5/26/2025 11:56:07 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [perf].[IndexDefinition](
	[Instance] [nvarchar](255) NULL,
	[DatabaseName] [nvarchar](255) NULL,
	[SchemaName] [nvarchar](255) NULL,
	[TableName] [nvarchar](255) NULL,
	[IndexName] [nvarchar](255) NULL,
	[PrimaryKey] [bit] NULL,
	[Cluster] [bit] NULL,
	[UniqueKey] [bit] NULL,  
	[KeyColumns] nvarchar(500) NULL,
	[Includes] nvarchar(2000) NULL,
	[Filter] nvarchar(250) NULL,
	[CollectionDate] [date] NULL
) ON [PRIMARY]  

CREATE CLUSTERED INDEX [CX_IndexDefinition_Schema_Table_Index] ON [perf].[IndexDefinition]
(
	[SchemaName] ASC,
	[TableName] ASC,
	[IndexName] ASC
)
ALTER TABLE [perf].[IndexDefinition] ADD  CONSTRAINT [DF_IndexDefinition_CollectionDate]  DEFAULT (getdate()) FOR [CollectionDate]
GO
 