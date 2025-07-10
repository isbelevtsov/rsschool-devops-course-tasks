stream {
    upstream api {
        server ${k3s_control_plane_private_ip}:6443;
    }
    server {
        listen 6443;
        proxy_pass api;
        proxy_timeout 20s;
    }
}
