# Create Route53 zone
resource "aws_route53_zone" "this" {
  name = var.domain
}

# Create Route53 alias record for the ALB
resource "aws_route53_record" "this" {
  zone_id = aws_route53_zone.this.zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = false
  }
}

# Create the certificate for the ALB
resource "aws_acm_certificate" "this" {
  domain_name       = var.domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}
