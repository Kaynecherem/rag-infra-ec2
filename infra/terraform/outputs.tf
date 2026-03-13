output "ec2_public_ip" {
  description = "EC2 public IP (Elastic IP)"
  value       = aws_eip.api.public_ip
}

output "ssh_command" {
  description = "SSH into the server"
  value       = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ec2-user@${aws_eip.api.public_ip}"
}

output "cloudfront_url" {
  description = "CloudFront HTTPS URL (legacy — use api.agencylensai.com instead)"
  value       = "https://${aws_cloudfront_distribution.api.domain_name}"
}

output "api_url" {
  description = "Custom API URL"
  value       = "https://api.${var.domain_name}"
}

output "cloudfront_domain" {
  description = "CloudFront domain (for CNAME record)"
  value       = aws_cloudfront_distribution.api.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation)"
  value       = aws_cloudfront_distribution.api.id
}

output "s3_bucket_name" {
  description = "S3 bucket for document storage"
  value       = aws_s3_bucket.documents.id
}

# ── DNS Records You Need to Add ──────────────────────────────────────

output "dns_records_to_add" {
  description = "Add these DNS records at your domain registrar"
  value = <<-EOT

    ╔══════════════════════════════════════════════════════════════════╗
    ║  DNS RECORDS — Add these at your domain registrar               ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║                                                                  ║
    ║  1. API (CNAME):                                                 ║
    ║     Name:  api                                                   ║
    ║     Value: ${aws_cloudfront_distribution.api.domain_name}        
    ║                                                                  ║
    ║  2. Console (CNAME):                                             ║
    ║     Name:  console                                               ║
    ║     Value: cname.vercel-dns.com                                  ║
    ║                                                                  ║
    ║  3. Wildcard for tenant subdomains (CNAME):                      ║
    ║     Name:  *                                                     ║
    ║     Value: cname.vercel-dns.com                                  ║
    ║                                                                  ║
    ╚══════════════════════════════════════════════════════════════════╝
  EOT
}

output "acm_validation_records" {
  description = "ACM certificate DNS validation records"
  value = {
    for dvo in aws_acm_certificate.api.domain_validation_options : dvo.domain_name => {
      type  = dvo.resource_record_type
      name  = dvo.resource_record_name
      value = dvo.resource_record_value
    }
  }
}

output "setup_log" {
  description = "Check bootstrap progress on EC2"
  value       = "ssh ec2-user@${aws_eip.api.public_ip} 'cat /var/log/insurance-rag-setup.log'"
}
