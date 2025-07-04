CREATE TABLE [perf].[IndexSummary](
	[Instance] [nvarchar](255) NULL,
	[DatabaseName] [nvarchar](255) NULL,
	[SchemaName] [nvarchar](255) NULL,
	[TableName] [nvarchar](255) NULL,
	[IndexName] [nvarchar](255) NULL,
	[PrimaryKey] [bit] NULL,
	[Cluster] [bit] NULL,
	[UniqueKey] [bit] NULL,
	[KeyColumns] [nvarchar](500) NULL,
	[Includes] [nvarchar](2000) NULL,
	[Filter] [nvarchar](250) NULL,
	[Status] [nvarchar](50) NULL,
	[ReadWriteRatio] [nvarchar](20) NULL,
	[Updates] [int] NULL,
	[Seeks] [int] NULL,
	[Scans] [int] NULL,
	[Lookups] [int] NULL,
	[IndexSizeMB] [decimal](10, 2) NULL,
	[IndexSpaceUpdatedGB] [decimal](20, 2) NULL,
	[CollectionDate] [date] NOT NULL,
	[Reviewed] [bit] NOT NULL
) ON [PRIMARY]
GO

CREATE CLUSTERED INDEX [CX_IndexSummary_Schema_Table_Index] ON [perf].[IndexSummary]
(
	[SchemaName] ASC,
	[TableName] ASC,
	[IndexName] ASC
)
ALTER TABLE [perf].[IndexSummary] ADD  CONSTRAINT [DF_IndexSummary_CollectionDate]  DEFAULT (getdate()) FOR [CollectionDate]
GO

ALTER TABLE [perf].[IndexSummary] ADD  CONSTRAINT [DF_IndexSummary_Reviewed]  DEFAULT ((0)) FOR [Reviewed]
GO

