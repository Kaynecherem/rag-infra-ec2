# ── ACM Certificate for api.agencylensai.com ─────────────────────────
# Must be in us-east-1 for CloudFront

resource "aws_acm_certificate" "api" {
  provider          = aws.us_east_1
  domain_name       = "api.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.project_name}-api-cert" }
}

# ── CloudFront Distribution ──────────────────────────────────────────

resource "aws_cloudfront_distribution" "api" {
  enabled         = true
  comment         = "${var.project_name} API"
  is_ipv6_enabled = true
  aliases         = ["api.${var.domain_name}"]

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

  origin {
    domain_name = aws_eip.api.public_dns
    origin_id   = "ec2-superadmin-api"

    custom_origin_config {
      http_port              = 8001
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Superadmin API — must come before the default behavior
  ordered_cache_behavior {
    path_pattern           = "/api/v1/superadmin/*"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "ec2-superadmin-api"
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id          = data.aws_cloudfront_cache_policy.no_cache.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_all.id
  }

  # Health check — brief caching
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

  # Widget JS — longer caching
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

  # Default — client API, no caching
  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "ec2-api"
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id          = data.aws_cloudfront_cache_policy.no_cache.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.forward_all.id
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.api.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = { Name = "${var.project_name}-cdn" }

  depends_on = [aws_acm_certificate_validation.api]
}

# ── Certificate DNS Validation ───────────────────────────────────────

# Output the validation records — you add these at your registrar
# Terraform waits for validation before attaching to CloudFront

resource "aws_acm_certificate_validation" "api" {
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.api.arn

  # This will block until the certificate is validated
  # You need to add the DNS record at your registrar first
  timeouts {
    create = "30m"
  }
}

# ── Cache Policies ───────────────────────────────────────────────────

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
    query_string_behavior = "all"
  }
}
