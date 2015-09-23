#!/bin/tcsh
#  
# job name
# request the nodes and processors 
#PBS -l nodes=1:ppn=16
#
# Name of the queue
#PBS -q default
#
# set the wall time
#PBS -l walltime=00:01:00
#
# export the environment
#PBS -V
#
# Send mail when the job finishes
#PBS -m bea
#PBS -M zjin@stanford.edu
#
# Define standard error file
#PBS -e screen_e.txt
#
#
# set submit qsurb dir as working dir
cd $PBS_O_WORKDIR
#
# execute GPRS
ADGPRS_RATE gprs_flash.in -1 > screenOutFlash.txt
#
# commands
# qsub ./adgprs_qsub.sh
#qstat
#qdel ID
