#!/usr/bin/env bash

###### SETUP ################
if [[ -z $AWS_PROFILE ]]
then
AWS_PROFILE=default
fi
echo using aws profile: $AWS_PROFILE
AWS_CMD="aws --profile $AWS_PROFILE --output text"
#set here the vpc-id where you want to launch the EC2
#following command will use the default VPC of the account
VPC_ID=$($AWS_CMD ec2 describe-vpcs --filter Name=isDefault,Values=true --query "Vpcs[].VpcId")
echo "vpc-id: $VPC_ID"
#the subnets inside the default VPC assign by default a public ip for the ec2s, we will pick the first one in the list
SUBNET_ID=$($AWS_CMD  ec2 describe-subnets --filter Name=vpc-id,Values=vpc-171bd072 --query "Subnets[0].SubnetId")
echo "subnet-id: $SUBNET_ID"

BASEDIR=$(dirname "$0")
#############################

###### Functions ################
function check_keypair(){
  $AWS_CMD ec2 describe-key-pairs --key-names demokey --query "KeyPairs[].KeyName" 2>/dev/null
  return $?
}


function generate_keypair(){
  echo "keypair not found, generating one.."
  keypair=$($AWS_CMD ec2 create-key-pair --key-name demokey --query "KeyMaterial")
  [[ -z  $keypair ]] && (echo "couldn't generate keypair!" ;exit -1)

  #store the private key for further uses
  echo "$keypair" > $BASEDIR/demokey.private
  #set correct permissions on private key
  chmod 400 $BASEDIR/demokey.private
}


function create_demo_sg(){
uniquedate=$(date +%Y%m%d-%H%M%S)
demoSg=$($AWS_CMD ec2 create-security-group --vpc-id $VPC_ID --group-name demosg-$uniquedate --description "demo security group" --query "GroupId" )
 echo $demoSg

}
#################################


#get the most recent ubutu 16.04 ami
amiId=$($AWS_CMD ec2 describe-images --filters Name=name,Values="ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-2017*" Name=root-device-type,Values=ebs --owner 099720109477 --query "reverse(sort_by(Images, &CreationDate))[:1][ImageId]" )

[[ -z  $amiId  ]] && (echo "no ami found!" ;exit -1)

echo "ami: $amiId"

#we need a demo keypair
check_keypair || generate_keypair


#get current ip address: we want to allow ssh only from our IP
currentIp=$(dig +short myip.opendns.com @resolver1.opendns.com)

#create a security group with our ip, we will attach it to the EC2
echo "creating security group.."
demosg=$(create_demo_sg)

echo security group: $demosg
$AWS_CMD ec2 authorize-security-group-ingress --group-id $demosg --protocol tcp --port 22 --cidr "$currentIp/32"

#ready to launch!
echo "starting instance.."
instanceId=$($AWS_CMD ec2 run-instances --count 1 --image-id $amiId --subnet-id $SUBNET_ID --instance-type t2.micro --security-group-ids $demosg --key-name demokey --query "Instances[].InstanceId" )
echo instance-id: $instanceId
#wait for the instance to be ready

$AWS_CMD ec2 wait instance-status-ok --instance-ids $instanceId

echo "instance $instanceId ready!"
#get the public ip of the instance
ec2Ip=$($AWS_CMD ec2 describe-instances --instance-ids $instanceId  --query "Reservations[].Instances[].PublicDnsName")

echo "to connect: ssh ubuntu@$ec2Ip -i $BASEDIR/demokey.private "
