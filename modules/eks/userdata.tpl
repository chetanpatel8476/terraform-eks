#!/bin/bash
set -o xtrace
export AWS_DEFAULT_REGION='${aws_region}'
ENVIRONMENT='${env}'
sudo yum install dstat.noarch mlocate.x86_64 jq.x86_64 perl-5.16.3-294.amzn2.x86_64 -y



function with_backoff {
  local max_attempts=10
  local timeout=2
  local attempt=0
  local exitCode=0

  while [[ $attempt < $max_attempts ]]
  do
    "$@"
    exitCode=$?

    if [[ $exitCode == 0 ]]
    then
      break
    fi

    echo "Failure! Retrying in $timeout.." 1>&2
    sleep $timeout
    attempt=$(( attempt + 1 ))
    timeout=$(( timeout * 2 ))
  done

  if [[ $exitCode != 0 ]]
  then
    echo "You've failed me for the last time! ($@)" 1>&2
  fi

  return $exitCode
}




## Setting hostname

APPLICATION_REGION='${azzone}'
NEW_HOSTNAME_PREFIX='${cluster_id}'
SERVER_IP=$(with_backoff curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
instance_id=$(with_backoff curl -s http://169.254.169.254/latest/meta-data/instance-id)
ServerName="$NEW_HOSTNAME_PREFIX-$SERVER_IP"
with_backoff aws ec2 create-tags --resources $instance_id --tags Key=Name,Value="$ServerName"
sudo echo "$ServerName" > /etc/hostname
sudo hostnamectl set-hostname "$ServerName"
endpoint='${endpoint}'

#Install AWS-CLI
curl "https://d1vvhvl2y92vvt.cloudfront.net/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

##joining the cluster 
ca=`aws eks describe-cluster --name '${cluster_id}' --region '${aws_region}' | jq ".cluster.certificateAuthority.data" | sed 's/\"//g'`
echo $HOSTNAME
echo "SETTING UP LOG ROTATION CONFIG"


sudo echo -e "/var/lib/docker/containers/*/*.log { \n   rotate 5 \n   missingok \n   notifempty\n   copytruncate \n  compress\n   maxsize 1G\n   hourly \n  }" | tee /etc/logrotate.d/eks-logs.conf
sudo logrotate -f /etc/logrotate.d/eks-logs.conf
/etc/eks/bootstrap.sh --apiserver-endpoint $endpoint --b64-cluster-ca $ca '${cluster_id}' --kubelet-extra-args '--cluster-dns=169.254.20.10'
echo "script is completed"


