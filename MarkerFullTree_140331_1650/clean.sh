#!/bin/bash
read -p "Warning: this script will automatically remove all generated files
(exept experiments files), do you want to continue y/[n]" ans
if [ "$ans" != "y" ]
then
    echo "aborting"
    exit 1
fi
find . -name *.csv | xargs rm -v
rm -rv figure
rm -v analyse.md analyse.html

