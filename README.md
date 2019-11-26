

# get minikube running
minikube start --cpus 3 --memory 8192                               # k8s v1.16.2 default as of 07NOV2019
minikube start --cpus 3 --memory 8192 --kubernetes-version v1.14.7  # k8s v1.14.7 aligns with UCP v2.3.2

# start dashboard in the background:
minikube dashboard &

# get helm/tiller running
kubectl apply -f tiller_sa_crb.yaml
helm init # wait for tiller pod to start in kube-system namespace
kubectl get pods -n kube-system

# install traefik:
helm install stable/traefik --name traefik --set dashboard.enabled=true,serviceType=NodePort,dashboard.domain=traefik.localdev,rbac.enabled=true --namespace kube-system
kubectl describe svc traefik --namespace kube-system
# put: "$(minikube ip) traefik.localdev" in /etc/hosts
# visit http://$(minikube ip):NodePort/

# create namespace(s)
kubectl apply -f namespaces.yaml

# add ingress for host-based resolution
kubectl apply -f ingress_host.yaml

# add ingress for URI-based translation
kubectl apply -f ingress_uri.yaml

# install docker pod
kubectl apply -f docker.yaml

# test docker pod
kubectl exec -ti docker -n localdev sh

# use minikube docker env
eval $(minikube docker-env)

# leave minikube docker env
eval $(minikube docker-env -u)

# create persistent volume(s)
kubectl apply -f pv.yaml

# setup registry
helm install --name docker-registry stable/docker-registry --set service.type=NodePort --namespace localdev

# setup jenkins master (default namespace):
#  jenkins slaves, one for build/deploy (localdev namespace):
#  use jenkins k8s plugin
helm install --name jenkins -f values-jenkins.yaml stable/jenkins --namespace localdev
printf $(kubectl get secret --namespace localdev jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode); echo
# add 'http://jenkins.localdev.svc.cluster.local:8080' as 'Jenkins URL' in 'Manage Jenkins' section

# setup chart museum
helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm repo update
helm install --name chartmuseum stable/chartmuseum --set service.type=NodePort --namespace localdev

# setup gitlab:
helm repo add gitlab https://charts.gitlab.io
helm repo update
helm search -l gitlab/gitlab
#helm get values gitlab > gitlab-values.yaml
helm upgrade --install gitlab gitlab/gitlab --timeout 600 -f values-gitlab.yaml --namespace localdev
printf $(kubectl get secret gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' --namespace localdev | base64 --decode); echo



Prepare Your Applications:

	Follow these guidelines when preparing your applications:

    Package your applications in a Docker Image according to the Docker Best Practices.
    To run the same Docker container in any of these environments: Development, Staging or Production, separate the processes and the configurations as follows:
        For Development: Create a default configuration.
        For Staging and Production: Create a non-default configuration using one or more:
            Configuration files that can be mounted into the container during runtime.
            Environment variables that are passed to the Docker container.


The 6-Step Automated CI/CD Pipeline in Kubernetes in Action
	General Assumptions and Guidelines:

    These steps are aligned with the best practices when running Jenkins agent(s).
    Assign a dedicated agent for building the App, and an additional agent for the deployment tasks. This is up to your good judgment.
    Run the pipeline for every branch. To do so, use the Jenkins Multibranch pipeline job (https://jenkins.io/doc/book/pipeline/multibranch/).

    Get code from Git
        Developer pushes code to Git, which triggers a Jenkins build webhook.
        Jenkins pulls the latest code changes.
    Run build and unit tests
        Jenkins runs the build.
        Application�s Docker image is created during the build.- Tests run against a running Docker container.
    Publish Docker image and Helm Chart
        Application�s Docker image is pushed to the Docker registry.
        Helm chart is packed and uploaded to the Helm repository.
    Deploy to Development
        Application is deployed to the Kubernetes development cluster or namespace using the published Helm chart.
        Tests run against the deployed application in Kubernetes development environment.
    Deploy to Staging
        Application is deployed to Kubernetes staging cluster or namespace using the published Helm chart.
        Run tests against the deployed application in the Kubernetes staging environment.
    [Optional] Deploy to Production
        The application is deployed to the production cluster if the application meets the defined criteria. Please note that you can set up as a manual approval step.
        Sanity tests run against the deployed application.
        If required, you can perform a rollback.

