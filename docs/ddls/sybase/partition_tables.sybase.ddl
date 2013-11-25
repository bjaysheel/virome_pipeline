-- partitiontables  sql2Chado.pl parses this first line
--
-- Author:         Jay Sundaram sundaram@tigr.org
-- Date Modified:  2005-07-18 
-- Schema:         Chado
-- CVS:            ANNOTATION/chado/tigr_schemas/chado_template/ALL_Modules/partition_tables.ddl
-- Version:        $Id: partition_tables.sybase.ddl 3317 2007-02-09 20:59:19Z sundaram $ -- chado-v1r3b3
--

-- Contains all the SQL statements required to partition the specified tables
--
---------------------------------------------------------
--
-- Module: Computational Analysis
--
---------------------------------------------------------
ALTER TABLE analysisfeature PARTITION 3;

---------------------------------------------------------
--
-- Module: Sequence
--
---------------------------------------------------------
ALTER TABLE featureprop PARTITION 3;
ALTER TABLE featureloc PARTITION 3;
ALTER TABLE feature PARTITION 3;

---------------------------------------------------------
--
-- Module: General
--
---------------------------------------------------------
ALTER TABLE dbxref PARTITION 3;
