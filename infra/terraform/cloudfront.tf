# ── CloudFront Distribution ──────────────────────────────────────────

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
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "ec2-api"
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id          = data.aws_cloudfront_cache_policy.no_cache.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_all.id
  }

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
  }

  tags = { Name = "${var.project_name}-cdn" }
}

data "aws_cloudfront_cache_policy" "no_cache" {
  name = "Managed-CachingDisabled"
}

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
