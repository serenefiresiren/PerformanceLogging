# Table Index Advisory

Reports on index efficiency, identifies gaps, and highlights ones that are just bloat. It is advisable to run it across a few clients of varying sizes before making a move on a particular index or table. Ignores tables in the `sys` and `conversion` schemas, heaps, and tables with no index over 5MB. Statuses are more what you'd call 'intelligent guidelines' than actual rules. 

Requires [dbatools](https://dbatools.io/).


## Data Definition
Self-explanatory: Instance, DatabaseName, SchemaName, TableName, IndexName, IndexSizeMB, ReadWriteRatio
- <u>LegacyCE:</u> Indicates if Legacy Cardinality Estimator is on or off.
- <u>PK:</u> Index is the Primary Key. Note: Each table only has one.
- <u>CI:</u> Clustered Index. Note: Each table only has one, typically on the PK.
- <u>UC:</u> Unique Index. Note: Each table can have more than one. 
- <u>Status:</u> Based upon thresholds in the next step.
   - <u>No Status (-):</u> No tuning required or a single index table is too small to consider.
   - <u>Adequate:</u> Serves a purpose but could be better.
   - <u>Better CI Available:</u> The table already has a non-clustered index that would be a better candidate for the clustered.
   - <u>Bloat:</u> Non-clustered index is complete unused or receives only updates. An index with no searching and any amount of updates is just a performance hit.
   - <u>Fair:</u> Used but not well. Indicates possible dead weight, duplication, subset, and/or poor structuring.
   - <u>Great:</u> Index can remain as is. Still take into consideration within the table as a whole, especially when addressing lookups on the clustered.
   - <u>Less Efficient:</u> Indicates poor performance, possible dead weight, and/or poor structuring. Needs further review within the context of the table.
   - <u>Missing NCI:</u> One or more non-clustered indexes do not exist. Unlikely the current ones could be manipulated well enough to compensate. 
   - <u>Review All Indexes:</u> One or more things is functionally wrong given the metrics of both the clustered and non-clustered indexes.
   - <u>Review NCIs:</u> All non-clustered indexes need to be review due to the usage of the clustered.
   - <u>Review Table:</u> Indicates the clustered is likely correct, but the number of scans and lookups indicates one or more indexes are not comprehensive or structured well enough. No one problem could be identified.  


- <u>IndexSpaceUpdatedGB:</u> Total Updates * IndexSizeMB in GBs. Possibly start by largest amount of data being manipulated in a table to determine order of operation. 

## Key Data Points

Partition Stats
- <u>IndexSizeMB</u>: Calculated from index pages used into MB
   - SUM(Used Pages) * 8 / 1024.0
- <u>Rows</u>: Number of rows in the index.
   - Usually the same across the board by table, but it will differ on filtered indexes.
   - Rely on IndexSize more than Rows as depth of data can vary wildly between indexes and tables.
      - 1 Million records in a single column table <> 1 Million records in a table with a varchar(max) column
- <u>Reads:</u> Seeks + Scans + Lookups
- <u>Reads_ScL:</u> Scans + Lookups
- <u>IndexCount:</u> Total number of indexes
- <u>TotalReads_NCI:</u> Total scans and seeks for all table non-clustered indexes
- <u>MaxSeeks_NCI:</u> The highest total seeks across all table non-clustered indexes.

General Counts
- <u>FKCount:</u> Number of foreign keys defined **on** the table.
   - Status thresholds include searching for missing indexes to support FKs against the table. 
- <u>ColumnCount:</u> Tables with only 1 column are excluded by default as no further tuning can be done.

Dynamic Calculations
- <u>ReadWriteRatio:</u> Number of reads per write. Values rounded up.
   - No updates or reads --> Blank
   - Updates > 0
     - (Reads/Updates) >= (55% of Updates) --> (Reads/Updates):10
     - (Reads/Updates) >= (5.5% of Updates) --> ((Reads/Updates) * 10):10
     - (Reads/Updates) >= (.55% of Updates) --> ((Reads/Updates) * 100:100
     - (Reads/Updates) >= (.05% of Updates) --> ((Reads/Updates) * 10000:1000
     - Reads < (5% of Updates) --> 0:1
   - Else --> 1:0
## Thresholds In Roughly Precedence Order
**Note:** Your mileage may vary. Stay aware of table sizes to avoid spending times fixing scans on a table that is fine being scanned.

**Standalone Clustered Indexes**

|Status|Satisfying Conditions| OR | OR|
|--|--|--|--|
|No Status (-)|Only one column|No Reads or Writes|Size < 1MB| 

**Standalone Clustered Indexes pt.2**

Updates + Reads > 0

|Status|Satisfying Conditions| OR | OR|
|--|--|--|--|
|Missing NCI|Seeks < Scans|(Seeks + Scans) > (50% of Updates) && Seeks < (10% of Scans)|Updates > 0 && Seeks > 0 & Scans > 0|
|Great|Scans = 0 && Seeks > 0|(10% of Seeks) > Scans ||
|Adequate|(50% of Seeks) > Scans|Else|| 


**Clustered Indexes**

Table has at least one other index.

|Status|Satisfying Conditions| OR | OR|
|--|--|--|--|
|Better CI Available|Lookups <= MaxSeeks_NCI && Seeks < MaxSeeks_NCI|||
|Review NCIs|Seeks < Reads_ScL && Seeks > MaxSeeks_NCI|Lookups > (10% of Seeks) && Lookups < MaxSeeks_NCI||
|Review Table|Reads = 0 && Updates > 0|Lookups > MaxSeeks_NCI|Else|
|Great|Updates < TotalReads_NCI|Seeks > TotalReads_NCI|

**Non-Clustered Indexes**

|Status|Satisfying Conditions| OR | 
|--|--|--|
|Bloat|Updates > 0 && Reads < (5% of Updates)|
|Less Efficient|Updates > 0 && Reads < (10% of Updates)|Seeks < (Scans * 2)|
|Great|Scans = 0 && Updates < Seeks|Seeks > (Scans * 100)|
|Adequate| Else|
