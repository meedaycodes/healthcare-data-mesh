import boto3
import os

def init_minio():
    s3 = boto3.client(
        's3',
        endpoint_url='http://minio:9000',
        aws_access_key_id='admin',
        aws_secret_access_key='password',
        region_name='us-east-1'
    )

    buckets = ['landing-zone', 'healthcare-warehouse']

    for bucket in buckets:
        try:
            s3.head_bucket(Bucket=bucket)
            print(f"Bucket '{bucket}' already exists.")
        except:
            print(f"Creating bucket '{bucket}'...")
            s3.create_bucket(Bucket=bucket)
            print(f"Bucket '{bucket}' created successfully.")

if __name__ == "__main__":
    init_minio()
