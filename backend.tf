terraform {
  backend "s3" {
    bucket = "roby-terraform-course"
    key    = "global/s3/terraform.tfstate"
    region = "eu-west-2"

    dynamodb_table = "rob-terraform-course-locks"
    encrypt        = true
  }
}