output "load_balancer_hostname" {
  description = "Load balancer hostname"
  value       = kubernetes_service.nginx_ingress_service.status.0.load_balancer.0.ingress.0.hostname
}


output "load_balancer_ip" {
  description = "Load balancer IP of ingress controller"
  value       = kubernetes_service.nginx_ingress_service.status.0.load_balancer.0.ingress.0.ip
}
