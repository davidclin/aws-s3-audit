
#!/bin/bash

# The following script is used to pass AWS profile, bucket, and region
# information to the s3-audit.go Golang script which in turn will
# find objects that are publically accessible.
#
# Note, this script allows you pass through several AWS profiles but is not
# recommended if you know that the account associated with the profile
# is large (ie: tri-na). In such cases, it is recommended that you run
# this script solely for the single account and batch the smaller accounts
# in a separate job.
#
# In addition, you may encounter situations where buckets are
# (1) known to be publically accessible, (2) have attached bucket
# policies that deny the script from running to completion,
# (3) takng a very long time (eg: > 1 day) to complete, (4) or have already
# been audited.
#
# As a workaround, this script provides a section where you can
# explicitly blacklist the aforementioned bucket use cases so you can
# re-run the script.
#
# Lastly, here are some useful tips:
#
# - If you run the script from a terminal, configure your client
#   so the session does not timeout during the run. This comes in handy
#   for really long runs.
# - Set the ulimit to the maximum hard limit. You can issue
#   `ulimit -Hn` then `ulimit -n <max hard limit>` and finally
#   `ulimit -a` to confirm the maximum nuber of open files is set.
#
#   Recommended value: ulimit -n 1048576
#
# - Pipe the output of the script to file so you can later parse
#   what you need (eg: find buckets that deny access, find
#   public objects returned by s3-audit.go script, find buckets that
#   successfully passed the audit so they can be blacklisted in the event
#   you need to re-run the script but don't want to re-scan the passed
#   buckets, etc.

# Declare an array variable for aws accounts in organization.
# Make sure you use the same profile name as used in your
# ~/.aws/config file and that there are no spaces in the profile name.
#
#
# [default]
#  region = us-east-1
#
#  s3 =
#     max_concurrent_requests = 100
#     max_queue_size = 10000
#     multipart_threshold = 64MB
#     multipart_chunksize = 16MB
#     max_bandwidth = 4096MB/s
#
#  [profile sandbox]
#  role_arn = arn:aws:iam::<accountid>:role/OrganizationAccountAccessRole
#  source_profile = default
#  region = us-east-1
#
#  etc.

# Add your AWS profile names here
declare -a profile=(
"default"
"sandbox"
"other-AWS-profile-names-you-may-have"
)

# Add S3 bucket names here that should not be screened
# because we already know they are public, are taking a long time,
# were successfully screened by a prior run, or denied access preventing
# the script from running to completion.
declare -a blacklist=(
)


# Loop through AWS profiles
for p in "${profile[@]}"; do


# Set AWS environment variable
export AWS_PROFILE="$p"


# Get complete list of buckets in account
bucket_list=($(aws --profile $p --region us-east-1 s3 ls s3:// --recursive | awk '{print $3}'))
bucket_count=${#bucket_list[@]}

# print summary
echo '----------------------------'
echo 'Account      : ' $p
echo 'Bucket count : ' $bucket_count
echo 'Date taken   : ' $(date)
echo '----------------------------'


# Loop through buckets in account
for i in "${bucket_list[@]}"; do


# Get bucket region location
bucket_location=($(aws s3api --profile $p get-bucket-location --bucket $i | awk '{print $2}'))

# Clean up bucket_location by stripping surrounding quotation marks
  if [ "$bucket_location" = "null" ]; then
    bucket_location="us-east-1"
  elif [ "$bucket_location" = '"us-east-2"' ]; then
    bucket_location="us-east-2"
  elif [ "$bucket_location" = '"us-west-1"' ]; then
    bucket_location="us-west-1"
  elif [ "$bucket_location" = '"us-west-2"' ]; then
    bucket_location="us-west-2"
  elif [ "$bucket_location" = '"ap-northeast-1"' ]; then
    bucket_location="ap-northeast-1"
  else
    echo "no bucket_location found"
  fi


# (OPTIONAL) Get number of objects in bucket ; this is useful to find out
# how large a bucket is but can be time consuming if it turns out to be large.
# If the API call is taking too long, try looking at the
# CloudWatch metrics dashboard from the management console instead.
# number_of_objects=($(aws s3 ls s3://$i --recursive --summarize --human-readable | grep Objects | awk '{print $3}'))

# Echo buckets skipped by blacklist ELSE echo all other audited buckets.
# Buckets that have no publically accessible objects will be indicated with
# 'Private'.  The s3-audit.go script can be modified so it prints 'Public'
# to make the returned output more obvious.
  if [[ " ${blacklist[@]} " =~ " $i " ]]; then
    echo "Skipped" $i "because we know it's public, has a bucket policy, or is extremely large"
  else
    # Retrieve list of objects with public ACL
    # echo $p, $i, $bucket_location, "contains" $number_of_objects "objects"
    echo "Private", $i, $bucket_location

    # Pass AWS profile, bucket, and region information to the invoke s3-audit.go script
    /home/ubuntu/go/src/github.com/s3-audit/s3-audit --profile $p --bucket $i --region $bucket_location
  fi
done
done
echo "Job completed: " $(date)
