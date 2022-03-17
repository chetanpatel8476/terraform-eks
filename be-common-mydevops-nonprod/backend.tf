terraform {
  backend "s3" {
    region = "eu-west-1"
    bucket = "mydevops-terraform-remote-tfstates-nonprod"
    dynamodb_table = "terraform-tfstates-lock-nonprod"
    key = "be-common-mydevops-nonprod/terraform.tfstate"
    profile = "svn"
  }
}