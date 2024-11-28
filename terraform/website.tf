module "hugosite" {
  source              = "github.com/fillup/terraform-hugo-s3-cloudfront"
  aliases             = ["webtest.ealingwoodcraft.org.uk"]
  bucket_name         = "webtest.ealingwoodcraft.org.uk"
  cert_domain         = "ealingwoodcraft.org.uk"
  deployment_user_arn = var.deployment_user_arn
}