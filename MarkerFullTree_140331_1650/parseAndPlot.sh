#!/bin/bash
echo "Creating plots directories"
#for d in $(\ls -d *.scn)
#do
#    mkdir -vp $d/plots
#done
 echo "removing old csv files"
 find . -name *.csv | xargs rm -v
 echo "parsing log to create csv files"
 ./csv_extractor.pl
echo "creating plots"
Rscript -e 'require(knitr); knit2html("analyse.rmd")'
