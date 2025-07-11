# Lookup the public hosted zone using the variable
data "aws_route53_zone" "this" {
  name         = var.route53_domain
  private_zone = false
}

# Create a wildcard A record
resource "aws_route53_record" "wildcard_bastion" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "*.${var.route53_domain}"
  type    = "A"
  ttl     = 300

  records = [aws_instance.bastion.public_ip]

  depends_on = [aws_instance.bastion]
}
