# Jenkins instalation script
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Download deployment files
mv /tmp/jenkins_ingress.yaml /opt/jenkins/conf
mv /tmp/ebs_storage_class.yaml /opt/jenkins/conf
mv /tmp/jenkins_pvc.yaml /opt/jenkins/conf
mv /tmp/jenkins_values.yaml /opt/jenkins/conf

# Create the Jenkins namespace and apply persistent store configurations
cd /opt/jenkins/conf
kubectl create namespace jenkins
kubectl apply -f jenkins_pvc.yaml -n jenkins

# Install Jenkins
helm install jenkins jenkins/jenkins -n jenkins -f jenkins_values.yaml
#Create ingress Traefik controller rule
kubectl apply -f jenkins_ingress.yaml -n jenkins
#Waiting for creation
sleep 30
sudo chown -R 1000:1000 /data/jenkins-data
