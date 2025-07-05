upstream jenkins {
    server ${k3s_controlplane_private_ip}:8080;
}

server {
    listen 8080;
    server_name jenkins.elysium-space.com;

    location / {
        proxy_pass http://jenkins;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
