#!/bin/sh
sed -i "s@^k8s_dir.*@k8s_dir=`pwd`@" ./options.conf

. ./options.conf
. ./env.sh
. ./custom.sh
. ./ca/init.sh
. ./kubectl/init.sh
. ./flannel/init.sh
. ./docker/init.sh
. ./node/init.sh

