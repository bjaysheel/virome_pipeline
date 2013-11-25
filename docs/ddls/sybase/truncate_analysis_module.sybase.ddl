-- truncateanalysis  sql2Chado.pl parses this first line
--
-- Author:         Jay Sundaram sundaram@tigr.org
-- Date Modified:  2005-07-18 
-- Schema:         Chado
-- CVS:            ANNOTATION/chado/tigr_schemas/chado_template/ALL_Modules/truncate_analysis_module.ddl
-- Version:        $Id: truncate_analysis_module.sybase.ddl 3317 2007-02-09 20:59:19Z sundaram $ -- chado-v1r3b3
--
--
-- Contains all the SQL statements required to TRUNCATE all tables in the Computational Analysis Module;
--
---------------------------------------------------------
--
-- Module: Computational Analysis
--
---------------------------------------------------------
TRUNCATE TABLE analysisfeature;
TRUNCATE TABLE analysisprop;
TRUNCATE TABLE analysis;

---------------------------------------------------------
--
-- Module: Sequence
--
---------------------------------------------------------
TRUNCATE TABLE featureprop;
TRUNCATE TABLE featureloc;
TRUNCATE TABLE feature;





