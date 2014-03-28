#!/bin/bash
# runner for testing results of buildservice product builds
#
# Required:
# --> prepare.sh
# --> product build setup in OBS:Virtualization:Appliances
#
# Put the following into the shell execution layer at jenkins
#
# /home/jenkins/kiwi/kiwi/tests/jenkins/product.sh <product> <repo> <arch>
#
# possible product: product-netboot | product-addon
# possible repo: images_Factory
# possible arch: i586
#
product=$1
repo=$2
arch=$3
osc rbl Virtualization:Appliances \
	$product $repo $arch > /tmp/${product}.result
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
