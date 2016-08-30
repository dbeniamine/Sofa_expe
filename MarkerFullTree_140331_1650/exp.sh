#!/bin/bash

START_TIME=$(date +%y%m%d_%H%M%S)
CMDLINE="$0 $@"
PREFIX="/home/david/Work/Sofa"
#BUILD
COMPI=true
BUILD_PATH="$PREFIX/SVN/Sofa-build"
SOFA_PATH="$PREFIX/SVN/Sofa"
BUILDS=('seq' 'seq-perfmon' 'openmp' 'openmp-perfmon')
#sofa scenes
SCNDIR="$PREFIX/expe/FlexibleLikwidPerfctr/scn"
SCN=$(\ls $SCNDIR)
#experiment name
EXP_NAME=$(basename $0)
OUTPUT="log"
RUN=30
NB_ITER=1000
#Sofa cmd
CMD="bin/runSofa --gui batch --start --simu tree"
#LIKWID
LIKWID_SETS=('DATA' 'L3' 'L2' 'L2CACHE' 'MEM')
LIKWID_CMD="/home/david/install/likwid/bin/likwid-perfctr"
INIT=false
#Schedtool
SCHED_CMD="schedtool -F -p 1 -e" #Fifo scheduling, with normal priority


function usage
{
    echo "this script must be run as root"
    echo "Usage $0 [options]"
    echo "options :"
    echo "h         Show this output and exit"
    echo "I         Disable the initialisation of likwid"
    echo "o output  Set the name of the outputfile (in EXP_DIR"
    echo "e name    Set the experiment name (used to create the EXP_DIR"
    echo "n nb_iter Set the number of iterations for Sofa"
    echo "r nbrun   Set the number of run for each configurations"
    echo "u user    Chown output to user"
    echo "C         Do not recompile Sofa"
}
#report error if needed
function testAndExitOnError
{
    err=$?
    if [ $err -ne 0 ]
    then
        echo "ERROR $err : $1"
        exit $err
    fi
}
#likwid initialisation
function initlikwid
{
    modprobe msr
    chmod o+rw /dev/cpu/*/msr
    likwid-accessD
    likwid-perfctr -a
    testAndExitOnError "likwid init"
}
function dumpInfos
{

    #Echo start time
    echo "Expe started at $START_TIME" 
    #Echo args
    echo "#### Cmd line args : ###"
    echo "$CMDLINE"
    echo "EXP_NAME $EXP_NAME"
    echo "NB_ITER $NB_ITER"
    echo "OUTPUT: $OUTPUT"
    echo "RUN $RUN"
    echo "No likwid init ? $INIT"
    echo "Owner of the outputs : $OUTPUT_USER"
    echo "########################"
    # DUMP environement important stuff
    echo "#### Hostname: #########"
    hostname
    echo "########################"
    cd $SOFA_PATH
    echo "##### git log: #########"
    pwd
    git log | head
    echo "########################"
    echo "#### git diff: #########"
    git diff
    echo "########################"
    cd -
    echo "#### likwid-topology: ##"
    #topology
    likwid-topology  -c
    cat /proc/cpuinfo 

    echo "########################"


    #DUMPING scripts
    cp -v $0 $EXP_DIR/
    cp -v ./*.sh $EXP_DIR/
    cp -v *.pl $EXP_DIR/ 
    cp -v *.rmd  $EXP_DIR/
}
#parsing args
while getopts "ChIo:e:n:r:u:" opt 
do
    case $opt in
        h)
            usage
            exit 0
            ;;
        I)
            INIT=true
            ;;
        e)
            EXP_NAME=$OPTARG
            ;;
        n)
            NB_ITER=$OPTARG
            ;;
        o)
            OUTPUT=$OPTARG
            ;;
        r)
            RUN=$OPTARG
            ;;
        u)
            OUTPUT_USER="$OPTARG"
            ;;
        C)
            COMPI=false
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done
if [ "$UID"  -ne 0 ]
then
    echo "THIS SCRIPT MUST BE RUN AS ROOT !"
    exit 1
fi

#post init
EXP_DIR="$EXP_NAME"_$(date +%y%m%d_%H%M) 
mkdir $EXP_DIR
ITER="--nb_iterations $NB_ITER"
OUTPUT="$EXP_DIR/$OUTPUT"

#Continue but change the OUTPUT
exec > >(tee $OUTPUT) 2>&1
dumpInfos


#Initializations
if ! $INIT
then
    echo "Initializating likwid"
    initlikwid
fi

#Compiling
if $COMPI
then
    cd $BUILD_PATH
    make cmake
    make
    testAndExitOnError "Compiling from $BUILD_PATH"
    cd -
fi


for run in $(seq 1 $RUN)
do 
    echo "RUN : $run"
    for scene in ${SCN[@]} 
    do
        echo "SCN : $scene"
        scn_file=$SCNDIR/$scene
        for Set in ${LIKWID_SETS[@]}
        do
            echo "SET : $Set"
            LIKWID_ARG="-O -g $Set"
            #Actual exp
            for dir in ${BUILDS[@]}
            do
                echo "DIR : $dir"
                mkdir -p $EXP_DIR/$scene/$Set/$dir
                #Likwid Settings
                ##marker
                marker=$(echo $dir | grep -i perfmon)
                if [  -z "$marker" ]
                then
                    LIKWID_Marker=""
                else
                    LIKWID_Marker="-m"
                fi
                ##openmp
                openmp=$(echo $dir | grep -i "openmp")
                if [ -z "$openmp" ]
                then
                    LIKWID_PROC="-C 0"
                else
                    LIKWID_PROC="-C 0-3"
                fi
                #Actual experiment
                EXECCMD="$SCHED_CMD $LIKWID_CMD $LIKWID_ARG $LIKWID_Marker  \
                    $LIKWID_PROC $BUILD_PATH/$dir/$CMD $ITER $scn_file"
                echo "$EXECCMD"
                $EXECCMD > $EXP_DIR/$scene/$Set/$dir/run$run
                testAndExitOnError "run number $run"
            done
        done
    done
done

if [ ! -z "$OUTPUT_USER" ]
then
    chown -R "$OUTPUT_USER":"$OUTPUT_USER" $EXP_DIR 
fi
cd $EXP_DIR/
./parseAndPlot.sh
cd -
#Echo thermal throttle info
echo "thermal_throttle infos :"
cat /sys/devices/system/cpu/cpu0/thermal_throttle/*
END_TIME=$(date +%y%m%d_%H%M%S)
echo "Expe ended at $END_TIME"

