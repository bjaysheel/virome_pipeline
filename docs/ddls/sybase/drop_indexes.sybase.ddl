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
ALTER TABLE cvterm_dbxref DROP CONSTRAINT fk_cvterm_dbxref02
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
DROP INDEX stockcollection_stock.idx_stockcollection_stock01;
DROP INDEX stock_relationship.idx_stock_relationship03;
DROP INDEX stock_relationship.idx_stock_relationship02;
DROP INDEX stock_relationship.idx_stock_relationship01;
DROP INDEX stock_relationship.uc1_stock_relationship;
DROP INDEX stockprop_pub.idx_stockprop_pub02;
DROP INDEX stockprop_pub.idx_stockprop_pub01;
DROP INDEX stockprop_pub.uc1_stockprop_pub;
DROP INDEX stockprop.idx_stockprop02;
DROP INDEX stockprop.idx_stockprop01;
DROP INDEX stockprop.uc1_stockprop;
DROP INDEX stock_pub.idx_stock_pub02;
DROP INDEX stock_pub.idx_stock_pub01;
DROP INDEX stock_pub.uc1_stock_pub;
DROP INDEX stock.idx_stock04;
DROP INDEX stock.idx_stock03;
DROP INDEX stock.idx_stock02;
DROP INDEX stock.idx_stock01;
DROP INDEX stock.uc1_stock;

--
-- Drop all Genetic module indices
--
DROP INDEX phenotype_comparison_cvterm.idx_phenotype_comparison_cvterm02;
DROP INDEX phenotype_comparison_cvterm.idx_phenotype_comparison_cvterm01;
DROP INDEX phenotype_comparison_cvterm.uc1_phenotype_comparison_cvterm;
DROP INDEX phenotype_comparison.idx_phenotype_comparison03;
DROP INDEX phenotype_comparison.idx_phenotype_comparison02;
DROP INDEX phenotype_comparison.idx_phenotype_comparison01;
DROP INDEX phenotype_comparison.uc1_phenotype_comparison;
DROP INDEX phendesc.idx_phendesc03;
DROP INDEX phendesc.idx_phendesc02;
DROP INDEX phendesc.idx_phendesc01;
DROP INDEX phendesc.uc1_phendesc;
DROP INDEX phenstatement.idx_phenstatement02;
DROP INDEX phenstatement.idx_phenstatement01;
DROP INDEX phenstatement.uc1_phenstatement;
DROP INDEX environment_cvterm.idx_environment_cvterm02;
DROP INDEX environment_cvterm.idx_environment_cvterm01;
DROP INDEX environment_cvterm.uc1_environment_cvterm;
DROP INDEX environment.uc1_environment;
DROP INDEX feature_genotype.idx_feature_genotype02;
DROP INDEX feature_genotype.idx_feature_genotype01;
DROP INDEX feature_genotype.uc1_feature_genotype;
DROP INDEX genotype.idx_genotype01;
DROP INDEX genotype.uc1_genotype;

--
-- Drop all Contact module indices
--
DROP INDEX contactprop.idx_contactprop01;
DROP INDEX contact_relationship.idx_contact_relationship01;
DROP INDEX contact.idx_contact01;

--
-- Drop Infection Module indexes and constraints
-- 
DROP INDEX incident_pub.idx_incident_pub01;
DROP INDEX incident_pub.uc1_incident_pub;
DROP INDEX transmission_pub.idx_transmission_pub01;
DROP INDEX transmission_pub.uc1_transmission_pub;
DROP INDEX infection_pub.idx_infection_pub01;
DROP INDEX infection_pub.uc1_infection_pub;
DROP INDEX incident_relationship.idx_incident_relationship02;
DROP INDEX incident_relationship.idx_incident_relationship01;
DROP INDEX incident_relationship.uc1_incident_relationship;
DROP INDEX incident_dbxref.idx_incident_dbxref02;
DROP INDEX incident_dbxref.idx_incident_dbxref01;
DROP INDEX incident_dbxref.uc1_incident_dbxref;
DROP INDEX incident_cvterm.idx_incident_cvterm02;
DROP INDEX incident_cvterm.idx_incident_cvterm01;
DROP INDEX incidentprop.idx_incidentprop01;
DROP INDEX incidentprop.uc1_incidentprop;
DROP INDEX incident.idx_incident02;
DROP INDEX incident.idx_incident01;
DROP INDEX transmission_dbxref.idx_transmission_dbxref02;
DROP INDEX transmission_dbxref.idx_transmission_dbxref01;
DROP INDEX transmission_dbxref.uc1_transmission_dbxref;
DROP INDEX transmission_cvterm.idx_transmission_cvterm02;
DROP INDEX transmission_cvterm.idx_transmission_cvterm01;
DROP INDEX transmissionprop.idx_transmissionprop01;
DROP INDEX transmissionprop.uc1_transmissionprop;
DROP INDEX transmission.idx_transmission02;
DROP INDEX transmission.idx_transmission01;
DROP INDEX transmission.uc1_transmission;
DROP INDEX infection_dbxref.idx_infection_dbxref02;
DROP INDEX infection_dbxref.idx_infection_dbxref01;
DROP INDEX infection_dbxref.uc1_infection_dbxref;
DROP INDEX infection_cvterm.idx_infection_cvterm02;
DROP INDEX infection_cvterm.idx_infection_cvterm01;
DROP INDEX infectionprop.idx_infectionprop01;
DROP INDEX infectionprop.uc1_infectionprop;
--
-- Drop chado indexes and constraints
--
DROP INDEX feature_cvterm_pub.idx_feature_cvterm_pub02;
DROP INDEX feature_cvterm_pub.idx_feature_cvterm_pub01;
DROP INDEX feature_cvterm_pub.uc1_feature_cvterm_pub;
DROP INDEX feature_cvterm_dbxref.idx_feature_cvterm_dbxref02;
DROP INDEX feature_cvterm_dbxref.idx_feature_cvterm_dbxref01;
DROP INDEX feature_cvterm_dbxref.uc1_feature_cvterm_dbxref;
DROP INDEX phylonode_relationship.idx_phylonode_relationship03;
DROP INDEX phylonode_relationship.idx_phylonode_relationship02;
DROP INDEX phylonode_relationship.idx_phylonode_relationship01;
DROP INDEX phylonode_relationship.uc1_phylonode_relationship;
DROP INDEX phylonodeprop.idx_phylonodeprop02;
DROP INDEX phylonodeprop.idx_phylonodeprop01;
DROP INDEX phylonodeprop.uc1_phylonodeprop;
DROP INDEX phylonode_organism.idx_phylonode_organism02;
DROP INDEX phylonode_organism.idx_phylonode_organism01;
DROP INDEX phylonode_organism.uc1_phylonode_organism;
DROP INDEX phylonode_pub.idx_phylonode_pub02;
DROP INDEX phylonode_pub.idx_phylonode_pub01;
DROP INDEX phylonode_pub.uc1_phylonode_pub;
DROP INDEX phylonode_dbxref.idx_phylonode_dbxref02;
DROP INDEX phylonode_dbxref.idx_phylonode_dbxref01;
DROP INDEX phylonode_dbxref.uc1_phylonode_dbxref;
DROP INDEX phylonode.idx_phylonode03;
DROP INDEX phylonode.idx_phylonode02;
DROP INDEX phylonode.idx_phylonode01;
DROP INDEX phylonode.uc2_phylonode;
DROP INDEX phylonode.uc1_phylonode;
DROP INDEX phylotree_pub.idx_phylotree_pub02;
DROP INDEX phylotree_pub.idx_phylotree_pub01;
DROP INDEX phylotree_pub.uc1_phylotree;
DROP INDEX tableinfo.uc1_tableinfo;
DROP INDEX synonym.idx_synonym01;
DROP INDEX synonym.uc1_synonym;
DROP INDEX pubprop.idx_pubprop01;
DROP INDEX pubprop.uc1_pubprop;
DROP INDEX pub_relationship.idx_pub_relationship02;
DROP INDEX pub_relationship.idx_pub_relationship01;
DROP INDEX pub_relationship.uc1_pub_relationship;
DROP INDEX pub_dbxref.idx_pub_dbxref02;
DROP INDEX pub_dbxref.idx_pub_dbxref01;
DROP INDEX pub_dbxref.uc1_pub_dbxref;
DROP INDEX pubauthor.idx_pubauthor01;
DROP INDEX pubauthor.uc1_pubauthor;
DROP INDEX pub.idx_pub01;
DROP INDEX pub.uc1_pub;
DROP INDEX project.uc1_project;
DROP INDEX organismprop.idx_organismprop01;
DROP INDEX organismprop.uc1_organismprop;
DROP INDEX organism_dbxref.idx_organism_dbxref02;
DROP INDEX organism_dbxref.idx_organism_dbxref01;
DROP INDEX organism_dbxref.uc1_organism_dbxref;
DROP INDEX organism.uc1_organism;
DROP INDEX featureprop_pub.idx_featureprop_pub01;
DROP INDEX featureprop_pub.uc1_featureprop_pub;
DROP INDEX featureprop.idx_featureprop01;
DROP INDEX featureprop.uc1_featureprop;
DROP INDEX featureloc.idx_featureloc06;
DROP INDEX featureloc.idx_featureloc03;
DROP INDEX featureloc.idx_featureloc02;
DROP INDEX featureloc.uc1_featureloc;
DROP INDEX feature_synonym.idx_feature_synonym02;
DROP INDEX feature_synonym.idx_feature_synonym01;
DROP INDEX feature_synonym.uc1_feature_synonym;
DROP INDEX feature_relprop_pub.idx_feature_relprop_pub01;
DROP INDEX feature_relprop_pub.uc1_feature_relprop_pub;
DROP INDEX feature_relationshipprop.idx_feature_relationshipprop01;
DROP INDEX feature_relationshipprop.uc1_feature_relationshipprop;
DROP INDEX feature_relationship_pub.idx_feature_relationship_pub01;
DROP INDEX feature_relationship_pub.uc1_feature_relationship_pub;
DROP INDEX feature_relationship.idx_feature_relationship01;
DROP INDEX feature_relationship.uc1_feature_relationship;
DROP INDEX feature_pub.idx_feature_pub01;
DROP INDEX feature_pub.uc1_feature_pub;
DROP INDEX feature_dbxref.uc1_feature_dbxref;
DROP INDEX feature_dbxref.pk_feature_dbxref;
DROP INDEX feature_cvtermprop.idx_feature_cvtermprop01;
DROP INDEX feature_cvtermprop.uc1_feature_cvtermprop;
DROP INDEX feature_cvterm.idx_feature_cvterm02;
DROP INDEX feature_cvterm.idx_feature_cvterm01;
DROP INDEX feature.idx_feature03;
DROP INDEX feature.idx_feature04;
DROP INDEX feature.idx_feature01;
DROP INDEX feature.idx_feature02;
DROP INDEX dbxrefprop.idx_dbxrefprop02;
DROP INDEX dbxrefprop.idx_dbxrefprop01;
DROP INDEX dbxrefprop.uc1_dbxrefprop;
DROP INDEX dbxref.idx_dbxref02;
DROP INDEX dbxref.idx_dbxref01;
DROP INDEX dbxref.uc1_dbxref;
DROP INDEX db.uc1_db;
DROP INDEX cvtermsynonym.idx_cvtermsynonym01;
DROP INDEX cvtermsynonym.uc1_cvtermsynonym;
DROP INDEX cvtermprop.idx_cvtermprop01;
DROP INDEX cvtermprop.uc1_cvtermprop;
DROP INDEX cvtermpath.idx_cvtermpath03;
DROP INDEX cvtermpath.idx_cvtermpath02;
DROP INDEX cvtermpath.idx_cvtermpath01;
DROP INDEX cvtermpath.uc1_cvtermpath;
DROP INDEX cvterm_relationship.idx_cvterm_relationship02;
DROP INDEX cvterm_relationship.idx_cvterm_relationship01;
DROP INDEX cvterm_relationship.uc1_cvterm_relationship;
DROP INDEX cvterm_dbxref.pk_cvterm_dbxref;
DROP INDEX cvterm_dbxref.uc1_cvterm_dbxref;
DROP INDEX cvterm.uc1_cvterm;
DROP INDEX cvterm.idx_cvterm01;
DROP INDEX cv.uc1_cv;
DROP INDEX analysisprop.idx_analysisprop01;
DROP INDEX analysisfeature.uc1_analysisfeature;
DROP INDEX analysisfeature.pk_analysisfeature;
DROP INDEX analysis.uc1_analysis;

--
-- Drop all Stock Module primary keys
--
DROP INDEX stockcollection_stock.pk_stockcollection_stock;
DROP INDEX stockcollectionprop.pk_stockcollectionprop;
DROP INDEX stockcollection.pk_stockcollection;
DROP INDEX stock_genotype.pk_stock_genotype;
DROP INDEX stock_cvterm.pk_stock_cvterm;
DROP INDEX stock_dbxref.pk_stock_dbxref;
DROP INDEX stock_relationship_pub.pk_stock_relationship_pub;
DROP INDEX stock_relationship.pk_stock_relationship;
DROP INDEX stockprop_pub.pk_stockprop_pub;
DROP INDEX stockprop.pk_stockprop;
DROP INDEX stock_pub.pk_stock_pub;
DROP INDEX stock.pk_stock;

--
-- Drop all Genetic Module primary keys
--
DROP INDEX phenotype_comparison_cvterm.pk_phenotype_comparison_cvterm;
DROP INDEX phenotype_comparison.pk_phenotype_comparison;
DROP INDEX phenotype.pk_phenotype;
DROP INDEX phendesc.pk_phendesc;
DROP INDEX phenstatement.pk_phenstatement;
DROP INDEX environment_cvterm.pk_environment_cvterm;
DROP INDEX environment.pk_environment;
DROP INDEX feature_genotype.pk_feature_genotype;
DROP INDEX genotype.pk_genotype;

--
-- Drop all Contact Module primary keys
--
DROP INDEX contactprop.pk_contactprop;
DROP INDEX contact_relationship.pk_contact_relationship;
DROP INDEX contact.pk_contact;

--
-- Drop all Infection Module primary keys
--
DROP INDEX incident_relationship.pk_incident_relationship;
DROP INDEX incident_dbxref.pk_incident_dbxref;
DROP INDEX incident_cvterm.pk_incident_cvterm;
DROP INDEX incidentprop.pk_incidentprop;
DROP INDEX incident.pk_incident;
DROP INDEX transmission_dbxref.pk_transmission_dbxref;
DROP INDEX transmission_cvterm.pk_transmission_cvterm;
DROP INDEX transmissionprop.pk_transmissionprop;
DROP INDEX transmission.pk_transmission;
DROP INDEX infection_dbxref.pk_infection_dbxref;
DROP INDEX infection_cvterm.pk_infection_cvterm;
DROP INDEX infectionprop.pk_infectionprop;
DROP INDEX infection.pk_infection;
--
-- Drop all chado primary keys
--
DROP INDEX feature_cvterm_pub.pk_feature_cvterm_pub;
DROP INDEX feature_cvterm_dbxref.pk_feature_cvterm_dbxref;
DROP INDEX phylonode_relationship.pk_phylonode_relationship;
DROP INDEX phylonodeprop.pk_phylonodeprop;
DROP INDEX phylonode_organism.pk_phylonode_organism;
DROP INDEX phylonode_pub.pk_phylonode_pub;
DROP INDEX phylonode_dbxref.pk_phylonode_dbxref;
DROP INDEX phylonode.pk_phylonode;
DROP INDEX phylotree_pub.pk_phylotree_pub;
DROP INDEX phylotree.pk_phylotree;
DROP INDEX pubauthor.pk_pubauthor;
DROP INDEX tableinfo.pk_tableinfo;
DROP INDEX synonym.pk_synonym;
DROP INDEX pubprop.pk_pubprop;
DROP INDEX pub_relationship.pk_pub_relationship;
DROP INDEX pub_dbxref.pk_pub_dbxref;
DROP INDEX pub.pk_pub;
DROP INDEX project.pk_project;
DROP INDEX organismprop.pk_organismprop;
DROP INDEX organism_dbxref.pk_organism_dbxref;
DROP INDEX organism.pk_organism;
DROP INDEX featureprop_pub.pk_featureprop_pub;
DROP INDEX feature_synonym.pk_feature_synonym;
DROP INDEX feature_relprop_pub.pk_feature_relprop_pub;
DROP INDEX feature_relationshipprop.pk_feature_relationshipprop;
DROP INDEX feature_relationship_pub.pk_feature_relationship_pub;
DROP INDEX feature_relationship.pk_feature_relationship;
DROP INDEX feature_pub.pk_feature_pub;
DROP INDEX feature_dbxref.idx_feature_dbxref01;
DROP INDEX feature_cvtermprop.pk_feature_cvtermprop;
DROP INDEX feature_cvterm.pk_feature_cvterm;
DROP INDEX dbxrefprop.pk_dbxrefprop;
DROP INDEX dbxref.pk_dbxref;
DROP INDEX db.pk_db;
DROP INDEX cvtermsynonym.pk_cvtermsynonym;
DROP INDEX cvtermprop.pk_cvtermprop;
DROP INDEX cvtermpath.pk_cvtermpath;
DROP INDEX cvterm_relationship.pk_cvterm_relationship;
DROP INDEX cvterm_dbxref.idx_cvterm_dbxref01;
DROP INDEX cvterm.pk_cvterm;
DROP INDEX cv.pk_cv;
DROP INDEX analysis.pk_analysis;
DROP INDEX analysisfeature.idx_analysisfeature01;
DROP INDEX featureprop.pk_featureprop;
DROP INDEX featureloc.idx_featureloc01;
DROP INDEX feature.idx_feature06;
