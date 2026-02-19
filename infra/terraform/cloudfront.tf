# ── CloudFront Distribution ──────────────────────────────────────────
# Provides HTTPS URL (*.cloudfront.net) for free
# Later: add custom domain with ACM certificate

resource "aws_cloudfront_distribution" "api" {
  enabled         = true
  comment         = "${var.project_name} API"
  is_ipv6_enabled = true

  origin {
    domain_name = aws_eip.api.public_dns
    origin_id   = "ec2-api"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # EC2 serves HTTP, CloudFront terminates SSL
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "ec2-api"
    viewer_protocol_policy = "redirect-to-https"

    # Don't cache API responses
    cache_policy_id          = data.aws_cloudfront_cache_policy.no_cache.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_all.id
  }

  # Health check endpoint can be cached briefly
  ordered_cache_behavior {
    path_pattern           = "/health"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "ec2-api"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 30
    max_ttl     = 60
  }

  # Widget JS can be cached longer
  ordered_cache_behavior {
    path_pattern           = "/widget/*"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "ec2-api"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    # When adding custom domain later:
    # acm_certificate_arn      = aws_acm_certificate.custom.arn
    # ssl_support_method       = "sni-only"
    # minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = { Name = "${var.project_name}-cdn" }
}

# ── Cache Policy: No caching for API ────────────────────────────────

# Use AWS managed "CachingDisabled" policy
data "aws_cloudfront_cache_policy" "no_cache" {
  name = "Managed-CachingDisabled"
}

# ── Origin Request Policy: Forward everything ───────────────────────

resource "aws_cloudfront_origin_request_policy" "forward_all" {
  name    = "${var.project_name}-forward-all"
  comment = "Forward all headers, cookies, query strings to origin"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = "allViewer"
  }

  query_strings_config {
    query_string_behavior = "none"
  }
}
