output "aws_lb_dns" {
  description = "The load balancer url. This will start returning HTTP 200 approx. 5 minutes after the terraform is deployed."
  value       = module.ecs.aws_lb_dns
}
