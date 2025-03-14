import boto3
import argparse
import os
import subprocess

# CLI example
# python3 release.py --version 1.0.0

BUCKET_NAME = 'fibula-femr-installer'

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True, help="version of the release")
    args = parser.parse_args()

    # build the mac installer
    subprocess.run(['./macOS-x64/build-macos-x64.sh', 'femr', args.version], input=b'N', check=True)

    aws_access_key = os.getenv('AWS_ACCESS_KEY_ID')
    aws_secret_key = os.getenv('AWS_SECRET_ACCESS_KEY')
    aws_region = 'us-east-2'

    s3 = boto3.client(
        's3',
        aws_access_key_id=aws_access_key,
        aws_secret_access_key=aws_secret_key,
        region_name=aws_region
    )

    print('Uploading macOS installer to S3. This may take a while...')

    s3.upload_file(
        f'./macOS-x64/target/pkg/femr-macos-installer-x64-{args.version}.pkg', 
        BUCKET_NAME, 
        f'macos/{args.version}/femr-x64-{args.version}.pkg'
    )

if __name__ == "__main__":
    main()

