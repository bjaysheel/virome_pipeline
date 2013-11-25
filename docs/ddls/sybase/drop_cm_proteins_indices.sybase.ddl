ALTER TABLE cm_proteins DROP CONSTRAINT fk_cm_proteins12;
ALTER TABLE cm_proteins DROP CONSTRAINT fk_cm_proteins05;
ALTER TABLE cm_proteins DROP CONSTRAINT fk_cm_proteins04;
ALTER TABLE cm_proteins DROP CONSTRAINT fk_cm_proteins03;
ALTER TABLE cm_proteins DROP CONSTRAINT fk_cm_proteins01;

DROP INDEX cm_proteins.idx_cm_proteins06;
DROP INDEX cm_proteins.idx_cm_proteins05;
DROP INDEX cm_proteins.idx_cm_proteins04;
DROP INDEX cm_proteins.idx_cm_proteins03;
DROP INDEX cm_proteins.idx_cm_proteins02;
DROP INDEX cm_proteins.pk_cm_proteins;

DROP INDEX cm_proteins.idx_cm_proteins01;
