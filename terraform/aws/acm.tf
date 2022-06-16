resource "tls_private_key" "alb" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "alb" {
  private_key_pem = tls_private_key.alb.private_key_pem

  subject {
    common_name  = "on-premise.secoda.co"
    organization = "Client per Secoda"
  }

  validity_period_hours = 87600 # 10 years.

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "alb" {
  count = var.certificate_arn == "" ? 1 : 0

  private_key      = tls_private_key.alb.private_key_pem
  certificate_body = tls_self_signed_cert.alb.cert_pem
}
