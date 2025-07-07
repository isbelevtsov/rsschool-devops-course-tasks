pipeline {
  agent {
    kubernetes {
      label 'kaniko-agent'  // Matches your predefined pod template
      defaultContainer 'kaniko'
    }
  }

  parameters {
        string(name: 'IMAGE', defaultValue: 'isbelevtsov/task-5', description: 'Docker image name (including repo)')
        string(name: 'TAG', defaultValue: 'latest', description: 'Image tag')
  }

  stages {
    stage('Build & Push with Kaniko') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'DOCKER_HUB_CREDS', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh '''
            mkdir -p /kaniko/.docker
            cat <<EOF > /kaniko/.docker/config.json
            {
              "auths": {
                "https://index.docker.io/v1/": {
                  "username": "$DOCKER_USER",
                  "password": "$DOCKER_PASS",
                  "auth": "$(echo -n "$DOCKER_USER:$DOCKER_PASS" | base64)"
                }
              }
            }
EOF

            /kaniko/executor \
              --context=$(pwd)/task_5/project/app \
              --dockerfile=$(pwd)/task_5/project/app/Dockerfile \
              --destination=${IMAGE}:${TAG} \
              --insecure \
              --skip-tls-verify
          '''
        }
      }
    }
  }
}
