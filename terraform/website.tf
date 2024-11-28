#based on https://registry.terraform.io/modules/fillup/hugo-s3-cloudfront/aws/latest
#But we need to use another provider to make the cert work

/*
 * Create S3 bucket with appropriate permissions
 */

data "aws_caller_identity" "current" {}


locals {
  bucket_policy = templatefile("./bucket-policy.json", {
    bucket_name         = var.bucket_name
    deployment_user_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/github-role"
  })
}

resource "aws_s3_bucket" "hugo" {
  bucket        = var.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "hugo_ownership" {
  bucket = aws_s3_bucket.hugo.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "public_static_acl" {
  bucket = aws_s3_bucket.hugo.id
  acl    = "private"
}

data "aws_iam_policy_document" "s3_policy_public_static" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.hugo.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_distribution.hugo.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "public_static_policy" {
  bucket = aws_s3_bucket.hugo.id
  policy = data.aws_iam_policy_document.s3_policy_public_static.json
}

resource "aws_s3_bucket_website_configuration" "hugo" {
  bucket = aws_s3_bucket.hugo.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "public/404.html"
  }

  // Routing rule is needed to support hugo friendly urls
  routing_rules = <<EOF
[{
    "Condition": {
        "KeyPrefixEquals": "/"
    },
    "Redirect": {
        "ReplaceKeyWith": "index.html"
    }
}]
EOF
}

resource "aws_s3_bucket_cors_configuration" "hugo" {
  bucket = aws_s3_bucket.hugo.id
  cors_rule {
    allowed_headers = []
    allowed_methods = ["GET"]
    allowed_origins = ["https://s3.amazonaws.com"]
    expose_headers  = []
    max_age_seconds = 3000
  }
}

// Get ACM cert for use with CloudFront
data "aws_acm_certificate" "cert" {
  domain   = "webtest.ealingwoodcraft.org.uk"
  provider = aws.us-east-1
}

/*
 * Create CloudFront distribution for SSL support but caching disabled, leave that to Cloudflare
 */
resource "aws_cloudfront_distribution" "hugo" {
  depends_on = [aws_s3_bucket.hugo]

  origin {
    domain_name = aws_s3_bucket_website_configuration.hugo.website_endpoint
    origin_id   = "hugo-s3-origin"
    origin_path = "/public"

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  dynamic "custom_error_response" {
    for_each = []
    content {
      error_code         = custom_error_response.value.error_code
      response_code      = custom_error_response.value.response_code
      response_page_path = custom_error_response.value.response_page_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = ["webtest.ealingwoodcraft.org.uk"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "hugo-s3-origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"

    // Using CloudFront defaults, tune to liking
    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  price_class = "PriceClass_100"

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2019"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}
