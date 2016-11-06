#!/bin/sh

# Determine the local ip
ifconfig | grep -oE "\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b" >> output
local_ip=$(head -n1 output) && \
rm output

if [ $ID -eq 1 ]; then

	echo "server.$ID=$local_ip:2888:3888;2181" >> $ZK_HOME/conf/zoo.cfg.dynamic
  	$ZK_HOME/bin/zkServer-initialize.sh --force --myid=$ID
  	ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start-foreground
else
	nslookup $HOSTNAME >> zk.cluster

	# Configure Zookeeper
	no_instances=$(($(wc -l < zk.cluster) - 2))

	while [ $no_instances -le $NO ] ; do
		rm -rf zk.cluster
		nslookup $HOSTNAME >> zk.cluster
		no_instances=$(($(wc -l < zk.cluster) - 2))
	done

	touch hosts
	
	while read line; do
		ip=$(echo $line | grep -oE "\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b")
		index=$(echo $line | grep -oE "Address [0-9]*:" | grep -oE "[0-9]*")
	        index=$(($index + 0))
		
		if [[ "$ip" == "$local_ip" ] && [$index -eq 0 ]]; then
			echo "server.$index=$local_ip:2888:3888;2181" >> $ZK_HOME/conf/zoo.cfg.dynamic
  			$ZK_HOME/bin/zkServer-initialize.sh --force --myid=$index
  			ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start-foreground
		else
			if [ "$ip" == "$local_ip" ]; then
				echo "`bin/zkCli.sh -server $ZK:2181 get /zookeeper/config|grep ^server`" >> $ZK_HOME/conf/zoo.cfg.dynamic
  				echo "server.$index=$i:2888:3888:observer;2181" >> $ZK_HOME/conf/zoo.cfg.dynamic
    				cp $ZK_HOME/conf/zoo.cfg.dynamic $ZK_HOME/conf/zoo.cfg.dynamic.org
  				$ZK_HOME/bin/zkServer-initialize.sh --force --myid=$index
  				ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start
  				$ZK_HOME/bin/zkCli.sh -server $ZK:2181 reconfig -add "server.$index=$ip:2888:3888:participant;2181"
  				$ZK_HOME/bin/zkServer.sh stop
  				ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start-foreground
			fi
		fi
	done < 'zk.cluster'
fi
	



#while read line; do#
#		ip=$(echo $line | grep -oE "\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b")#
#		index=$(echo $line | grep -oE "Address [0-9]*:" | grep -oE "[0-9]*")
#    index=$(($index + 0))
#		if [ "$index" -le "$no_instances" ] && [ "$index" -gt "0" ]; then
			#echo "server.$index=$ip:2888:3888" >> $KAFKA_HOME/config/zookeeper.properties
			#echo "$(cat hosts) $ip:2181" >  hosts
#		fi#
		#if [ "$ip" == "$local_ip" ]; then
			#echo "$index" >> /tmp/zookeeper/myid
			#index=$(($index -1))
			#sed "s/broker.id=0/broker.id=$index/" $KAFKA_HOME/config/server.properties >> $KAFKA_HOME/config/server.properties.tmp
      #mv $KAFKA_HOME/config/server.properties.tmp $KAFKA_HOME/config/server.properties
#		fi
#done < 'zk.cluster' 
