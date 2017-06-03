## EC2

# ./startec2.sh

The script will start an ec2 instance on the default vpc in one of the subnets available

- It looks for the most recent ubuntu ami available

- It generates a "demokey" keypair and store the public key on AWS, the private key will be in _script_directory_/demokey.private

  **Note**: if you re-run the script, the keypair is not recreated. If you lose the private key generated at first run, delete the keypair before runnning the script again (aws ec2 delete-key-pair --key-name demokey)

- A security group is created and will be attached to the ec2 instance: this SG allows only your current IP adress for port 22

- It then waits for the ec2 instance to be available, and outputs the correct command to ssh to it

By default the script will use your "default" profile for aws credential, you can use another one if you set AWS_PROFILE before to run the script (eg.: AWS_PROFILE=my-profile ./startec2.sh)

This script needs the following aws permissions:
```
- ec2:DescribeVpcs
- ec2:DescribeSubnets
- ec2:DescribeKeyPairs and ec2:CreateKeyPair
- ec2:CreateSecurityGroup
- ec2:DescribeInstances
- ec2:DescribeImages
- ec2:AuthorizeSecurityGroupIngress
- ec2:RunInstances
```
