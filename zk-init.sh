#!/bin/sh

# Determine the local ip
ifconfig | grep -oE "\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b" >> output
local_ip=$(head -n1 output)
rm output

# Determine the local ZK index
myindex=$(echo $local_ip | sed -e 's/\.//g')

# Wait for containers to be up and running
sleep 10

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
#rm zk.cluster

#sort -n zk.cluster.tmp > zk.cluster.tmp.sort
#mv zk.cluster.tmp.sort zk.cluster.tmp

touch $ZK_HOME/conf/zoo.cfg.dynamic		
chmod -R 777 $ZK_HOME

# Run each Zookeeper node as standalone Zookeeper
if [ $NO == 1 ]; then
	echo "server.$myindex=$local_ip:2888:3888;2181" >> $ZK_HOME/conf/zoo.cfg.dynamic
	$ZK_HOME/bin/zkServer-initialize.sh --force --myid=$myindex
	echo "I am starting zookeeper"
	ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start-foreground
	echo "It was started"
#else
#	echo "====== STEP 0 ========"
#	echo "Starting Zooky as standalone server"
#	echo "server.$myindex=$local_ip:2888:3888;2181" >> $ZK_HOME/conf/zoo.cfg.dynamic
#	$ZK_HOME/bin/zkServer-initialize.sh --force --myid=$myindex
#	echo "I am starting zookeeper"
#	ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start
#	jps
fi
# Check the configuration of the rest of the servers
while read line; do
	if [ "$line" == "$local_ip" ]; then 
		echo "====== STEP 0 ========"
		echo "Starting Zooky as standalone server"
		echo "server.$myindex=$local_ip:2888:3888;2181" >> $ZK_HOME/conf/zoo.cfg.dynamic
		$ZK_HOME/bin/zkServer-initialize.sh --force --myid=$myindex
		echo "I am starting zookeeper"
		ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start
		jps
	fi	
	if [ "$line" != "$local_ip" ] && [ "$line" != "" ]; then
		echo "`$ZK_HOME/bin/zkCli.sh -server $line:2181 config /zookeeper | grep ^server`" >> cluster.config
		echo "my index is $myindex and the configuration of $line is "
		cat cluster.config
		grep "$line" cluster.config > result
		echo "the result of the comparison is $result"
		
		# If the local_ip is not present in the configuration
		if [ "$result" != "$local_ip" ]; then
			echo "`$ZK_HOME/bin/zkCli.sh -server $line:2181 get /zookeeper/config | grep ^server`" >> $ZK_HOME/conf/zoo.cfg.dynamic
			
			echo "=======STEP 1 =========="
			echo "the current configuration of $line server is:"
			cat  $ZK_HOME/conf/zoo.cfg.dynamic
			
			echo "======= STEP 2 ========"
			echo "Adding current server in the current zookeeper dynamic configuration"
			#newindex=$(echo $line | sed -e 's/\.//g')
			#echo "server.$newindex=$line:2888:3888;2181" >> $ZK_HOME/conf/zoo.cfg.dynamic
			grep "$local_ip" $ZK_HOME/conf/zoo.cfg.dynamic > result
			echo "Se regaseste $local_ip in configul lui $line?"
			cat result
			
			echo "server.$myindex=$local_ip:2888:3888:observer;2181" >> $ZK_HOME/conf/zoo.cfg.dynamic		
			cp $ZK_HOME/conf/zoo.cfg.dynamic $ZK_HOME/conf/zoo.cfg.dynamic.org
			echo "Eu sunt $myindex"
			cat $ZK_HOME/conf/zoo.cfg.dynamic
			$ZK_HOME/bin/zkServer.sh stop
			echo "Zookeeper is stopped"
			
			echo "====== STEP 3 ========="
			echo "Reconfigure server $myindex"
  			$ZK_HOME/bin/zkServer-initialize.sh --force --myid=$myindex
			#echo "the current server is started"
			
			echo "======= STEP 4 ========"
			echo "Start server"
  			ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start
			index=$(echo $line | sed -e 's/\.//g')
  			
			echo "====== STEP 5 ========="
			echo "Reconfigure server $line by adding the current server"
			$ZK_HOME/bin/zkCli.sh -server $line:2181 reconfig -add "server.$myindex=$local_ip:2888:3888:participant;2181"
			
			echo "======= STEP 6 ======="
			echo "Stopping Zooky"
  			$ZK_HOME/bin/zkServer.sh stop
			
			echo "======= STEP 7 ========"
			echo "Starting Zooky"
  			ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start
		fi
		rm result
	fi 
#done < 'zk.cluster.tmp'
done < 'zk.cluster.tmp'
$ZK_HOME/bin/zkServer.sh stop
ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start-foreground

rm zk.cluster.tmp
