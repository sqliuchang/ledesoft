#!/bin/sh

source /koolshare/scripts/base.sh
eval `dbus export ssrserver_`
alias echo_date='echo $(date +%Y年%m月%d日\ %X)'
LOGFILE="/tmp/upload/ssrserver_log.txt"
lockfile=/tmp/ssrserver.locker
CONFIG_FILE=/var/etc/ssr_server.json
PID_FILE=/var/run/ssr_server.pid

check_run_system(){
	echo_date "开始检测固件内ShadowsocksRR支持环境"
	echo_date "====================================================="
	local hbipk ipknum
	ipknum="1"
	hbipk="shadowsocksRR-server"
	for hbipk in $hbipk
	do
		if [ -z "`opkg list-installed | grep $hbipk`" ]; then
			echo_date "安装支持环境-$ipknum"
			wget --no-check-certificate --timeout=8 --tries=2 -O - https://lede-opkg.koolcenter.com/opkg/$hbipk.ipk > /tmp/upload/$hbipk.ipk
			if [ "$?" -eq 0 ] ; then
				opkg install /tmp/upload/$hbipk.ipk >/dev/null 2>&1
				rm -rf /tmp/upload/$hbipk.ipk
				echo_date "支持环境-$ipknum已安装，检测通过"
			else
				echo_date "安装支持环境-$ipknum失败，你的网络可能有问题，请重试！"
				rm -rf /tmp/ssrserver.locker
				echo XU6J03M6 >> $LOGFILE
				exit 0
			fi
		else
			echo_date "支持环境-$ipknum已安装，检测通过"		
		fi
	ipknum=`expr $ipknum + 1`
	done
}

get_fast_switch(){
	case "$1" in
		0)
			echo "false"
		;;
		1)
			echo "true"
		;;
	esac
}

gen_config_file() {
cat <<-EOF >$CONFIG_FILE
{
	"server": "0.0.0.0",
	"server_port": $ssrserver_port,
	"local_address":"127.0.0.1",
	"local_port":1984,
	"password": "$ssrserver_passwd",
	"timeout": $ssrserver_timeout,
	"method": "$ssrserver_encrypt",
	"protocol": "$ssrserver_protocol",
	"protocol_param": "$ssrserver_protocol_param",
	"obfs": "$ssrserver_obfs",
	"obfs_param": "$ssrserver_obfs_param",
	"redirect": "$ssrserver_redirect",
	"fast_open": "$(get_fast_switch $ssrserver_tcp)"
}
EOF
}

open_port(){
	echo_date "打开防火墙端口"
	iptables -I zone_wan_input 2 -p tcp -m tcp --dport $ssrserver_port -m comment --comment "softcenter: ssrserver" -j ACCEPT >/dev/null 2>&1
	iptables -I zone_wan_input 2 -p udp -m udp --dport $ssrserver_port -m comment --comment "softcenter: ssrserver" -j ACCEPT >/dev/null 2>&1
}

close_port(){
	echo_date "关闭防火墙端口"
	iptables -D zone_wan_input -p tcp -m tcp --dport $ssrserver_port -m comment --comment "softcenter: ssrserver" -j ACCEPT >/dev/null 2>&1
	iptables -D zone_wan_input -p udp -m udp --dport $ssrserver_port -m comment --comment "softcenter: ssrserver" -j ACCEPT >/dev/null 2>&1
}

write_nat_start(){
	echo_date 添加防火墙重启触发事件
	uci -q batch <<-EOT
	  delete firewall.ssrserver
	  set firewall.ssrserver=include
	  set firewall.ssrserver.type=script
	  set firewall.ssrserver.path="/koolshare/scripts/ssrserver_nat.sh"
	  set firewall.ssrserver.family=any
	  set firewall.ssrserver.reload=1
	  commit firewall
	EOT
}

remove_nat_start(){
	echo_date 删除NAT-Start触发
	uci -q batch <<-EOT
	  delete firewall.ssrserver
	  commit firewall
	EOT
}

stop_ssrserver(){
	echo_date "====================================================="
	echo_date "		     LEDE软件中心 -- ShadowsocksR服务器"
	echo_date "====================================================="
	close_port
	echo_date "停止已经运行的服务！"
	start-stop-daemon -K -p $PID_FILE || true
	##/usr/bin/python /usr/share/ssr/shadowsocks/server.py  \
	##-c $CONFIG_FILE  \
	##--pid-file $PID_FILE  \
	##--log-file $LOGFILE  \
	##-d stop >/dev/null 2>&1 &
}

start_ssrserver(){
	check_run_system
	echo_date "生成临时配置文件"
	gen_config_file
	echo_date "开始运行服务"
	mkdir -p  /var/etc
	##/usr/bin/python /usr/share/ssr/shadowsocks/server.py  \
	##-c $CONFIG_FILE  \
	##--pid-file $PID_FILE  \
	##--log-file $LOGFILE  \
	##-d start >/dev/null 2>&1 &
	start-stop-daemon -S -q -b -m -p $PID_FILE -x /usr/bin/python -- /usr/share/ssr/shadowsocks/server.py -c $CONFIG_FILE --pid-file $PID_FILE --log-file $LOGFILE -d start
	open_port
	write_nat_start
	echo_date "服务已开启！页面将在3秒后刷新"
	echo_date "====================================================="
	echo_date ""
	echo_date "以下是服务器运行日志："
}

creat_start_up(){
	if [ ! -L "/etc/rc.d/S99ssrserver.sh" ]; then
		ln -s /koolshare/init.d/S99ssrserver.sh /etc/rc.d/S99ssrserver.sh
	fi
}

case $1 in
port)
	open_port
	;;
stop)
	cat /dev/null >$LOGFILE
	stop_ssrserver >> $LOGFILE
	remove_nat_start >> $LOGFILE
	echo_date "所有服务已关闭！" >> $LOGFILE
	echo XU6J03M6 >> $LOGFILE
    ;;
*)
	if [ "$ssrserver_enable" == "1" ]; then
		[ -f "/tmp/ssrserver.locker" ] && exit 0
		cat /dev/null >$LOGFILE
		touch /tmp/ssrserver.locker
		stop_ssrserver >> $LOGFILE
		remove_nat_start >> $LOGFILE
		echo_date "所有服务已关闭！" >> $LOGFILE
		start_ssrserver >> $LOGFILE
		rm -rf /tmp/ssrserver.locker
		echo XU6J03M6 >> $LOGFILE
	else
		cat /dev/null >$LOGFILE
		stop_ssrserver >> $LOGFILE
		remove_nat_start >> $LOGFILE
		echo_date "所有服务已关闭！" >> $LOGFILE
		echo XU6J03M6 >> $LOGFILE
	fi
	;;
esac
