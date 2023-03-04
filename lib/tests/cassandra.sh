#!/bin/bash

setup_java_home()
{
	if [ -d /usr/lib/jvm/java-1.11.0-openjdk ]; then
		export JAVA_HOME=/usr/lib/jvm/java-1.11.0-openjdk
		export CASSANDRA_USE_JDK11=true
	elif [ -d /usr/lib/jvm/java-11-openjdk-amd64 ]; then
		export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
		export CASSANDRA_USE_JDK11=true
	elif [ -d /usr/lib/jvm/java-1.8.0-openjdk ]; then
		export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
	elif [ -d /usr/lib/jvm/java-8-openjdk-amd64 ]; then
		export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
	else
		echo "ERROR: NO avaliable JAVA_HOME" >&2 && exit 1
	fi
}
