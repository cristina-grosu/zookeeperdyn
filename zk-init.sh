#!/bin/sh

# Determine the local ip
ifconfig | grep -oE "\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b" >> output
local_ip=$(head -n1 output)
rm output

sleep 30

nslookup $HOSTNAME
nslookup $HOSTNAME >> zk.cluster

# Configure Zookeeper
no_instances=$(($(wc -l < zk.cluster) - 2))

while [ $no_instances -le $NO ] ; do
	rm -rf zk.cluster
	nslookup $HOSTNAME
	nslookup $HOSTNAME >> zk.cluster
	no_instances=$(($no_instances + 1))
done

while read line; do
	ip=$(echo $line | grep -oE "\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b")
	echo "$ip" >> zk.cluster.tmp
done < 'zk.cluster'
rm zk.cluster

sort -n zk.cluster.tmp > zk.cluster.tmp.sort
mv zk.cluster.tmp.sort zk.cluster.tmp

index=0		
while read line; do
	if [ "$line" != "" ]; then
       		index=$(($index + 1))
	
		if [ $index -eq 1 ]; then 
			ZK=$line
		fi
		if [ "$line" == "$local_ip" ] && [ $index -eq 1 ]; then
			echo "server.$index=$local_ip:2888:3888;2181" >> $ZK_HOME/conf/zoo.cfg.dynamic
  			$ZK_HOME/bin/zkServer-initialize.sh --force --myid=$index
  			ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start-foreground
			echo "EU sunt Primul"
		else
			echo "Eu sunt $index"
			
			grep "$local_ip" $ZK_HOME/conf/zoo.cfg.dynamic > result
			if [ "$result" != "$local_ip" ]; then
			if [ "$line" == "$local_ip" ] && [ $index -ne 1 ]; then
				echo "`bin/zkCli.sh -server $ZK:2181 get /zookeeper/config|grep ^server`" >> $ZK_HOME/conf/zoo.cfg.dynamic
  				echo "server.$index=$local_ip:2888:3888:observer;2181" >> $ZK_HOME/conf/zoo.cfg.dynamic
    				cp $ZK_HOME/conf/zoo.cfg.dynamic $ZK_HOME/conf/zoo.cfg.dynamic.org
				echo "Eu sunt $index"
				echo "zoo.cfg"
				cat  $ZK_HOME/conf/zoo.cfg
				echo "zoo.cfg.dynamic"
				$ZK_HOME/conf/zoo.cfg.dynamic
				echo "ZK is $ZK and I am $line" 
  				$ZK_HOME/bin/zkServer-initialize.sh --force --myid=$index
  				ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start
  				$ZK_HOME/bin/zkCli.sh -server $ZK:2181 reconfig -add "server.$index=$local_ip:2888:3888:participant;2181"
  				$ZK_HOME/bin/zkServer.sh stop
  				ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start-foreground
			fi
			fi
		fi
	fi
done < 'zk.cluster.tmp'

rm zk.cluster.tmp
