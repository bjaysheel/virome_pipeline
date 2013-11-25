---------------------------------------------------------------------------------------------
--
-- Always create the clustered indexes first as they require more free space.
-- Remember that these clustered indexes are physically ordered on the storage media.
--
---------------------------------------------------------------------------------------------

CREATE CLUSTERED INDEX idx_cm_clusters01 ON cm_clusters (analysis_id) WITH CONSUMERS=6;
CREATE CLUSTERED INDEX idx_cm_cluster_members01 ON cm_cluster_members (feature_id, organism_id) WITH CONSUMERS=6;

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
