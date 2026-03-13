output "ec2_public_ip" {
  description = "EC2 public IP (Elastic IP)"
  value       = aws_eip.api.public_ip
}

output "ssh_command" {
  description = "SSH into the server"
  value       = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ec2-user@${aws_eip.api.public_ip}"
}

output "cloudfront_url" {
  description = "CloudFront HTTPS URL — this is your API URL"
  value       = "https://${aws_cloudfront_distribution.api.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation)"
  value       = aws_cloudfront_distribution.api.id
}

output "s3_bucket_name" {
  description = "S3 bucket for document storage"
  value       = aws_s3_bucket.documents.id
}

output "setup_log" {
  description = "Check bootstrap progress on EC2"
  value       = "ssh ec2-user@${aws_eip.api.public_ip} 'cat /var/log/insurance-rag-setup.log'"
}

# ── Values needed as GitHub Secrets ──────────────────────────────────

output "github_secrets_needed" {
  value = <<-EOT

    ╔══════════════════════════════════════════════════════════════╗
    ║  Add these GitHub Secrets to backend repos:                  ║
    ╠══════════════════════════════════════════════════════════════╣
    ║                                                              ║
    ║  EC2_HOST = ${aws_eip.api.public_ip}                         
    ║  EC2_SSH_KEY = <contents of ~/.ssh/${var.ssh_key_name}.pem>   
    ║  CLOUDFRONT_DIST_ID = ${aws_cloudfront_distribution.api.id}  
    ║                                                              ║
    ╚══════════════════════════════════════════════════════════════╝
  EOT
}
