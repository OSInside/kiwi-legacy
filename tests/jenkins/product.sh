#!/bin/bash
# runner for testing results of buildservice product and image builds
#
# the kiwi XML description can be either a product or image definition
# which results in either a product ISO media containing the RPMs of
# the distribution or a read-to-use appliance according to the
# capabilities of the kiwi appliance builder. To simplify the use
# of this script in jenkins we call all results 'products'
#
# Required:
# --> prepare.sh
# --> product build setup in some buildservice project
#
# Put the following into the shell execution layer at jenkins
#
# /home/jenkins/kiwi/kiwi/tests/jenkins/product.sh \
#     <project> <product> <repo> <arch> [ hop-host ]
#
# project e.g: Virtualization:Appliances
# product e.g: product-netboot
# repo e.g:    images_Factory
# arch e.g:    i586
# hop e.g:     ms@isny.sytes.net
#
project=$1
product=$2
repo=$3
arch=$4
hop=$5
if [ -z "$hop" ];then
  osc rbl $project \
    $product $repo $arch > /tmp/${product}.result
else
  su - jenkins -c \
    "ssh $hop rbl $project $product $repo $arch > /tmp/${product}.result"
fi
if [ ! $? = 0 ];then
  # osc call failed for some reason
  exit 1
fi
cat /tmp/${product}.result
if ! grep -qi "KIWI exited successfully" /tmp/${product}.result;then
  # product build failed for some reason
  exit 1
fi

rm -f /tmp/${product}.result
exit 0
