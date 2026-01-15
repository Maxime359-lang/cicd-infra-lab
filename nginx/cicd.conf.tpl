# HTTP: only ACME + redirect to HTTPS
server {
    listen 80;
    server_name cicd-github.<EC2_IP>.nip.io cicd-gitlab.<EC2_IP>.nip.io;

    location /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
        default_type "text/plain";
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS: GitHub app
server {
    listen 443 ssl;
    http2 on;
    server_name cicd-github.<EC2_IP>.nip.io;

    ssl_certificate     /etc/letsencrypt/live/cicd-nipio/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/cicd-nipio/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;

    # --- Security headers (enterprise baseline) ---
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header Referrer-Policy "no-referrer" always;

    location / {
        proxy_pass http://127.0.0.1:8081;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 5s;
        proxy_read_timeout 30s;
        proxy_send_timeout 30s;

        proxy_buffering on;
    }
}

# HTTPS: GitLab app
server {
    listen 443 ssl;
    http2 on;
    server_name cicd-gitlab.<EC2_IP>.nip.io;

    ssl_certificate     /etc/letsencrypt/live/cicd-nipio/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/cicd-nipio/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;

    # --- Security headers (enterprise baseline) ---
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header Referrer-Policy "no-referrer" always;

    location / {
        proxy_pass http://127.0.0.1:8082;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 5s;
        proxy_read_timeout 30s;
        proxy_send_timeout 30s;

        proxy_buffering on;
    }
}
