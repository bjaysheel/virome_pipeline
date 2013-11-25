---------------------------------------------------------------------------------------
--
--
-- Contains all the SQL statements required to bind default values
-- to the appropriate columns in tables belonging to ALL Modules
--
-- Assumes the defaults have been defined already as:
--
-- create default zero_def as 0
-- create default one_def as 1
-- create default empty_string_def as ''
-- create default date_def as getdate()
-- create default false_def as 'false'
-- create default true_def as 'true'
--
--
---------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------
--
-- Module: CV
--
---------------------------------------------------------------------------------------

--
-- Table: cvterm
--
exec sp_bindefault zero_def, 'cvterm.is_obsolete'
exec sp_bindefault zero_def, 'cvterm.is_relationshiptype'
exec sp_bindefault zero_def, 'cvterm_dbxref.is_for_definition'

--
-- Table: cvtermprop
--
exec sp_bindefault empty_string_def, 'cvtermprop.value'
exec sp_bindefault zero_def, 'cvtermprop.rank'

--
-- Table: dbxrefprop
--
exec sp_bindefault empty_string_def, 'dbxrefprop.value'
exec sp_bindefault zero_def, 'dbxrefprop.rank'

---------------------------------------------------------------------------------------
--
-- Module: General
--
---------------------------------------------------------------------------------------

--
-- Table: tableinfo
--
exec sp_bindefault zero_def, 'tableinfo.is_view';
exec sp_bindefault one_def, 'tableinfo.is_updateable';
exec sp_bindefault date_def, 'tableinfo.modification_date';

--
-- Table: dbxref
--
exec sp_bindefault empty_string_def, 'dbxref.version';

---------------------------------------------------------------------------------------
--
-- Module: Organism
--
---------------------------------------------------------------------------------------

--
-- Table: organism
--
exec sp_bindefault zero_def, 'organismprop.rank';


---------------------------------------------------------------------------------------
--
-- Module: Pub
--
---------------------------------------------------------------------------------------

--
-- Table: pub
--
exec sp_bindefault zero_def, 'pub.is_obsolete';

--
-- Table: pub_dbxref
--
exec sp_bindefault one_def, 'pub_dbxref.is_current';

--
-- Table: pub_author
--
exec sp_bindefault zero_def, 'pub_author.editor';

---------------------------------------------------------------------------------------
--
-- Module: Sequence
--
---------------------------------------------------------------------------------------

--
-- Table: feature
--
exec sp_bindefault zero_def, 'feature.is_analysis';
exec sp_bindefault zero_def, 'feature.is_obsolete';
exec sp_bindefault date_def, 'feature.timeaccessioned';
exec sp_bindefault date_def, 'feature.timelastmodified';

--
-- Table: featureloc
--
exec sp_bindefault zero_def, 'featureloc.is_fmin_partial';
exec sp_bindefault zero_def, 'featureloc.is_fmax_partial';
exec sp_bindefault zero_def, 'featureloc.locgroup';
exec sp_bindefault zero_def, 'featureloc.rank';

--
-- Table: featureprop
--
exec sp_bindefault zero_def, 'featureprop.rank';

--
-- Table: feature_dbxref
--
exec sp_bindefault one_def, 'feature_dbxref.is_current';

--
-- Table: feature_relationship
--
exec sp_bindefault zero_def, 'feature_relationship.rank';

--
-- Table: feature_relationshipprop
--
exec sp_bindefault zero_def, 'feature_relationshipprop.rank';

--
-- Table: feature_cvterm
--
exec sp_bindefault one_def, 'feature_cvterm.is_not';

--
-- Table: feature_cvtermprop
--
exec sp_bindefault zero_def, 'feature_cvtermprop.rank';

--
-- Table: feature_synonym
--
exec sp_bindefault one_def, 'feature_synonym.is_current';
exec sp_bindefault zero_def, 'feature_synonym.is_internal';

---------------------------------------------------------------------------------------
--
-- Module: Computational Analysis
--
---------------------------------------------------------------------------------------

--
-- Table: analysis
--
exec sp_bindefault date_def, 'analysis.timeexecuted';
