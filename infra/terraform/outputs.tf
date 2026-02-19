output "ec2_public_ip" {
  description = "EC2 public IP (Elastic IP)"
  value       = aws_eip.api.public_ip
}

output "ssh_command" {
  description = "SSH into the server"
  value       = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ec2-user@${aws_eip.api.public_ip}"
}

output "cloudfront_url" {
  description = "CloudFront HTTPS URL - this is your API URL"
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

output "next_steps" {
  value = <<-EOT

    ╔══════════════════════════════════════════════════════════════╗
    ║  DEPLOYMENT COMPLETE - Next Steps:                          ║
    ╠══════════════════════════════════════════════════════════════╣
    ║                                                              ║
    ║  1. SSH into the server:                                     ║
    ║     ssh -i ~/.ssh/${var.ssh_key_name}.pem ec2-user@${aws_eip.api.public_ip}    ║
    ║                                                              ║
    ║  2. Clone your code:                                         ║
    ║     cd /opt/insurance-rag                                    ║
    ║     sudo git clone <YOUR_REPO> .                             ║
    ║                                                              ║
    ║  3. Start the stack:                                         ║
    ║     sudo docker compose up -d --build                        ║
    ║                                                              ║
    ║  4. Test:                                                    ║
    ║     curl https://${aws_cloudfront_distribution.api.domain_name}/health  ║
    ║                                                              ║
    ╚══════════════════════════════════════════════════════════════╝
  EOT
}
