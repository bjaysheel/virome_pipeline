-- int
-- Integer (whole number) data from -2^31 (-2,147,483,648) through 2^31 - 1 (2,147,483,647). Storage size is 4 bytes.
--
-- smallint
-- Integer (whole number) data from -2^15 (-32,768) through 2^15 - 1 (32,767). Storage size is 2 bytes.
--
-- tinyint
-- Integer (whole number) data from 0 through 255. Storage size is 1 byte. 


--
-- Table: cm_clusters
--
 
CREATE TABLE cm_clusters (
  cm_clusters_id     NUMERIC(9,0) NOT NULL,
  cluster_id         NUMERIC(9,0) NOT NULL,
  analysis_id        NUMERIC(9,0) NOT NULL,
  num_members        SMALLINT NOT NULL,
  num_organisms      TINYINT NOT NULL,
  percent_coverage   DOUBLE PRECISION NULL,
  percent_identity   DOUBLE PRECISION NULL
);
 

--
-- Table: cm_cluster_members
--
 
CREATE TABLE cm_cluster_members (
  cm_cluster_members_id   NUMERIC(9,0) NOT NULL,
  cluster_id              NUMERIC(9,0) NOT NULL,
  feature_id              NUMERIC(9,0) NOT NULL,
  organism_id             NUMERIC(9,0) NOT NULL,
  uniquename              VARCHAR(255) NOT NULL,
  accession1              VARCHAR(305) NOT NULL,
  accession2              VARCHAR(305) NOT NULL,
);
 
