#!/bin/bash
# this script is used to create/deploy soliders on aws/azure

set -euo pipefail

function usage
{
   ME=$(basename $0)
   cat<<EOF
Usage: $ME [OPTIONS] ACTION

This script is used to create/deploy soliders on cloud providers.
Supported cloud providers: aws,azure

OPTIONS:
   -h             print this help message
   -n             dryrun mode
   -c instances   number of instances in 8 AWS regions (default: $AWS_VM)
   -C instances   number of instances in 3 Azure regions (default: $AZ_VM)
   -s shards      number of shards (default: $SHARD_NUM)
   -t clients     number of clients (default: $CLIENT_NUM)
   -p profile     aws profile (default: $PROFILE)
   -f ip_file     file containing ip address of pre-launched VMs

ACTION:
   n/a

EXAMPLES:
   $ME -c 100 -C 100 -s 10 -t 1

   $ME -c 100 -s 10 -t 1 -f azure/configs/raw_ip.txt

EOF
   exit 1
}

AWS_VM=2
AZ_VM=0
SHARD_NUM=2
CLIENT_NUM=1
SLEEP_TIME=10
PROFILE=harmony
IP_FILE=
ROOTDIR=$(dirname $0)/..
TS=$(date +%Y%m%d.%H%M%S)

while getopts "hnc:C:s:t:p:f:" option; do
   case $option in
      n) DRYRUN=--dry-run ;;
      c) AWS_VM=$OPTARG ;;
      C) AZ_VM=$OPTARG ;;
      s) SHARD_NUM=$OPTARG ;;
      t) CLIENT_NUM=$OPTARG ;;
      p) PROFILE=$OPTARG ;;
      f) IP_FILE=$OPTARG ;;
      h|?|*) usage ;;
   esac
done

shift $(($OPTIND-1))

ACTION=$@

function launch_vms
{
   MAX_VM_PER_DEPLOY=200
   if [ $AZ_VM -gt 0 ]; then
   (
      if [ $AZ_VM -gt $MAX_VM_PER_DEPLOY ]; then
         VG_GROUP=$(( $AZ_VM / $MAX_VM_PER_DEPLOY ))
         reminder=$(( $AZ_VM % $MAX_VM_PER_DEPLOY ))
         if [ $reminder -gt 1 ]; then
            VG_GROUP=$(( $VG_GROUP + 1 ))
         fi
      else
         VG_GROUP=1
      fi
      echo "$(date) Creating $VG_GROUP resource groups at 3 Azure regions"
      pushd $ROOTDIR/azure
      ./go-az.sh -g $VG_GROUP init

      echo "$(date) Creating $AZ_VM instances at 3 Azure regions"
      ./go-az.sh -g $VG_GROUP launch $AZ_VM
      popd
   ) &
   fi

   echo "$(date) Creating $AWS_VM instances at 8 AWS regions"
   ./create_solider_instances.py --profile ${PROFILE}-ec2 --regions 1,2,3,4,5,6,7,8 --instances $AWS_VM,$AWS_VM,$AWS_VM,$AWS_VM,$AWS_VM,$AWS_VM,$AWS_VM,$AWS_VM

   # wait for the background task to finish
   wait
   cp $ROOTDIR/azure/configs/benchmark.rg.* logs/$TS

   echo "Sleep for $SLEEP_TIME seconds"
   sleep $SLEEP_TIME
}

function collect_ip
{
   if [ $AZ_VM -gt 0 ]; then
   (
      echo "Collecting IP addresses from Azure"
      pushd $ROOTDIR/azure
      ./go-az.sh listip
      popd
   ) &
   fi

   echo "Collecting IP addresses from AWS"
   ./collect_public_ips.py --profile ${PROFILE}-ec2 --instance_output instance_output.txt

   wait
}

function generate_distribution
{
   if [[ $AZ_VM -gt 0 && -f $ROOTDIR/azure/configs/raw_ip.txt ]]; then
      echo "Merge raw_ip.txt from Azure"
      cat $ROOTDIR/azure/configs/raw_ip.txt >> raw_ip.txt
   fi

   if [  -f "$IP_FILE" ]; then
      echo "Merge pre-launched IP address"
      cat $IP_FILE >> raw_ip.txt
   fi

   grep -vE '^ node' raw_ip.txt > raw_ip.good.txt
   mv -f raw_ip.good.txt raw_ip.txt

   cp raw_ip.txt logs/$TS
   cp $ROOTDIR/azure/configs/*.ips logs/$TS

   echo "Generate distribution_config"
   ./generate_distribution_config.py --ip_list_file raw_ip.txt --shard_number $SHARD_NUM --client_number $CLIENT_NUM

   cp distribution_config.txt logs/$TS
}

function prepare_commander
{
   echo "Run commander prepare"
   ./commander_prepare.py --ts $TS
}

function upload_to_s3
{
   aws --profile ${PROFILE}-s3 s3 cp distribution_config.txt s3://unique-bucket-bin/distribution_config.txt --acl public-read-write
   aws --profile ${PROFILE}-s3 s3 sync logs s3://harmony-benchmark/logs
}

####### main #########
mkdir -p logs/$TS
date
launch_vms
date
collect_ip
date
generate_distribution
date
prepare_commander
date
upload_to_s3
date
