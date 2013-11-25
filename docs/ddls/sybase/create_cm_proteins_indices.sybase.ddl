CREATE CLUSTERED INDEX idx_cm_proteins01 ON cm_proteins (protein_id) WITH CONSUMERS=6;
 
CREATE UNIQUE NONCLUSTERED INDEX pk_cm_proteins ON cm_proteins (cm_proteins_id) WITH CONSUMERS=6;
CREATE NONCLUSTERED INDEX idx_cm_proteins02 ON cm_proteins (cds_id) WITH CONSUMERS=6;
CREATE NONCLUSTERED INDEX idx_cm_proteins03 ON cm_proteins (gene_id) WITH CONSUMERS=6;
CREATE NONCLUSTERED INDEX idx_cm_proteins04 ON cm_proteins (transcript_id) WITH CONSUMERS=6;
CREATE NONCLUSTERED INDEX idx_cm_proteins05 ON cm_proteins (srcfeature_id) WITH CONSUMERS=6;
CREATE NONCLUSTERED INDEX idx_cm_proteins06 ON cm_proteins (organism_id) WITH CONSUMERS=6;

ALTER TABLE cm_proteins ADD CONSTRAINT fk_cm_proteins01 FOREIGN KEY (protein_id) REFERENCES feature(feature_id);
ALTER TABLE cm_proteins ADD CONSTRAINT fk_cm_proteins03 FOREIGN KEY (cds_id) REFERENCES feature(feature_id);
ALTER TABLE cm_proteins ADD CONSTRAINT fk_cm_proteins04 FOREIGN KEY (gene_id) REFERENCES feature(feature_id);
ALTER TABLE cm_proteins ADD CONSTRAINT fk_cm_proteins05 FOREIGN KEY (transcript_id) REFERENCES feature(feature_id);
ALTER TABLE cm_proteins ADD CONSTRAINT fk_cm_proteins12 FOREIGN KEY (organism_id) REFERENCES organism(organism_id);
