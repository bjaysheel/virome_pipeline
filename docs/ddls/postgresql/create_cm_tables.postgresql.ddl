
--
-- Table: cm_blast
--
CREATE TABLE cm_blast (
  cm_blast_id         INT NOT NULL,
  qfeature_id         INT NOT NULL,
  qorganism_id        INT NOT NULL,
  hfeature_id         INT NOT NULL,
  horganism_id        INT NOT NULL,
  per_id              DOUBLE PRECISION NULL,
  per_sim             DOUBLE PRECISION NULL,
  p_value             DOUBLE PRECISION NULL,
  mfeature_id         INT NOT NULL,
  per_cov	          DOUBLE PRECISION NULL
);

--
-- Table: cm_proteins
--

CREATE TABLE cm_proteins (
  cm_proteins_id     INT NOT NULL,
  protein_id         INT NOT NULL,
  organism_id        INT NOT NULL,
  uniquename         VARCHAR(255) NOT NULL,
  cds_id             INT NOT NULL,
  gene_id            INT NOT NULL,
  transcript_id      INT NOT NULL,
  exon_count         SMALLINT NOT NULL,
  accession1         VARCHAR(305) NOT NULL,
  accession2         VARCHAR(305) NOT NULL,
  gene_product_name  VARCHAR(2000) NOT NULL,
  fmin               INT NOT NULL,
  fmax               INT NOT NULL,
  seqlen             INT NOT NULL,
  strand             SMALLINT NOT NULL,
  srcfeature_id      INT NOT NULL
);
 

--
-- Table: cm_clusters
--
 
CREATE TABLE cm_clusters (
  cm_clusters_id     INT NOT NULL,
  cluster_id         INT NOT NULL,
  analysis_id        INT NOT NULL,
  num_members        SMALLINT NOT NULL,
  num_organisms      INT NOT NULL,
  percent_coverage   DOUBLE PRECISION NULL,
  percent_identity   DOUBLE PRECISION NULL
);
 

--
-- Table: cm_cluster_members
--
 
CREATE TABLE cm_cluster_members (
  cm_cluster_members_id   INT NOT NULL,
  cluster_id              INT NOT NULL,
  feature_id              INT NOT NULL,
  organism_id             INT NOT NULL,
  uniquename              VARCHAR(255) NOT NULL,
  accession1              VARCHAR(305) NOT NULL,
  accession2              VARCHAR(305) NOT NULL
);
 
