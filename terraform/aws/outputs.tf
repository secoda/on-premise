output "aws_lb_dns" {
  description = "The load balancer url. This will start returning HTTP 200 approx. 5 minutes after the terraform is deployed."
  value       = module.ecs.aws_lb_dns
}

output "security_group_id" {
  description = "ECS security group ID used for Secoda"
  value       = aws_security_group.ecs_sg.id
}
