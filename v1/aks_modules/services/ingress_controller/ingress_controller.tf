resource "kubernetes_deployment" "nginx_ingress" {
  metadata {
    name = "nginx-ingress-controller"

    labels = {
      app = "nginx-ingress"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "nginx-ingress"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx-ingress"
        }
      }

      spec {
        node_selector = {
          agentpool = var.node_pool_name
        }

        container {
          name  = "nginx-ingress-controller"
          image = "k8s.gcr.io/ingress-nginx/controller:v1.0.0"

          port {
            container_port = 80
            name           = "http"
          }

          port {
            container_port = 443
            name           = "https"
          }

          port {
            container_port = 1433
            name           = "tcp"
          }

          # Readiness probe to check if pod is active
          readiness_probe {
            http_get {
              path = "/healthz"
              port = "http"
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          # Liveness probe to check pod health status
          liveness_probe {
            http_get {
              path = "/healthz"
              port = "http"
            }

            initial_delay_seconds = 15
            period_seconds        = 20
          }
        }
      }
    }
  }
}


resource "kubernetes_service" "nginx_ingress_service" {
  metadata {
    name = "nginx-ingress-service"
  }

  spec {
    selector = {
      app = "nginx-ingress"
    }

    port {
      port        = 80
      target_port = 80
    }

    port {
      port        = 443
      target_port = 443
      protocol    = "TCP"
    }

    port {
      port        = 1433
      target_port = 1433
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }
}
