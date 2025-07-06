server {
    listen 8080;
    # server_name jenkins.elysium-space.com;

    location / {
        proxy_pass http://${k3s_control_plane_private_ip}:80;
        proxy_set_header Host jenkins.elysium-space.com;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
