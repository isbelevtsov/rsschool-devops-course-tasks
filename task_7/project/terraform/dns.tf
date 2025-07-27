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

resource "aws_route53_record" "ses_dkim_records" {
  count   = 3
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "${aws_ses_domain_dkim.monitoring_email.dkim_tokens[count.index]}._domainkey.${var.route53_domain}"
  type    = "CNAME"
  ttl     = 300
  records = ["${aws_ses_domain_dkim.monitoring_email.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_route53_record" "ses_domain_verification" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "_amazonses.${var.route53_domain}"
  type    = "TXT"
  ttl     = 300
  records = [aws_ses_domain_identity.monitoring_email.verification_token]
}
