#!/bin/bash
METRICS=('bandwidth' 'Memory BW' 'data volume')
FUNCTIONS=('applyDJT')
SCNDIRS=('linearRigidandAffineFrame.scn' 'linearQuadraticFrame.scn')
declare -A METRICS_NAME
# Escape / for sed
METRICS_NAME=([bandwidth]='Bandwidth (MBytes\/s)' [Memory BW]='Bandwidth (MBytes\/s)' \
    [data volume]='Data volume (GBytes)')

OFS=$IFS
IFS=$'\n'
echo "Function,Scene,Metric,Type,Level,Run,Value" > results.csv
for dir in ${SCNDIRS[@]}
do
    for fct in ${FUNCTIONS[@]}
    do
        for metric in ${METRICS[@]}
        do
            # Grep results have the following form:
            #   dir/Level/type-perfmon/runXX.Metric.csv:contents
            #   Contents:
            #     seq-perfmon,Config,Expe,Metric,Value
            #       or
            #     openmp-perfmon,Config,Expe,Metric,Sum,Max,Min,Avg
            # In all case, value is the last value
            # Units:
            #   Volume: GBytes
            #   BW: MBytes/s
            #   bandwidth: MBytes/s
            name=${METRICS_NAME[$metric]}
            grep $metric -Rn $dir/*/*/*.Metric.csv | grep $fct | sed -e \
                "s/$dir\/\(.*\)\/\(.*\)-perfmon\/run\([^\.]*\)\..*:.*-perfmon,\([^,]*\),[^,]*,\([^,]*\).*$/\4,$dir,$name,\2,\1,\3,\5/" \
                | sed -e 's/seq/sequential/' -e 's/\.scn//'  >> results.csv
        done
    done
done
IFS=$OFS
