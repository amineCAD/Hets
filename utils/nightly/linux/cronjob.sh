#!/bin/bash -x

PATH=/bin:/usr/bin:/usr/X11R6/bin:/home/linux-bkb/bin
UDG_HOME=/home/linux-bkb/uDrawGraph-3.1
MAKE=make
HETS_LIB=/local/home/maeder/haskell/CASL-lib

export PATH
export MAKE
export HETS_LIB

hetsdir=/home/www/agbkb/forschung/formal_methods/CoFI/hets
destdir=$hetsdir/src-distribution/daily

cd /local/home/maeder/haskell
. ../cronjob.sh

makeHets
makeLibCheck

# install hets binary
cd CASL-lib
chmod 775 hets
chgrp wwwbkb hets
bzip2 -k hets
\cp -fp hets.bz2 $hetsdir/linux/daily/
chgrp linuxbkb hets
\cp -fp hets /home/linux-bkb/bin/

# copy matching version for hets.cgi
\cp -f ../HetCATS/utils/hetcasl.sty /home/www/cofi/hets-tmp/

# make latex documentation
\cp ../HetCATS/utils/hetcasl.sty .
pdflatex Basic-Libraries

# create some result files
cat */*.th > ../th.log
cat */*.pp.het > ../pp.log

cd Basic
/local/home/maeder/haskell/runisabelle.sh *.thy > ../../isa.log 2>&1
fgrep \*\*\* ../../isa.log
cd ..

/local/home/maeder/haskell/runSPASS.sh Basic/*.dfg > ../spass.log 2>&1

./hets -v2 -o thy Calculi/Time/AllenHayesLadkin_TACAS.het
cd Calculi/Time
/local/home/maeder/haskell/runisabelle.sh *.thy > ../../../isaHC.log 2>&1
fgrep \*\*\* ../../../isaHC.log
cd ../..

./hets -v2 -o thy Calculi/Space/RCCDagstuhl2.het
cd Calculi/Space
/local/home/maeder/haskell/runisabelle.sh *.thy > ../../../isaHC2.log 2>&1
fgrep \*\*\* ../../../isaHC2.log
cd ../..

# try out other binaries
../HetCATS/Syntax/hetpa Basic/LinearAlgebra_II.casl

../HetCATS/Common/ATerm/ATermLibTest Basic/*.env
diff Basic/LinearAlgebra_II.env Basic/LinearAlgebra_II.env.ttttt

time ../HetCATS/Common/ATerm/ATermDiffMain Basic/LinearAlgebra_II.env \
    Basic/LinearAlgebra_II.env.ttttt

cats -input=nobin -output=nobin -spec=gen_aterm Basic/SimpleDatatypes.casl
../HetCATS/ATC/ATCTest Basic/SimpleDatatypes.tree.gen_trm
./hets -v3 -p -i gen_trm -o pp.het Basic/SimpleDatatypes.tree.gen_trm

# build user guide
cd ../HetCATS/doc
pdflatex UserGuide
bibtex UserGuide
pdflatex UserGuide
pdflatex UserGuide
cd ..

# move docs and release sources to destination
make doc
\cp doc/UserGuide.pdf docs
\cp doc/Programming-Guidelines.txt docs
\cp ../CASL-lib/Basic-Libraries.pdf docs
chgrp -R wwwbkb docs
\cp -rfp docs $destdir
gzip HetCATS.tar
chmod 664 HetCATS.tar.gz
chgrp wwwbkb HetCATS.tar.gz
\cp -fp HetCATS.tar.gz $destdir

# more tests in HetCATS
Common/test_parser -p casl_id2 Common/test/MixIds.casl
Haskell/hana ToHaskell/test/*.hascasl.hs
cd Haskell/test/HOLCF
cp ../HOL/*.hs .
../../../Haskell/h2hf hc *.hs
/local/home/maeder/haskell/runHsIsabelle.sh *.thy > ../../../../isaHs.log 2>&1
fgrep \*\*\* ../../../../isaHs.log

# build and install locally hets.cgi
cd ../../../HetCATS
make hets.cgi
\cp hets.cgi /home/www/users/maeder/cgi-bin
cd ..

# pack CASL-lib for cofi at fixed location
cd ../../cofi-libs/CASL-lib
cvs up -dPA
cd ..
tar czvf lib.tgz -C CASL-lib --exclude=CVS --exclude=.cvsignore \
    --exclude=diplom_dw .
chmod 664 lib.tgz
chgrp agcofi lib.tgz
\cp -fp lib.tgz /home/www/cofi/Libraries/daily/

# repack putting docs into sources on www server
cd $destdir
\rm -rf HetCATS
tar zxf HetCATS.tar.gz
\mv docs HetCATS/docs
\rm -f HetCATS.tar.gz
tar zcf Hets-src.tgz HetCATS

# a few more tests
cd $HETS_LIB
date
for i in Basic/*.env; \
   do ./hets -v2 -o prf $i; done
date
for i in */*.prf; do ./hets -v2 -o th $i; done
date

# check out CASL-lib in /home/cofi/CASL-lib for hets.cgi
cd /home/cofi/CASL-lib
cvs -d :pserver:cvsread@cvs-agbkb.informatik.uni-bremen.de:/repository up -dPA
