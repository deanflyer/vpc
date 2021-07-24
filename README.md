# vpc

vpc.sh is a shell script that creates AWS VPC/EC2 resources.

I use it to quickly spin up some subnets and an EC2 resource for testing purposes when I can't be bothered with CloudFormation.

## Installation

All you need is the vpc.sh file.
You will need to have installed Amazons AWS CLI and configured it with your user credentials.
Information on install the AWS CLI can be found here - https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html and here https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html

## Dependencies

You will need to install jq a JSON parser and have the AWS CLI installed and configured.

## Usage

<code>./vpc.sh</code>

Run the above command to start the shell script and follow the prompts

It will create the following resources/configuration:

VPC<br/>
Two Subnets<br/>
Internet Gateway attached to VPC<br/>
Create route for IGW in main route table<br/>
Configure subnet1 to issue public IP addresses for EC2 instances<br/>
EC2 keypair with associated .pem file<br/>
EC2 Security Group with an inbound security rule<br/>
EC2 instance<br/>

It will create the following local files:

igw.json<br/>
instances.json<br/>
private-rt.json<br/>
public-rt.json<br/>
subnet1.json<br/>
subnet2.json<br/>
test-keypair.pem (EC2 keypair private key)<br/>
vpc.json<br/>

Once all AWS resources are created you can pause the script or exit it (control+c) at the point where it asks "Terminate created AWS resources?". 
If you continue it will delete all previously created AWS resources. 

## Support

If you want to contact me send an email to enquiries@awsmadesimple.co.uk and I'll get back to you within a reasonable timescale.

## Licence

See license.txt file
