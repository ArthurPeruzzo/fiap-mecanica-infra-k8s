resource "aws_s3_bucket" "bucket-backend" {
  bucket = var.project_name
  tags   = var.tags
}
