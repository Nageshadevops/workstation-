# AWS credentials come from ~/.aws/credentials of user siddug (aws configure).
provider "aws" {
  region = var.aws_region

  # These tags are added to every resource, so you can find them in the console.
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
