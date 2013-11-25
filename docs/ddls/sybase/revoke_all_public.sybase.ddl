-- revokeallpublic   sql2Chado.pl parses this first line
--
-- Author:         Jay Sundaram sundaram@tigr.org
-- Date Modified:  2005-07-18 
-- Schema:         Chado
-- CVS:            ANNOTATION/chado/tigr_schemas/chado_template/ALL_Modules/revoke_all_public.ddl
-- Version:        $Id: revoke_all_public.sybase.ddl 3683 2007-08-20 18:24:16Z jaysundaram $ -- chado-v1r3b3
--
-- Contains all the SQL statements required to revoke all permissions to public
--
--
--
----------------------------------------------------------------------------------------------------------------

--------------------------------------------------------
--
-- Module: General
--
--------------------------------------------------------
	
REVOKE ALL ON tableinfo TO PUBLIC;
REVOKE ALL ON db TO PUBLIC;
REVOKE ALL ON dbxref TO PUBLIC;
REVOKE ALL ON project TO PUBLIC;

--------------------------------------------------------
--
-- Module: CV
--
--------------------------------------------------------
REVOKE ALL ON cv TO PUBLIC;
REVOKE ALL ON cvterm TO PUBLIC;
REVOKE ALL ON cvterm_relationship TO PUBLIC;
REVOKE ALL ON cvtermpath TO PUBLIC;
REVOKE ALL ON cvtermsynonym TO PUBLIC;
REVOKE ALL ON cvterm_dbxref TO PUBLIC;
REVOKE ALL ON cvtermprop TO PUBLIC;
REVOKE ALL ON dbxrefprop TO PUBLIC;

--------------------------------------------------------
--
-- Module: Pub
--
--------------------------------------------------------
REVOKE ALL ON pub TO PUBLIC;
REVOKE ALL ON pub_relationship TO PUBLIC;
REVOKE ALL ON pub_dbxref TO PUBLIC;
REVOKE ALL ON pubauthor TO PUBLIC;
REVOKE ALL ON pubprop TO PUBLIC;

--------------------------------------------------------
--
-- Module: Organism
--
--------------------------------------------------------
REVOKE ALL ON organism TO PUBLIC;
REVOKE ALL ON organism_dbxref TO PUBLIC;
REVOKE ALL ON organismprop TO PUBLIC;

--------------------------------------------------------
--
-- Module: Sequence
--
--------------------------------------------------------
REVOKE ALL ON feature TO PUBLIC;
REVOKE ALL ON featureloc TO PUBLIC;
REVOKE ALL ON feature_pub TO PUBLIC;
REVOKE ALL ON featureprop TO PUBLIC;
REVOKE ALL ON featureprop_pub TO PUBLIC;
REVOKE ALL ON feature_dbxref TO PUBLIC;
REVOKE ALL ON feature_relationship TO PUBLIC;
REVOKE ALL ON feature_relationship_pub TO PUBLIC;
REVOKE ALL ON feature_relationshipprop TO PUBLIC;
REVOKE ALL ON feature_relprop_pub TO PUBLIC;
REVOKE ALL ON feature_cvterm TO PUBLIC;
REVOKE ALL ON feature_cvtermprop TO PUBLIC;
REVOKE ALL ON feature_cvterm_dbxref TO PUBLIC;
REVOKE ALL ON feature_cvterm_pub TO PUBLIC;
REVOKE ALL ON synonym TO PUBLIC;
REVOKE ALL ON feature_synonym TO PUBLIC;

--------------------------------------------------------
--
-- Module: Computational Analysis
--
--------------------------------------------------------
REVOKE ALL ON analysis TO PUBLIC;
REVOKE ALL ON analysisprop TO PUBLIC;
REVOKE ALL ON analysisfeature TO PUBLIC;



--------------------------------------------------------
--
-- Module: Phylogeny
--
--------------------------------------------------------

REVOKE ALL ON phylotree TO PUBLIC;
REVOKE ALL ON phylotree_pub TO PUBLIC;
REVOKE ALL ON phylonode TO PUBLIC;
REVOKE ALL ON phylonode_dbxref TO PUBLIC;
REVOKE ALL ON phylonode_pub TO PUBLIC;
REVOKE ALL ON phylonode_organism TO PUBLIC;
REVOKE ALL ON phylonodeprop TO PUBLIC;
REVOKE ALL ON phylonode_relationship TO PUBLIC;

-------------------------------------------------------
--
-- Module: Infection
--
-------------------------------------------------------
REVOKE ALL ON infection TO PUBLIC;
REVOKE ALL ON infectionprop TO PUBLIC;
REVOKE ALL ON infection_cvterm TO PUBLIC;
REVOKE ALL ON infection_dbxref TO PUBLIC;
REVOKE ALL ON transmission TO PUBLIC;
REVOKE ALL ON transmissionprop TO PUBLIC;
REVOKE ALL ON transmission_cvterm TO PUBLIC;
REVOKE ALL ON transmission_dbxref TO PUBLIC;
REVOKE ALL ON incident TO PUBLIC;
REVOKE ALL ON incidentprop TO PUBLIC;
REVOKE ALL ON incident_cvterm TO PUBLIC;
REVOKE ALL ON incident_dbxref TO PUBLIC;
REVOKE ALL ON incident_relationship TO PUBLIC;
REVOKE ALL ON infection_pub TO PUBLIC;
REVOKE ALL ON transmission_pub TO PUBLIC;
REVOKE ALL ON incident_pub TO PUBLIC;

------------------------------------------------------
--
-- Module: Contact
--
------------------------------------------------------
REVOKE ALL ON contact TO PUBLIC;
REVOKE ALL ON contactprop TO PUBLIC;
REVOKE ALL ON contact_relationship TO PUBLIC;


------------------------------------------------------
--
-- Module: Genotype
--
------------------------------------------------------
REVOKE ALL ON genotype TO PUBLIC;
REVOKE ALL ON feature_genotype TO PUBLIC;
REVOKE ALL ON environment TO PUBLIC;
REVOKE ALL ON environment_cvterm TO PUBLIC;
REVOKE ALL ON phenstatement TO PUBLIC;
REVOKE ALL ON phendesc TO PUBLIC;
REVOKE ALL ON phenotype_comparison TO PUBLIC;
REVOKE ALL ON phenotype_comparison_cvterm TO PUBLIC;


-----------------------------------------------------
--
-- Module: Stock
--
-----------------------------------------------------
REVOKE ALL ON stock TO PUBLIC;
REVOKE ALL ON stock_pub TO PUBLIC;
REVOKE ALL ON stockprop TO PUBLIC;
REVOKE ALL ON stockprop_pub TO PUBLIC;
REVOKE ALL ON stock_relationship TO PUBLIC;
REVOKE ALL ON stock_relationship_pub TO PUBLIC;
REVOKE ALL ON stock_dbxref TO PUBLIC;
REVOKE ALL ON stock_cvterm TO PUBLIC;
REVOKE ALL ON stock_genotype TO PUBLIC;
REVOKE ALL ON stockcollection TO PUBLIC;
REVOKE ALL ON stockcollectionprop TO PUBLIC;

