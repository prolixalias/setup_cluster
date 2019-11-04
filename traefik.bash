helm install stable/traefik --name traefik --set dashboard.enabled=true,serviceType=NodePort,dashboard.domain=dashboard.traefik,rbac.enabled=true  --namespace kube-system
