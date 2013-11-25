--
-- Drop all Stock Module foreign key constraints
--
ALTER TABLE stockcollection_stock DROP CONSTRAINT fk_stockcollection_stock02;
ALTER TABLE stockcollection_stock DROP CONSTRAINT fk_stockcollection_stock01;
ALTER TABLE stockcollectionprop DROP CONSTRAINT fk_stockcollectionprop02;
ALTER TABLE stockcollectionprop DROP CONSTRAINT fk_stockcollectionprop01;
ALTER TABLE stockcollection DROP CONSTRAINT fk_stockcollection02;
ALTER TABLE stockcollection DROP CONSTRAINT fk_stockcollection01;
ALTER TABLE stock_genotype DROP CONSTRAINT fk_stock_genotype02;
ALTER TABLE stock_genotype DROP CONSTRAINT fk_stock_genotype01;
ALTER TABLE stock_cvterm DROP CONSTRAINT fk_stock_cvterm03;
ALTER TABLE stock_cvterm DROP CONSTRAINT fk_stock_cvterm02;
ALTER TABLE stock_cvterm DROP CONSTRAINT fk_stock_cvterm01;
ALTER TABLE stock_dbxref DROP CONSTRAINT fk_stock_dbxref02;
ALTER TABLE stock_dbxref DROP CONSTRAINT fk_stock_dbxref01;
ALTER TABLE stock_relationship_pub DROP CONSTRAINT fk_stock_relationship_pub02;
ALTER TABLE stock_relationship_pub DROP CONSTRAINT fk_stock_relationship_pub01;
ALTER TABLE stock_relationship DROP CONSTRAINT fk_stock_relationship03;
ALTER TABLE stock_relationship DROP CONSTRAINT fk_stock_relationship02;
ALTER TABLE stock_relationship DROP CONSTRAINT fk_stock_relationship01;
ALTER TABLE stockprop_pub DROP CONSTRAINT fk_stockprop_pub02;
ALTER TABLE stockprop_pub DROP CONSTRAINT fk_stockprop_pub01;
ALTER TABLE stockprop DROP CONSTRAINT fk_stockprop02;
ALTER TABLE stockprop DROP CONSTRAINT fk_stockprop01;
ALTER TABLE stock_pub DROP CONSTRAINT fk_stock_pub02;
ALTER TABLE stock_pub DROP CONSTRAINT fk_stock_pub01;
ALTER TABLE stock DROP CONSTRAINT fk_stock03;
ALTER TABLE stock DROP CONSTRAINT fk_stock02;
ALTER TABLE stock DROP CONSTRAINT fk_stock01;

--
-- Drop all Genetic Module foreign key constraints
--
ALTER TABLE phenotype_comparison_cvterm DROP CONSTRAINT fk_phenotype_comparison_cvterm02;
ALTER TABLE phenotype_comparison_cvterm DROP CONSTRAINT fk_phenotype_comparison_cvterm01;
ALTER TABLE phenotype_comparison DROP CONSTRAINT fk_phenotype_comparison08;
ALTER TABLE phenotype_comparison DROP CONSTRAINT fk_phenotype_comparison07;
ALTER TABLE phenotype_comparison DROP CONSTRAINT fk_phenotype_comparison06;
ALTER TABLE phenotype_comparison DROP CONSTRAINT fk_phenotype_comparison05;
ALTER TABLE phenotype_comparison DROP CONSTRAINT fk_phenotype_comparison04;
ALTER TABLE phenotype_comparison DROP CONSTRAINT fk_phenotype_comparison03;
ALTER TABLE phenotype_comparison DROP CONSTRAINT fk_phenotype_comparison02;
ALTER TABLE phenotype_comparison DROP CONSTRAINT fk_phenotype_comparison01;
ALTER TABLE phendesc DROP CONSTRAINT fk_phendesc04;
ALTER TABLE phendesc DROP CONSTRAINT fk_phendesc03;
ALTER TABLE phendesc DROP CONSTRAINT fk_phendesc02;
ALTER TABLE phendesc DROP CONSTRAINT fk_phendesc01;
ALTER TABLE phenstatement DROP CONSTRAINT fk_phenstatement05;
ALTER TABLE phenstatement DROP CONSTRAINT fk_phenstatement04;
ALTER TABLE phenstatement DROP CONSTRAINT fk_phenstatement03;
ALTER TABLE phenstatement DROP CONSTRAINT fk_phenstatement02;
ALTER TABLE phenstatement DROP CONSTRAINT fk_phenstatement01;
ALTER TABLE environment_cvterm DROP CONSTRAINT fk_environment_cvterm02;
ALTER TABLE environment_cvterm DROP CONSTRAINT fk_environment_cvterm01;
ALTER TABLE feature_genotype DROP CONSTRAINT fk_feature_genotype04;
ALTER TABLE feature_genotype DROP CONSTRAINT fk_feature_genotype03;
ALTER TABLE feature_genotype DROP CONSTRAINT fk_feature_genotype02;
ALTER TABLE feature_genotype DROP CONSTRAINT fk_feature_genotype01;

--
-- Drop all Contact Module foreign key constraints
--
ALTER TABLE contactprop DROP CONSTRAINT fk_contactprop02;
ALTER TABLE contactprop DROP CONSTRAINT fk_contactprop01;
ALTER TABLE contact_relationship DROP CONSTRAINT fk_contact_relationship03;
ALTER TABLE contact_relationship DROP CONSTRAINT fk_contact_relationship02;
ALTER TABLE contact_relationship DROP CONSTRAINT fk_contact_relationship01;
ALTER TABLE contact DROP CONSTRAINT fk_contact01;


--
-- Drop the Infection Module foreign keys
--
ALTER TABLE incident_pub DROP CONSTRAINT fk_incident_pub02;
ALTER TABLE incident_pub DROP CONSTRAINT fk_incident_pub01;
ALTER TABLE transmission_pub DROP CONSTRAINT fk_transmission_pub02;
ALTER TABLE transmission_pub DROP CONSTRAINT fk_transmission_pub01;
ALTER TABLE infection_pub DROP CONSTRAINT fk_infection_pub02;
ALTER TABLE infection_pub DROP CONSTRAINT fk_infection_pub01;
ALTER TABLE incident_relationship DROP CONSTRAINT fk_incident_relationship03;
ALTER TABLE incident_relationship DROP CONSTRAINT fk_incident_relationship02;
ALTER TABLE incident_relationship DROP CONSTRAINT fk_incident_relationship01;
ALTER TABLE incident_dbxref DROP CONSTRAINT fk_incident_dbxref02;
ALTER TABLE incident_dbxref DROP CONSTRAINT fk_incident_dbxref01;
ALTER TABLE incident_cvterm DROP CONSTRAINT fk_incident_cvterm03;
ALTER TABLE incident_cvterm DROP CONSTRAINT fk_incident_cvterm02;
ALTER TABLE incident_cvterm DROP CONSTRAINT fk_incident_cvterm01;
ALTER TABLE incidentprop DROP CONSTRAINT fk_incidentprop02;
ALTER TABLE incidentprop DROP CONSTRAINT fk_incidentprop01;
ALTER TABLE incident DROP CONSTRAINT fk_incident02;

-- this will be changed after addition of Geography Module
ALTER TABLE incident DROP CONSTRAINT fk_incident01;
ALTER TABLE transmission_dbxref DROP CONSTRAINT fk_transmission_dbxref02;
ALTER TABLE transmission_dbxref DROP CONSTRAINT fk_transmission_dbxref01;
ALTER TABLE transmission_cvterm DROP CONSTRAINT fk_transmission_cvterm03;
ALTER TABLE transmission_cvterm DROP CONSTRAINT fk_transmission_cvterm02;
ALTER TABLE transmission_cvterm DROP CONSTRAINT fk_transmission_cvterm01;
ALTER TABLE transmissionprop DROP CONSTRAINT fk_transmissionprop02;
ALTER TABLE transmissionprop DROP CONSTRAINT fk_transmissionprop01;
ALTER TABLE transmission DROP CONSTRAINT fk_transmission04;
ALTER TABLE transmission DROP CONSTRAINT fk_transmission03;
ALTER TABLE transmission DROP CONSTRAINT fk_transmission02;
ALTER TABLE transmission DROP CONSTRAINT fk_transmission01;
ALTER TABLE infection_dbxref DROP CONSTRAINT fk_infection_dbxref02;
ALTER TABLE infection_dbxref DROP CONSTRAINT fk_infection_dbxref01;
ALTER TABLE infection_cvterm DROP CONSTRAINT fk_infection_cvterm03;
ALTER TABLE infection_cvterm DROP CONSTRAINT fk_infection_cvterm02;
ALTER TABLE infection_cvterm DROP CONSTRAINT fk_infection_cvterm01;
ALTER TABLE infectionprop DROP CONSTRAINT fk_infectionprop02;
ALTER TABLE infectionprop DROP CONSTRAINT fk_infectionprop01;
ALTER TABLE infection DROP CONSTRAINT fk_infection03;
ALTER TABLE infection DROP CONSTRAINT fk_infection02;
ALTER TABLE infection DROP CONSTRAINT fk_infection01;
--
-- Drop chado foreign keys follow
--
ALTER TABLE phylonode_relationship DROP CONSTRAINT fk_phylonode_relationship03;
ALTER TABLE phylonode_relationship DROP CONSTRAINT fk_phylonode_relationship02;
ALTER TABLE phylonode_relationship DROP CONSTRAINT fk_phylonode_relationship01;
ALTER TABLE phylonodeprop DROP CONSTRAINT fk_phylonodeprop02;
ALTER TABLE phylonodeprop DROP CONSTRAINT fk_phylonodeprop01;
ALTER TABLE phylonode_organism DROP CONSTRAINT fk_phylonode_organism02;
ALTER TABLE phylonode_organism DROP CONSTRAINT fk_phylonode_organism01;
ALTER TABLE phylonode_pub DROP CONSTRAINT fk_phylonode_pub02;
ALTER TABLE phylonode_pub DROP CONSTRAINT fk_phylonode_pub01;
ALTER TABLE phylonode_dbxref DROP CONSTRAINT fk_phylonode_dbxref02;
ALTER TABLE phylonode_dbxref DROP CONSTRAINT fk_phylonode_dbxref01;
ALTER TABLE phylonode DROP CONSTRAINT fk_phylonode04;
ALTER TABLE phylonode DROP CONSTRAINT fk_phylonode03;
ALTER TABLE phylonode DROP CONSTRAINT fk_phylonode02;
ALTER TABLE phylonode DROP CONSTRAINT fk_phylonode01;
ALTER TABLE phylotree_pub DROP CONSTRAINT fk_phylotree_pub02;
ALTER TABLE phylotree_pub DROP CONSTRAINT fk_phylotree_pub01;
ALTER TABLE phylotree DROP CONSTRAINT fk_phylotree02;
ALTER TABLE phylotree DROP CONSTRAINT fk_phylotree01;
ALTER TABLE analysisfeature DROP CONSTRAINT fk_analysisfeature03;
ALTER TABLE analysisfeature DROP CONSTRAINT fk_analysisfeature02;
ALTER TABLE analysisfeature DROP CONSTRAINT fk_analysisfeature01;
ALTER TABLE analysisprop DROP CONSTRAINT fk_analysisprop02;
ALTER TABLE analysisprop DROP CONSTRAINT fk_analysisprop01;
ALTER TABLE feature_synonym DROP CONSTRAINT fk_feature_synonym03;
ALTER TABLE feature_synonym DROP CONSTRAINT fk_feature_synonym02;
ALTER TABLE feature_synonym DROP CONSTRAINT fk_feature_synonym01;
ALTER TABLE synonym DROP CONSTRAINT fk_synonym01;
ALTER TABLE feature_cvterm_pub DROP CONSTRAINT fk_feature_cvterm_pub02;
ALTER TABLE feature_cvterm_pub DROP CONSTRAINT fk_feature_cvterm_pub01;
ALTER TABLE feature_cvterm_dbxref DROP CONSTRAINT fk_feature_cvterm_dbxref02;
ALTER TABLE feature_cvterm_dbxref DROP CONSTRAINT fk_feature_cvterm_dbxref01;
ALTER TABLE feature_cvtermprop DROP CONSTRAINT fk_feature_cvtermprop02;
ALTER TABLE feature_cvtermprop DROP CONSTRAINT fk_feature_cvtermprop01;
ALTER TABLE feature_cvterm DROP CONSTRAINT fk_feature_cvterm03;
ALTER TABLE feature_cvterm DROP CONSTRAINT fk_feature_cvterm02;
ALTER TABLE feature_cvterm DROP CONSTRAINT fk_feature_cvterm01;
ALTER TABLE feature_relprop_pub DROP CONSTRAINT fk_feature_relprop_pub02;
ALTER TABLE feature_relprop_pub DROP CONSTRAINT fk_feature_relprop_pub01;
ALTER TABLE feature_relationshipprop DROP CONSTRAINT fk_feature_relationshipprop02;
ALTER TABLE feature_relationshipprop DROP CONSTRAINT fk_feature_relationshipprop01;
ALTER TABLE feature_relationship_pub DROP CONSTRAINT fk_feature_relationship_pub02;
ALTER TABLE feature_relationship_pub DROP CONSTRAINT fk_feature_relationship_pub01;
ALTER TABLE feature_relationship DROP CONSTRAINT fk_feature_relationship03;
ALTER TABLE feature_relationship DROP CONSTRAINT fk_feature_relationship02;
ALTER TABLE feature_relationship DROP CONSTRAINT fk_feature_relationship01;
ALTER TABLE feature_dbxref DROP CONSTRAINT fk_feature_dbxref02;
ALTER TABLE feature_dbxref DROP CONSTRAINT fk_feature_dbxref01;
ALTER TABLE featureprop_pub DROP CONSTRAINT fk_featureprop_pub02;
ALTER TABLE featureprop_pub DROP CONSTRAINT fk_featureprop_pub01;
ALTER TABLE featureprop DROP CONSTRAINT fk_featureprop02;
ALTER TABLE featureprop DROP CONSTRAINT fk_featureprop01;
ALTER TABLE feature_pub DROP CONSTRAINT fk_feature_pub02;
ALTER TABLE feature_pub DROP CONSTRAINT fk_feature_pub01;
ALTER TABLE featureloc DROP CONSTRAINT fk_featureloc02;
ALTER TABLE featureloc DROP CONSTRAINT fk_featureloc01;
ALTER TABLE feature DROP CONSTRAINT fk_feature03;
ALTER TABLE feature DROP CONSTRAINT fk_feature02;
ALTER TABLE feature DROP CONSTRAINT fk_feature01;
ALTER TABLE organismprop DROP CONSTRAINT fk_organismprop02;
ALTER TABLE organismprop DROP CONSTRAINT fk_organismprop01;
ALTER TABLE organism_dbxref DROP CONSTRAINT fk_organism_dbxref02;
ALTER TABLE organism_dbxref DROP CONSTRAINT fk_organism_dbxref01;
ALTER TABLE pubprop DROP CONSTRAINT fk_pubprop02;
ALTER TABLE pubprop DROP CONSTRAINT fk_pubprop01;
ALTER TABLE pubauthor DROP CONSTRAINT fk_pubauthor01;
ALTER TABLE pub_dbxref DROP CONSTRAINT fk_pub_dbxref02;
ALTER TABLE pub_dbxref DROP CONSTRAINT fk_pub_dbxref01;
ALTER TABLE pub_relationship DROP CONSTRAINT fk_pub_relationship03;
ALTER TABLE pub_relationship DROP CONSTRAINT fk_pub_relationship02;
ALTER TABLE pub_relationship DROP CONSTRAINT fk_pub_relationship01;
ALTER TABLE pub DROP CONSTRAINT fk_pub01;
ALTER TABLE dbxrefprop DROP CONSTRAINT fk_dbxrefprop02;
ALTER TABLE dbxrefprop DROP CONSTRAINT fk_dbxrefprop01;
ALTER TABLE cvtermprop DROP CONSTRAINT fk_cvtermprop02;
ALTER TABLE cvtermprop DROP CONSTRAINT fk_cvtermprop01;
ALTER TABLE cvterm_dbxref DROP CONSTRAINT fk_cvterm_dbxref02;
ALTER TABLE cvterm_dbxref DROP CONSTRAINT fk_cvterm_dbxref01;
ALTER TABLE cvtermsynonym DROP CONSTRAINT fk_cvtermsynonym02;
ALTER TABLE cvtermsynonym DROP CONSTRAINT fk_cvtermsynonym01;
ALTER TABLE cvtermpath DROP CONSTRAINT fk_cvtermpath04;
ALTER TABLE cvtermpath DROP CONSTRAINT fk_cvtermpath03;
ALTER TABLE cvtermpath DROP CONSTRAINT fk_cvtermpath02;
ALTER TABLE cvtermpath DROP CONSTRAINT fk_cvtermpath01;
ALTER TABLE cvterm_relationship DROP CONSTRAINT fk_cvterm_relationship03;
ALTER TABLE cvterm_relationship DROP CONSTRAINT fk_cvterm_relationship02;
ALTER TABLE cvterm_relationship DROP CONSTRAINT fk_cvterm_relationship01;
ALTER TABLE cvterm DROP CONSTRAINT fk_cvterm02;
ALTER TABLE cvterm DROP CONSTRAINT fk_cvterm01;
ALTER TABLE dbxref DROP CONSTRAINT fk_dbxref01;


--
-- Drop all Stock module indices
--
DROP INDEX idx_stock_relationship03;
DROP INDEX idx_stock_relationship02;
DROP INDEX idx_stock_relationship01;
DROP INDEX uc1_stock_relationship;
DROP INDEX idx_stockprop_pub02;
DROP INDEX idx_stockprop_pub01;
DROP INDEX uc1_stockprop_pub;
DROP INDEX idx_stockprop02;
DROP INDEX idx_stockprop01;
DROP INDEX uc1_stockprop;
DROP INDEX idx_stock_pub02;
DROP INDEX idx_stock_pub01;
DROP INDEX uc1_stock_pub;
DROP INDEX idx_stock04;
DROP INDEX idx_stock03;
DROP INDEX idx_stock02;
DROP INDEX idx_stock01;
DROP INDEX uc1_stock;

--
-- Drop all Genetic module indices
--
DROP INDEX idx_phenotype_comparison_cvterm02;
DROP INDEX idx_phenotype_comparison_cvterm01;
DROP INDEX uc1_phenotype_comparison_cvterm;
DROP INDEX idx_phenotype_comparison03;
DROP INDEX idx_phenotype_comparison02;
DROP INDEX idx_phenotype_comparison01;
DROP INDEX uc1_phenotype_comparison;
DROP INDEX idx_phendesc03;
DROP INDEX idx_phendesc02;
DROP INDEX idx_phendesc01;
DROP INDEX uc1_phendesc;
DROP INDEX idx_phenstatement02;
DROP INDEX idx_phenstatement01;
DROP INDEX uc1_phenstatement;
DROP INDEX idx_environment_cvterm02;
DROP INDEX idx_environment_cvterm01;
DROP INDEX uc1_environment_cvterm;
DROP INDEX uc1_environment;
DROP INDEX idx_feature_genotype02;
DROP INDEX idx_feature_genotype01;
DROP INDEX uc1_feature_genotype;
DROP INDEX idx_genotype01;
DROP INDEX uc1_genotype;

--
-- Drop all Contact module indices
--
DROP INDEX idx_contactprop01;
DROP INDEX idx_contact_relationship01;
DROP INDEX idx_contact01;

--
-- Drop Infection Module indexes and constraints
-- 
DROP INDEX idx_incident_pub01;
DROP INDEX uc1_incident_pub;
DROP INDEX idx_transmission_pub01;
DROP INDEX uc1_transmission_pub;
DROP INDEX idx_infection_pub01;
DROP INDEX uc1_infection_pub;
DROP INDEX idx_incident_relationship02;
DROP INDEX idx_incident_relationship01;
DROP INDEX uc1_incident_relationship;
DROP INDEX idx_incident_dbxref02;
DROP INDEX idx_incident_dbxref01;
DROP INDEX uc1_incident_dbxref;
DROP INDEX idx_incident_cvterm02;
DROP INDEX idx_incident_cvterm01;
DROP INDEX idx_incidentprop01;
DROP INDEX uc1_incidentprop;
DROP INDEX idx_incident02;
DROP INDEX idx_incident01;
DROP INDEX idx_transmission_dbxref02;
DROP INDEX idx_transmission_dbxref01;
DROP INDEX uc1_transmission_dbxref;
DROP INDEX idx_transmission_cvterm02;
DROP INDEX idx_transmission_cvterm01;
DROP INDEX idx_transmissionprop01;
DROP INDEX uc1_transmissionprop;
DROP INDEX idx_transmission02;
DROP INDEX idx_transmission01;
DROP INDEX uc1_transmission;
DROP INDEX idx_infection_dbxref02;
DROP INDEX idx_infection_dbxref01;
DROP INDEX uc1_infection_dbxref;
DROP INDEX idx_infection_cvterm02;
DROP INDEX idx_infection_cvterm01;
DROP INDEX idx_infectionprop01;
DROP INDEX uc1_infectionprop;
DROP INDEX uc1_infection;
DROP INDEX idx_infection02;
DROP INDEX idx_infection03;
DROP INDEX idx_infection04;
--
-- Drop chado indexes and constraints
--
DROP INDEX idx_feature_cvterm_pub02;
DROP INDEX idx_feature_cvterm_pub01;
DROP INDEX uc1_feature_cvterm_pub;
DROP INDEX idx_feature_cvterm_dbxref02;
DROP INDEX idx_feature_cvterm_dbxref01;
DROP INDEX uc1_feature_cvterm_dbxref;
DROP INDEX idx_phylonode_relationship03;
DROP INDEX idx_phylonode_relationship02;
DROP INDEX idx_phylonode_relationship01;
DROP INDEX uc1_phylonode_relationship;
DROP INDEX idx_phylonodeprop02;
DROP INDEX idx_phylonodeprop01;
DROP INDEX uc1_phylonodeprop;
DROP INDEX idx_phylonode_organism02;
DROP INDEX idx_phylonode_organism01;
DROP INDEX uc1_phylonode_organism;
DROP INDEX idx_phylonode_pub02;
DROP INDEX idx_phylonode_pub01;
DROP INDEX uc1_phylonode_pub;
DROP INDEX idx_phylonode_dbxref02;
DROP INDEX idx_phylonode_dbxref01;
DROP INDEX uc1_phylonode_dbxref;
DROP INDEX idx_phylonode03;
DROP INDEX idx_phylonode02;
DROP INDEX idx_phylonode01;
DROP INDEX uc2_phylonode;
DROP INDEX uc1_phylonode;
DROP INDEX idx_phylotree_pub02;
DROP INDEX idx_phylotree_pub01;
DROP INDEX uc1_phylotree;
DROP INDEX uc1_tableinfo;
DROP INDEX idx_synonym01;
DROP INDEX uc1_synonym;
DROP INDEX idx_pubprop01;
DROP INDEX uc1_pubprop;
DROP INDEX idx_pub_relationship02;
DROP INDEX idx_pub_relationship01;
DROP INDEX uc1_pub_relationship;
DROP INDEX idx_pub_dbxref02;
DROP INDEX idx_pub_dbxref01;
DROP INDEX uc1_pub_dbxref;
DROP INDEX idx_pubauthor01;
DROP INDEX uc1_pubauthor;
DROP INDEX idx_pub01;
DROP INDEX uc1_pub;
DROP INDEX uc1_project;
DROP INDEX idx_organismprop01;
DROP INDEX uc1_organismprop;
DROP INDEX idx_organism_dbxref02;
DROP INDEX idx_organism_dbxref01;
DROP INDEX uc1_organism_dbxref;
DROP INDEX uc1_organism;
DROP INDEX idx_featureprop_pub01;
DROP INDEX uc1_featureprop_pub;
DROP INDEX idx_featureprop01;
DROP INDEX uc1_featureprop;
DROP INDEX idx_featureloc07;
DROP INDEX idx_featureloc06;
DROP INDEX idx_featureloc03;
DROP INDEX idx_featureloc02;
DROP INDEX uc1_featureloc;
DROP INDEX idx_feature_synonym02;
DROP INDEX idx_feature_synonym01;
DROP INDEX uc1_feature_synonym;
DROP INDEX idx_feature_relprop_pub01;
DROP INDEX uc1_feature_relprop_pub;
DROP INDEX idx_feature_relationshipprop01;
DROP INDEX uc1_feature_relationshipprop;
DROP INDEX idx_feature_relationship_pub01;
DROP INDEX uc1_feature_relationship_pub;
DROP INDEX idx_feature_relationship01;
DROP INDEX idx_feature_relationship02;
DROP INDEX uc1_feature_relationship;
DROP INDEX idx_feature_pub01;
DROP INDEX uc1_feature_pub;
DROP INDEX uc1_feature_dbxref;
DROP INDEX pk_feature_dbxref;
DROP INDEX idx_feature_cvtermprop01;
DROP INDEX uc1_feature_cvtermprop;
DROP INDEX idx_feature_cvterm02;
DROP INDEX idx_feature_cvterm01;
DROP INDEX idx_feature03;
DROP INDEX idx_feature04;
DROP INDEX idx_feature01;
DROP INDEX idx_feature02;
DROP INDEX idx_dbxrefprop02;
DROP INDEX idx_dbxrefprop01;
DROP INDEX uc1_dbxrefprop;
DROP INDEX idx_dbxref02;
DROP INDEX idx_dbxref01;
DROP INDEX uc1_dbxref;
DROP INDEX uc1_db;
DROP INDEX idx_cvtermsynonym01;
DROP INDEX uc1_cvtermsynonym;
DROP INDEX idx_cvtermprop01;
DROP INDEX uc1_cvtermprop;
DROP INDEX idx_cvtermpath03;
DROP INDEX idx_cvtermpath02;
DROP INDEX idx_cvtermpath01;
DROP INDEX uc1_cvtermpath;
DROP INDEX idx_cvterm_relationship02;
DROP INDEX idx_cvterm_relationship01;
DROP INDEX uc1_cvterm_relationship;
DROP INDEX pk_cvterm_dbxref;
DROP INDEX uc1_cvterm_dbxref;
DROP INDEX uc1_cvterm;
DROP INDEX idx_cvterm01;
DROP INDEX uc1_cv;
DROP INDEX idx_analysisprop01;
DROP INDEX uc1_analysisfeature;
DROP INDEX pk_analysisfeature;
DROP INDEX uc1_analysis;

--
-- Drop all Stock Module primary keys
--
DROP INDEX pk_stockcollection_stock;
DROP INDEX pk_stockcollectionprop;
DROP INDEX pk_stockcollection;
DROP INDEX pk_stock_genotype;
DROP INDEX pk_stock_cvterm;
DROP INDEX pk_stock_dbxref;
DROP INDEX pk_stock_relationship_pub;
DROP INDEX pk_stock_relationship;
DROP INDEX pk_stockprop_pub;
DROP INDEX pk_stockprop;
DROP INDEX pk_stock_pub;
DROP INDEX pk_stock;

--
-- Drop all Genetic Module primary keys
--
DROP INDEX pk_phenotype_comparison_cvterm;
DROP INDEX pk_phenotype_comparison;
DROP INDEX pk_phenotype;
DROP INDEX pk_phendesc;
DROP INDEX pk_phenstatement;
DROP INDEX pk_environment_cvterm;
DROP INDEX pk_environment;
DROP INDEX pk_feature_genotype;
DROP INDEX pk_genotype;

--
-- Drop all Contact Module primary keys
--
DROP INDEX pk_contactprop;
DROP INDEX pk_contact_relationship;
DROP INDEX pk_contact;

--
-- Drop all Infection Module primary keys
--
DROP INDEX pk_incident_relationship;
DROP INDEX pk_incident_dbxref;
DROP INDEX pk_incident_cvterm;
DROP INDEX pk_incidentprop;
DROP INDEX pk_incident;
DROP INDEX pk_transmission_dbxref;
DROP INDEX pk_transmission_cvterm;
DROP INDEX pk_transmissionprop;
DROP INDEX pk_transmission;
DROP INDEX pk_infection_dbxref;
DROP INDEX pk_infection_cvterm;
DROP INDEX pk_infectionprop;
DROP INDEX pk_infection;
--
-- Drop all chado primary keys
--
DROP INDEX pk_feature_cvterm_pub;
DROP INDEX pk_feature_cvterm_dbxref;
DROP INDEX pk_phylonode_relationship;
DROP INDEX pk_phylonodeprop;
DROP INDEX pk_phylonode_organism;
DROP INDEX pk_phylonode_pub;
DROP INDEX pk_phylonode_dbxref;
DROP INDEX pk_phylonode;
DROP INDEX pk_phylotree_pub;
DROP INDEX pk_phylotree;
DROP INDEX pk_pubauthor;
DROP INDEX pk_tableinfo;
DROP INDEX pk_synonym;
DROP INDEX pk_pubprop;
DROP INDEX pk_pub_relationship;
DROP INDEX pk_pub_dbxref;
DROP INDEX pk_pub;
DROP INDEX pk_project;
DROP INDEX pk_organismprop;
DROP INDEX pk_organism_dbxref;
DROP INDEX pk_organism;
DROP INDEX pk_featureprop_pub;
DROP INDEX pk_feature_synonym;
DROP INDEX pk_feature_relprop_pub;
DROP INDEX pk_feature_relationshipprop;
DROP INDEX pk_feature_relationship_pub;
DROP INDEX pk_feature_relationship;
DROP INDEX pk_feature_pub;
DROP INDEX idx_feature_dbxref01;
DROP INDEX pk_feature_cvtermprop;
DROP INDEX pk_feature_cvterm;
DROP INDEX pk_dbxrefprop;
DROP INDEX pk_dbxref;
DROP INDEX pk_db;
DROP INDEX pk_cvtermsynonym;
DROP INDEX pk_cvtermprop;
DROP INDEX pk_cvtermpath;
DROP INDEX pk_cvterm_relationship;
DROP INDEX idx_cvterm_dbxref01;
DROP INDEX pk_cvterm;
DROP INDEX pk_cv;
DROP INDEX pk_analysis;
DROP INDEX idx_analysisfeature01;
DROP INDEX pk_featureprop;
DROP INDEX idx_featureloc01;
DROP INDEX idx_feature06;
