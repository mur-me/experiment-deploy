#!/bin/bash
set -euo pipefail
source ./common.sh

function usage
{
   ME=$(basename $0)
   MSG=${1:-''}

   if [ -n "$MSG" ]; then
      echo NOTE: $MSG
      echo
   fi

   cat<<EOF

Usage: $ME [Options] ACTION

This script is used to manage resource group, network security group
and vnet in Azure.

The script will be executed in dryrun mode by default.
You need to use -G to request the real execution of the commands.

Options:
   -h             print this help message
   -G             do the real work
   -r region      [MANDATORY] run in region (supported regions: ${REGIONS[@]})
   -g group       number of resource groups (default: $GROUP)
   -s start       the starting prefix of the resource group (default: $START)

   -p profile     the profile of the generated output file (default: $PROFILE)
   -t template    the resource template file (default: $TEMPLATE)
   -v parameter   the parameter file  (default: $PARAMETER)

   -a tag         tag of the resource group (default: $TAG)
   -x prefix      prefix of the subnet (default: $PREFIX)


Action:
   list           list the resources
   init           do deployment to init a region
   terminate      terminate all resources in one region

Examples:
   $ME -r eastus list
   $ME -r eastus deploy
   $ME -r eastus terminate

# the resource group will be named as: hb-rg-{REGION}-{TAG}-{START}{NUM}
Ex:
   hb-rg-eastus-$TAG-${START}1
   hb-rg-eastus-$TAG-${START}2
   hb-rg-eastus-$TAG-${START}3

EOF

   exit 0
}

function valid_arguments
{
   local match=1
   if [ -z "$REGION" ]; then
      return $match
   fi

   for region in "${REGIONS[@]}"; do
      # run on specificed region
      if [ "$region" != "$REGION" ]; then
         continue
      else
         match=0
         break
      fi
   done
 
   return $match
}

function do_init_region
{
   for i in $(seq 1 $GROUP); do
      $DRYRUN ./deploy.sh -i $SUBSCRIPTION -g hb-rg-$REGION-$TAG-${START}$i -n bh-rg-$REGION-deployment -l $REGION -t $TEMPLATE -v $PARAMETER -p start=$START$i
   done
}

function do_terminate_region
{
   echo TODO: remove all the resource groups in the region: $REGION
}

function do_list_resources
{
   echo TODO: list all resource groups in the region: $REGION
}

######################################################

DRYRUN=echo
TS=$(date +%Y%m%d.%H%M%S)
TAG=$(date +%m%d)
REGION=
TEMPLATE=configs/vnet-template.json
PARAMETER=configs/vnet-parameters.json
PREFIX=10.10.0.0/20
PROFILE=benchmark
GROUP=1
START=100

while getopts "hnGr:g:t:v:a:x:p:s:" option; do
   case $option in
      r) REGION=$OPTARG ;;
      G) DRYRUN= ;;
      t) TEMPLATE=$OPTARG ;;
      v) PARAMETER=$OPTARG ;;
      g) GROUP=$OPTARG ;;
      a) TAG=$OPTARG ;;
      x) PREFIX=$OPTARG ;;
      s) START=$OPTARG ;;
      h|?|*) usage "Help Message" ;;
   esac
done


shift $(($OPTIND-1))

ACTION=$@

if ! valid_arguments ; then
   usage "Invalid command line arguments"
fi

if [[ ! -z $ACTION && ! -z $DRYRUN ]]; then
   echo '***********************************'
   echo "Please use -G to do the real work"
   echo '***********************************'
fi

mkdir -p logs

case $ACTION in
   list)
      do_list_resources ;;
   terminate)
      do_terminate_region ;;
   init)
      do_init_region ;;
   *)
      usage "Invalid/missing Action: '$ACTION'" ;;
esac
