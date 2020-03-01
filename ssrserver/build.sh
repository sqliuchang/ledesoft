#!/bin/sh

MODULE=ssrserver
VERSION=0.4
TITLE="SSR Server"
DESCRIPTION=科学上网服务器
HOME_URL=Module_ssrserver.asp
CHANGELOG="开源加密脚本;init脚本提供stop选项;优化安装环境检测"

# Check and include base
DIR="$( cd "$( dirname "$BASH_SOURCE[0]" )" && pwd )"

# now include build_base.sh
. $DIR/../softcenter/build_base.sh

# change to module directory
cd $DIR

# build bin
sh $DIR/build/build ssrserver

# do something here

do_build_result

sh backup.sh $MODULE
