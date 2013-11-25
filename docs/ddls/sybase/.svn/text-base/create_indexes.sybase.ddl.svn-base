-- createindexes
-- create clustered indexes first - they require more free space to create 
-- (up to 120% of the space consumed by the table itself)

-- create clustered indexes on large tables first, taking advantage of all
-- the free space in the database not yet consumed by other indexes 

CREATE UNIQUE CLUSTERED INDEX idx_feature06 ON feature (type_id, feature_id);
CREATE UNIQUE CLUSTERED INDEX idx_featureloc01 ON featureloc (feature_id, featureloc_id);
CREATE UNIQUE CLUSTERED INDEX pk_featureprop ON featureprop (featureprop_id);
CREATE UNIQUE CLUSTERED INDEX idx_analysisfeature01 ON analysisfeature (analysis_id, feature_id, pidentity, significance);

-- create remaining clustered indexes

CREATE UNIQUE CLUSTERED INDEX pk_analysis ON analysis (analysis_id);
CREATE UNIQUE CLUSTERED INDEX pk_cv ON cv (cv_id);
CREATE UNIQUE CLUSTERED INDEX pk_cvterm ON cvterm (cvterm_id);
CREATE UNIQUE CLUSTERED INDEX idx_cvterm_dbxref01 ON cvterm_dbxref (dbxref_id, cvterm_id);
CREATE UNIQUE CLUSTERED INDEX pk_cvterm_relationship ON cvterm_relationship (cvterm_relationship_id);
CREATE UNIQUE CLUSTERED INDEX pk_cvtermpath ON cvtermpath (cvtermpath_id);
CREATE UNIQUE CLUSTERED INDEX pk_cvtermprop ON cvtermprop (cvtermprop_id);
CREATE UNIQUE CLUSTERED INDEX pk_cvtermsynonym ON cvtermsynonym (cvtermsynonym_id);
CREATE UNIQUE CLUSTERED INDEX pk_db ON db (db_id);
CREATE UNIQUE CLUSTERED INDEX pk_dbxref ON dbxref (dbxref_id);
CREATE UNIQUE CLUSTERED INDEX pk_dbxrefprop ON dbxrefprop (dbxrefprop_id);
CREATE UNIQUE CLUSTERED INDEX pk_feature_cvterm ON feature_cvterm (feature_cvterm_id);
CREATE UNIQUE CLUSTERED INDEX pk_feature_cvtermprop ON feature_cvtermprop (feature_cvtermprop_id);
CREATE UNIQUE CLUSTERED INDEX idx_feature_dbxref01 ON feature_dbxref (dbxref_id, feature_id);
CREATE UNIQUE CLUSTERED INDEX pk_feature_pub ON feature_pub (feature_pub_id);
CREATE UNIQUE CLUSTERED INDEX pk_feature_relationship ON feature_relationship (feature_relationship_id);
CREATE UNIQUE CLUSTERED INDEX pk_feature_relationship_pub ON feature_relationship_pub (feature_relationship_pub_id);
CREATE UNIQUE CLUSTERED INDEX pk_feature_relationshipprop ON feature_relationshipprop (feature_relationshipprop_id);
CREATE UNIQUE CLUSTERED INDEX pk_feature_relprop_pub ON feature_relprop_pub (feature_relprop_pub_id);
CREATE UNIQUE CLUSTERED INDEX pk_feature_synonym ON feature_synonym (feature_synonym_id);
CREATE UNIQUE CLUSTERED INDEX pk_featureprop_pub ON featureprop_pub (featureprop_pub_id);
CREATE UNIQUE CLUSTERED INDEX pk_organism ON organism (organism_id);
CREATE UNIQUE CLUSTERED INDEX pk_organism_dbxref ON organism_dbxref (organism_dbxref_id);
CREATE UNIQUE CLUSTERED INDEX pk_organismprop ON organismprop (organismprop_id);
CREATE UNIQUE CLUSTERED INDEX pk_project ON project (project_id);
CREATE UNIQUE CLUSTERED INDEX pk_pub ON pub (pub_id);
CREATE UNIQUE CLUSTERED INDEX pk_pub_dbxref ON pub_dbxref (pub_dbxref_id);
CREATE UNIQUE CLUSTERED INDEX pk_pub_relationship ON pub_relationship (pub_relationship_id);
CREATE UNIQUE CLUSTERED INDEX pk_pubprop ON pubprop (pubprop_id);
CREATE UNIQUE CLUSTERED INDEX pk_synonym ON synonym (synonym_id);
CREATE UNIQUE CLUSTERED INDEX pk_tableinfo ON tableinfo (tableinfo_id);
CREATE UNIQUE CLUSTERED INDEX pk_pubauthor ON pubauthor (pubauthor_id);
CREATE UNIQUE CLUSTERED INDEX pk_phylotree ON phylotree (phylotree_id);
CREATE UNIQUE CLUSTERED INDEX pk_phylotree_pub ON phylotree_pub (phylotree_pub_id);
CREATE UNIQUE CLUSTERED INDEX pk_phylonode ON phylonode (phylonode_id);
CREATE UNIQUE CLUSTERED INDEX pk_phylonode_dbxref ON phylonode_dbxref (phylonode_dbxref_id);
CREATE UNIQUE CLUSTERED INDEX pk_phylonode_pub ON phylonode_pub (phylonode_pub_id);
CREATE UNIQUE CLUSTERED INDEX pk_phylonode_organism ON phylonode_organism (phylonode_organism_id);
CREATE UNIQUE CLUSTERED INDEX pk_phylonodeprop ON phylonodeprop (phylonodeprop_id);
CREATE UNIQUE CLUSTERED INDEX pk_phylonode_relationship ON phylonode_relationship (phylonode_relationship_id);
CREATE UNIQUE CLUSTERED INDEX pk_feature_cvterm_dbxref ON feature_cvterm_dbxref (feature_cvterm_dbxref_id);
CREATE UNIQUE CLUSTERED INDEX pk_feature_cvterm_pub ON feature_cvterm_pub (feature_cvterm_pub_id);
--
-- Infection Module primary keys follow
--
CREATE UNIQUE INDEX pk_infection ON infection (infection_id);
CREATE UNIQUE INDEX pk_infectionprop ON infectionprop (infectionprop_id);
CREATE UNIQUE INDEX pk_infection_cvterm ON infection_cvterm (infection_cvterm_id);
CREATE UNIQUE INDEX pk_infection_dbxref ON infection_dbxref (infection_dbxref_id);
CREATE UNIQUE INDEX pk_transmission ON transmission (transmission_id);
CREATE UNIQUE INDEX pk_transmissionprop ON transmissionprop (transmissionprop_id);
CREATE UNIQUE INDEX pk_transmission_cvterm ON transmission_cvterm (transmission_cvterm_id);
CREATE UNIQUE INDEX pk_transmission_dbxref ON transmission_dbxref (transmission_dbxref_id);
CREATE UNIQUE INDEX pk_incident ON incident (incident_id);
CREATE UNIQUE INDEX pk_incidentprop ON incidentprop (incidentprop_id);
CREATE UNIQUE INDEX pk_incident_cvterm ON incident_cvterm (incident_cvterm_id);
CREATE UNIQUE INDEX pk_incident_dbxref ON incident_dbxref (incident_dbxref_id);
CREATE UNIQUE INDEX pk_incident_relationship ON incident_relationship (incident_relationship_id);

--
-- Contact Module primary keys follow
--
CREATE UNIQUE INDEX pk_contact ON contact (contact_id);
CREATE UNIQUE INDEX pk_contact_relationship ON contact_relationship (contact_relationship_id);
CREATE UNIQUE INDEX pk_contactprop ON contactprop (contactprop_id);

--
-- Genetic Module primary keys follow
--
CREATE UNIQUE INDEX pk_genotype ON genotype (genotype_id);
CREATE UNIQUE INDEX pk_feature_genotype ON feature_genotype (feature_genotype_id);
CREATE UNIQUE INDEX pk_environment ON environment (environment_id);
CREATE UNIQUE INDEX pk_environment_cvterm ON environment_cvterm (environment_cvterm_id);
CREATE UNIQUE INDEX pk_phenstatement ON phenstatement (phenstatement_id);
CREATE UNIQUE INDEX pk_phendesc ON phendesc (phendesc_id);
CREATE UNIQUE INDEX pk_phenotype ON phenotype (phenotype_id);
CREATE UNIQUE INDEX pk_phenotype_comparison ON phenotype_comparison (phenotype_comparison_id);
CREATE UNIQUE INDEX pk_phenotype_comparison_cvterm ON phenotype_comparison_cvterm (phenotype_comparison_cvterm_id);

--
-- Stock Module primary keys follow
--
CREATE UNIQUE INDEX pk_stock ON stock (stock_id);
CREATE UNIQUE INDEX pk_stock_pub ON stock_pub (stock_pub_id);
CREATE UNIQUE INDEX pk_stockprop ON stockprop (stockprop_id);
CREATE UNIQUE INDEX pk_stockprop_pub ON stockprop_pub (stockprop_pub_id);
CREATE UNIQUE INDEX pk_stock_relationship ON stock_relationship (stock_relationship_id);
CREATE UNIQUE INDEX pk_stock_relationship_pub ON stock_relationship_pub (stock_relationship_pub_id);
CREATE UNIQUE INDEX pk_stock_dbxref ON stock_dbxref (stock_dbxref_id);
CREATE UNIQUE INDEX pk_stock_cvterm ON stock_cvterm (stock_cvterm_id);
CREATE UNIQUE INDEX pk_stock_genotype ON stock_genotype (stock_genotype_id);
CREATE UNIQUE INDEX pk_stockcollection ON stockcollection (stockcollection_id);
CREATE UNIQUE INDEX pk_stockcollectionprop ON stockcollectionprop (stockcollectionprop_id);
CREATE UNIQUE INDEX pk_stockcollection_stock ON stockcollection_stock (stockcollection_stock_id);

-- create all nonclustered indexes

CREATE UNIQUE NONCLUSTERED INDEX uc1_analysis ON analysis (program, programversion, sourcename);
CREATE UNIQUE NONCLUSTERED INDEX pk_analysisfeature ON analysisfeature (analysisfeature_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_analysisfeature ON analysisfeature (feature_id, analysis_id);
CREATE UNIQUE CLUSTERED INDEX idx_analysisprop01 ON analysisprop(analysis_id, type_id, value);
CREATE UNIQUE NONCLUSTERED INDEX uc1_cv ON cv (name);
CREATE UNIQUE NONCLUSTERED INDEX idx_cvterm01 ON cvterm (cv_id, cvterm_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_cvterm ON cvterm (name, cv_id, is_obsolete);
CREATE UNIQUE NONCLUSTERED INDEX uc1_cvterm_dbxref ON cvterm_dbxref (cvterm_id, dbxref_id);
CREATE UNIQUE NONCLUSTERED INDEX pk_cvterm_dbxref ON cvterm_dbxref (cvterm_dbxref_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_cvterm_relationship ON cvterm_relationship (type_id, subject_id, object_id);
CREATE NONCLUSTERED INDEX idx_cvterm_relationship01 ON cvterm_relationship (object_id);
CREATE NONCLUSTERED INDEX idx_cvterm_relationship02 ON cvterm_relationship (subject_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_cvtermpath ON cvtermpath (subject_id, object_id, type_id, pathdistance);
CREATE NONCLUSTERED INDEX idx_cvtermpath01 ON cvtermpath (type_id);
CREATE NONCLUSTERED INDEX idx_cvtermpath02 ON cvtermpath (cv_id);
CREATE NONCLUSTERED INDEX idx_cvtermpath03 ON cvtermpath (object_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_cvtermprop ON cvtermprop (cvterm_id, type_id, value, rank);
CREATE NONCLUSTERED INDEX idx_cvtermprop01 ON cvtermprop (cvterm_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_cvtermsynonym ON cvtermsynonym (cvterm_id, synonym);
CREATE NONCLUSTERED INDEX idx_cvtermsynonym01 ON cvtermsynonym (cvterm_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_db ON db (name);
CREATE UNIQUE NONCLUSTERED INDEX uc1_dbxref ON dbxref (db_id, accession, version);
CREATE UNIQUE NONCLUSTERED INDEX idx_dbxref01 ON dbxref (version, dbxref_id);
CREATE UNIQUE NONCLUSTERED INDEX idx_dbxref02 ON dbxref (accession, dbxref_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_dbxrefprop ON dbxrefprop (dbxref_id, type_id, value, rank);
CREATE NONCLUSTERED INDEX idx_dbxrefprop01 ON dbxrefprop (dbxref_id);
CREATE NONCLUSTERED INDEX idx_dbxrefprop02 ON dbxrefprop (type_id);
CREATE UNIQUE NONCLUSTERED INDEX idx_feature02 ON feature (organism_id, uniquename, type_id);
CREATE UNIQUE NONCLUSTERED INDEX idx_feature01 ON feature (feature_id);
CREATE UNIQUE NONCLUSTERED INDEX idx_feature04 ON feature (dbxref_id, feature_id);
CREATE UNIQUE NONCLUSTERED INDEX idx_feature03 ON feature (uniquename, feature_id);
CREATE NONCLUSTERED INDEX idx_feature_cvterm01 ON feature_cvterm (pub_id);
CREATE UNIQUE NONCLUSTERED INDEX idx_feature_cvterm02 ON feature_cvterm (cvterm_id, feature_id, feature_cvterm_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_feature_cvtermprop ON feature_cvtermprop (feature_cvterm_id, type_id, rank);
CREATE NONCLUSTERED INDEX idx_feature_cvtermprop01 ON feature_cvtermprop (type_id);
CREATE UNIQUE NONCLUSTERED INDEX pk_feature_dbxref ON feature_dbxref (feature_dbxref_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_feature_dbxref ON feature_dbxref (feature_id, dbxref_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_feature_pub ON feature_pub (feature_id, pub_id);
CREATE NONCLUSTERED INDEX idx_feature_pub01 ON feature_pub (pub_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_feature_relationship ON feature_relationship (subject_id, object_id, type_id);
CREATE NONCLUSTERED INDEX idx_feature_relationship01 ON feature_relationship (object_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_feature_relationship_pub ON feature_relationship_pub (feature_relationship_id, pub_id);
CREATE NONCLUSTERED INDEX idx_feature_relationship_pub01 ON feature_relationship_pub (pub_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_feature_relationshipprop ON feature_relationshipprop (feature_relationship_id, type_id, rank);
CREATE NONCLUSTERED INDEX idx_feature_relationshipprop01 ON feature_relationshipprop (type_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_feature_relprop_pub ON feature_relprop_pub (feature_relationshipprop_id, pub_id);
CREATE NONCLUSTERED INDEX idx_feature_relprop_pub01 ON feature_relprop_pub (pub_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_feature_synonym ON feature_synonym (synonym_id, feature_id, pub_id);
CREATE NONCLUSTERED INDEX idx_feature_synonym01 ON feature_synonym (pub_id);
CREATE NONCLUSTERED INDEX idx_feature_synonym02 ON feature_synonym (feature_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_featureloc ON featureloc (feature_id, locgroup, rank);
CREATE UNIQUE NONCLUSTERED INDEX idx_featureloc02 ON featureloc (srcfeature_id, feature_id, featureloc_id);
CREATE NONCLUSTERED INDEX idx_featureloc03 ON featureloc (srcfeature_id, fmin, fmax);
CREATE UNIQUE NONCLUSTERED INDEX idx_featureloc06 ON featureloc (featureloc_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_featureprop ON featureprop (feature_id, type_id, value, rank);
CREATE NONCLUSTERED INDEX idx_featureprop01 ON featureprop (type_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_featureprop_pub ON featureprop_pub (featureprop_id, pub_id);
CREATE NONCLUSTERED INDEX idx_featureprop_pub01 ON featureprop_pub (pub_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_organism ON organism (genus, species);
CREATE UNIQUE NONCLUSTERED INDEX uc1_organism_dbxref ON organism_dbxref (organism_id, dbxref_id);
CREATE NONCLUSTERED INDEX idx_organism_dbxref01 ON organism_dbxref (organism_id);
CREATE NONCLUSTERED INDEX idx_organism_dbxref02 ON organism_dbxref (dbxref_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_organismprop ON organismprop (organism_id, type_id, value, rank);
CREATE NONCLUSTERED INDEX idx_organismprop01 ON organismprop (type_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_project ON project (name);
CREATE UNIQUE NONCLUSTERED INDEX uc1_pub ON pub (uniquename, type_id);
CREATE NONCLUSTERED INDEX idx_pub01 ON pub (type_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_pubauthor ON pubauthor (pub_id, rank);
CREATE NONCLUSTERED INDEX idx_pubauthor01 ON pubauthor (pub_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_pub_dbxref ON pub_dbxref (pub_id, dbxref_id);
CREATE NONCLUSTERED INDEX idx_pub_dbxref01 ON pub_dbxref (pub_id);
CREATE NONCLUSTERED INDEX idx_pub_dbxref02 ON pub_dbxref (dbxref_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_pub_relationship ON pub_relationship (subject_id, object_id, type_id);
CREATE NONCLUSTERED INDEX idx_pub_relationship01 ON pub_relationship (type_id);
CREATE NONCLUSTERED INDEX idx_pub_relationship02 ON pub_relationship (object_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_pubprop ON pubprop (pub_id, type_id, value);
CREATE NONCLUSTERED INDEX idx_pubprop01 ON pubprop (type_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_synonym ON synonym (name, type_id);
CREATE NONCLUSTERED INDEX idx_synonym01 ON synonym (type_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_tableinfo ON tableinfo (name);
CREATE UNIQUE NONCLUSTERED INDEX uc1_phylotree ON phylotree_pub (phylotree_id, pub_id);
CREATE NONCLUSTERED INDEX idx_phylotree_pub01 ON phylotree_pub (phylotree_id);
CREATE NONCLUSTERED INDEX idx_phylotree_pub02 ON phylotree_pub (pub_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_phylonode ON phylonode (phylotree_id, left_idx);
CREATE UNIQUE NONCLUSTERED INDEX uc2_phylonode ON phylonode (phylotree_id, right_idx);
CREATE NONCLUSTERED INDEX idx_phylonode01 ON phylonode (phylotree_id);
CREATE NONCLUSTERED INDEX idx_phylonode02 ON phylonode (type_id);
CREATE NONCLUSTERED INDEX idx_phylonode03 ON phylonode (feature_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_phylonode_dbxref ON phylonode_dbxref (phylonode_id, dbxref_id);
CREATE NONCLUSTERED INDEX idx_phylonode_dbxref01 ON phylonode_dbxref (phylonode_id);
CREATE NONCLUSTERED INDEX idx_phylonode_dbxref02 ON phylonode_dbxref (dbxref_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_phylonode_pub ON phylonode_pub (phylonode_id, pub_id);
CREATE NONCLUSTERED INDEX idx_phylonode_pub01 ON phylonode_pub (phylonode_id);
CREATE NONCLUSTERED INDEX idx_phylonode_pub02 ON phylonode_pub (pub_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_phylonode_organism ON phylonode_organism (phylonode_id, organism_id);
CREATE NONCLUSTERED INDEX idx_phylonode_organism01 ON phylonode_organism (phylonode_id);
CREATE NONCLUSTERED INDEX idx_phylonode_organism02 ON phylonode_organism (organism_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_phylonodeprop ON phylonodeprop (phylonode_id, type_id, value, rank);
CREATE NONCLUSTERED INDEX idx_phylonodeprop01 ON phylonodeprop (phylonode_id);
CREATE NONCLUSTERED INDEX idx_phylonodeprop02 ON phylonodeprop (type_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_phylonode_relationship ON phylonode_relationship (subject_id, object_id, type_id);
CREATE NONCLUSTERED INDEX idx_phylonode_relationship01 ON phylonode_relationship (subject_id);
CREATE NONCLUSTERED INDEX idx_phylonode_relationship02 ON phylonode_relationship (object_id);
CREATE NONCLUSTERED INDEX idx_phylonode_relationship03 ON phylonode_relationship (type_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_feature_cvterm_dbxref ON feature_cvterm_dbxref (feature_cvterm_id, dbxref_id);
CREATE NONCLUSTERED INDEX idx_feature_cvterm_dbxref01 ON feature_cvterm_dbxref (feature_cvterm_id);
CREATE NONCLUSTERED INDEX idx_feature_cvterm_dbxref02 ON feature_cvterm_dbxref (dbxref_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_feature_cvterm_pub ON feature_cvterm_pub (feature_cvterm_id, pub_id);
CREATE NONCLUSTERED INDEX idx_feature_cvterm_pub01 ON feature_cvterm_pub (feature_cvterm_id);
CREATE NONCLUSTERED INDEX idx_feature_cvterm_pub02 ON feature_cvterm_pub (pub_id);
--
-- Infection Module indices and constraints follow
--
CREATE UNIQUE INDEX uc1_infectionprop ON infectionprop (infection_id, type_id, value, rank);
CREATE INDEX idx_infectionprop01 ON infectionprop (infection_id);
CREATE INDEX idx_infection_cvterm01 ON infection_cvterm (pub_id);
CREATE UNIQUE INDEX idx_infection_cvterm02 ON infection_cvterm (cvterm_id, infection_id, infection_cvterm_id);
CREATE UNIQUE  INDEX uc1_infection_dbxref ON infection_dbxref (infection_id, dbxref_id);
CREATE INDEX idx_infection_dbxref01 ON infection_dbxref (infection_id);
CREATE INDEX idx_infection_dbxref02 ON infection_dbxref (dbxref_id);
CREATE UNIQUE INDEX uc1_transmission ON transmission (type_id, subject_id, object_id, portal_id);
CREATE INDEX idx_transmission01 ON transmission (object_id);
CREATE INDEX idx_transmission02 ON transmission (subject_id);
CREATE UNIQUE INDEX uc1_transmissionprop ON transmissionprop (transmission_id, type_id, value, rank);
CREATE INDEX idx_transmissionprop01 ON transmissionprop (transmission_id);
CREATE INDEX idx_transmission_cvterm01 ON transmission_cvterm (pub_id);
CREATE UNIQUE INDEX idx_transmission_cvterm02 ON transmission_cvterm (cvterm_id, transmission_id, transmission_cvterm_id);
CREATE UNIQUE  INDEX uc1_transmission_dbxref ON transmission_dbxref (transmission_id, dbxref_id);
CREATE INDEX idx_transmission_dbxref01 ON transmission_dbxref (transmission_id);
CREATE INDEX idx_transmission_dbxref02 ON transmission_dbxref (dbxref_id);
CREATE INDEX idx_incident01 ON incident (period_start);
CREATE INDEX idx_incident02 ON incident (period_end);
CREATE UNIQUE INDEX uc1_incidentprop ON incidentprop (incident_id, type_id, value, rank);
CREATE INDEX idx_incidentprop01 ON incidentprop (incident_id);
CREATE INDEX idx_incident_cvterm01 ON incident_cvterm (pub_id);
CREATE UNIQUE INDEX idx_incident_cvterm02 ON incident_cvterm (cvterm_id, incident_id, incident_cvterm_id);
CREATE UNIQUE  INDEX uc1_incident_dbxref ON incident_dbxref (incident_id, dbxref_id);
CREATE INDEX idx_incident_dbxref01 ON incident_dbxref (incident_id);
CREATE INDEX idx_incident_dbxref02 ON incident_dbxref (dbxref_id);
CREATE UNIQUE INDEX uc1_incident_relationship ON incident_relationship (subject_id, object_id, type_id);
CREATE INDEX idx_incident_relationship01 ON incident_relationship (object_id);
CREATE INDEX idx_incident_relationship02 ON incident_relationship (subject_id);
CREATE UNIQUE  INDEX uc1_infection_pub ON infection_pub (infection_id, pub_id);
CREATE INDEX idx_infection_pub01 ON infection_pub (pub_id);
CREATE UNIQUE  INDEX uc1_transmission_pub ON transmission_pub (transmission_id, pub_id);
CREATE INDEX idx_transmission_pub01 ON transmission_pub (pub_id);
CREATE UNIQUE  INDEX uc1_incident_pub ON incident_pub (incident_id, pub_id);
CREATE INDEX idx_incident_pub01 ON incident_pub (pub_id);


--
-- Contact module indices follow
--
CREATE CLUSTERED INDEX idx_contact01 ON contact (type_id,name);
CREATE CLUSTERED INDEX idx_contact_relationship01 ON contact_relationship (type_id, subject_id, object_id);
CREATE CLUSTERED INDEX idx_contactprop01 ON contactprop (contact_id, type_id, value);

--
-- Genetic module indices follow
--
CREATE UNIQUE CLUSTERED INDEX uc1_genotype ON genotype (uniquename);
CREATE NONCLUSTERED INDEX idx_genotype01 ON genotype (name);
CREATE UNIQUE NONCLUSTERED INDEX uc1_feature_genotype ON feature_genotype (feature_id, genotype_id, cvterm_id, chromosome_id, rank, cgroup);
CREATE CLUSTERED INDEX idx_feature_genotype01 ON feature_genotype (feature_id);
CREATE NONCLUSTERED INDEX idx_feature_genotype02 ON feature_genotype (genotype_id);
CREATE UNIQUE CLUSTERED INDEX uc1_environment ON environment (uniquename);
CREATE UNIQUE CLUSTERED INDEX uc1_environment_cvterm ON environment_cvterm (environment_id, cvterm_id);
CREATE INDEX idx_environment_cvterm01 ON environment_cvterm (environment_id);
CREATE INDEX idx_environment_cvterm02 ON environment_cvterm (cvterm_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_phenstatement ON phenstatement (genotype_id, phenotype_id, environment_id, type_id, pub_id);
CREATE CLUSTERED INDEX idx_phenstatement01 ON phenstatement (genotype_id);
CREATE NONCLUSTERED INDEX idx_phenstatement02 ON phenstatement (phenotype_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_phendesc ON phendesc (genotype_id, environment_id, type_id, pub_id);
CREATE CLUSTERED INDEX idx_phendesc01 ON phendesc (genotype_id);
CREATE NONCLUSTERED INDEX idx_phendesc02 ON phendesc (environment_id);
CREATE NONCLUSTERED INDEX idx_phendesc03 ON phendesc (pub_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_phenotype_comparison ON phenotype_comparison (genotype1_id, environment1_id, genotype2_id, environment2_id, phenotype1_id, pub_id);
CREATE CLUSTERED INDEX idx_phenotype_comparison01 ON phenotype_comparison (genotype1_id);
CREATE NONCLUSTERED INDEX idx_phenotype_comparison02 ON phenotype_comparison (genotype2_id);
CREATE NONCLUSTERED INDEX idx_phenotype_comparison03 ON phenotype_comparison (pub_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_phenotype_comparison_cvterm ON phenotype_comparison_cvterm (phenotype_comparison_id, cvterm_id);
CREATE CLUSTERED INDEX idx_phenotype_comparison_cvterm01 ON phenotype_comparison_cvterm (phenotype_comparison_id);
CREATE NONCLUSTERED INDEX idx_phenotype_comparison_cvterm02 ON phenotype_comparison_cvterm (cvterm_id);

--
-- Stock module indices follow
--
CREATE UNIQUE NONCLUSTERED INDEX uc1_stock ON stock (organism_id, uniquename, type_id);
CREATE CLUSTERED INDEX idx_stock01 ON stock (dbxref_id);
CREATE NONCLUSTERED INDEX idx_stock02 ON stock (organism_id);
CREATE NONCLUSTERED INDEX idx_stock03 ON stock (type_id);
CREATE NONCLUSTERED INDEX idx_stock04 ON stock (uniquename);
CREATE UNIQUE NONCLUSTERED INDEX uc1_stock_pub ON stock_pub (stock_id, pub_id);
CREATE CLUSTERED INDEX idx_stock_pub01 ON stock_pub (stock_id);
CREATE NONCLUSTERED INDEX idx_stock_pub02 ON stock_pub (pub_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_stockprop ON stockprop (stock_id, type_id, value, rank);
CREATE CLUSTERED INDEX idx_stockprop01 ON stockprop (stock_id);
CREATE NONCLUSTERED INDEX idx_stockprop02 ON stockprop (type_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_stockprop_pub ON stockprop_pub (stockprop_id, pub_id);
CREATE CLUSTERED INDEX idx_stockprop_pub01 ON stockprop_pub (stockprop_id);
CREATE NONCLUSTERED INDEX idx_stockprop_pub02 ON stockprop_pub (pub_id);
CREATE UNIQUE NONCLUSTERED INDEX uc1_stock_relationship ON stock_relationship (subject_id, object_id, type_id, rank);
CREATE CLUSTERED INDEX idx_stock_relationship01 ON stock_relationship (subject_id);
CREATE NONCLUSTERED INDEX idx_stock_relationship02 ON stock_relationship (object_id);
CREATE NONCLUSTERED INDEX idx_stock_relationship03 ON stock_relationship (type_id);
CREATE UNIQUE CLUSTERED INDEX idx_stockcollection_stock01 ON stockcollection_stock (stockcollection_id, stock_id);


 
-- with all indexes in place, we can add the constraints

ALTER TABLE dbxref ADD CONSTRAINT fk_dbxref01 FOREIGN KEY (db_id) REFERENCES db(db_id);
ALTER TABLE cvterm ADD CONSTRAINT fk_cvterm01 FOREIGN KEY (cv_id) REFERENCES cv(cv_id);
ALTER TABLE cvterm ADD CONSTRAINT fk_cvterm02 FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id);
ALTER TABLE cvterm_relationship ADD CONSTRAINT fk_cvterm_relationship01 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE cvterm_relationship ADD CONSTRAINT fk_cvterm_relationship02 FOREIGN KEY (subject_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE cvterm_relationship ADD CONSTRAINT fk_cvterm_relationship03 FOREIGN KEY (object_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE cvtermpath ADD CONSTRAINT fk_cvtermpath01 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE cvtermpath ADD CONSTRAINT fk_cvtermpath02 FOREIGN KEY (subject_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE cvtermpath ADD CONSTRAINT fk_cvtermpath03 FOREIGN KEY (object_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE cvtermpath ADD CONSTRAINT fk_cvtermpath04 FOREIGN KEY (cv_id) REFERENCES cv(cv_id);
ALTER TABLE cvtermsynonym ADD CONSTRAINT fk_cvtermsynonym01 FOREIGN KEY (cvterm_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE cvtermsynonym ADD CONSTRAINT fk_cvtermsynonym02 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE cvterm_dbxref ADD CONSTRAINT fk_cvterm_dbxref01 FOREIGN KEY (cvterm_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE cvterm_dbxref ADD CONSTRAINT fk_cvterm_dbxref02 FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id);
ALTER TABLE cvtermprop ADD CONSTRAINT fk_cvtermprop01 FOREIGN KEY (cvterm_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE cvtermprop ADD CONSTRAINT fk_cvtermprop02 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE dbxrefprop ADD CONSTRAINT fk_dbxrefprop01 FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id);
ALTER TABLE dbxrefprop ADD CONSTRAINT fk_dbxrefprop02 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE pub ADD CONSTRAINT fk_pub01 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE pub_relationship ADD CONSTRAINT fk_pub_relationship01 FOREIGN KEY (subject_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE pub_relationship ADD CONSTRAINT fk_pub_relationship02 FOREIGN KEY (object_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE pub_relationship ADD CONSTRAINT fk_pub_relationship03 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE pub_dbxref ADD CONSTRAINT fk_pub_dbxref01 FOREIGN KEY (pub_id) REFERENCES pub(pub_id);
ALTER TABLE pub_dbxref ADD CONSTRAINT fk_pub_dbxref02 FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id);
ALTER TABLE pubauthor ADD CONSTRAINT fk_pubauthor01 FOREIGN KEY (pub_id) REFERENCES pub(pub_id);
ALTER TABLE pubprop ADD CONSTRAINT fk_pubprop01 FOREIGN KEY (pub_id) REFERENCES pub(pub_id);
ALTER TABLE pubprop ADD CONSTRAINT fk_pubprop02 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE organism_dbxref ADD CONSTRAINT fk_organism_dbxref01 FOREIGN KEY (organism_id) REFERENCES organism(organism_id);
ALTER TABLE organism_dbxref ADD CONSTRAINT fk_organism_dbxref02 FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id);
ALTER TABLE organismprop ADD CONSTRAINT fk_organismprop01 FOREIGN KEY (organism_id) REFERENCES organism(organism_id);
ALTER TABLE organismprop ADD CONSTRAINT fk_organismprop02 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE feature ADD CONSTRAINT fk_feature01 FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id);
ALTER TABLE feature ADD CONSTRAINT fk_feature02 FOREIGN KEY (organism_id) REFERENCES organism(organism_id);
ALTER TABLE feature ADD CONSTRAINT fk_feature03 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE featureloc ADD CONSTRAINT fk_featureloc01 FOREIGN KEY (feature_id) REFERENCES feature(feature_id);
ALTER TABLE featureloc ADD CONSTRAINT fk_featureloc02 FOREIGN KEY (srcfeature_id) REFERENCES feature(feature_id);
ALTER TABLE feature_pub ADD CONSTRAINT fk_feature_pub01 FOREIGN KEY (feature_id) REFERENCES feature(feature_id);
ALTER TABLE feature_pub ADD CONSTRAINT fk_feature_pub02 FOREIGN KEY (pub_id) REFERENCES pub(pub_id);
ALTER TABLE featureprop ADD CONSTRAINT fk_featureprop01 FOREIGN KEY (feature_id) REFERENCES feature(feature_id);
ALTER TABLE featureprop ADD CONSTRAINT fk_featureprop02 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE featureprop_pub ADD CONSTRAINT fk_featureprop_pub01 FOREIGN KEY (featureprop_id) REFERENCES featureprop(featureprop_id);
ALTER TABLE featureprop_pub ADD CONSTRAINT fk_featureprop_pub02 FOREIGN KEY (pub_id) REFERENCES pub(pub_id);
ALTER TABLE feature_dbxref ADD CONSTRAINT fk_feature_dbxref01 FOREIGN KEY (feature_id) REFERENCES feature(feature_id);
ALTER TABLE feature_dbxref ADD CONSTRAINT fk_feature_dbxref02 FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id);
ALTER TABLE feature_relationship ADD CONSTRAINT fk_feature_relationship01 FOREIGN KEY (subject_id) REFERENCES feature(feature_id);
ALTER TABLE feature_relationship ADD CONSTRAINT fk_feature_relationship02 FOREIGN KEY (object_id) REFERENCES feature(feature_id);
ALTER TABLE feature_relationship ADD CONSTRAINT fk_feature_relationship03 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE feature_relationship_pub ADD CONSTRAINT fk_feature_relationship_pub01 FOREIGN KEY (feature_relationship_id) REFERENCES feature_relationship(feature_relationship_id);
ALTER TABLE feature_relationship_pub ADD CONSTRAINT fk_feature_relationship_pub02 FOREIGN KEY (pub_id) REFERENCES pub(pub_id);
ALTER TABLE feature_relationshipprop ADD CONSTRAINT fk_feature_relationshipprop01 FOREIGN KEY (feature_relationship_id) REFERENCES feature_relationship(feature_relationship_id);
ALTER TABLE feature_relationshipprop ADD CONSTRAINT fk_feature_relationshipprop02 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE feature_relprop_pub ADD CONSTRAINT fk_feature_relprop_pub01 FOREIGN KEY (feature_relationshipprop_id) REFERENCES feature_relationshipprop(feature_relationshipprop_id);
ALTER TABLE feature_relprop_pub ADD CONSTRAINT fk_feature_relprop_pub02 FOREIGN KEY (pub_id) REFERENCES pub(pub_id);
ALTER TABLE feature_cvterm ADD CONSTRAINT fk_feature_cvterm01 FOREIGN KEY (feature_id) REFERENCES feature(feature_id);
ALTER TABLE feature_cvterm ADD CONSTRAINT fk_feature_cvterm02 FOREIGN KEY (cvterm_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE feature_cvterm ADD CONSTRAINT fk_feature_cvterm03 FOREIGN KEY (pub_id) REFERENCES pub(pub_id);
ALTER TABLE feature_cvtermprop ADD CONSTRAINT fk_feature_cvtermprop01 FOREIGN KEY (feature_cvterm_id) REFERENCES feature_cvterm(feature_cvterm_id);
ALTER TABLE feature_cvtermprop ADD CONSTRAINT fk_feature_cvtermprop02 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE feature_cvterm_dbxref ADD CONSTRAINT fk_feature_cvterm_dbxref01 FOREIGN KEY (feature_cvterm_id) REFERENCES feature_cvterm(feature_cvterm_id);
ALTER TABLE feature_cvterm_dbxref ADD CONSTRAINT fk_feature_cvterm_dbxref02 FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id);
ALTER TABLE feature_cvterm_pub ADD CONSTRAINT fk_feature_cvterm_pub01 FOREIGN KEY (feature_cvterm_id) REFERENCES feature_cvterm(feature_cvterm_id);
ALTER TABLE feature_cvterm_pub ADD CONSTRAINT fk_feature_cvterm_pub02 FOREIGN KEY (pub_id) REFERENCES pub(pub_id);
ALTER TABLE synonym ADD CONSTRAINT fk_synonym01 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE feature_synonym ADD CONSTRAINT fk_feature_synonym01 FOREIGN KEY (synonym_id) REFERENCES synonym(synonym_id);
ALTER TABLE feature_synonym ADD CONSTRAINT fk_feature_synonym02 FOREIGN KEY (feature_id) REFERENCES feature(feature_id);
ALTER TABLE feature_synonym ADD CONSTRAINT fk_feature_synonym03 FOREIGN KEY (pub_id) REFERENCES pub(pub_id);
ALTER TABLE analysisprop ADD CONSTRAINT fk_analysisprop01 FOREIGN KEY (analysis_id) REFERENCES analysis(analysis_id);
ALTER TABLE analysisprop ADD CONSTRAINT fk_analysisprop02 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE analysisfeature ADD CONSTRAINT fk_analysisfeature01 FOREIGN KEY (feature_id) REFERENCES feature(feature_id);
ALTER TABLE analysisfeature ADD CONSTRAINT fk_analysisfeature02 FOREIGN KEY (analysis_id) REFERENCES analysis(analysis_id);
ALTER TABLE analysisfeature ADD CONSTRAINT fk_analysisfeature03 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE phylotree ADD CONSTRAINT fk_phylotree01 FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id);
ALTER TABLE phylotree ADD CONSTRAINT fk_phylotree02 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE phylotree_pub ADD CONSTRAINT fk_phylotree_pub01 FOREIGN KEY (phylotree_id) REFERENCES phylotree(phylotree_id);
ALTER TABLE phylotree_pub ADD CONSTRAINT fk_phylotree_pub02 FOREIGN KEY (pub_id) REFERENCES pub(pub_id);
ALTER TABLE phylonode ADD CONSTRAINT fk_phylonode01 FOREIGN KEY (phylotree_id) REFERENCES phylotree(phylotree_id);
ALTER TABLE phylonode ADD CONSTRAINT fk_phylonode02 FOREIGN KEY (parent_phylonode_id) REFERENCES phylonode(phylonode_id);
ALTER TABLE phylonode ADD CONSTRAINT fk_phylonode03 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE phylonode ADD CONSTRAINT fk_phylonode04 FOREIGN KEY (type_id) REFERENCES feature(feature_id);
ALTER TABLE phylonode_dbxref ADD CONSTRAINT fk_phylonode_dbxref01 FOREIGN KEY (phylonode_id) REFERENCES phylonode(phylonode_id);
ALTER TABLE phylonode_dbxref ADD CONSTRAINT fk_phylonode_dbxref02 FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id);
ALTER TABLE phylonode_pub ADD CONSTRAINT fk_phylonode_pub01 FOREIGN KEY (phylonode_id) REFERENCES phylonode(phylonode_id);
ALTER TABLE phylonode_pub ADD CONSTRAINT fk_phylonode_pub02 FOREIGN KEY (pub_id) REFERENCES pub(pub_id);
ALTER TABLE phylonode_organism ADD CONSTRAINT fk_phylonode_organism01 FOREIGN KEY (phylonode_id) REFERENCES phylonode(phylonode_id);
ALTER TABLE phylonode_organism ADD CONSTRAINT fk_phylonode_organism02 FOREIGN KEY (organism_id) REFERENCES organism(organism_id);
ALTER TABLE phylonodeprop ADD CONSTRAINT fk_phylonodeprop01 FOREIGN KEY (phylonode_id) REFERENCES phylonode(phylonode_id);
ALTER TABLE phylonodeprop ADD CONSTRAINT fk_phylonodeprop02 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE phylonode_relationship ADD CONSTRAINT fk_phylonode_relationship01 FOREIGN KEY (subject_id) REFERENCES phylonode(phylonode_id);
ALTER TABLE phylonode_relationship ADD CONSTRAINT fk_phylonode_relationship02 FOREIGN KEY (object_id) REFERENCES phylonode(phylonode_id);
ALTER TABLE phylonode_relationship ADD CONSTRAINT fk_phylonode_relationship03 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
--
-- Infection Module foreign keys follow
--
ALTER TABLE infection ADD CONSTRAINT fk_infection01 FOREIGN KEY (pathogen_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE infection ADD CONSTRAINT fk_infection02 FOREIGN KEY (hostres_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE infection ADD CONSTRAINT fk_infection03 FOREIGN KEY (disease_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE infectionprop ADD CONSTRAINT fk_infectionprop01 FOREIGN KEY (infection_id) REFERENCES infection(infection_id);
ALTER TABLE infectionprop ADD CONSTRAINT fk_infectionprop02 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE infection_cvterm ADD CONSTRAINT fk_infection_cvterm01 FOREIGN KEY (infection_id) REFERENCES infection(infection_id);
ALTER TABLE infection_cvterm ADD CONSTRAINT fk_infection_cvterm02 FOREIGN KEY (cvterm_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE infection_cvterm ADD CONSTRAINT fk_infection_cvterm03 FOREIGN KEY (pub_id) REFERENCES pub(pub_id);
ALTER TABLE infection_dbxref ADD CONSTRAINT fk_infection_dbxref01 FOREIGN KEY (infection_id) REFERENCES infection(infection_id);
ALTER TABLE infection_dbxref ADD CONSTRAINT fk_infection_dbxref02 FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id);
ALTER TABLE transmission ADD CONSTRAINT fk_transmission01 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE transmission ADD CONSTRAINT fk_transmission02 FOREIGN KEY (subject_id) REFERENCES infection(infection_id);
ALTER TABLE transmission ADD CONSTRAINT fk_transmission03 FOREIGN KEY (object_id) REFERENCES infection(infection_id);
ALTER TABLE transmission ADD CONSTRAINT fk_transmission04 FOREIGN KEY (portal_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE transmissionprop ADD CONSTRAINT fk_transmissionprop01 FOREIGN KEY (transmission_id) REFERENCES transmission(transmission_id);
ALTER TABLE transmissionprop ADD CONSTRAINT fk_transmissionprop02 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE transmission_cvterm ADD CONSTRAINT fk_transmission_cvterm01 FOREIGN KEY (transmission_id) REFERENCES transmission(transmission_id);
ALTER TABLE transmission_cvterm ADD CONSTRAINT fk_transmission_cvterm02 FOREIGN KEY (cvterm_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE transmission_cvterm ADD CONSTRAINT fk_transmission_cvterm03 FOREIGN KEY (pub_id) REFERENCES pub(pub_id);
ALTER TABLE transmission_dbxref ADD CONSTRAINT fk_transmission_dbxref01 FOREIGN KEY (transmission_id) REFERENCES transmission(transmission_id);
ALTER TABLE transmission_dbxref ADD CONSTRAINT fk_transmission_dbxref02 FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id);
ALTER TABLE incident ADD CONSTRAINT fk_incident01 FOREIGN KEY (transmission_id) REFERENCES transmission(transmission_id);
-- this will be changed after addition of Geography Module
ALTER TABLE incident ADD CONSTRAINT fk_incident02 FOREIGN KEY (location_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE incidentprop ADD CONSTRAINT fk_incidentprop01 FOREIGN KEY (incident_id) REFERENCES incident(incident_id);
ALTER TABLE incidentprop ADD CONSTRAINT fk_incidentprop02 FOREIGN KEY (type_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE incident_cvterm ADD CONSTRAINT fk_incident_cvterm01 FOREIGN KEY (incident_id) REFERENCES incident(incident_id);
ALTER TABLE incident_cvterm ADD CONSTRAINT fk_incident_cvterm02 FOREIGN KEY (cvterm_id) REFERENCES cvterm(cvterm_id);
ALTER TABLE incident_cvterm ADD CONSTRAINT fk_incident_cvterm03 FOREIGN KEY (pub_id) REFERENCES pub(pub_id);
ALTER TABLE incident_dbxref ADD CONSTRAINT fk_incident_dbxref01 FOREIGN KEY (incident_id) REFERENCES incident(incident_id);
ALTER TABLE incident_dbxref ADD CONSTRAINT fk_incident_dbxref02 FOREIGN KEY (dbxref_id) REFERENCES dbxref(dbxref_id);
ALTER TABLE incident_relationship ADD CONSTRAINT fk_incident_relationship01 FOREIGN KEY (type_id) REFERENCES cvterm (cvterm_id);
ALTER TABLE incident_relationship ADD CONSTRAINT fk_incident_relationship02 FOREIGN KEY (subject_id) REFERENCES incident (incident_id);
ALTER TABLE incident_relationship ADD CONSTRAINT fk_incident_relationship03 FOREIGN KEY (object_id) REFERENCES incident (incident_id);
ALTER TABLE infection_pub ADD CONSTRAINT fk_infection_pub01 FOREIGN KEY (infection_id) REFERENCES infection(infection_id);
ALTER TABLE infection_pub ADD CONSTRAINT fk_infection_pub02 FOREIGN KEY (pub_id) REFERENCES pub(pub_id);
ALTER TABLE transmission_pub ADD CONSTRAINT fk_transmission_pub01 FOREIGN KEY (transmission_id) REFERENCES transmission(transmission_id);
ALTER TABLE transmission_pub ADD CONSTRAINT fk_transmission_pub02 FOREIGN KEY (pub_id) REFERENCES pub(pub_id);
ALTER TABLE incident_pub ADD CONSTRAINT fk_incident_pub01 FOREIGN KEY (incident_id) REFERENCES incident(incident_id);
ALTER TABLE incident_pub ADD CONSTRAINT fk_incident_pub02 FOREIGN KEY (pub_id) REFERENCES pub(pub_id);


--
-- Contact Module foreign key constraints follow
--
ALTER TABLE contact ADD CONSTRAINT fk_contact01 FOREIGN KEY (type_id) REFERENCES cvterm (cvterm_id);
ALTER TABLE contact_relationship ADD CONSTRAINT fk_contact_relationship01 FOREIGN KEY (type_id) REFERENCES cvterm (cvterm_id);
ALTER TABLE contact_relationship ADD CONSTRAINT fk_contact_relationship02 FOREIGN KEY (subject_id) REFERENCES contact (contact_id);
ALTER TABLE contact_relationship ADD CONSTRAINT fk_contact_relationship03 FOREIGN KEY (object_id) REFERENCES contact (contact_id);
ALTER TABLE contactprop ADD CONSTRAINT fk_contactprop01 FOREIGN KEY (contact_id) REFERENCES contact (contact_id);
ALTER TABLE contactprop ADD CONSTRAINT fk_contactprop02 FOREIGN KEY (type_id) REFERENCES cvterm (cvterm_id);

--
-- Genetic Module foreign key constraints follow
--
ALTER TABLE feature_genotype ADD CONSTRAINT fk_feature_genotype01 FOREIGN KEY (feature_id) REFERENCES feature (feature_id);
ALTER TABLE feature_genotype ADD CONSTRAINT fk_feature_genotype02 FOREIGN KEY (genotype_id) REFERENCES genotype (genotype_id);
ALTER TABLE feature_genotype ADD CONSTRAINT fk_feature_genotype03 FOREIGN KEY (chromosome_id) REFERENCES feature (feature_id);
ALTER TABLE feature_genotype ADD CONSTRAINT fk_feature_genotype04 FOREIGN KEY (cvterm_id) REFERENCES cvterm (cvterm_id);
ALTER TABLE environment_cvterm ADD CONSTRAINT fk_environment_cvterm01 FOREIGN KEY (environment_id) REFERENCES environment (environment_id);
ALTER TABLE environment_cvterm ADD CONSTRAINT fk_environment_cvterm02 FOREIGN KEY (cvterm_id) REFERENCES cvterm (cvterm_id);
ALTER TABLE phenstatement ADD CONSTRAINT fk_phenstatement01 FOREIGN KEY (genotype_id) REFERENCES genotype (genotype_id);
ALTER TABLE phenstatement ADD CONSTRAINT fk_phenstatement02 FOREIGN KEY (environment_id) REFERENCES environment (environment_id);
ALTER TABLE phenstatement ADD CONSTRAINT fk_phenstatement03 FOREIGN KEY (phenotype_id) REFERENCES phenotype (phenotype_id);
ALTER TABLE phenstatement ADD CONSTRAINT fk_phenstatement04 FOREIGN KEY (type_id) REFERENCES cvterm (cvterm_id);
ALTER TABLE phenstatement ADD CONSTRAINT fk_phenstatement05 FOREIGN KEY (pub_id) REFERENCES pub (pub_id);
ALTER TABLE phendesc ADD CONSTRAINT fk_phendesc01 FOREIGN KEY (genotype_id) REFERENCES genotype (genotype_id);
ALTER TABLE phendesc ADD CONSTRAINT fk_phendesc02 FOREIGN KEY (environment_id) REFERENCES environment (environment_id);
ALTER TABLE phendesc ADD CONSTRAINT fk_phendesc03 FOREIGN KEY (type_id) REFERENCES cvterm (cvterm_id);
ALTER TABLE phendesc ADD CONSTRAINT fk_phendesc04 FOREIGN KEY (pub_id) REFERENCES pub (pub_id);
ALTER TABLE phenotype_comparison ADD CONSTRAINT fk_phenotype_comparison01 FOREIGN KEY (genotype1_id) REFERENCES genotype (genotype_id);
ALTER TABLE phenotype_comparison ADD CONSTRAINT fk_phenotype_comparison02 FOREIGN KEY (environment1_id) REFERENCES environment (environment_id);
ALTER TABLE phenotype_comparison ADD CONSTRAINT fk_phenotype_comparison03 FOREIGN KEY (genotype2_id) REFERENCES genotype (genotype_id);
ALTER TABLE phenotype_comparison ADD CONSTRAINT fk_phenotype_comparison04 FOREIGN KEY (environment2_id) REFERENCES environment (environment_id);
ALTER TABLE phenotype_comparison ADD CONSTRAINT fk_phenotype_comparison05 FOREIGN KEY (phenotype1_id) REFERENCES phenotype (phenotype_id);
ALTER TABLE phenotype_comparison ADD CONSTRAINT fk_phenotype_comparison06 FOREIGN KEY (phenotype2_id) REFERENCES phenotype (phenotype_id);
ALTER TABLE phenotype_comparison ADD CONSTRAINT fk_phenotype_comparison07 FOREIGN KEY (pub_id) REFERENCES pub (pub_id);
ALTER TABLE phenotype_comparison ADD CONSTRAINT fk_phenotype_comparison08 FOREIGN KEY (organism_id) REFERENCES organism (organism_id);
ALTER TABLE phenotype_comparison_cvterm ADD CONSTRAINT fk_phenotype_comparison_cvterm01 FOREIGN KEY (phenotype_comparison_id) REFERENCES phenotype_comparison (phenotype_comparison_id);
ALTER TABLE phenotype_comparison_cvterm ADD CONSTRAINT fk_phenotype_comparison_cvterm02 FOREIGN KEY (cvterm_id) REFERENCES cvterm (cvterm_id);

--
-- Stock Module foreign key constraints follow
--
ALTER TABLE stock ADD CONSTRAINT fk_stock01 FOREIGN KEY (dbxref_id) REFERENCES dbxref (dbxref_id);
ALTER TABLE stock ADD CONSTRAINT fk_stock02 FOREIGN KEY (organism_id) REFERENCES organism (organism_id);
ALTER TABLE stock ADD CONSTRAINT fk_stock03 FOREIGN KEY (type_id) REFERENCES cvterm (cvterm_id);
ALTER TABLE stock_pub ADD CONSTRAINT fk_stock_pub01 FOREIGN KEY (stock_id) REFERENCES stock (stock_id);
ALTER TABLE stock_pub ADD CONSTRAINT fk_stock_pub02 FOREIGN KEY (pub_id) REFERENCES pub (pub_id);
ALTER TABLE stockprop ADD CONSTRAINT fk_stockprop01 FOREIGN KEY (stock_id) REFERENCES stock (stock_id);
ALTER TABLE stockprop ADD CONSTRAINT fk_stockprop02 FOREIGN KEY (type_id) REFERENCES cvterm (cvterm_id);
ALTER TABLE stockprop_pub ADD CONSTRAINT fk_stockprop_pub01 FOREIGN KEY (stockprop_id) REFERENCES stockprop (stockprop_id);
ALTER TABLE stockprop_pub ADD CONSTRAINT fk_stockprop_pub02 FOREIGN KEY (pub_id) REFERENCES pub (pub_id);
ALTER TABLE stock_relationship ADD CONSTRAINT fk_stock_relationship01 FOREIGN KEY (subject_id) REFERENCES stock (stock_id);
ALTER TABLE stock_relationship ADD CONSTRAINT fk_stock_relationship02 FOREIGN KEY (object_id) REFERENCES stock (stock_id);
ALTER TABLE stock_relationship ADD CONSTRAINT fk_stock_relationship03 FOREIGN KEY (type_id) REFERENCES cvterm (cvterm_id);
ALTER TABLE stock_relationship_pub ADD CONSTRAINT fk_stock_relationship_pub01 FOREIGN KEY (stock_relationship_id) REFERENCES stock_relationship (stock_relationship_id);
ALTER TABLE stock_relationship_pub ADD CONSTRAINT fk_stock_relationship_pub02 FOREIGN KEY (pub_id) REFERENCES pub (pub_id);
ALTER TABLE stock_dbxref ADD CONSTRAINT fk_stock_dbxref01 FOREIGN KEY (stock_id) REFERENCES stock (stock_id);
ALTER TABLE stock_dbxref ADD CONSTRAINT fk_stock_dbxref02 FOREIGN KEY (dbxref_id) REFERENCES dbxref (dbxref_id);
ALTER TABLE stock_cvterm ADD CONSTRAINT fk_stock_cvterm01 FOREIGN KEY (stock_id) REFERENCES stock (stock_id);
ALTER TABLE stock_cvterm ADD CONSTRAINT fk_stock_cvterm02 FOREIGN KEY (cvterm_id) REFERENCES cvterm (cvterm_id);
ALTER TABLE stock_cvterm ADD CONSTRAINT fk_stock_cvterm03 FOREIGN KEY (pub_id) REFERENCES pub (pub_id);
ALTER TABLE stock_genotype ADD CONSTRAINT fk_stock_genotype01 FOREIGN KEY (stock_id) REFERENCES stock (stock_id);
ALTER TABLE stock_genotype ADD CONSTRAINT fk_stock_genotype02 FOREIGN KEY (genotype_id) REFERENCES genotype (genotype_id);
ALTER TABLE stockcollection ADD CONSTRAINT fk_stockcollection01 FOREIGN KEY (type_id) REFERENCES cvterm (cvterm_id);
ALTER TABLE stockcollection ADD CONSTRAINT fk_stockcollection02 FOREIGN KEY (contact_id) REFERENCES contact (contact_id);
ALTER TABLE stockcollectionprop ADD CONSTRAINT fk_stockcollectionprop01 FOREIGN KEY (stockcollection_id) REFERENCES stockcollection (stockcollection_id);
ALTER TABLE stockcollectionprop ADD CONSTRAINT fk_stockcollectionprop02 FOREIGN KEY (type_id) REFERENCES cvterm (cvterm_id);
ALTER TABLE stockcollection_stock ADD CONSTRAINT fk_stockcollection_stock01 FOREIGN KEY (stockcollection_id) REFERENCES stockcollection (stockcollection_id);
ALTER TABLE stockcollection_stock ADD CONSTRAINT fk_stockcollection_stock02 FOREIGN KEY (stock_id) REFERENCES stock (stock_id);
