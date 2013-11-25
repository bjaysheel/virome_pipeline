
--
-- View: cm_genes
--

CREATE VIEW cm_genes
AS
SELECT 	t.feature_id       AS "feature_id_transcript",
       	t.uniquename       AS "uniquename_transcript",
       	flt.fmin           AS "fmin_transcript",
       	flt.fmax           AS "fmax_transcript",
       	c.feature_id       AS "feature_id_cds",
	c.uniquename       AS "uniquename_cds",
	flc.fmin           AS "fmin_cds",
	flc.fmax           AS "fmax_cds",
	g.feature_id       AS "feature_id_gene",
	g.uniquename       AS "uniquename_gene",
	flg.fmin           AS "fmin_gene",
	flg.fmax           AS "fmax_gene",
	p.feature_id       AS "feature_id_protein",
	flg.srcfeature_id  AS "srcfeature_id",
	fp.value           AS "gene_product_name"
FROM feature t, feature c, feature g, feature p, 
     featureprop fp, featureloc flt, featureloc flc, 
     featureloc flg, cvterm ct, cvterm cc, cvterm cg,
     cvterm cp, cvterm cfp, feature_relationship frel1, 
     feature_relationship frel2, feature_relationship frel3
WHERE ct.name = 'transcript'
AND cc.name = 'CDS'
AND cg.name = 'gene'
AND cp.name = 'polypeptide'
AND cfp.name = 'gene_product_name'
AND ct.cvterm_id = t.type_id
AND cc.cvterm_id = c.type_id
AND cg.cvterm_id = g.type_id
AND cp.cvterm_id = p.type_id
AND g.feature_id = frel1.object_id
AND t.feature_id = frel1.subject_id
AND t.feature_id = frel2.object_id
AND c.feature_id = frel2.subject_id
AND c.feature_id = frel3.object_id
AND p.feature_id = frel3.subject_id
AND p.feature_id = fp.feature_id
AND fp.type_id = cfp.cvterm_id
AND g.feature_id = flg.feature_id
AND t.feature_id = flt.feature_id
AND c.feature_id = flc.feature_id;

--
-- View: cm_gene_structure
--

CREATE VIEW cm_gene_structure
AS
SELECT 	e.feature_id       AS "feature_id_exon",
       	fle.fmin           AS "fmin_exon",
       	fle.fmax           AS "fmax_exon"
FROM feature e, featureloc fle, cvterm ce
WHERE ce.name = 'exon'
AND ce.cvterm_id = e.type_id
AND e.feature_id = fle.feature_id;


--
-- View: cm_cvterms
--

CREATE VIEW cm_cvterms
AS
SELECT 	c.cvterm_id AS "cvterm_id",
	c.cv_id     AS "cv_id",
	c.name      AS "name",
    	d.accession AS "accession"
FROM cvterm c, cv, dbxref d
WHERE cv.cv_id = c.cv_id
AND c.dbxref_id = d.dbxref_id;
