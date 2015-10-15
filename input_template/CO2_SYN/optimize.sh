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
#PBS -l walltime=02:00:00
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
AD_OPT_RATE opt.in 16 > screenOut.txt
#
# commands
# qsub ./adgprs_qsub.sh
#qstat
#qdel ID
