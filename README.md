![Alt text](./images/virome_logo.png "VIROME")

VIROME Ergatis Pipeline
-----------------------

This is the central repository of all scripts and ergatis configuration files used by the Viral Informatics Resource fOr Metagenomic Exploration (VIROME) pipeline.

More information on VIROME can be found on the VIROME website [http://virome.dbi.udel.edu](http://virome.dbi.udel.edu "VIROME Website") or the [VIROME publication](http://standardsingenomics.org/index.php/sigen/article/view/sigs.2945051/753).

If you use VIROME please cite:

> Wommack KE, Bhavsar J, Polson SW, et al. VIROME: a standard operating procedure for analysis of viral metagenome sequences. Stand Genomic Sci. 2012;6(3):427-39.

The VIROME bioinformatics pipeline is controlled using [ergatis](http://ergatis.sourceforge.net) and runs on the [Data Intensive Academic Grid (DIAG)](http://diagcomputing.org) hosted by the [University of Maryland School of Medicine Institutes for Genome Sciences](http://www.igs.umaryland.edu). While this repository is tailored for a system with ergatis installed there are many useful scripts in the /bin directory that some researchers may find useful in their work.

After cloning this repo I typically rename:

    mv virome_pipeline package_virome

If this is the first time you've cloned this repository and you're going to set it up to work with ergatis, then there are several global variables and hard-coded file paths that need to be updated. These will be easy to spot as they will typically lead with "/diag/projects/virome".

Overview of Contents
--------------------

| Item                     | Description |
|--------------------------|-------------|
| autopipe_package         | All of the files for the automated pipeline
| /bin                     | All of the Perl scripts for VIROME pipeline
| /docs                    | All XML docs needed for Ergatis configuration
| /man                     | Man pages
| /project_saved_templates | Templates for VIROME Ergatis pipelines
| README.md                | This README
| /samples                 | Example data
| /software                | Locally installed software for VIROME
| sofware.config           | Ergatis software config file

![Alt text](./images/moore_logo.jpg "GBMF")

*Rev 02 Oct 2015 DJN*