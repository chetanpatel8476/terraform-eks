locals {

userdata = <<EOF

#!/bin/bash
export PATH=$PATH:/usr/local/bin
curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.18.8/2020-09-18/bin/linux/amd64/aws-iam-authenticator
chmod +x aws-iam-authenticator
mkdir -p $HOME/bin && cp ./aws-iam-authenticator $HOME/bin/aws-iam-authenticator && export PATH=$HOME/bin:$PATH
echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
aws-iam-authenticator version
echo 'aws-iam-authenticator installed'
curl -o kubectl https://storage.googleapis.com/kubernetes-release/release/v1.18.6/bin/linux/amd64/kubectl
chmod +x ./kubectl
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH
echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
kubectl version --short --client
echo 'kubectl installed ...'
which pip >/dev/null
if [ $? -ne 0 ];
then
  echo 'PIP NOT PRESENT'
  if [ -n "$(which yum)" ];
  then
    yum install -y python-pip
    touch abc
  else
    apt-get -y update && apt-get -y install python-pip
  fi
else
  echo 'PIP ALREADY PRESENT'
fi
EOF
}