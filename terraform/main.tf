provider "aws" {
    region = "eu-west-2"
}

terraform {
    backend "s3" {
        bucket         = "ralph-terraform-state"
        key            = "ealing-woodcraft-website"
        region         = "eu-west-2"
        encrypt        = true
    }
}