-- createtables  sql2Chado.pl parses this first line
--
-- Author:         Jay Sundaram sundaram@tigr.org
-- Date Modified:  2005-07-18 
-- Schema:         Chado
-- CVS:            ANNOTATION/chado/tigr_schemas/chado_template/ALL_Modules/create_tables.ddl
-- Version:        $Name$
--
------------------------------------------------------------------------------------------
--
-- Module: General
--
------------------------------------------------------------------------------------------

--
-- Table: tableinfo
--

CREATE TABLE tableinfo (
  tableinfo_id        NUMERIC(9,0)  NOT NULL,
  name                VARCHAR(30)   NOT NULL,
  primary_key_column  VARCHAR(30)   NULL,
  is_view             BIT           NOT NULL,
  view_on_table_id    NUMERIC(9,0)  NULL,
  superclass_table_id NUMERIC(9,0)  NULL,
  is_updateable       BIT           NOT NULL,
  modification_date   SMALLDATETIME NOT NULL
);

--
-- Table: project
--
CREATE TABLE project (
  project_id  NUMERIC(9,0) NOT NULL,
  name        VARCHAR(255) NOT NULL,
  description VARCHAR(255) NOT NULL
);


--
-- Table: db
--

CREATE TABLE db (
  db_id       NUMERIC(9,0) NOT NULL,
  name        VARCHAR(50)  NOT NULL,
  description VARCHAR(255) NULL,
  urlprefix   VARCHAR(255) NULL,
  url         VARCHAR(255) NULL
);

--
-- Table: dbxref
--

CREATE TABLE dbxref (
  dbxref_id   NUMERIC(9,0)  NOT NULL,
  db_id       NUMERIC(9,0)  NOT NULL,
  accession   VARCHAR(255)  NOT NULL,
  version     VARCHAR(50)   NOT NULL,
  description VARCHAR(255)  NULL
);

---------------------------------------------------------
--
-- Module: CV
--
---------------------------------------------------------

--
-- Table: cv
--

CREATE TABLE cv (
  cv_id      NUMERIC(9,0) NOT NULL,
  name       VARCHAR(255) NOT NULL,
  definition VARCHAR(255) NULL
);

--
-- Table: cvterm
--

CREATE TABLE cvterm (
       cvterm_id           NUMERIC(9,0)  NOT NULL,
       cv_id               NUMERIC(9,0)  NOT NULL,
       name                VARCHAR(255)  NOT NULL,
       definition          VARCHAR(1200) NULL,
       dbxref_id           NUMERIC(9,0)  NULL,
       is_obsolete         TINYINT       NOT NULL,
       is_relationshiptype BIT           NOT NULL
);

--
-- Table: cvterm_relationship
--

CREATE TABLE cvterm_relationship (
  cvterm_relationship_id NUMERIC(9,0) NOT NULL,
  type_id                NUMERIC(9,0) NOT NULL,
  subject_id             NUMERIC(9,0) NOT NULL,
  object_id              NUMERIC(9,0) NOT NULL
);

--
-- Table: cvtermpath
--

CREATE TABLE cvtermpath (
  cvtermpath_id NUMERIC(9,0) NOT NULL,
  type_id       NUMERIC(9,0) NULL,
  subject_id    NUMERIC(9,0) NOT NULL,
  object_id     NUMERIC(9,0) NOT NULL,
  cv_id         NUMERIC(9,0) NOT NULL,
  pathdistance  NUMERIC(9,0) NULL
);

--
-- Table: cvtermsynonym
--

CREATE TABLE cvtermsynonym (
  cvtermsynonym_id NUMERIC(9,0)  NOT NULL,
  cvterm_id        NUMERIC(9,0)  NOT NULL,
  synonym          VARCHAR(1024) NOT NULL,
  type_id          NUMERIC(9,0)  NULL
);

--
-- Table: cvterm_dbxref
--

CREATE TABLE cvterm_dbxref (
  cvterm_dbxref_id  NUMERIC(9,0) NOT NULL,
  cvterm_id         NUMERIC(9,0) NOT NULL,
  dbxref_id         NUMERIC(9,0) NOT NULL,
  is_for_definition BIT          NOT NULL
);

--
-- Table: cvtermprop
--

CREATE TABLE cvtermprop (
       cvtermprop_id NUMERIC(9,0) NOT NULL,
       cvterm_id     NUMERIC(9,0) NOT NULL,
       type_id       NUMERIC(9,0) NOT NULL,
       value         VARCHAR(1000) NOT NULL,
       rank          NUMERIC(9,0) NOT NULL
);

--
-- Table: dbxrefprop
--

CREATE TABLE dbxrefprop (
       dbxrefprop_id NUMERIC(9,0) NOT NULL,
       dbxref_id     NUMERIC(9,0) NOT NULL,
       type_id       NUMERIC(9,0) NOT NULL,
       value         VARCHAR(255) NOT NULL,
       rank          NUMERIC(9,0) NOT NULL
);

--------------------------------------------------------
--
-- Module: Organism
--
--------------------------------------------------------

--
-- Table: organism
--

CREATE TABLE organism (
  organism_id  NUMERIC(9,0) NOT NULL,
  abbreviation VARCHAR(255)  NULL,
  genus        VARCHAR(255) NOT NULL,
  species      VARCHAR(255) NOT NULL,
  common_name  VARCHAR(255) NULL,
  comment      VARCHAR(255) NULL
);

--
-- Table: organism_dbxref
--

CREATE TABLE organism_dbxref (
  organism_dbxref_id NUMERIC(9,0) NOT NULL,
  organism_id        NUMERIC(9,0) NOT NULL,
  dbxref_id          NUMERIC(9,0) NOT NULL
);

--
-- Table: organismprop
--

CREATE TABLE organismprop (
  organismprop_id NUMERIC(9,0) NOT NULL,
  organism_id     NUMERIC(9,0) NOT NULL,
  type_id         NUMERIC(9,0) NOT NULL,
  value           VARCHAR(255) NOT NULL,
  rank            NUMERIC(9,0) NOT NULL
);

--------------------------------------------------------
--
-- Module: Pub
--
--------------------------------------------------------

--
-- Table: pub
--

CREATE TABLE pub (
  pub_id        NUMERIC(9,0) NOT NULL,
  title         VARCHAR(255) NULL,
  volumetitle   VARCHAR(255) NULL,
  volume        VARCHAR(255) NULL,
  series_name   VARCHAR(255) NULL,
  issue         VARCHAR(255) NULL,
  pyear         VARCHAR(255) NULL,
  pages         VARCHAR(255) NULL,
  miniref       VARCHAR(255) NULL,
  uniquename    VARCHAR(255) NOT NULL,
  type_id       NUMERIC(9,0) NOT NULL,
  is_obsolete   BIT          NOT NULL,
  publisher     VARCHAR(255) NULL,
  pubplace      VARCHAR(255) NULL
);

--
-- Table: pub_relationship
--

CREATE TABLE pub_relationship (
  pub_relationship_id NUMERIC(9,0) NOT NULL,
  subject_id          NUMERIC(9,0) NOT NULL,
  object_id           NUMERIC(9,0) NOT NULL,
  type_id             NUMERIC(9,0) NOT NULL
);

--
-- Table: pub_dbxref
--

CREATE TABLE pub_dbxref (
  pub_dbxref_id NUMERIC(9,0) NOT NULL,
  pub_id        NUMERIC(9,0) NOT NULL,
  dbxref_id     NUMERIC(9,0) NOT NULL,
  is_current    BIT          NOT NULL
);

--
-- Table: pubauthor
--

CREATE TABLE pubauthor (
  pubauthor_id  NUMERIC(9,0) NOT NULL,
  pub_id        NUMERIC(9,0) NOT NULL,
  rank          NUMERIC(9,0) NOT NULL,
  editor        BIT          NOT NULL,
  surname       VARCHAR(255) NOT NULL,
  givennames    VARCHAR(100)     NULL,
  suffix        VARCHAR(100)     NULL
);

--
-- Table: pubprop
--

CREATE TABLE pubprop (
  pubprop_id NUMERIC(9,0) NOT NULL,
  pub_id     NUMERIC(9,0) NOT NULL,
  type_id    NUMERIC(9,0) NOT NULL,
  value      VARCHAR(255) NOT NULL,
  rank       NUMERIC(9,0) NULL
);


--------------------------------------------------------
--
-- Module: Sequence
--
--------------------------------------------------------

--
-- Table: feature
--

CREATE TABLE feature (
  feature_id       NUMERIC(9,0)  NOT NULL,
  dbxref_id        NUMERIC(9,0)  NULL,
  organism_id      NUMERIC(9,0)  NOT NULL,
  name             VARCHAR(255)  NULL,
  uniquename       VARCHAR(255)   NOT NULL,
  residues         TEXT          NULL,
  seqlen           NUMERIC(9,0)  NULL,
  md5checksum      CHAR(32)      NULL,
  type_id          NUMERIC(9,0)  NOT NULL,
  is_analysis      BIT           NOT NULL,
  is_obsolete      BIT           NOT NULL,
  timeaccessioned  SMALLDATETIME NOT NULL,
  timelastmodified SMALLDATETIME NOT NULL
);

--
-- Table: featureloc
--

CREATE TABLE featureloc (
  featureloc_id   NUMERIC(9,0) NOT NULL,
  feature_id      NUMERIC(9,0) NOT NULL,
  srcfeature_id   NUMERIC(9,0) NULL,
  fmin            NUMERIC(9,0) NULL,
  is_fmin_partial BIT          NOT NULL,
  fmax            NUMERIC(9,0) NULL,
  is_fmax_partial BIT          NOT NULL,
  strand          SMALLINT     NULL,
  phase           NUMERIC(9,0) NULL,
  residue_info    VARCHAR(7500) NULL,
  locgroup        NUMERIC(9,0) NOT NULL,
  rank            NUMERIC(9,0) NOT NULL
);

--
-- Table: feature_pub
--

CREATE TABLE feature_pub (
  feature_pub_id NUMERIC(9,0) NOT NULL,
  feature_id     NUMERIC(9,0) NOT NULL,
  pub_id         NUMERIC(9,0) NOT NULL
);

--
-- Table: featureprop
--

CREATE TABLE featureprop (
  featureprop_id NUMERIC(9,0)  NOT NULL,
  feature_id     NUMERIC(9,0)  NOT NULL,
  type_id        NUMERIC(9,0)  NOT NULL,
  value          VARCHAR(2000) NOT NULL,
  rank           NUMERIC(9,0)  NOT NULL
);

--
-- Table: featureprop_pub
--

CREATE TABLE featureprop_pub (
  featureprop_pub_id NUMERIC(9,0) NOT NULL,
  featureprop_id     NUMERIC(9,0) NOT NULL,
  pub_id             NUMERIC(9,0) NOT NULL
);

--
-- Table: feature_dbxref
--

CREATE TABLE feature_dbxref (
  feature_dbxref_id NUMERIC(9,0) NOT NULL,
  feature_id        NUMERIC(9,0) NOT NULL,
  dbxref_id         NUMERIC(9,0) NOT NULL,
  is_current        BIT          NOT NULL
);

--
-- Table: feature_relationship
--

CREATE TABLE feature_relationship (
  feature_relationship_id NUMERIC(9,0) NOT NULL,
  subject_id              NUMERIC(9,0) NOT NULL,
  object_id               NUMERIC(9,0) NOT NULL,
  type_id                 NUMERIC(9,0) NOT NULL,
  value                   VARCHAR(255) NULL,
  rank                    NUMERIC(9,0) NULL
);

--
-- Table: feature_relationship_pub
--

CREATE TABLE feature_relationship_pub (
  feature_relationship_pub_id NUMERIC(9,0) NOT NULL,
  feature_relationship_id     NUMERIC(9,0) NOT NULL,
  pub_id                      NUMERIC(9,0) NOT NULL
);

--
-- Table feature_relationshipprop
--

CREATE TABLE feature_relationshipprop (
  feature_relationshipprop_id NUMERIC(9,0) NOT NULL,
  feature_relationship_id     NUMERIC(9,0) NOT NULL,
  type_id                     NUMERIC(9,0) NOT NULL,
  value                       VARCHAR(255) NOT NULL,
  rank                        NUMERIC(9,0) NOT NULL
);

--
-- Table: feature_relprop_pub
--

CREATE TABLE feature_relprop_pub (
  feature_relprop_pub_id NUMERIC(9,0) NOT NULL,
  feature_relationshipprop_id     NUMERIC(9,0) NOT NULL,
  pub_id                          NUMERIC(9,0) NOT NULL
);

--
-- Table: feature_cvterm
--

CREATE TABLE feature_cvterm (
  feature_cvterm_id NUMERIC(9,0) NOT NULL,
  feature_id        NUMERIC(9,0) NOT NULL,
  cvterm_id         NUMERIC(9,0) NOT NULL,
  pub_id            NUMERIC(9,0) NOT NULL,
  is_not            BIT          NOT NULL
);

--
-- Table: feature_cvtermprop
--

CREATE TABLE feature_cvtermprop (
    feature_cvtermprop_id NUMERIC(9,0) NOT NULL,
    feature_cvterm_id     NUMERIC(9,0) NOT NULL,
    type_id               NUMERIC(9,0) NOT NULL,
    value                 VARCHAR(255) NOT NULL,
    rank                  NUMERIC(9,0) NOT NULL
);

--
-- Table: feature_cvterm_dbxref
--

CREATE TABLE feature_cvterm_dbxref (
    feature_cvterm_dbxref_id  NUMERIC(9,0) NOT NULL,
    feature_cvterm_id         NUMERIC(9,0) NOT NULL,
    dbxref_id                 NUMERIC(9,0) NOT NULL
);

--
-- Table: feature_cvterm_dbxref
--

CREATE TABLE feature_cvterm_pub (
    feature_cvterm_pub_id  NUMERIC(9,0) NOT NULL,
    feature_cvterm_id      NUMERIC(9,0) NOT NULL,
    pub_id              NUMERIC(9,0) NOT NULL
);

--
-- Table: synonym
--

CREATE TABLE synonym (
  synonym_id   NUMERIC(9,0) NOT NULL,
  name         VARCHAR(255) NOT NULL,
  type_id      NUMERIC(9,0) NOT NULL,
  synonym_sgml VARCHAR(255) NOT NULL
);

--
-- Table: feature_synonym
--

CREATE TABLE feature_synonym (
  feature_synonym_id NUMERIC(9,0) NOT NULL,
  synonym_id         NUMERIC(9,0) NOT NULL,
  feature_id         NUMERIC(9,0) NOT NULL,
  pub_id             NUMERIC(9,0) NOT NULL,
  is_current         BIT          NOT NULL,
  is_internal        BIT          NOT NULL
);

----------------------------------------------------
--
-- Module: Computational Analysis
--
----------------------------------------------------

--
-- Table: analysis
--

CREATE TABLE analysis (
  analysis_id    NUMERIC(9,0)  NOT NULL,
  name           VARCHAR(255)  NULL,
  description    VARCHAR(255)  NULL,
  program        VARCHAR(50)   NOT NULL,
  programversion VARCHAR(50)   NOT NULL,
  algorithm      VARCHAR(50)   NULL,
  sourcename     VARCHAR(255)  NULL,
  sourceversion  VARCHAR(50)   NULL,
  sourceuri      VARCHAR(255)  NULL,
  timeexecuted   SMALLDATETIME NOT NULL
);

--
-- Table: analysisprop
--

CREATE TABLE analysisprop (
  analysisprop_id NUMERIC(9,0) NOT NULL,
  analysis_id     NUMERIC(9,0) NOT NULL,
  type_id         NUMERIC(9,0) NOT NULL,
  value           VARCHAR(255) NULL
);

--
-- Table: analysisfeature
--

CREATE TABLE analysisfeature (
  analysisfeature_id NUMERIC(9,0) NOT NULL,
  feature_id         NUMERIC(9,0) NOT NULL,
  analysis_id        NUMERIC(9,0) NOT NULL,
  rawscore           DOUBLE PRECISION NULL,
  normscore          DOUBLE PRECISION NULL,
  significance       DOUBLE PRECISION NULL,
  pidentity          DOUBLE PRECISION NULL,
  type_id            NUMERIC(9,0) NULL	
);


----------------------------------------------------
--
-- Module: Phylogeny
--
----------------------------------------------------

--
-- Table: phylotree
--

CREATE TABLE phylotree (
  phylotree_id        NUMERIC(9,0) NOT NULL,
  dbxref_id           NUMERIC(9,0) NOT NULL,
  name                VARCHAR(255)     NULL,
  type_id             NUMERIC(9,0) NOT NULL,
  comment             VARCHAR(255)     NULL
);

--
-- Table: phylotree_pub
--

CREATE TABLE phylotree_pub (
  phylotree_pub_id    NUMERIC(9,0) NOT NULL,
  phylotree_id        NUMERIC(9,0) NOT NULL,
  pub_id              NUMERIC(9,0) NOT NULL
);

--
-- Table: phylonode
--

CREATE TABLE phylonode (
  phylonode_id        NUMERIC(9,0) NOT NULL,
  phylotree_id        NUMERIC(9,0) NOT NULL,
  parent_phylonode_id NUMERIC(9,0)     NULL,
  left_idx            NUMERIC(9,0) NOT NULL,
  right_idx           NUMERIC(9,0) NOT NULL,
  type_id             NUMERIC(9,0) NOT NULL,
  feature_id          NUMERIC(9,0)     NULL,
  label               VARCHAR(255)     NULL,
  distance            DOUBLE PRECISION
);


--
-- Table: phylonode_dbxref
--

CREATE TABLE phylonode_dbxref (
  phylonode_dbxref_id    NUMERIC(9,0) NOT NULL,
  phylonode_id           NUMERIC(9,0) NOT NULL,
  dbxref_id              NUMERIC(9,0) NOT NULL
);

--
-- Table: phylonode_pub
--

CREATE TABLE phylonode_pub (
  phylonode_pub_id    NUMERIC(9,0) NOT NULL,
  phylonode_id        NUMERIC(9,0) NOT NULL,
  pub_id              NUMERIC(9,0) NOT NULL
);

--
-- Table: phylonode_organism
--

CREATE TABLE phylonode_organism (
  phylonode_organism_id    NUMERIC(9,0) NOT NULL,
  phylonode_id             NUMERIC(9,0) NOT NULL,
  organism_id              NUMERIC(9,0) NOT NULL
);



--
-- Table: phylonodeprop
--

CREATE TABLE phylonodeprop (
  phylonodeprop_id    NUMERIC(9,0) NOT NULL,
  phylonode_id        NUMERIC(9,0) NOT NULL,
  type_id             NUMERIC(9,0) NOT NULL,
  value               VARCHAR(255) NOT NULL,
  rank                NUMERIC(9,0) NOT NULL
);


--
-- Table: phylonode_relationship
--

CREATE TABLE phylonode_relationship (
  phylonode_relationship_id    NUMERIC(9,0) NOT NULL,
  subject_id                   NUMERIC(9,0) NOT NULL,
  object_id                    NUMERIC(9,0) NOT NULL,
  type_id                      NUMERIC(9,0) NOT NULL,
  rank                         INT
);


-----------------------------------------------------------------------------
--
-- Module: Infection
--
-----------------------------------------------------------------------------

--
-- Table: infection
--
CREATE TABLE infection (
  infection_id NUMERIC(9,0) NOT NULL,
  pathogen_id  NUMERIC(9,0) NOT NULL,
  hostres_id   NUMERIC(9,0) NOT NULL,
  disease_id   NUMERIC(9,0) NULL
);

--
-- Table: infectionprop
--
CREATE TABLE infectionprop (
  infectionprop_id NUMERIC(9,0) NOT NULL,
  infection_id     NUMERIC(9,0) NOT NULL,
  type_id          NUMERIC(9,0) NOT NULL,
  value            VARCHAR(255) NOT NULL,
  rank             NUMERIC(9,0) NOT NULL
);

--
-- Table: infection_cvterm
--
CREATE TABLE infection_cvterm (
  infection_cvterm_id NUMERIC(9,0) NOT NULL,
  infection_id        NUMERIC(9,0) NOT NULL,
  cvterm_id           NUMERIC(9,0) NOT NULL,
  pub_id              NUMERIC(9,0) NULL,
  is_not              BIT          NOT NULL
);

--
-- Table: infection_dbxref
--

CREATE TABLE infection_dbxref (
  infection_dbxref_id  NUMERIC(9,0) NOT NULL,
  infection_id         NUMERIC(9,0) NOT NULL,
  dbxref_id         NUMERIC(9,0) NOT NULL,
  is_for_definition BIT          NOT NULL
);

--
-- Table: transmission
--
CREATE TABLE transmission (
  transmission_id NUMERIC(9,0) NOT NULL,
  type_id         NUMERIC(9,0) NOT NULL,
  subject_id      NUMERIC(9,0) NOT NULL,
  object_id       NUMERIC(9,0) NOT NULL,
  portal_id	  NUMERIC(9,0) NULL
);

--
-- Table: transmissionprop
--
CREATE TABLE transmissionprop (
  transmissionprop_id NUMERIC(9,0) NOT NULL,
  transmission_id     NUMERIC(9,0) NOT NULL,
  type_id          NUMERIC(9,0) NOT NULL,
  value            VARCHAR(255) NOT NULL,
  rank             NUMERIC(9,0) NOT NULL
);

--
-- Table: transmission_cvterm
--
CREATE TABLE transmission_cvterm (
  transmission_cvterm_id NUMERIC(9,0) NOT NULL,
  transmission_id        NUMERIC(9,0) NOT NULL,
  cvterm_id           NUMERIC(9,0) NOT NULL,
  pub_id              NUMERIC(9,0) NULL,
  is_not              BIT          NOT NULL
);

--
-- Table: transmission_dbxref
--
CREATE TABLE transmission_dbxref (
  transmission_dbxref_id  NUMERIC(9,0) NOT NULL,
  transmission_id         NUMERIC(9,0) NOT NULL,
  dbxref_id         NUMERIC(9,0) NOT NULL,
  is_for_definition BIT          NOT NULL
);

--
-- Table: incident
--
CREATE TABLE incident (
  incident_id     NUMERIC(9,0) NOT NULL,
  transmission_id NUMERIC(9,0) NOT NULL,
  period_start    SMALLDATETIME NOT NULL,
  period_end      SMALLDATETIME NULL,
  location_id     NUMERIC(9,0) NOT NULL
);

--
-- Table: incidentprop
--
CREATE TABLE incidentprop (
  incidentprop_id NUMERIC(9,0) NOT NULL,
  incident_id     NUMERIC(9,0) NOT NULL,
  type_id          NUMERIC(9,0) NOT NULL,
  value            VARCHAR(255) NOT NULL,
  rank             NUMERIC(9,0) NOT NULL
);

--
-- Table: incident_cvterm
--
CREATE TABLE incident_cvterm (
  incident_cvterm_id NUMERIC(9,0) NOT NULL,
  incident_id        NUMERIC(9,0) NOT NULL,
  cvterm_id           NUMERIC(9,0) NOT NULL,
  pub_id              NUMERIC(9,0) NULL,
  is_not              BIT          NOT NULL
);

--
-- Table: incident_dbxref
--
CREATE TABLE incident_dbxref (
  incident_dbxref_id  NUMERIC(9,0) NOT NULL,
  incident_id         NUMERIC(9,0) NOT NULL,
  dbxref_id         NUMERIC(9,0) NOT NULL,
  is_for_definition BIT          NOT NULL
);

--
-- Table: incident_relationship
--
CREATE TABLE incident_relationship (
  incident_relationship_id NUMERIC(9,0) NOT NULL,
  type_id         	   NUMERIC(9,0) NOT NULL,
  subject_id      	   NUMERIC(9,0) NOT NULL,
  object_id       	   NUMERIC(9,0) NOT NULL
);


--
-- Table: infection_pub
--
CREATE TABLE infection_pub (
  infection_pub_id NUMERIC(9,0) NOT NULL,
  infection_id     NUMERIC(9,0) NOT NULL,
  pub_id         NUMERIC(9,0) NOT NULL
);

--
-- Table: transmission_pub
--
CREATE TABLE transmission_pub (
  transmission_pub_id NUMERIC(9,0) NOT NULL,
  transmission_id     NUMERIC(9,0) NOT NULL,
  pub_id         NUMERIC(9,0) NOT NULL
);

--
-- Table: incident_pub
--
CREATE TABLE incident_pub (
  incident_pub_id NUMERIC(9,0) NOT NULL,
  incident_id     NUMERIC(9,0) NOT NULL,
  pub_id         NUMERIC(9,0) NOT NULL
);


-----------------------------------------------------------------------------
--
-- Module: Contact
--
-----------------------------------------------------------------------------

--
-- Table: contact
--
CREATE TABLE contact (
  contact_id   NUMERIC(9,0) NOT NULL,
  type_id      NUMERIC(9,0) NOT NULL,
  name         VARCHAR(255) NOT NULL,
  description  VARCHAR(255) NOT NULL
);

--
-- Table: contactprop
--
CREATE TABLE contactprop (
  contactprop_id  NUMERIC(9,0) NOT NULL,
  contact_id      NUMERIC(9,0) NOT NULL,
  type_id         NUMERIC(9,0) NOT NULL,
  value           VARCHAR(255) NOT NULL
);

--
-- Table: contact_relationship
--
CREATE TABLE contact_relationship (
  contact_relationship_id NUMERIC(9,0) NOT NULL,
  type_id                 NUMERIC(9,0) NOT NULL,
  subject_id              NUMERIC(9,0) NOT NULL,
  object_id               NUMERIC(9,0) NOT NULL,
);


-----------------------------------------------------------------------------
--
-- Module: Genetic
--
-----------------------------------------------------------------------------

--
-- Table: genotype
--
CREATE TABLE genotype (
  genotype_id  NUMERIC(9,0) NOT NULL,
  name         VARCHAR(255) NOT NULL,
  uniquename   VARCHAR(255) NOT NULL,
  description  VARCHAR(255)     NULL
);


--
-- Table: feature_genotype
--
CREATE TABLE feature_genotype (
  feature_genotype_id NUMERIC(9,0) NOT NULL,
  feature_id          NUMERIC(9,0) NOT NULL,
  genotype_id         NUMERIC(9,0) NOT NULL,
  chromosome_id       NUMERIC(9,0)     NULL,
  rank                NUMERIC(9,0) NOT NULL,
  cgroup              NUMERIC(9,0) NOT NULL,
  cvterm_id           NUMERIC(9,0) NOT NULL
);

--
-- Table: environment
--
CREATE TABLE environment (
  environment_id    NUMERIC(9,0) NOT NULL,
  uniquename        VARCHAR(255) NOT NULL,
  description       VARCHAR(255)     NULL
);

--
-- Table: environment_cvterm
--
CREATE TABLE environment_cvterm (
  environment_cvterm_id  NUMERIC(9,0) NOT NULL,
  environment_id         NUMERIC(9,0) NOT NULL,
  cvterm_id              NUMERIC(9,0) NOT NULL
);

--
-- Table: phenotype
--
CREATE TABLE phenotype (
    phenotype_id  NUMERIC(9,0) NOT NULL,
    uniquename    VARCHAR(255) NOT NULL,
    observable_id NUMERIC(9,0)     NULL,
    attr_id       NUMERIC(9,0)     NULL,
    value         VARCHAR(255)     NULL,
    cvalue_id     NUMERIC(9,0)     NULL,
    assay_id      NUMERIC(9,0)     NULL
);

--
-- Table: phenstatement
--
CREATE TABLE phenstatement (
  phenstatement_id  NUMERIC(9,0) NOT NULL,
  genotype_id       NUMERIC(9,0) NOT NULL,
  environment_id    NUMERIC(9,0) NOT NULL,
  phenotype_id      NUMERIC(9,0) NOT NULL,
  type_id           NUMERIC(9,0) NOT NULL,
  pub_id            NUMERIC(9,0) NOT NULL,
);


--
-- Table: phendesc
--
CREATE TABLE phendesc (
  phendesc_id     NUMERIC(9,0) NOT NULL,
  genotype_id     NUMERIC(9,0) NOT NULL,
  environment_id  NUMERIC(9,0) NOT NULL,
  description     VARCHAR(255) NOT NULL,
  type_id         NUMERIC(9,0) NOT NULL,
  pub_id          NUMERIC(9,0) NOT NULL
);

--
-- Table: phenotype_comparison
--
CREATE TABLE phenotype_comparison (
  phenotype_comparison_id NUMERIC(9,0) NOT NULL,
  genotype1_id            NUMERIC(9,0) NOT NULL,
  environment1_id         NUMERIC(9,0) NOT NULL,
  genotype2_id            NUMERIC(9,0) NOT NULL,
  environment2_id         NUMERIC(9,0) NOT NULL,
  phenotype1_id           NUMERIC(9,0) NOT NULL,
  phenotype2_id           NUMERIC(9,0)     NULL,
  pub_id                  NUMERIC(9,0) NOT NULL,
  organism_id             NUMERIC(9,0) NOT NULL
);

--
-- Table: phenotype_comparison_cvterm
--
CREATE TABLE phenotype_comparison_cvterm (
  phenotype_comparison_cvterm_id NUMERIC(9,0) NOT NULL,
  phenotype_comparison_id        NUMERIC(9,0) NOT NULL,
  cvterm_id                      NUMERIC(9,0) NOT NULL,
  rank                           NUMERIC(9,0) NOT NULL,
);

-----------------------------------------------------------------------------
--
-- Module: Stock
--
-----------------------------------------------------------------------------

--
-- Table: stock
--
CREATE TABLE stock (
  stock_id    NUMERIC(9,0) NOT NULL,
  dbxref_id   NUMERIC(9,0) NOT NULL,
  organism_id NUMERIC(9,0) NOT NULL,
  name        VARCHAR(255)     NULL,
  uniquename  VARCHAR(255) NOT NULL,
  description VARCHAR(255) NOT NULL,
  type_id     NUMERIC(9,0) NOT NULL,
  is_obsolete BIT          NOT NULL
);

--
-- Table: stock_pub
--
CREATE TABLE stock_pub (
  stock_pub_id   NUMERIC(9,0) NOT NULL,
  stock_id       NUMERIC(9,0) NOT NULL,
  pub_id         NUMERIC(9,0) NOT NULL
);

--
-- Table: stockprop
--
CREATE TABLE stockprop (
  stockprop_id   NUMERIC(9,0) NOT NULL,
  stock_id       NUMERIC(9,0) NOT NULL,
  type_id        NUMERIC(9,0) NOT NULL,
  value          VARCHAR(255) NOT NULL,
  rank           NUMERIC(9,0) NOT NULL
);

--
-- Table: stockprop_pub
--
CREATE TABLE stockprop_pub (
  stockprop_pub_id  NUMERIC(9,0) NOT NULL,
  stockprop_id      NUMERIC(9,0) NOT NULL,
  pub_id            NUMERIC(9,0) NOT NULL
);


--
-- Table: stock_relationship
--
CREATE TABLE stock_relationship (
  stock_relationship_id NUMERIC(9,0) NOT NULL,
  subject_id            NUMERIC(9,0) NOT NULL,
  object_id             NUMERIC(9,0) NOT NULL,
  type_id               NUMERIC(9,0) NOT NULL,
  value                 VARCHAR(255) NOT NULL,
  rank                  INT          NOT NULL
);

--
-- Table: stock_relationship_pub
--
CREATE TABLE stock_relationship_pub (
  stock_relationship_pub_id NUMERIC(9,0) NOT NULL,
  stock_relationship_id     NUMERIC(9,0) NOT NULL,
  pub_id                    NUMERIC(9,0) NOT NULL,
);

--
-- Table: stock_dbxref
--
CREATE TABLE stock_dbxref (
  stock_dbxref_id NUMERIC(9,0) NOT NULL,
  stock_id        NUMERIC(9,0) NOT NULL,
  dbxref_id       NUMERIC(9,0) NOT NULL,
  is_current      BIT          NOT NULL
);


--
-- Table: stock_cvterm
--
CREATE TABLE stock_cvterm (
  stock_cvterm_id   NUMERIC(9,0) NOT NULL,
  stock_id          NUMERIC(9,0) NOT NULL,
  cvterm_id         NUMERIC(9,0) NOT NULL,
  pub_id            NUMERIC(9,0) NOT NULL,
);

--
-- Table: stock_genotype
--
CREATE TABLE stock_genotype (
  stock_genotype_id  NUMERIC(9,0) NOT NULL,
  stock_id           NUMERIC(9,0) NOT NULL,
  genotype_id        NUMERIC(9,0) NOT NULL,
);


--
-- Table: stockcollection
--
CREATE TABLE stockcollection (
  stockcollection_id  NUMERIC(9,0) NOT NULL,
  type_id             NUMERIC(9,0) NOT NULL,
  contact_id          NUMERIC(9,0)     NULL,
  name                VARCHAR(255)     NULL,
  uniquename          VARCHAR(255) NOT NULL,
);

--
-- Table: stockcollection_stock
--
CREATE TABLE stockcollection_stock (
    stockcollection_stock_id    NUMERIC(9,0) NOT NULL,
    stockcollection_id          NUMERIC(9,0) NOT NULL,
    stock_id                    NUMERIC(9,0) NOT NULL,
);

--
-- Table: stockcollectionprop
--
CREATE TABLE stockcollectionprop (
  stockcollectionprop_id  NUMERIC(9,0) NOT NULL,
  stockcollection_id      NUMERIC(9,0) NOT NULL,
  type_id                 NUMERIC(9,0) NOT NULL,
  value                   VARCHAR(255) NOT NULL,
  rank                    NUMERIC(9,0) NOT NULL
);


--
-- Table: stockcollectionprop_stock
--
CREATE TABLE stockcollectionprop_stock (
  stockcollection_stock_id  NUMERIC(9,0) NOT NULL,
  stockcollection_id        NUMERIC(9,0) NOT NULL,
  stock_id                  NUMERIC(9,0) NOT NULL,
);

