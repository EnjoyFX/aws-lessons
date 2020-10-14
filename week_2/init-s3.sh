echo "You should have valid aws cli session for success of this script (aws configure > enter Access Key ID and AWS Secret Key)"
echo ""
echo " -- making s3 bucket..."
aws s3 mb s3://aws-andy-test-001 --region us-east-1
echo " -- adding versioning..."
aws s3api put-bucket-versioning --bucket aws-andy-test-001 --versioning-configuration Status=Enabled
echo " -- creating the file..."
date > the_file.txt
echo " -- moving file to s3 bucket with setting ACL(access control list) as private..."
aws s3 cp the_file.txt s3://aws-andy-test-001 --acl private
