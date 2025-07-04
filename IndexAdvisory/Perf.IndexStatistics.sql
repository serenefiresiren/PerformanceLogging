CREATE TABLE [perf].[IndexStatistics](
	[Instance] [nvarchar](255) NULL,
	[DatabaseName] [nvarchar](255) NULL,
	[SchemaName] [nvarchar](255) NULL,
	[TableName] [nvarchar](255) NULL,
	[IndexName] [nvarchar](255) NULL, 
	[Status] [nvarchar](50) NULL,
	[ReadWriteRatio] [nvarchar](20) NULL,
	[Updates] [int] NULL,
	[Seeks] [int] NULL,
	[Scans] [int] NULL,
	[Lookups] [int] NULL,
	[IndexSizeMB] [decimal](10, 2) NULL,
	[IndexSpaceUpdatedGB] [decimal](20, 2) NULL,
	[CollectionDate] [date] NOT NULL
) ON [PRIMARY]
GO

CREATE CLUSTERED INDEX [CX_IndexStatistics_Schema_Table_Index] ON [perf].IndexStatistics
(
	[SchemaName] ASC,
	[TableName] ASC,
	[IndexName] ASC
)
ALTER TABLE [perf].IndexStatistics ADD  CONSTRAINT [DF_IndexStatistics_CollectionDate]  DEFAULT (getdate()) FOR [CollectionDate]
GO
 
