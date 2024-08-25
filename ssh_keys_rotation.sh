#!/bin/bash


# Paths
PRIVATE_IP=$1
KEY_DIR="/home/ubuntu/.ssh"
OLD_KEY="/home/ubuntu/old_key"
NEW_KEY="${KEY_DIR}/id_rsa"
NEW_KEY_PUB="${NEW_KEY}.pub"

if [[ $# -eq 1 ]]; then
	if [[ -f "${KEY_DIR}/id_rsa" ]]; then
		cd /home/ubuntu/.ssh/
		if [[ -f "${OLD_KEY}" ]]; then
			cd /home/ubuntu
			rm -f old_key
		fi
		mv "${KEY_DIR}/id_rsa" "${OLD_KEY}" #CHANGE THE NAME TO THE OLD KEY
		rm  -f "${KEY_DIR}/id_rsa.pub"
	fi

	cd /home/ubuntu
	#GENERATE SSH_KEY ON THE PUBLIC INSTANCE
	ssh-keygen -t rsa -b 4096 -f /home/ubuntu/key_change -P "" -q
	mv key_change "${NEW_KEY}"
	mv key_change.pub "${NEW_KEY_PUB}"

	#FORWARD PUBLIC KEY TO PRIVATE INSTANCE
	scp -i  "${OLD_KEY}" "${NEW_KEY_PUB}" ubuntu@"${PRIVATE_IP}":/home/ubuntu

	#APPEND THE NEW KEYS TO authorized_keys FILE.
	ssh -i "${OLD_KEY}" ubuntu@"${PRIVATE_IP}" "cat id_rsa.pub >> .ssh/authorized_keys"

	#CHCEK IF CAN I CONNECT TO THE MESHIN WITH THE NEW KEY
	ssh -i "${NEW_KEY}" ubuntu@"${PRIVATE_IP}" "cat id_rsa.pub > .ssh/authorized_keys"
	if [[ $? -eq 0 ]]; then
		echo "Now you can connect to the private machine only with this key: ${NEW_KEY}"
		rm /home/ubuntu/old_key
		rm /home/ubuntu/.ssh/id_rsa.pub
		ssh -i "${NEW_KEY}" ubuntu@"${PRIVATE_IP}" "rm /home/ubuntu/id_rsa.pub"
	else
		echo "The key you created is not good"
	fi
else
	echo "Please insert the private ip of your instance"
	exit 1
fi