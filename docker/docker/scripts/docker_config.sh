#!/bin/sh
export KSROOT=/koolshare
source $KSROOT/scripts/base.sh
eval `dbus export docker_`
alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/docker_log.txt

check_version(){
	local fwlocal checkversion
	fwlocal=`cat /etc/openwrt_release|grep DISTRIB_RELEASE|cut -d "'" -f 2|cut -d "V" -f 2`
	checkversion=`versioncmp $fwlocal 2.26`
	[ "$checkversion" == "1" ] && {
		echo_date "不符合启动条件，请升级到2.26或以后的版"
		dbus set docker_basic_enable="0"
		echo XU6J03M6
		http_response "233"
		exit 0
	}
}

check_sysctl(){
	local nf_bridge
	nf_bridge=`sysctl net.bridge.bridge-nf-call-iptables |cut -d "=" -f2`
	[ "$nf_bridge" == "1" ] || {
		echo_date "配置内核参数"
		sysctl -w net.bridge.bridge-nf-call-ip6tables=1 >/dev/null 2>&1
		sysctl -w net.bridge.bridge-nf-call-iptables=1 >/dev/null 2>&1
	}
}

install_run_system(){
	mkdir -p "$docker_basic_disk/docker"
	mkdir -p "$docker_basic_disk/docker/data"
	mkdir -p "$docker_basic_disk/docker/config"
	echo_date "开始下载运行环境"
	wget --no-check-certificate --timeout=8 --tries=2 -O - https://download.docker.com/linux/static/stable/x86_64/docker-18.09.1.tgz > /tmp/upload/docker.tgz
	if [ "$?" -eq 0 ] ; then
		tar zxf /tmp/upload/docker.tgz -C "$docker_basic_disk/docker"
		mv $docker_basic_disk/docker/docker $docker_basic_disk/docker/bin
		chmod a+x $docker_basic_disk/docker/bin/*
		rm -rf /tmp/upload/docker.tgz
		if [ -x "$docker_basic_disk/docker/bin/docker" -a -x "$docker_basic_disk/docker/bin/dockerd" ]; then
			echo_date "运行环境已安装成功，检测通过"
		else
			echo_date "运行环境安装失败，安装盘可能空间不够！"		
			echo XU6J03M6 >> $LOGFILE
			exit 0
		fi
	else
		echo_date "安装运行环境失败，你的网络可能有问题，请重试！"
		rm -rf /tmp/upload/docker.tgz
		echo XU6J03M6 >> $LOGFILE
		exit 0
	fi
}

set_registry(){
	echo_date "配置镜像源地址"
	[ -d "$docker_basic_disk/docker/config" ] || mkdir -p $docker_basic_disk/docker/config
	cat > $docker_basic_disk/docker/config/daemon.json <<-EOF
		{ 
			"registry-mirrors": ["$docker_basic_url"] 
		}
	EOF
}

start_process(){
	echo_date "开始运行进程"
	export PATH=$KSROOT/bin:$KSROOT/scripts:/usr/bin:/sbin:/bin:/usr/sbin:$docker_basic_disk/docker/bin
	dockerd --config-file="$docker_basic_disk/docker/config/daemon.json" \
			--data-root="$docker_basic_disk/docker/data" \
			--exec-root="$docker_basic_disk/docker/data/run" \
			--dns="223.5.5.5" \
			--dns="114.114.114.114" \
			--iptables=true \
			--ip-masq=true \
			--selinux-enabled=false \
			--ip-forward=true \
			--ip="0.0.0.0" \
			--group root & \ 
			>/dev/null 2>&1
}

stop_process(){
	echo_date "关闭服务进程"
	killall dockerd >/dev/null 2>&1
}

check_run_system(){
	echo_date "开始检查安装目录配置"
	if [ -d "$docker_basic_disk" ]; then
		echo_date "配置的安装目录已找到，开始检查运行环境"
		if [ -d "$docker_basic_disk/docker/bin" -a -x "$docker_basic_disk/docker/bin/dockerd" ]; then
			echo_date "运行环境已经安装就绪！"
		else
			echo_date "运行环境未初始化，准备安装"
			install_run_system
		fi
	else
		echo_date "配置的安装目录$docker_basic_disk未找到，请检查配置"
		echo XU6J03M6 >> $LOGFILE
		exit 0
	fi
}

check_profile(){
	echo_date "开始检查环境变量配置"
	if [ -d "/etc/profile.d" -a -f "/etc/profile.d/docker.sh" ]; then
		echo_date "环境变量已配置"
	else
		echo_date "正在配置环境变量"
		mkdir -p /etc/profile.d
		echo "export PATH=$KSROOT/bin:$KSROOT/scripts:/usr/bin:/sbin:/bin:/usr/sbin:$docker_basic_disk/docker/bin" > /etc/profile.d/docker.sh
		echo_date "环境变量已配置"
	fi
}

clean_profile(){
	echo_date "清理环境变量配置"
	rm /etc/profile.d/docker.sh	
}

run_cmd(){
	local RUNCMD
	RUNCMD=$(echo "$1" | base64_decode)
	echo_date "运行自定义命令：$RUNCMD"
	echo_date ========================================================================
	export PATH=$KSROOT/bin:$KSROOT/scripts:/usr/bin:/sbin:/bin:/usr/sbin:$docker_basic_disk/docker/bin
	$RUNCMD
	echo_date
	echo_date ========================================================================
}

download_image(){
	echo_date ========================================================================
	export PATH=$KSROOT/bin:$KSROOT/scripts:/usr/bin:/sbin:/bin:/usr/sbin:$docker_basic_disk/docker/bin
	echo_date 开始下载镜像
	docker pull "$1"
	if [ "$?" == "0" ];then
		echo_date "镜像下载成功！"
		echo_date "本页面将在5s后刷新，请稍候进入映像标签页查看你的镜像"
	else
		echo_date "镜像下载失败，错误代码：$? ！"
	fi
}

rm_image(){
	echo_date ========================================================================
	export PATH=$KSROOT/bin:$KSROOT/scripts:/usr/bin:/sbin:/bin:/usr/sbin:$docker_basic_disk/docker/bin
	echo_date 删除本地镜像：$1
	docker image rm $1 >/dev/null 2>&1
	if [ "$?" -eq 0 ] ; then
		echo_date 删除成功！	
	else
		echo_date 删除失败，存在关联的容器！	
	fi
}

clean_dbus(){
	echo_date 清理$1数据
	local seach_values value
	seach_values=`dbus list docker_$1_|cut -d "=" -f1`
	for value in $seach_values
	do
		dbus remove $value
	done
}

rm_container(){
	stop_container $1
	echo_date ========================================================================
	export PATH=$KSROOT/bin:$KSROOT/scripts:/usr/bin:/sbin:/bin:/usr/sbin:$docker_basic_disk/docker/bin
	echo_date 删除已创建的容器：$1
	docker container rm $1 >/dev/null 2>&1
	if [ "$?" -eq 0 ] ; then
		echo_date 删除成功！
		[ -z "$2" ] && clean_dbus $1
	else
		echo_date 删除失败！	
	fi
}

stop_container(){
	export PATH=$KSROOT/bin:$KSROOT/scripts:/usr/bin:/sbin:/bin:/usr/sbin:$docker_basic_disk/docker/bin
	local RUNCONTAINER
	RUNCONTAINER=`docker ps|grep -v grep|grep $1`
	echo_date ========================================================================
	if [ -n "$RUNCONTAINER" ]; then	
		echo_date 关闭正在运行的容器：$1
		docker container stop $1 >/dev/null 2>&1
		if [ "$?" -eq 0 ] ; then
			echo_date 关闭成功！
		else
			echo_date 关闭失败！
		fi
	else
		echo_date $1没有运行！
	fi
}

start_container(){
	export PATH=$KSROOT/bin:$KSROOT/scripts:/usr/bin:/sbin:/bin:/usr/sbin:$docker_basic_disk/docker/bin
	local RUNCONTAINER
	RUNCONTAINER=`docker ps|grep -v grep|grep $1`
	echo_date ========================================================================
	if [ -z "$RUNCONTAINER" ]; then	
		echo_date 启动容器：$1
		docker container start $1 >/dev/null 2>&1
		if [ "$?" -eq 0 ] ; then
			echo_date 启动成功！
		else
			echo_date 启动失败！
		fi
	else
		echo_date $1正在运行！
	fi
}

get_autoboot() {
	case "$1" in
		0)
			echo ""
		;;
		1)
			echo "--restart=always"
		;;
	esac
}

create_container(){
	export PATH=$KSROOT/bin:$KSROOT/scripts:/usr/bin:/sbin:/bin:/usr/sbin:$docker_basic_disk/docker/bin
	local RUNCOMM dbusauto dbusimage dbusther
	dbusimage=$(dbus get "docker_$1_image")
	dbusauto=$(dbus get "docker_$1_auto")
	dbusther=$(dbus get "docker_$1_other"|base64_decode|grep -v '^\s*$')
	echo_date ========================================================================
	echo_date 创建容器名称：$1
	RUNCOMM="docker run -d --name $1 $dbusther $(get_autoboot $dbusauto) $dbusimage"
	echo_date $RUNCOMM
	$RUNCOMM >/dev/null 2>&1
	if [ "$?" -eq 0 ] ; then
		echo_date 创建成功！
	else
		echo_date 创建失败！
	fi
}

edit_container(){
	export PATH=$KSROOT/bin:$KSROOT/scripts:/usr/bin:/sbin:/bin:/usr/sbin:$docker_basic_disk/docker/bin
	local RUNCOMM dbusimage dbusauto dbusther
	#dbusnet=$(dbus get "docker_$1_net")
	dbusimage=$(dbus get "docker_$1_image")
	dbusauto=$(dbus get "docker_$1_auto")
	#dbusfile=$(dbus get "docker_$1_file"|base64_decode|grep -v '^\s*$'|sed 's/^/ -v &/g'|xargs)
	#if [ "$dbusnet" == "bridge" ]; then
	#	dbusport=$(dbus get "docker_$1_port"|base64_decode|grep -v '^\s*$'|sed 's/^/ -p &/g'|xargs)
	#else
	#	dbusport=""
	#fi
	#dbusenv=$(dbus get "docker_$1_env"|base64_decode|grep -v '^\s*$'|sed 's/^/ -e &/g'|xargs)
	#[ -n "$dbusenv" ] && dbusenv="-e $dbusenv"
	dbusther=$(dbus get "docker_$1_other"|base64_decode|grep -v '^\s*$')
	echo_date ========================================================================
	echo_date 修改容器名称：$1 的配置参数
	stop_container $1
	rm_container $1 0
	RUNCOMM="docker run -d --name $1 $dbusther $(get_autoboot $dbusauto) $dbusimage"
	echo_date $RUNCOMM
	$RUNCOMM >/dev/null 2>&1
	if [ "$?" -eq 0 ] ; then
		echo_date 修改成功！
	else
		echo_date 修改失败！
	fi
}

login_docker_hub(){
	[ "docker_basic_login" == "1" ] && {
		export PATH=$KSROOT/bin:$KSROOT/scripts:/usr/bin:/sbin:/bin:/usr/sbin:$docker_basic_disk/docker/bin
		echo_date "配置登陆到Docker Hub"
		if [ -f "/root/.docker/config.json" ]; then
			echo_date "你已经登陆到Docker Hub，需要更改账号请先手动删除/root/.docker/config.json"
		else
			docker login <<-EOF
			$docker_basic_user
			$docker_basic_passwd
			EOF
			if [ "$?" -eq 0 ] ; then
				echo_date 登陆成功！
			else
				echo_date 登陆失败，请检查账号设置！
			fi
		fi
	}
}

get_images_info(){
	local images_info
	export PATH=$KSROOT/bin:$KSROOT/scripts:/usr/bin:/sbin:/bin:/usr/sbin:$docker_basic_disk/docker/bin
	images_info=`docker images --format "<{{.Repository}}>{{.Tag}}>{{.Size}}"|sed ':a;N;$!ba;s/\n//g'|base64_encode`
	echo "$images_info"
}

get_container_info(){
	local container_info
	export PATH=$KSROOT/bin:$KSROOT/scripts:/usr/bin:/sbin:/bin:/usr/sbin:$docker_basic_disk/docker/bin
	container_info=`docker ps -a --format "<{{.Names}}>{{.Image}}>{{.Status}}"|sed ':a;N;$!ba;s/\n//g'|base64_encode`
	echo "$container_info"
}

creat_start_up(){
	[ ! -L "/etc/rc.d/S99docker.sh" ] && ln -sf $KSROOT/init.d/S99docker.sh /etc/rc.d/S99docker.sh
}

start_docker(){
	check_version
	check_run_system
	set_registry
	check_sysctl
	start_process
	check_profile
	creat_start_up
	login_docker_hub
}

restart_docker(){
	stop_docker
	while [ `pidof dockerd` ]; do
		sleep 1
	done
	start_docker
	echo_date ============================ docker 启动完毕 ============================
}

stop_docker(){
	echo_date ========================================================================
	stop_process
	[ "$docker_basic_enable" == "1" ] || clean_profile
}

# used by rc.d
case $1 in
start)
		restart_docker
	;;
stop)
	stop_docker
	echo_date ============================ docker 成功关闭 ============================
	;;
clean)
	clean_dbus
	echo_date ============================ docker ql ============================
	;;
*)
	[ -z "$2" ] && restart_docker
	;;
esac

# used by httpdb
case $2 in
1)
	if [ "$docker_basic_enable" == "1" ];then
		restart_docker > $LOG_FILE
	else
		stop_docker > $LOG_FILE
		echo_date ============================ docker 成功关闭 ============================
	fi
	echo XU6J03M6 >> $LOG_FILE
	http_response $1
	;;
2)
	# search image
	export PATH=$KSROOT/bin:$KSROOT/scripts:/usr/bin:/sbin:/bin:/usr/sbin:$docker_basic_disk/docker/bin
	search_info=`docker search --no-trunc --format "<{{.Name}}>{{.Description}}>{{.StarCount}}" "$docker_basic_seach"|sed ':a;N;$!ba;s/\n//g'|base64_encode`
	if [ -n "$search_info" ];then
		http_response "$search_info"
	else
		http_response "0"
	fi
	;;
3)
	# run cmd
	run_cmd $docker_basic_cmd > $LOG_FILE
	echo_date 运行完成！ >> $LOG_FILE
	echo XU6J03M6 >> $LOG_FILE
	http_response $1
	;;
4)
	# download imge	
	download_image $docker_table_send > $LOG_FILE 2>&1
	echo XU6J03M6 >> $LOG_FILE
	http_response $1
	;;
5)
	# 创建容器
	create_container $docker_table_send > $LOG_FILE
	echo XU6J03M6 >> $LOG_FILE
	http_response $1
	;;
6)
	# 删除映像
	rm_image $docker_table_send > $LOG_FILE
	echo XU6J03M6 >> $LOG_FILE
	http_response $1
	;;
7)
	# 启动容器
	start_container $docker_table_send > $LOG_FILE
	echo XU6J03M6 >> $LOG_FILE
	http_response $1
	;;
8)
	# 停止容器
	stop_container $docker_table_send > $LOG_FILE
	echo XU6J03M6 >> $LOG_FILE
	http_response $1
	;;
9)
	# 删除容器
	rm_container $docker_table_send > $LOG_FILE
	echo XU6J03M6 >> $LOG_FILE
	http_response $1
	;;
10)
	# 修改容器
	edit_container $docker_table_send > $LOG_FILE
	echo XU6J03M6 >> $LOG_FILE
	http_response $1
	;;
11)
	# get table status
	images_status=`get_images_info`
	if [ -n "$images_status" ];then
		http_response "$images_status"
	else
		http_response "0"
	fi
	;;
12)
	# get table status
	container_status=`get_container_info`
	if [ -n "$container_status" ];then
		http_response "$container_status"
	else
		http_response "0"
	fi
	;;
esac
