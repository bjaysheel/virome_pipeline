-- int
-- Integer (whole number) data from -2^31 (-2,147,483,648) through 2^31 - 1 (2,147,483,647). Storage size is 4 bytes.
--
-- smallint
-- Integer (whole number) data from -2^15 (-32,768) through 2^15 - 1 (32,767). Storage size is 2 bytes.
--
-- tinyint
-- Integer (whole number) data from 0 through 255. Storage size is 1 byte. 

--
-- Table: cm_proteins
--

CREATE TABLE cm_proteins (
  cm_proteins_id     NUMERIC(9,0) NOT NULL,
  protein_id         NUMERIC(9,0) NOT NULL,
  organism_id        NUMERIC(9,0) NOT NULL,
  uniquename         VARCHAR(255) NOT NULL,
  cds_id             NUMERIC(9,0) NOT NULL,
  gene_id            NUMERIC(9,0) NOT NULL,
  transcript_id      NUMERIC(9,0) NOT NULL,
  exon_count         SMALLINT NOT NULL,
  accession1         VARCHAR(305) NOT NULL,
  accession2         VARCHAR(305) NOT NULL,
  gene_product_name  VARCHAR(2000) NOT NULL,
  fmin               NUMERIC(9,0) NOT NULL,
  fmax               NUMERIC(9,0) NOT NULL,
  seqlen             NUMERIC(9,0) NOT NULL,
  strand             SMALLINT NOT NULL,
  srcfeature_id      NUMERIC(9,0) NOT NULL
);
