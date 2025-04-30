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

    aws_access_key = os.getenv('AWS_ACCESS_KEY_ID')
    aws_secret_key = os.getenv('AWS_SECRET_ACCESS_KEY')
    aws_region = 'us-east-2'

    s3 = boto3.client(
        's3',
        aws_access_key_id=aws_access_key,
        aws_secret_access_key=aws_secret_key,
        region_name=aws_region
    )

    print("Building Intel Mac installer.")
    # build the mac installer
    subprocess.run(['./macInstaller/build-macInstaller.sh', 'femr', args.version, "1"], input=b'N', check=True)

    print('Uploading Intel Mac installer to S3. This may take a while...')

    s3.upload_file(
        f'./macInstaller/target/pkg/femr-macos-installer-intel-{args.version}.pkg', 
        BUCKET_NAME, 
        f'macos/intel/{args.version}/femr-intel-{args.version}.pkg'
    )

    print("Building Apple Silicon Mac installer.")
    # build the mac installer
    subprocess.run(['./macInstaller/build-macInstaller.sh', 'femr', args.version, "2"], input=b'N', check=True)

    print('Uploading Arm Mac installer to S3. This may take a while...')

    s3.upload_file(
        f'./macInstaller/target/pkg/femr-macos-installer-arm-{args.version}.pkg', 
        BUCKET_NAME, 
        f'macos/arm/{args.version}/femr-arm-{args.version}.pkg'
    )

if __name__ == "__main__":
    main()

