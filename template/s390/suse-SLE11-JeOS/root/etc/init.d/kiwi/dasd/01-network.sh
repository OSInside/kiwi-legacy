#!/bin/bash
# s390 network hardware setup
# ----
#======================================
# Functions...
#--------------------------------------
. /include

qeth_port=VSWL2
qeth_read=0.0.0800
qeth_write=0.0.0801
qeth_ctrl=0.0.0802
qeth_up=1

#======================================
# Include kernel parameters
#--------------------------------------
includeKernelParameters

#======================================
# Bring the device online
#--------------------------------------
qeth_configure -p $qeth_port -l $qeth_read $qeth_write $qeth_ctrl $qeth_up

