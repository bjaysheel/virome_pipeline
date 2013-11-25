---------------------------------------------------------------------------------------------
--
-- Always create the clustered indexes first as they require more free space.
-- Remember that these clustered indexes are physically ordered on the storage media.
--
---------------------------------------------------------------------------------------------

CREATE CLUSTERED INDEX idx_cm_blast01 ON cm_blast (qfeature_id, qorganism_id) WITH CONSUMERS=6;

--
-- table: cm_blast
--
CREATE UNIQUE NONCLUSTERED INDEX pk_cm_blast ON cm_blast (cm_blast_id) WITH CONSUMERS=6;
CREATE NONCLUSTERED INDEX idx_cm_blast02 ON cm_blast (qorganism_id, horganism_id, qfeature_id) WITH CONSUMERS=6;

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

