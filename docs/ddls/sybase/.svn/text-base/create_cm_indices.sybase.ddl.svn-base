---------------------------------------------------------------------------------------------
--
-- Always create the clustered indexes first as they require more free space.
-- Remember that these clustered indexes are physically ordered on the storage media.
--
---------------------------------------------------------------------------------------------

CREATE CLUSTERED INDEX idx_cm_blast01 ON cm_blast (qfeature_id, qorganism_id) WITH CONSUMERS=6;
CREATE CLUSTERED INDEX idx_cm_proteins01 ON cm_proteins (protein_id) WITH CONSUMERS=6;
CREATE CLUSTERED INDEX idx_cm_clusters01 ON cm_clusters (analysis_id) WITH CONSUMERS=6;
CREATE CLUSTERED INDEX idx_cm_cluster_members01 ON cm_cluster_members (feature_id, organism_id) WITH CONSUMERS=6;

--
-- table: cm_blast
--
CREATE UNIQUE NONCLUSTERED INDEX pk_cm_blast ON cm_blast (cm_blast_id) WITH CONSUMERS=6;
CREATE NONCLUSTERED INDEX idx_cm_blast02 ON cm_blast (qorganism_id, horganism_id, qfeature_id) WITH CONSUMERS=6;

--
-- table: cm_proteins
--
CREATE UNIQUE NONCLUSTERED INDEX pk_cm_proteins ON cm_proteins (cm_proteins_id) WITH CONSUMERS=6;
CREATE NONCLUSTERED INDEX idx_cm_proteins02 ON cm_proteins (cds_id) WITH CONSUMERS=6;
CREATE NONCLUSTERED INDEX idx_cm_proteins03 ON cm_proteins (gene_id) WITH CONSUMERS=6;
CREATE NONCLUSTERED INDEX idx_cm_proteins04 ON cm_proteins (transcript_id) WITH CONSUMERS=6;
CREATE NONCLUSTERED INDEX idx_cm_proteins05 ON cm_proteins (srcfeature_id) WITH CONSUMERS=6;
CREATE NONCLUSTERED INDEX idx_cm_proteins06 ON cm_proteins (organism_id) WITH CONSUMERS=6;

--
-- table: cm_clusters
--
CREATE UNIQUE NONCLUSTERED INDEX pk_cm_clusters ON cm_clusters (cm_clusters_id) WITH CONSUMERS=6;

--
-- table: cm_cluster_members
--
CREATE UNIQUE NONCLUSTERED INDEX pk_cm_cluster_members ON cm_cluster_members (cm_cluster_members_id) WITH CONSUMERS=6;
CREATE NONCLUSTERED INDEX idx_cm_cluster_members02 ON cm_cluster_members (uniquename) WITH CONSUMERS=6;
CREATE NONCLUSTERED INDEX idx_cm_cluster_members03 ON cm_cluster_members (accession1) WITH CONSUMERS=6;
CREATE NONCLUSTERED INDEX idx_cm_cluster_members04 ON cm_cluster_members (accession2) WITH CONSUMERS=6;

---------------------------------------------------------------------------------------------
--
-- Once all indexes are in place, we can add the foreign key constraints
--
---------------------------------------------------------------------------------------------

--
-- table: cm_blast
--
ALTER TABLE cm_blast ADD CONSTRAINT fk_cm_blast01 FOREIGN KEY (qfeature_id) REFERENCES feature(feature_id);
ALTER TABLE cm_blast ADD CONSTRAINT fk_cm_blast03 FOREIGN KEY (hfeature_id) REFERENCES feature(feature_id);
ALTER TABLE cm_blast ADD CONSTRAINT fk_cm_blast05 FOREIGN KEY (mfeature_id) REFERENCES feature(feature_id);

--
-- table: cm_proteins
--
ALTER TABLE cm_proteins ADD CONSTRAINT fk_cm_proteins01 FOREIGN KEY (protein_id) REFERENCES feature(feature_id);
ALTER TABLE cm_proteins ADD CONSTRAINT fk_cm_proteins03 FOREIGN KEY (cds_id) REFERENCES feature(feature_id);
ALTER TABLE cm_proteins ADD CONSTRAINT fk_cm_proteins04 FOREIGN KEY (gene_id) REFERENCES feature(feature_id);
ALTER TABLE cm_proteins ADD CONSTRAINT fk_cm_proteins05 FOREIGN KEY (transcript_id) REFERENCES feature(feature_id);
ALTER TABLE cm_proteins ADD CONSTRAINT fk_cm_proteins12 FOREIGN KEY (organism_id) REFERENCES organism(organism_id);

--
-- table: cm_clusters
--
ALTER TABLE cm_clusters ADD CONSTRAINT fk_cm_clusters01 FOREIGN KEY (cluster_id) REFERENCES feature(feature_id);
ALTER TABLE cm_clusters ADD CONSTRAINT fk_cm_clusters02 FOREIGN KEY (analysis_id) REFERENCES analysis(analysis_id);

--
-- table: cm_cluster_members
--
ALTER TABLE cm_cluster_members ADD CONSTRAINT fk_cm_cluster_members01 FOREIGN KEY (cluster_id) REFERENCES feature(feature_id);
ALTER TABLE cm_cluster_members ADD CONSTRAINT fk_cm_cluster_members02 FOREIGN KEY (organism_id) REFERENCES organism(organism_id);
ALTER TABLE cm_cluster_members ADD CONSTRAINT fk_cm_cluster_members03 FOREIGN KEY (feature_id) REFERENCES feature(feature_id);
ALTER TABLE cm_cluster_members ADD CONSTRAINT fk_cm_cluster_members04 FOREIGN KEY (organism_id) REFERENCES organism(organism_id);
