#!/bin/bash
aws_profile=('default');
your_region="us-east-1"

#loop AWS profiles
for i in "${aws_profile[@]}"; do
  echo "AWS Profile: " "${i}"
  buckets=($(aws --profile "${i}" --region $your_region s3 ls s3:// --recursive | awk '{print $3}'))

  #loop S3 buckets
  for j in "${buckets[@]}"; do
  echo '"'"${j}"'"'
  done
done
