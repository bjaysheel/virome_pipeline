--
-- Author:         Jay Sundaram sundaram@tigr.org
-- Date Modified:  2005-07-18 
-- Schema:         Chado
-- CVS:            ANNOTATION/chado/tigr_schemas/chado_template/ALL_Modules/create_tables.ddl
-- Version:        $Name:  $
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
  tableinfo_id        INT          NOT NULL,
  name                VARCHAR(30)  NOT NULL,
  primary_key_column  VARCHAR(30)  NULL,
  is_view             BOOLEAN      NOT NULL,
  view_on_table_id    INT          NULL,
  superclass_table_id INT          NULL,
  is_updateable       BOOLEAN      NOT NULL,
  modification_date   TIMESTAMP    NOT NULL
);

--
-- Table: project
--
CREATE TABLE project (
  project_id  INT          NOT NULL,
  name        VARCHAR(255) NOT NULL,
  description VARCHAR(255) NOT NULL
);


--
-- Table: db
--

CREATE TABLE db (
  db_id       INT          NOT NULL,
  name        VARCHAR(50)  NOT NULL,
  description VARCHAR(255) NULL,
  urlprefix   VARCHAR(255) NULL,
  url         VARCHAR(255) NULL
);

--
-- Table: dbxref
--

CREATE TABLE dbxref (
  dbxref_id   INT           NOT NULL,
  db_id       INT           NOT NULL,
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
  cv_id      INT          NOT NULL,
  name       VARCHAR(255) NOT NULL,
  definition VARCHAR(255) NULL
);

--
-- Table: cvterm
--

CREATE TABLE cvterm (
  cvterm_id           INT           NOT NULL,
  cv_id               INT           NOT NULL,
  name                VARCHAR(255)  NOT NULL,
  definition          VARCHAR(1200) NULL,
  dbxref_id           INT           NULL,
  is_obsolete         INT           NOT NULL,
  is_relationshiptype BOOLEAN       NOT NULL
);

--
-- Table: cvterm_relationship
--

CREATE TABLE cvterm_relationship (
  cvterm_relationship_id INT NOT NULL,
  type_id                INT NOT NULL,
  subject_id             INT NOT NULL,
  object_id              INT NOT NULL
);

--
-- Table: cvtermpath
--

CREATE TABLE cvtermpath (
  cvtermpath_id INT NOT NULL,
  type_id       INT NULL,
  subject_id    INT NOT NULL,
  object_id     INT NOT NULL,
  cv_id         INT NOT NULL,
  pathdistance  INT NULL
);

--
-- Table: cvtermsynonym
--

CREATE TABLE cvtermsynonym (
  cvtermsynonym_id INT           NOT NULL,
  cvterm_id        INT           NOT NULL,
  synonym          VARCHAR(1024) NOT NULL,
  type_id          INT           NULL
);

--
-- Table: cvterm_dbxref
--

CREATE TABLE cvterm_dbxref (
  cvterm_dbxref_id  INT     NOT NULL,
  cvterm_id         INT     NOT NULL,
  dbxref_id         INT     NOT NULL,
  is_for_definition BOOLEAN NOT NULL
);

--
-- Table: cvtermprop
--

CREATE TABLE cvtermprop (
       cvtermprop_id INT          NOT NULL,
       cvterm_id     INT          NOT NULL,
       type_id       INT          NOT NULL,
       value         VARCHAR(1000) NOT NULL,
       rank          INT          NOT NULL
);

--
-- Table: dbxrefprop
--

CREATE TABLE dbxrefprop (
       dbxrefprop_id INT          NOT NULL,
       dbxref_id     INT          NOT NULL,
       type_id       INT          NOT NULL,
       value         VARCHAR(255) NOT NULL,
       rank          INT          NOT NULL
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
  organism_id  INT          NOT NULL,
  abbreviation VARCHAR(255)  NULL,
  genus        VARCHAR(255)  NOT NULL,
  species      VARCHAR(255)  NOT NULL,
  common_name  VARCHAR(255) NULL,
  comment      VARCHAR(255) NULL
);

--
-- Table: organism_dbxref
--

CREATE TABLE organism_dbxref (
  organism_dbxref_id INT NOT NULL,
  organism_id        INT NOT NULL,
  dbxref_id          INT NOT NULL
);

--
-- Table: organismprop
--

CREATE TABLE organismprop (
  organismprop_id INT          NOT NULL,
  organism_id     INT          NOT NULL,
  type_id         INT          NOT NULL,
  value           VARCHAR(255) NOT NULL,
  rank            INT          NOT NULL
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
  pub_id        INT          NOT NULL,
  title         VARCHAR(255) NULL,
  volumetitle   VARCHAR(255) NULL,
  volume        VARCHAR(255) NULL,
  series_name   VARCHAR(255) NULL,
  issue         VARCHAR(255) NULL,
  pyear         VARCHAR(255) NULL,
  pages         VARCHAR(255) NULL,
  miniref       VARCHAR(255) NULL,
  uniquename    VARCHAR(255) NOT NULL,
  type_id       INT          NOT NULL,
  is_obsolete   BOOLEAN      NOT NULL,
  publisher     VARCHAR(255) NULL,
  pubplace      VARCHAR(255) NULL
);

--
-- Table: pub_relationship
--

CREATE TABLE pub_relationship (
  pub_relationship_id INT NOT NULL,
  subject_id          INT NOT NULL,
  object_id           INT NOT NULL,
  type_id             INT NOT NULL
);

--
-- Table: pub_dbxref
--

CREATE TABLE pub_dbxref (
  pub_dbxref_id INT     NOT NULL,
  pub_id        INT     NOT NULL,
  dbxref_id     INT     NOT NULL,
  is_current    BOOLEAN NOT NULL
);

--
-- Table: pubauthor
--

CREATE TABLE pubauthor (
  pubauthor_id  INT           NOT NULL,
  pub_id        INT           NOT NULL,
  rank          INT           NOT NULL,
  editor        BOOLEAN       NOT NULL,
  surname       VARCHAR(255)  NOT NULL,
  givennames    VARCHAR(100)  NULL,
  suffix        VARCHAR(100)  NULL
);

--
-- Table: pubprop
--

CREATE TABLE pubprop (
  pubprop_id INT          NOT NULL,
  pub_id     INT          NOT NULL,
  type_id    INT          NOT NULL,
  value      VARCHAR(255) NOT NULL,
  rank       INT          NULL
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
  feature_id       INT           NOT NULL,
  dbxref_id        INT           NULL,
  organism_id      INT           NOT NULL,
  name             VARCHAR(255)  NULL,
  uniquename       VARCHAR(255)  NOT NULL,
  residues         TEXT          NULL,
  seqlen           INT           NULL,
  md5checksum      CHAR(32)      NULL,
  type_id          INT           NOT NULL,
  is_analysis      BOOLEAN       NOT NULL,
  is_obsolete      BOOLEAN       NOT NULL,
  timeaccessioned  TIMESTAMP     NOT NULL,
  timelastmodified TIMESTAMP     NOT NULL
);

--
-- Table: featureloc
--

CREATE TABLE featureloc (
  featureloc_id   INT          NOT NULL,
  feature_id      INT          NOT NULL,
  srcfeature_id   INT          NULL,
  fmin            INT          NULL,
  is_fmin_partial BOOLEAN      NOT NULL,
  fmax            INT          NULL,
  is_fmax_partial BOOLEAN      NOT NULL,
  strand          SMALLINT     NULL,
  phase           INT          NULL,
  residue_info    VARCHAR(7500) NULL,
  locgroup        INT          NOT NULL,
  rank            INT          NOT NULL
);

--
-- Table: feature_pub
--

CREATE TABLE feature_pub (
  feature_pub_id INT NOT NULL,
  feature_id     INT NOT NULL,
  pub_id         INT NOT NULL
);

--
-- Table: featureprop
--

CREATE TABLE featureprop (
  featureprop_id INT  NOT NULL,
  feature_id     INT  NOT NULL,
  type_id        INT  NOT NULL,
  value          VARCHAR(2000) NOT NULL,
  rank           INT  NOT NULL
);

--
-- Table: featureprop_pub
--

CREATE TABLE featureprop_pub (
  featureprop_pub_id INT NOT NULL,
  featureprop_id     INT NOT NULL,
  pub_id             INT NOT NULL
);

--
-- Table: feature_dbxref
--

CREATE TABLE feature_dbxref (
  feature_dbxref_id INT NOT NULL,
  feature_id        INT NOT NULL,
  dbxref_id         INT NOT NULL,
  is_current        BOOLEAN          NOT NULL
);

--
-- Table: feature_relationship
--

CREATE TABLE feature_relationship (
  feature_relationship_id INT NOT NULL,
  subject_id              INT NOT NULL,
  object_id               INT NOT NULL,
  type_id                 INT NOT NULL,
  value                   VARCHAR(255) NULL,
  rank                    INT NULL
);

--
-- Table: feature_relationship_pub
--

CREATE TABLE feature_relationship_pub (
  feature_relationship_pub_id INT NOT NULL,
  feature_relationship_id     INT NOT NULL,
  pub_id                      INT NOT NULL
);

--
-- Table feature_relationshipprop
--

CREATE TABLE feature_relationshipprop (
  feature_relationshipprop_id INT NOT NULL,
  feature_relationship_id     INT NOT NULL,
  type_id                     INT NOT NULL,
  value                       VARCHAR(255) NOT NULL,
  rank                        INT NOT NULL
);

--
-- Table: feature_relprop_pub
--

CREATE TABLE feature_relprop_pub (
  feature_relprop_pub_id INT NOT NULL,
  feature_relationshipprop_id     INT NOT NULL,
  pub_id                          INT NOT NULL
);

--
-- Table: feature_cvterm
--

CREATE TABLE feature_cvterm (
  feature_cvterm_id INT NOT NULL,
  feature_id        INT NOT NULL,
  cvterm_id         INT NOT NULL,
  pub_id            INT NOT NULL,
  is_not            BOOLEAN          NOT NULL
);

--
-- Table: feature_cvtermprop
--

CREATE TABLE feature_cvtermprop (
    feature_cvtermprop_id INT NOT NULL,
    feature_cvterm_id     INT NOT NULL,
    type_id               INT NOT NULL,
    value                 VARCHAR(255) NOT NULL,
    rank                  INT NOT NULL
);

--
-- Table: feature_cvterm_dbxref
--

CREATE TABLE feature_cvterm_dbxref (
    feature_cvterm_dbxref_id  INT NOT NULL,
    feature_cvterm_id         INT NOT NULL,
    dbxref_id                 INT NOT NULL
);

--
-- Table: feature_cvterm_dbxref
--

CREATE TABLE feature_cvterm_pub (
    feature_cvterm_pub_id  INT NOT NULL,
    feature_cvterm_id      INT NOT NULL,
    pub_id              INT NOT NULL
);

--
-- Table: synonym
--

CREATE TABLE synonym (
  synonym_id   INT NOT NULL,
  name         VARCHAR(255) NOT NULL,
  type_id      INT NOT NULL,
  synonym_sgml VARCHAR(255) NOT NULL
);

--
-- Table: feature_synonym
--

CREATE TABLE feature_synonym (
  feature_synonym_id INT NOT NULL,
  synonym_id         INT NOT NULL,
  feature_id         INT NOT NULL,
  pub_id             INT NOT NULL,
  is_current         BOOLEAN          NOT NULL,
  is_internal        BOOLEAN          NOT NULL
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
  analysis_id    INT  NOT NULL,
  name           VARCHAR(255)  NULL,
  description    VARCHAR(255)  NULL,
  program        VARCHAR(50)   NOT NULL,
  programversion VARCHAR(50)   NOT NULL,
  algorithm      VARCHAR(50)   NULL,
  sourcename     VARCHAR(255)  NULL,
  sourceversion  VARCHAR(50)   NULL,
  sourceuri      VARCHAR(255)  NULL,
  timeexecuted   TIMESTAMP NOT NULL
);

--
-- Table: analysisprop
--

CREATE TABLE analysisprop (
  analysisprop_id INT NOT NULL,
  analysis_id     INT NOT NULL,
  type_id         INT NOT NULL,
  value           VARCHAR(255) NULL
);

--
-- Table: analysisfeature
--

CREATE TABLE analysisfeature (
  analysisfeature_id INT NOT NULL,
  feature_id         INT NOT NULL,
  analysis_id        INT NOT NULL,
  rawscore           DOUBLE PRECISION NULL,
  normscore          DOUBLE PRECISION NULL,
  significance       DOUBLE PRECISION NULL,
  pidentity          DOUBLE PRECISION NULL,
  type_id            INT NULL	
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
  phylotree_id        INT NOT NULL,
  dbxref_id           INT NOT NULL,
  name                VARCHAR(255)     NULL,
  type_id             INT NOT NULL,
  comment             VARCHAR(255)     NULL
);

--
-- Table: phylotree_pub
--

CREATE TABLE phylotree_pub (
  phylotree_pub_id    INT NOT NULL,
  phylotree_id        INT NOT NULL,
  pub_id              INT NOT NULL
);

--
-- Table: phylonode
--

CREATE TABLE phylonode (
  phylonode_id        INT NOT NULL,
  phylotree_id        INT NOT NULL,
  parent_phylonode_id INT     NULL,
  left_idx            INT NOT NULL,
  right_idx           INT NOT NULL,
  type_id             INT NOT NULL,
  feature_id          INT     NULL,
  label               VARCHAR(255)     NULL,
  distance            DOUBLE PRECISION
);


--
-- Table: phylonode_dbxref
--

CREATE TABLE phylonode_dbxref (
  phylonode_dbxref_id    INT NOT NULL,
  phylonode_id           INT NOT NULL,
  dbxref_id              INT NOT NULL
);

--
-- Table: phylonode_pub
--

CREATE TABLE phylonode_pub (
  phylonode_pub_id    INT NOT NULL,
  phylonode_id        INT NOT NULL,
  pub_id              INT NOT NULL
);

--
-- Table: phylonode_organism
--

CREATE TABLE phylonode_organism (
  phylonode_organism_id    INT NOT NULL,
  phylonode_id             INT NOT NULL,
  organism_id              INT NOT NULL
);



--
-- Table: phylonodeprop
--

CREATE TABLE phylonodeprop (
  phylonodeprop_id    INT NOT NULL,
  phylonode_id        INT NOT NULL,
  type_id             INT NOT NULL,
  value               VARCHAR(255) NOT NULL,
  rank                INT NOT NULL
);


--
-- Table: phylonode_relationship
--

CREATE TABLE phylonode_relationship (
  phylonode_relationship_id    INT NOT NULL,
  subject_id                   INT NOT NULL,
  object_id                    INT NOT NULL,
  type_id                      INT NOT NULL,
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
  infection_id INT NOT NULL,
  pathogen_id  INT NOT NULL,
  hostres_id   INT NOT NULL,
  disease_id   INT NULL
);

--
-- Table: infectionprop
--
CREATE TABLE infectionprop (
  infectionprop_id INT NOT NULL,
  infection_id     INT NOT NULL,
  type_id          INT NOT NULL,
  value            VARCHAR(255) NOT NULL,
  rank             INT NOT NULL
);

--
-- Table: infection_cvterm
--
CREATE TABLE infection_cvterm (
  infection_cvterm_id INT NOT NULL,
  infection_id        INT NOT NULL,
  cvterm_id           INT NOT NULL,
  pub_id              INT NULL,
  is_not              BIT          NOT NULL
);

--
-- Table: infection_dbxref
--

CREATE TABLE infection_dbxref (
  infection_dbxref_id  INT NOT NULL,
  infection_id         INT NOT NULL,
  dbxref_id         INT NOT NULL,
  is_for_definition BIT          NOT NULL
);

--
-- Table: transmission
--
CREATE TABLE transmission (
  transmission_id INT NOT NULL,
  type_id         INT NOT NULL,
  subject_id      INT NOT NULL,
  object_id       INT NOT NULL,
  portal_id	  INT NULL
);

--
-- Table: transmissionprop
--
CREATE TABLE transmissionprop (
  transmissionprop_id INT NOT NULL,
  transmission_id     INT NOT NULL,
  type_id             INT NOT NULL,
  value               VARCHAR(255) NOT NULL,
  rank                INT NOT NULL
);

--
-- Table: transmission_cvterm
--
CREATE TABLE transmission_cvterm (
  transmission_cvterm_id INT NOT NULL,
  transmission_id        INT NOT NULL,
  cvterm_id              INT NOT NULL,
  pub_id                 INT NULL,
  is_not                 BIT          NOT NULL
);

--
-- Table: transmission_dbxref
--
CREATE TABLE transmission_dbxref (
  transmission_dbxref_id  INT NOT NULL,
  transmission_id         INT NOT NULL,
  dbxref_id               INT NOT NULL,
  is_for_definition BIT   NOT NULL
);

--
-- Table: incident
--
CREATE TABLE incident (
  incident_id     INT NOT NULL,
  transmission_id INT NOT NULL,
  location_id     INT,
  date_start      TIMESTAMP WITHOUT TIME ZONE,
  date_end        TIMESTAMP WITHOUT TIME ZONE,
  gender          CHAR(1)
);

--
-- Table: incidentprop
--
CREATE TABLE incidentprop (
  incidentprop_id INT NOT NULL,
  incident_id     INT NOT NULL,
  type_id         INT NOT NULL,
  value           VARCHAR(255) NOT NULL,
  rank            INT NOT NULL
);

--
-- Table: incident_cvterm
--
CREATE TABLE incident_cvterm (
  incident_cvterm_id INT NOT NULL,
  incident_id        INT NOT NULL,
  cvterm_id          INT NOT NULL,
  pub_id             INT NULL,
  is_not             BIT          NOT NULL
);

--
-- Table: incident_dbxref
--
CREATE TABLE incident_dbxref (
  incident_dbxref_id  INT NOT NULL,
  incident_id         INT NOT NULL,
  dbxref_id           INT NOT NULL,
  is_for_definition   BIT          NOT NULL
);

--
-- Table: incident_relationship
--
CREATE TABLE incident_relationship (
  incident_relationship_id INT NOT NULL,
  type_id         	   INT NOT NULL,
  subject_id      	   INT NOT NULL,
  object_id       	   INT NOT NULL
);


--
-- Table: infection_pub
--
CREATE TABLE infection_pub (
  infection_pub_id INT NOT NULL,
  infection_id     INT NOT NULL,
  pub_id           INT NOT NULL
);

--
-- Table: transmission_pub
--
CREATE TABLE transmission_pub (
  transmission_pub_id INT NOT NULL,
  transmission_id     INT NOT NULL,
  pub_id              INT NOT NULL
);

--
-- Table: incident_pub
--
CREATE TABLE incident_pub (
  incident_pub_id INT NOT NULL,
  incident_id     INT NOT NULL,
  pub_id          INT NOT NULL
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
  contact_id   INT NOT NULL,
  type_id      INT NOT NULL,
  name         VARCHAR(255) NOT NULL,
  description  VARCHAR(255) NOT NULL
);

--
-- Table: contactprop
--
CREATE TABLE contactprop (
  contactprop_id  INT NOT NULL,
  contact_id      INT NOT NULL,
  type_id         INT NOT NULL,
  value           VARCHAR(255) NOT NULL
);

--
-- Table: contact_relationship
--
CREATE TABLE contact_relationship (
  contact_relationship_id INT NOT NULL,
  type_id                 INT NOT NULL,
  subject_id              INT NOT NULL,
  object_id               INT NOT NULL
);


-----------------------------------------------------------------------------
--
-- Module: Genotype
--
-----------------------------------------------------------------------------

--
-- Table: genotype
--
CREATE TABLE genotype (
  genotype_id  INT NOT NULL,
  name         VARCHAR(255) NOT NULL,
  uniquename   VARCHAR(255) NOT NULL,
  description  VARCHAR(255)     NULL
);


--
-- Table: feature_genotype
--
CREATE TABLE feature_genotype (
  feature_genotype_id INT NOT NULL,
  feature_id          INT NOT NULL,
  genotype_id         INT NOT NULL,
  chromosome_id       INT     NULL,
  rank                INT NOT NULL,
  cgroup              INT NOT NULL,
  cvterm_id           INT NOT NULL
);

--
-- Table: environment
--
CREATE TABLE environment (
  environment_id    INT NOT NULL,
  uniquename        VARCHAR(255) NOT NULL,
  description       VARCHAR(255)     NULL
);

--
-- Table: environment_cvterm
--
CREATE TABLE environment_cvterm (
  environment_cvterm_id  INT NOT NULL,
  environment_id         INT NOT NULL,
  cvterm_id              INT NOT NULL
);

--
-- Table: phenotype
--
CREATE TABLE phenotype (
    phenotype_id  INT NOT NULL,
    uniquename    VARCHAR(255) NOT NULL,
    observable_id INT     NULL,
    attr_id       INT     NULL,
    value         VARCHAR(255)     NULL,
    cvalue_id     INT     NULL,
    assay_id      INT     NULL
);

--
-- Table: phenstatement
--
CREATE TABLE phenstatement (
  phenstatement_id  INT NOT NULL,
  genotype_id       INT NOT NULL,
  environment_id    INT NOT NULL,
  phenotype_id      INT NOT NULL,
  type_id           INT NOT NULL,
  pub_id            INT NOT NULL
);


--
-- Table: phendesc
--
CREATE TABLE phendesc (
  phendesc_id     INT NOT NULL,
  genotype_id     INT NOT NULL,
  environment_id  INT NOT NULL,
  description     VARCHAR(255) NOT NULL,
  type_id         INT NOT NULL,
  pub_id          INT NOT NULL
);

--
-- Table: phenotype_comparison
--
CREATE TABLE phenotype_comparison (
  phenotype_comparison_id INT NOT NULL,
  genotype1_id            INT NOT NULL,
  environment1_id         INT NOT NULL,
  genotype2_id            INT NOT NULL,
  environment2_id         INT NOT NULL,
  phenotype1_id           INT NOT NULL,
  phenotype2_id           INT     NULL,
  pub_id                  INT NOT NULL,
  organism_id             INT NOT NULL
);

--
-- Table: phenotype_comparison_cvterm
--
CREATE TABLE phenotype_comparison_cvterm (
  phenotype_comparison_cvterm_id INT NOT NULL,
  phenotype_comparison_id        INT NOT NULL,
  cvterm_id                      INT NOT NULL,
  rank                           INT NOT NULL
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
  stock_id    INT NOT NULL,
  dbxref_id   INT NOT NULL,
  organism_id INT NOT NULL,
  name        VARCHAR(255)     NULL,
  uniquename  VARCHAR(255) NOT NULL,
  description VARCHAR(255) NOT NULL,
  type_id     INT NOT NULL,
  is_obsolete BIT          NOT NULL
);

--
-- Table: stock_pub
--
CREATE TABLE stock_pub (
  stock_pub_id   INT NOT NULL,
  stock_id       INT NOT NULL,
  pub_id         INT NOT NULL
);

--
-- Table: stockprop
--
CREATE TABLE stockprop (
  stockprop_id   INT NOT NULL,
  stock_id       INT NOT NULL,
  type_id        INT NOT NULL,
  value          VARCHAR(255) NOT NULL,
  rank           INT NOT NULL
);

--
-- Table: stockprop_pub
--
CREATE TABLE stockprop_pub (
  stockprop_pub_id  INT NOT NULL,
  stockprop_id      INT NOT NULL,
  pub_id            INT NOT NULL
);


--
-- Table: stock_relationship
--
CREATE TABLE stock_relationship (
  stock_relationship_id INT NOT NULL,
  subject_id            INT NOT NULL,
  object_id             INT NOT NULL,
  type_id               INT NOT NULL,
  value                 VARCHAR(255) NOT NULL,
  rank                  INT          NOT NULL
);

--
-- Table: stock_relationship_pub
--
CREATE TABLE stock_relationship_pub (
  stock_relationship_pub_id INT NOT NULL,
  stock_relationship_id     INT NOT NULL,
  pub_id                    INT NOT NULL
);

--
-- Table: stock_dbxref
--
CREATE TABLE stock_dbxref (
  stock_dbxref_id INT NOT NULL,
  stock_id        INT NOT NULL,
  dbxref_id       INT NOT NULL,
  is_current      BIT          NOT NULL
);


--
-- Table: stock_cvterm
--
CREATE TABLE stock_cvterm (
  stock_cvterm_id   INT NOT NULL,
  stock_id          INT NOT NULL,
  cvterm_id         INT NOT NULL,
  pub_id            INT NOT NULL
);

--
-- Table: stock_genotype
--
CREATE TABLE stock_genotype (
  stock_genotype_id  INT NOT NULL,
  stock_id           INT NOT NULL,
  genotype_id        INT NOT NULL
);


--
-- Table: stockcollection
--
CREATE TABLE stockcollection (
  stockcollection_id  INT NOT NULL,
  type_id             INT NOT NULL,
  contact_id          INT     NULL,
  name                VARCHAR(255)     NULL,
  uniquename          VARCHAR(255) NOT NULL
);

--
-- Table: stockcollection_stock
--
CREATE TABLE stockcollection_stock (
    stockcollection_stock_id    INT NOT NULL,
    stockcollection_id          INT NOT NULL,
    stock_id                    INT NOT NULL
);

--
-- Table: stockcollectionprop
--
CREATE TABLE stockcollectionprop (
  stockcollectionprop_id  INT NOT NULL,
  stockcollection_id      INT NOT NULL,
  type_id                 INT NOT NULL,
  value                   VARCHAR(255) NOT NULL,
  rank                    INT NOT NULL
);


--
-- Table: stockcollectionprop_stock
--
CREATE TABLE stockcollectionprop_stock (
  stockcollection_stock_id  INT NOT NULL,
  stockcollection_id        INT NOT NULL,
  stock_id                  INT NOT NULL
);

