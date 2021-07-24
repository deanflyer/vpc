# Shell script for creating AWS resources
# Resources will be created in default VPC (run AWS configure list to see what your default region is set to) unless specififed otherwise 
# Dependencies - requires jq JSON parsing utility to be installed and AWS CLI

# General variables
DEFAULT_VPC="10.0.0.0/16"
DEFAULT_VPC_TAG="test-VPC"
DEFAULT_AVAILABILITY_ZONE_1=""
DEFAULT_AVAILABILITY_ZONE_2=""
DEFAULT_SUBNET1="10.0.1.0/24"
DEFAULT_SUBNET1_TAG="public-subnet"
DEFAULT_SUBNET2="10.0.2.0/24"
DEFAULT_SUBNET2_TAG="private-subnet"
DEFAULT_IGW="IGW1"
DEFAULT_PUBLIC_RT="public-route-table"
DEFAULT_PRIVATE_RT="private-route-table"
DEFAULT_KEYPAIR="test-keypair"
DEFAULT_SECURITY_GROUP="TestSecurityGroup"
DEFAULT_SECURITY_GROUP_DESCRIPTION="Test Security Group (autocreated)"
DEFAULT_SECURITY_GROUP_TAG_NAME="Test"
DEFAULT_INBOUND_RULE_PROTOCOL="tcp"
DEFAULT_INBOUND_RULE_PORT="22"
DEFAULT_INBOUND_RULE_CIDR="0.0.0.0/0"
DEFAULT_INSTANCE_TYPE="t2.micro"
INSTANCE_ID=""
EC2_PUBLIC_IP_ADDRESS=""

# Default output filenames
VPCOUTPUT="vpc.json"
SN1OUTPUT="subnet1.json"
SN2OUTPUT="subnet2.json"
IGWOUTPUT="igw.json"
PUBLIC_RT_OUTPUT="public-rt.json"
PRIVATE_RT_OUTPUT="private-rt.json"
INSTANCEOUTPUT="instances.json"

echo "AWS CLI Utility"

# Select AWS region
CURRENT_REGION=$(aws configure get region)
echo -n "Enter AWS region, or press enter for default region["$CURRENT_REGION"]: " 
read SELECTEDREGION
if [ -n "$SELECTEDREGION" ]
	then
		CURRENT_REGION=$SELECTEDREGION
		echo "AWS region has been changed to:" $CURRENT_REGION
fi

# Create a VPC
# When you create a VPC, it automatically has a main route table. 
# We can use this or just create our own route tables and associate them with out subnets later on
echo -n "Enter CIDR-block you want to create ["$DEFAULT_VPC"]: " 
read CIDRBLOCK
if [ -z "$CIDRBLOCK" ]
	then
		CIDRBLOCK=$DEFAULT_VPC
fi

echo -n "Enter name of the VPC ["$DEFAULT_VPC_TAG"]: " 
read VPCTAGNAME
if [ -z "$VPCTAGNAME" ]
	then
		VPCTAGNAME=$DEFAULT_VPC_TAG
		aws ec2 create-vpc --region $CURRENT_REGION --cidr-block $CIDRBLOCK --tag-specifications 'ResourceType=vpc, Tags=[{Key=Name,Value='$VPCTAGNAME'}]' --output json > $VPCOUTPUT
fi
if [ $? -eq 0 ]
	then
		VPCID=$(cat $VPCOUTPUT | jq -r ".Vpc.VpcId")	
		echo "VPC creation successful. [SUCCESS]"
		echo "VPC ID:" $VPCID
	else
		echo "VPC creation failed. AWS CLI return code is:" $? "[FAIL]"
		exit
fi

# Create 2 subnets within our VPC in separate AZs
# Retrieve Region AZs and associate first 2 available AZs with our 2 subnets respectively (unless user specifies otherwise)
echo
echo "CREATE SUBNETS"
echo "AZs in "$CURRENT_REGION" are: "
aws ec2 describe-availability-zones --region $CURRENT_REGION | jq -r .AvailabilityZones[].ZoneName
DEFAULT_AVAILABILITY_ZONE_1=$(aws ec2 describe-availability-zones --region $CURRENT_REGION | jq -r .AvailabilityZones[0].ZoneName)
DEFAULT_AVAILABILITY_ZONE_2=$(aws ec2 describe-availability-zones --region $CURRENT_REGION | jq -r .AvailabilityZones[1].ZoneName)
echo -n "First subnet IP address ["$DEFAULT_SUBNET1":]"
read SUBNET1
if [ -z "$SUBNET1" ]
	then
		SUBNET1=$DEFAULT_SUBNET1
fi
echo -n "First subnet name ["$DEFAULT_SUBNET1_TAG"]: " 
read SN1TAGNAME
if [ -z "$SN1TAGNAME" ]
	then
		SN1TAGNAME=$DEFAULT_SUBNET1_TAG
fi

echo -n "First subnet Availability Zone ["$DEFAULT_AVAILABILITY_ZONE_1"]: " 
read SN1AZ
if [ -z "$SN1AZ" ]
	then
		SN1AZ=$DEFAULT_AVAILABILITY_ZONE_1
fi

echo -n "Second subnet IP address ["$DEFAULT_SUBNET2"]: " 
read SUBNET2
if [ -z "$SUBNET2" ]
	then
		SUBNET2=$DEFAULT_SUBNET2
fi

echo -n "Second subnet name ["$DEFAULT_SUBNET2_TAG"]: " 
read SN2TAGNAME
if [ -z "$SN2TAGNAME" ]
	then
		SN2TAGNAME=$DEFAULT_SUBNET2_TAG
fi

echo -n "Second subnet Availability Zone ["$DEFAULT_AVAILABILITY_ZONE_2"]: " 
read SN2AZ
if [ -z "$SN2AZ" ]
	then
		SN2AZ=$DEFAULT_AVAILABILITY_ZONE_2
fi

aws ec2 create-subnet --region $CURRENT_REGION --availability-zone $SN1AZ --vpc-id $VPCID --cidr-block $SUBNET1 --tag-specifications 'ResourceType=subnet, Tags=[{Key=Name,Value='$SN1TAGNAME'}]' > $SN1OUTPUT
if [ $? -eq 0 ]
then
	SUBNET1ID=$(cat $SN1OUTPUT | jq -r ".Subnet.SubnetId")	
	echo "Subnet 1 created. Subnet ID: "$SUBNET1ID "[SUCCESS]"
else
	echo "VPC creation failed. See" $SN1OUTPUT "for further details. AWS CLI return code is:" $? "[FAIL]"
	exit
fi

aws ec2 create-subnet --region $CURRENT_REGION --availability-zone $SN2AZ --vpc-id $VPCID --cidr-block $SUBNET2 --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value='$SN2TAGNAME'}]' --output json > $SN2OUTPUT
if [ $? -eq 0 ]
	then
		SUBNET2ID=$(cat $SN2OUTPUT | jq -r ".Subnet.SubnetId")	
		echo "Subnet 2 created. Subnet ID: "$SUBNET2ID "[SUCCESS]"
	else
		echo "VPC creation failed. See "$SN2OUTPUT" for further details. AWS CLI return code is:" $? "[FAIL]"
		exit
fi

# Create Internet Gateway
echo 
echo "CREATE INTERNET GATEWAY"
echo -n "Internet Gateway name ["$DEFAULT_IGW"]: " 
read IGWNAME
if [ -z "$IGWNAME" ]
	then
		IGWNAME=$DEFAULT_IGW
fi
aws ec2 create-internet-gateway --region $CURRENT_REGION --tag-specifications 'ResourceType=internet-gateway, Tags=[{Key=Name,Value='$IGWNAME'}]' --output json > $IGWOUTPUT
if [ $? -eq 0 ]
	then
		IGWID=$(cat $IGWOUTPUT | jq -r ".InternetGateway.InternetGatewayId")
		echo "Internet Gateway created [SUCCESS]"
		echo "Internet gateway ID: "$IGWID
	else
		echo "Internet Gateway creation failed. See" $IGWOUTPUT "for further details. AWS CLI return code is:" $? "[FAIL]"
		exit
fi

# Attach Internet Gateway to VPC
echo 
echo "ATTACH INTERNET GATEWAY TO VPC"
aws ec2 attach-internet-gateway --region $CURRENT_REGION --vpc-id $VPCID --internet-gateway-id $IGWID
if [ $? -eq 0 ]
	then
		echo "Internet gateway attached successfully. [SUCCESS]"
	else
		echo "Internet gateway not attached AWS CLI return code is:" $? "[FAIL]"
		exit
fi

# Create public and private routing table for our subnets
# Note - As we are explicitly associating our subnets with our created rout tables the main VPC route table is redundant.
echo
echo "CREATE PUBLIC SUBNET ROUTE TABLE"
aws ec2 create-route-table --region $CURRENT_REGION --vpc-id $VPCID --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value='$DEFAULT_PUBLIC_RT'}]' > $PUBLIC_RT_OUTPUT
if [ $? -eq 0 ]
	then
		echo "Public subnet route table crated successfully. [SUCCESS]"
		PUBLIC_SUBNET_RT=$(jq -r .[].RouteTableId public-rt.json)
		echo "Public subnet route table ID: "$PUBLIC_SUBNET_RT
	else
		echo "Public subnet route table creation failed. AWS return code is: "$? "[FAIL]"
		exit
fi

# Create private routing table
echo
echo "CREATE PRIVATE SUBNET ROUTE TABLE"
aws ec2 create-route-table --region $CURRENT_REGION --vpc-id $VPCID --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value='$DEFAULT_PRIVATE_RT'}]' > $PRIVATE_RT_OUTPUT
if [ $? -eq 0 ]
	then
		echo "Private subnet route table crated successfully. [SUCCESS]"
		PRIVATE_SUBNET_RT=$(jq -r .[].RouteTableId private-rt.json)
		echo "Private subnet route table ID: "$PRIVATE_SUBNET_RT
	else
		echo "Private subnet route table creation failed. AWS return code is: "$? "[FAIL]"
		exit
fi

# Attach internet gateway to public subnet route table
echo
echo "ADD INTERNET GATEWAY TO PUBLIC SUBNET ROUTE TABLE"
aws ec2 create-route --region $CURRENT_REGION --route-table-id $PUBLIC_SUBNET_RT --destination-cidr-block 0.0.0.0/0 --gateway-id $IGWID > /dev/null
if [ $? -eq 0 ]
	then
		echo "Dest:0.0.0.0/0 -" $IGWID "associated with main Route table" $MAIN_RT_TABLE "[SUCCESS]"
	else
		echo "Route table could not be associated with main Route table [FAIL]"
		echo "AWS CLI return code is:" $?
		exit
fi

# Associate our public and private subnets explicitly with our public and private route tables
echo
echo "ASSOCIATE PUBLIC SUBNET WITH PUBLIC ROUTE TABLE"
aws ec2 associate-route-table --region $CURRENT_REGION --subnet-id $SUBNET1ID --route-table-id $PUBLIC_SUBNET_RT > /dev/null
if [ $? -eq 0 ]
	then
		echo $SUBNET1ID "explicitly associated with "$PUBLIC_SUBNET_RT "[SUCCESS]"
	else
		echo $SUBNET1ID "could not be associated with "$PUBLIC_SUBNET_RT "[FAIL]"
		echo "AWS CLI return code is:" $?
		exit
fi

echo
echo "ASSOCIATE PRIVATE SUBNET WITH PRIVATE ROUTE TABLE"
aws ec2 associate-route-table --region $CURRENT_REGION --subnet-id $SUBNET2ID --route-table-id $PRIVATE_SUBNET_RT > /dev/null
if [ $? -eq 0 ]
	then
		echo $SUBNET2ID "explicitly associated with "$PRIVATE_SUBNET_RT "[SUCCESS]"
	else
		echo $SUBNET2ID "could not be associated with "$PRIVATE_SUBNET_RT "[FAIL]"
		echo "AWS CLI return code is:" $?
		exit
fi

# Make subnet1 issue public-IP addresses to EC2 instances on launch
echo
echo "AUTO-ASSIGN PUBLIC IPV4"
aws ec2 modify-subnet-attribute --region $CURRENT_REGION --subnet-id $SUBNET1ID --map-public-ip-on-launch
if [ $? -eq 0 ]
	then
		echo "Enabled auto-assign public IPv4 address on launch on "$SUBNET1ID "[SUCCESS]"
	else
		echo "auto-assign public IPv4 address on launch on "$SUBNET1ID "[FAILED]"
		echo "AWS CLI return code is:" $?
		exit
fi

# Create keypair
echo
echo "CREATE KEY-PAIR"
echo -n "Enter key-pair name ["$DEFAULT_KEYPAIR"]: " 
read KEYPAIR
if [ -z "$KEYPAIR" ]
	then
		KEYPAIR=$DEFAULT_KEYPAIR
	fi
aws ec2 create-key-pair --region $CURRENT_REGION --key-name $KEYPAIR --query 'KeyMaterial' --output text > ./$KEYPAIR.pem
chmod 600 $KEYPAIR.pem 
if [ $? -eq 0 ]
	then
		echo "keypair generated. File saved locally as "$KEYPAIR".pem [SUCCESS]"
		echo -n "KeyFingerprint: " 
		aws ec2 describe-key-pairs --region $CURRENT_REGION --key-name $KEYPAIR | jq -r ".KeyPairs[].KeyFingerprint"
	else
		echo "keypair generation [FAIL]"
		echo "AWS CLI return code is:" $?
		exit
fi

# Create Security Group
echo
echo "CREATE SECURITY GROUP"
echo -n "Enter security group name ["$DEFAULT_SECURITY_GROUP"]: " 
read SECURITY_GROUP
if [ -z "$SECURITY_GROUP" ]
	then
		SECURITY_GROUP=$DEFAULT_SECURITY_GROUP
fi

echo -n "Enter security group description ["$DEFAULT_SECURITY_GROUP_DESCRIPTION"]: " 
read SECURITY_GROUP_DESCRIPTION
if [ -z "$SECURITY_GROUP_DESCRIPTION" ]
	then
		SECURITY_GROUP_DESCRIPTION=$DEFAULT_SECURITY_GROUP_DESCRIPTION
fi

echo -n "Enter security group tag name ["$DEFAULT_SECURITY_GROUP_TAG_NAME"]: " 
read SECURITY_GROUP_TAG_NAME
if [ -z "$SECURITY_GROUP_TAG_NAME" ]
	then
		SECURITY_GROUP_TAG_NAME=$DEFAULT_SECURITY_GROUP_TAG_NAME
fi

aws ec2 create-security-group --region $CURRENT_REGION --description "$SECURITY_GROUP_DESCRIPTION" --group-name $SECURITY_GROUP --vpc-id $VPCID --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value='$SECURITY_GROUP_TAG_NAME'}]' > /dev/null
if [ $? -eq 0 ]
	then
		SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --region $CURRENT_REGION --filters Name=group-name,Values=$SECURITY_GROUP | jq -r .SecurityGroups[].GroupId)
		echo "Security group created [SUCCESS]"
		echo -n "Security group ID: "
		echo $SECURITY_GROUP_ID
	else
		echo "Security group creation [FAIL]"
		echo "AWS CLI return code is:" $?
		exit
fi

#---------------------------------
# Add inbound rule to security group
# echo
# echo "ADD INBOUND RULE TO SECURITY GROUP"
# echo -n "Protocol (tcp,udp,icmp) ["$DEFAULT_INBOUND_RULE_PROTOCOL"]: " 

# read INBOUND_RULE_PROTOCOL
# if [ -z "$INBOUND_RULE_PROTOCOL" ]
# 	then
# 		INBOUND_RULE_PROTOCOL=$DEFAULT_INBOUND_RULE_PROTOCOL
# fi
# echo -n "Port no. ["$DEFAULT_INBOUND_RULE_PORT"]: " 
# read INBOUND_RULE_PORT
# if [ -z "$INBOUND_RULE_PORT" ]
# 	then
# 		INBOUND_RULE_PORT=$DEFAULT_INBOUND_RULE_PORT
# fi
# echo -n "CIDR block ["$DEFAULT_INBOUND_RULE_CIDR"]: " 
# read INBOUND_RULE_CIDR_BLOCK
# if [ -z "INBOUND_RULE_CIDR_BLOCK" ]
# 	then
# 		INBOUND_RULE_CIDR_BLOCK=$DEFAULT_INBOUND_RULE_CIDR
# fi

# aws ec2 authorize-security-group-ingress --region $CURRENT_REGION --group-id $SECURITY_GROUP_ID --protocol $INBOUND_RULE_PROTOCOL --port $INBOUND_RULE_PORT --cidr $DEFAULT_INBOUND_RULE_CIDR
#  if [ $? -eq 0 ]
# 	then
# 		echo "Inbound rule" $INBOUND_RULE_CIDR">" $INBOUND_RULE_PORT "added to security group: "$SECURITY_GROUP_ID" [SUCCESS]"
# 	else
# 		echo "Inbound rule addition [FAIL]"
# 		echo "AWS CLI return code is:" $?
# 		exit
# fi
#-----------------------------------------------

# do while loop for adding multiple security rules. Will run at least once and test for exit at bottom of loop.
while true; do
	echo
	echo "ADD AN INBOUND RULE TO SECURITY GROUP"

	echo -n "Protocol (tcp,udp,icmp) ["$DEFAULT_INBOUND_RULE_PROTOCOL"]: " 
	read INBOUND_RULE_PROTOCOL
	if [ -z "$INBOUND_RULE_PROTOCOL" ]
		then
			INBOUND_RULE_PROTOCOL=$DEFAULT_INBOUND_RULE_PROTOCOL
	fi
	
	echo -n "Port no. ["$DEFAULT_INBOUND_RULE_PORT"]: " 
	read INBOUND_RULE_PORT
	if [ -z "$INBOUND_RULE_PORT" ]
		then
			INBOUND_RULE_PORT=$DEFAULT_INBOUND_RULE_PORT
	fi

	echo -n "CIDR block ["$DEFAULT_INBOUND_RULE_CIDR"]: " 
	read INBOUND_RULE_CIDR_BLOCK
	if [ -z "INBOUND_RULE_CIDR_BLOCK" ]
		then
			INBOUND_RULE_CIDR_BLOCK=$DEFAULT_INBOUND_RULE_CIDR
	fi

	aws ec2 authorize-security-group-ingress --region $CURRENT_REGION --group-id $SECURITY_GROUP_ID --protocol $INBOUND_RULE_PROTOCOL --port $INBOUND_RULE_PORT --cidr $DEFAULT_INBOUND_RULE_CIDR
	if [ $? -eq 0 ]
		then
			echo "Inbound rule" $INBOUND_RULE_CIDR">" $INBOUND_RULE_PORT "added to security group: "$SECURITY_GROUP_ID" [SUCCESS]"
		else
			echo "Inbound rule addition [FAIL]"
			echo "AWS CLI return code is:" $?
			exit
	fi

	read -p "'q' to quit security rule creation or press enter to add another security rule:" QUIT_TEST
	[[ $QUIT_TEST != "q" ]] || break
done

# Get current (latest) version of Amazon 2 Linux AMI for x86_64 (query by wilcard name, sort by reverse date and display latest version only) and launch EC2 instance/s
# For arm64 AMI use "amzn2-ami-hvm-2.0.????????.?-arm64-gp2"
echo
echo "RETRIEVE LATEST x86 AMAZON LINUX 2 AMI"
LATEST_AL2_AMI=$(aws ec2 describe-images --region $CURRENT_REGION --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-2.0.????????.?-x86_64-gp2" "Name=state,Values=available" --query "reverse(sort_by(Images, &CreationDate))[:1].ImageId" --output text)
echo "Latest version of AMI is: "$LATEST_AL2_AMI
echo -n "Enter EC2 Instance Type required ["$DEFAULT_INSTANCE_TYPE"]: " 
read INSTANCE_TYPE 
if [ -z "$INSTANCE_TYPE" ]
	then
		INSTANCE_TYPE=$DEFAULT_INSTANCE_TYPE
fi
echo "Launching "$INSTANCE_TYPE" EC2 INSTANCE IN PUBLIC SUBNET: "$SUBNET1ID

# Launch EC2 instance and send output to $INSTANCEOUTPUT filename
aws ec2 run-instances --region $CURRENT_REGION --image-id $LATEST_AL2_AMI --count 1 --instance-type $INSTANCE_TYPE --key-name $KEYPAIR --security-group-ids $SECURITY_GROUP_ID --subnet-id $SUBNET1ID --output json > $INSTANCEOUTPUT
INSTANCE_ID=$(jq -r  '.Instances[].InstanceId' $INSTANCEOUTPUT) 
if [ $? -eq 0 ]
	then
		echo "EC2 Instance launched [SUCCESS]"
		echo "Instance ID: "$INSTANCE_ID
	else
		echo "Instance(s) not launched [FAIL]"
		echo "AWS CLI return code is:" $?
		exit
fi

# Query EC2 instance with current $INSTANCE_ID and retrieve Public IP address
EC2_PUBLIC_IP_ADDRESS=$(aws ec2 describe-instances --region $CURRENT_REGION --filters Name=instance-id,Values=$INSTANCE_ID --query Reservations[*].Instances[*].PublicIpAddress --output text)
echo  "EC2 Public IP address: "$EC2_PUBLIC_IP_ADDRESS
echo

# Clean up and delete created AWS resources
echo "Terminate created AWS resources? 
Do not proceed unless you wish to terminate the AWS resources you just created."
echo "Note - This script will fail if you run it immediately after resource creation due to propagation delays"
read -eiN -p "Terminate all AWS created resources? [y/N]" YN 
if [ $YN = "Y" ] || [ $YN = "y" ]
	then
  		echo "Terminating EC2 instance: "$INSTANCE_ID
		aws ec2 terminate-instances --region $CURRENT_REGION --instance-ids $INSTANCE_ID > /dev/null
		echo "Pausing for 90 seconds for propagation delays."
		sleep 90
		echo "Deleting security group: "$SECURITY_GROUP_ID
		aws ec2 delete-security-group --region $CURRENT_REGION --group-id $SECURITY_GROUP_ID
		echo "Deleting subnet: "$SUBNET1ID
		aws ec2 delete-subnet --region $CURRENT_REGION --subnet-id $SUBNET1ID
		echo "Deleting subnet: "$SUBNET2ID
		aws ec2 delete-subnet --region $CURRENT_REGION --subnet-id $SUBNET2ID
		echo "Detaching internet gateway: "$IGWID
		aws ec2 detach-internet-gateway --region $CURRENT_REGION --internet-gateway-id $IGWID --vpc-id $VPCID
		echo "Deleting internet gateway: "$IGWID
		aws ec2 delete-internet-gateway --region $CURRENT_REGION --internet-gateway-id $IGWID
		echo "Deleting public route table: "$PUBLIC_SUBNET_RT
		aws ec2 delete-route-table --region $CURRENT_REGION --route-table-id $PUBLIC_SUBNET_RT
		echo "Deleting private route table: "$PRIVATE_SUBNET_RT
		aws ec2 delete-route-table --region $CURRENT_REGION --route-table-id $PRIVATE_SUBNET_RT
		echo "Deleting VPC: "$VPCID
		aws ec2 delete-vpc --region $CURRENT_REGION --vpc-id $VPCID
		echo "All AWS resources deleted"
	else
		echo "Script complete. AWS resources retained."
fi