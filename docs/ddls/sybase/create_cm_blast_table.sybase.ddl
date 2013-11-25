-- int
-- Integer (whole number) data from -2^31 (-2,147,483,648) through 2^31 - 1 (2,147,483,647). Storage size is 4 bytes.
--
-- smallint
-- Integer (whole number) data from -2^15 (-32,768) through 2^15 - 1 (32,767). Storage size is 2 bytes.
--
-- tinyint
-- Integer (whole number) data from 0 through 255. Storage size is 1 byte. 

--
-- Table: cm_blast
--
CREATE TABLE cm_blast (
  cm_blast_id         NUMERIC(9,0) NOT NULL,
  qfeature_id         NUMERIC(9,0) NOT NULL,
  qorganism_id        NUMERIC(9,0) NOT NULL,
  hfeature_id         NUMERIC(9,0) NOT NULL,
  horganism_id        NUMERIC(9,0) NOT NULL,
  per_id	          DOUBLE PRECISION NULL,
  per_sim             DOUBLE PRECISION NULL,
  p_value             DOUBLE PRECISION NULL,
  mfeature_id         NUMERIC(9,0) NULL,
  per_cov             FLOAT(8) NULL
);

