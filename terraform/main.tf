provider "aws" {
    region = "eu-west-2"
}

provider "aws" {
    alias  = "us-east-1"
    region = "us-east-1"
}

terraform {
    backend "s3" {
        bucket         = "ralph-terraform-state"
        key            = "ealing-woodcraft-website"
        region         = "eu-west-2"
        encrypt        = true
    }
}