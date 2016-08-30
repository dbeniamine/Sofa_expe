#!/bin/bash

sudo modprobe msr
sudo chmod o+rw /dev/cpu/*/msr
/home/david/install/likwid/bin/likwid-accessD
/home/david/install/likwid/bin/likwid-perfctr -a
if [ $? -ne 0 ]
then
    echo "error during likwid init"
fi
