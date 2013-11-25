-- grantselectpublic  sql2Chado.pl parses this first line
--
-- Author:         Jay Sundaram sundaram@tigr.org
-- Date Modified:  2005-07-18 
-- Schema:         Chado
-- CVS:            ANNOTATION/chado/tigr_schemas/chado_template/ALL_Modules/grant_select_all.ddl
-- Version:        $Id: grant_select_all.sybase.ddl 3317 2007-02-09 20:59:19Z sundaram $ -- chado-v1r3b3
--
-- Contains all the SQL statements required to grant select permissions to public
--
--
--
----------------------------------------------------------------------------------------------------------------

--------------------------------------------------------
--
-- Module: General
--
--------------------------------------------------------
	
GRANT SELECT ON tableinfo TO PUBLIC;
GRANT SELECT ON db TO PUBLIC;
GRANT SELECT ON dbxref TO PUBLIC;
GRANT SELECT ON project TO PUBLIC;

--------------------------------------------------------
--
-- Module: CV
--
--------------------------------------------------------
GRANT SELECT ON cv TO PUBLIC;
GRANT SELECT ON cvterm TO PUBLIC;
GRANT SELECT ON cvterm_relationship TO PUBLIC;
GRANT SELECT ON cvtermpath TO PUBLIC;
GRANT SELECT ON cvtermsynonym TO PUBLIC;
GRANT SELECT ON cvterm_dbxref TO PUBLIC;
GRANT SELECT ON cvtermprop TO PUBLIC;
GRANT SELECT ON dbxrefprop TO PUBLIC;

--------------------------------------------------------
--
-- Module: Pub
--
--------------------------------------------------------
GRANT SELECT ON pub TO PUBLIC;
GRANT SELECT ON pub_relationship TO PUBLIC;
GRANT SELECT ON pub_dbxref TO PUBLIC;
GRANT SELECT ON pubauthor TO PUBLIC;
GRANT SELECT ON pubprop TO PUBLIC;

--------------------------------------------------------
--
-- Module: Organism
--
--------------------------------------------------------
GRANT SELECT ON organism TO PUBLIC;
GRANT SELECT ON organism_dbxref TO PUBLIC;
GRANT SELECT ON organismprop TO PUBLIC;

--------------------------------------------------------
--
-- Module: Sequence
--
--------------------------------------------------------
GRANT SELECT ON feature TO PUBLIC;
GRANT SELECT ON featureloc TO PUBLIC;
GRANT SELECT ON feature_pub TO PUBLIC;
GRANT SELECT ON featureprop TO PUBLIC;
GRANT SELECT ON featureprop_pub TO PUBLIC;
GRANT SELECT ON feature_dbxref TO PUBLIC;
GRANT SELECT ON feature_relationship TO PUBLIC;
GRANT SELECT ON feature_relationship_pub TO PUBLIC;
GRANT SELECT ON feature_relationshipprop TO PUBLIC;
GRANT SELECT ON feature_relprop_pub TO PUBLIC;
GRANT SELECT ON feature_cvterm TO PUBLIC;
GRANT SELECT ON feature_cvtermprop TO PUBLIC;
GRANT SELECT ON feature_cvterm_pub TO PUBLIC;
GRANT SELECT ON feature_cvterm_dbxref TO PUBLIC;
GRANT SELECT ON synonym TO PUBLIC;
GRANT SELECT ON feature_synonym TO PUBLIC;

--------------------------------------------------------
--
-- Module: Computational Analysis
--
--------------------------------------------------------
GRANT SELECT ON analysis TO PUBLIC;
GRANT SELECT ON analysisprop TO PUBLIC;
GRANT SELECT ON analysisfeature TO PUBLIC;


--------------------------------------------------------
--
-- Module: Phylogeny
--
--------------------------------------------------------

GRANT SELECT ON phylotree TO PUBLIC;
GRANT SELECT ON phylotree_pub TO PUBLIC;
GRANT SELECT ON phylonode TO PUBLIC;
GRANT SELECT ON phylonode_dbxref TO PUBLIC;
GRANT SELECT ON phylonode_pub TO PUBLIC;
GRANT SELECT ON phylonode_organism TO PUBLIC;
GRANT SELECT ON phylonodeprop TO PUBLIC;
GRANT SELECT ON phylonode_relationship TO PUBLIC;




