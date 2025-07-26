upstream flask {
  keepalive 32;
  server ${k3s_control_plane_private_ip}:80;
}

server {
  listen 80;
  server_name flask.${route53_domain};

  access_log /var/log/nginx/flask.access.log;
  error_log /var/log/nginx/flask.error.log;

  ignore_invalid_headers off;

  location / {
    proxy_pass         http://flask;
    proxy_redirect     default;
    proxy_http_version 1.1;

    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;

    proxy_set_header   Upgrade           $http_upgrade;
    proxy_set_header   Connection        $connection_upgrade;

    client_max_body_size       10m;
    client_body_buffer_size    128k;

    proxy_connect_timeout      90;
    proxy_send_timeout         90;
    proxy_read_timeout         90;
    proxy_request_buffering    off;
  }
}
