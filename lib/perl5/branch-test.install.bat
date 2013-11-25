cd /tmp/cas2
rm -rf *_install

cvs co -r bsml-v2r2b0-branch bsml_install
cd !$
/usr/local/devel/ANNOTATION/perl/bin/perl Makefile.PL PREFIX=/usr/local/devel/ANNOTATION/cas/branch-test/ SCHEMA_DOCS_DIR=/usr/local/devel/ANNOTATION/cas/branch-test/docs
make; make install

cd /tmp/cas2
cvs co -r papyrus-v2r2b1-branch papyrus_install
cd !$
/usr/local/devel/ANNOTATION/perl/bin/perl Makefile.PL PREFIX=/usr/local/devel/ANNOTATION/cas/branch-test/ WORKFLOW_DOCS_DIR=/usr/local/devel/ANNOTATION/cas/branch-test/docs SCHEMA_DOCS_DIR=/usr/local/devel/ANNOTATION/cas/branch-test/docs
make;make install

cd /tmp/cas2
cvs co -r prism-v1r5b1-branch euk_prism_install
cd !$
/usr/local/devel/ANNOTATION/perl/bin/perl Makefile.PL PREFIX=/usr/local/devel/ANNOTATION/cas/branch-test/
make;make install

cd /tmp/cas2
cvs co -r prism-v1r5b1-branch prok_prism_install
cd !$
/usr/local/devel/ANNOTATION/perl/bin/perl Makefile.PL PREFIX=/usr/local/devel/ANNOTATION/cas/branch-test/
make;make install

cd /tmp/cas2
cvs co -r prism-v1r5b1-branch shared_prism_install
cd !$
/usr/local/devel/ANNOTATION/perl/bin/perl Makefile.PL PREFIX=/usr/local/devel/ANNOTATION/cas/branch-test/
make;make install

cd /tmp/cas2
cvs co -r prism-v1r5b1-branch chado_prism_install
cd !$
/usr/local/devel/ANNOTATION/perl/bin/perl Makefile.PL PREFIX=/usr/local/devel/ANNOTATION/cas/branch-test/
make;make install

cd /tmp/cas2
cvs co -r prism-v1r5b1-branch coati_install
cd !$
/usr/local/devel/ANNOTATION/perl/bin/perl Makefile.PL PREFIX=/usr/local/devel/ANNOTATION/cas/branch-test/
make;make install

cd /tmp/cas2
cvs co peffect
cd !$
make;make install
