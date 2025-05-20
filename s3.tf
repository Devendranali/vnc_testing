provider "aws" {
    region = "us-east-1"
    access_key = "---"
    secret_key = "---"
}

resource "aws_s3_bucket" "aws_s3" {
    bucket = "vnc_bucket" 
}

resource "aws_s3_bucket_versioning" "aws_version" {
    bucket = aws_s3_bucket.aws_s3
    bucket_versioning = {
        status = "Enabled"
    }
}

resource "aws_s3_bucket_ownership_controls" "aws_owner" {
    bucket = aws_s3_bucket.aws_s3
    rule {
        object_ownership = "BucketOwnerEnforced"
    }
} 

resource "aws_s3_bucket_acl" "aws_acl" {
    depends_on = [aws_s3_bucket_ownership_controls.example]
    bucket = aws_s3_bucket.aws.aws_s3
    acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.aws.s3

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}