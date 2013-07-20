(function HEAD (root-domain) <<-END
#
# AgentBox nginx configuration
# this file was automatically generated
#
worker_processes  8;

events {
    worker_connections  1024;
}

http {
    root #{AGENTBOX-PATH}/public;
    error_page 404  /404.html;
    error_page 403  /403.html;
    error_page 502  /502.html;

    log_format agentbox '$msec|$time_local|$host|$request|$status|$bytes_sent|$request_time|$remote_addr|$http_referer|$http_user_agent|||';
    access_log #{AGENTBOX-PATH}/var/nginx-access.log agentbox;
    error_log #{AGENTBOX-PATH}/var/nginx-error.log debug;

    ssl_certificate     #{AGENTBOX-PATH}/chief/etc/wildcard_agent_io.crt;
    ssl_certificate_key #{AGENTBOX-PATH}/chief/etc/wildcard_agent_io.key;

    large_client_header_buffers 4 32k;

    gzip on;
    gzip_proxied any;

    types_hash_bucket_size 64;
    types {
        application/x-mpegURL                   m3u8;
        video/MP2T                              ts;
        video/mp4                               mp4;
        application/xml                         xml;
        image/gif                               gif;
        image/jpeg                              jpg;
        image/png                               png;
        image/bmp                               bmp;
        image/x-icon                            ico;
        text/css                                css;
        text/html                               html;
        text/plain                              txt;
        application/pdf                         pdf;
        text/xml                                plist;
        application/octet-stream                dmg;
        application/octet-stream                ipa;
        application/octet-stream                mobileprovision;
        application/x-apple-aspen-config        mobileconfig;
    }
    default_type       text/html;

    server_names_hash_bucket_size 64;
    server_names_hash_max_size 8192;
    server {
        listen          80;
        listen          443 ssl;
        server_name     chief.#{root-domain};
        location / {
            proxy_set_header Host $host;
            proxy_pass  http://127.0.0.1:2010/;
        }
        client_max_body_size 10M;
    }

    server {
        listen          80;
        listen          443 ssl;
        server_name     api.#{root-domain};
        location / {
            proxy_set_header Host $host;
            proxy_pass  http://127.0.0.1:2013/;
        }
        client_max_body_size 10M;
    }
END)

(function MORE (root-domain) <<-END
    server {
        listen          80;
        listen          443 default ssl;
        server_name     #{root-domain};
        root            #{AGENTBOX-PATH}/public;
        index           index.html;
        location / {
            try_files $uri.html $uri $uri/ =404;
        }
    }

END)

(function nginx-service (app)
          (if (app deployment:)
              (then (set listen "listen 80;")
                    (set range ((app domains:) rangeOfString:(get-property "root-domain")))
                    (if (> (range 1) 0)
                        (listen appendString:" listen 443 ssl;"))
                    (set domains (app domains:))
                    (set port ((((app deployment:) workers:) 0) port:))
                    (set servers "")
                    (((app deployment:) workers:) each:
                     (do (worker)
                         (servers appendString:(+ "        server 127.0.0.1:" (worker port:) ";\n"))))
                    (set s <<-END
    upstream #{(app _id:)} {
#{servers}    }
    server {
        #{listen}
        server_name     #{domains};
        location / {
            proxy_set_header Host $host;
            proxy_pass  http://#{(app _id:)};
            proxy_set_header X-Forwarded-For $remote_addr;
        }
    }
END))
              (else (set s "")))
          s)

(set TAIL <<-END

    server {
        listen          80;
        server_name     ~^(.*)$;
        error_page 404  /404.html;
        error_page 403  /403.html;
        error_page 502  /502.html;
    }
}       
END)

(function nginx-config-with-services (root-domain apps)
          (set config (+ (HEAD root-domain)
                         ((apps map:
                                (do (app)
                                    (nginx-service app)))
                          componentsJoinedByString:"\n")
                         TAIL))
          ;(puts "--------- nginx.config -- START ----------")
          ;(puts config)
          ;(puts "--------- nginx.config --- END ------------")
          config)

(function nginx-conf-path ()
          (if (eq (uname) "Linux")
              (then "/etc/nginx/nginx.conf")
              (else "#{AGENTBOX-PATH}/nginx/nginx.conf")))

(function nginx-path ()
          (if (eq (uname) "Linux")
              (then "/usr/sbin/nginx")
              (else "/usr/local/nginx/sbin/nginx")))

(function restart-nginx ()
          ((NSFileManager defaultManager) removeItemAtPath:(nginx-conf-path) error:nil)
          (set apps (mongo findArray:nil inCollection:(+ SITE ".apps")))
          ((nginx-config-with-services (get-property "root-domain") apps)
           writeToFile:(nginx-conf-path) atomically:YES)
          (system "#{(nginx-path)} -s reload -c #{(nginx-conf-path)} -p #{AGENTBOX-PATH}/nginx/"))

(function prime-nginx ()
          (set root-domain (get-property "root-domain"))
          ((NSFileManager defaultManager) removeItemAtPath:(nginx-conf-path) error:nil)
          ((nginx-config-with-services root-domain (array)) writeToFile:(nginx-conf-path) atomically:YES)
          ;; site index
          ((&html (&head (&title "X Machine"))
                  (&body style:"background-color:#000; color:#FFF; font-family:Helvetica;"
                         (&p (&strong "This is X Machine."))
                         (&p "Running at " root-domain ".")))
           writeToFile:"#{AGENTBOX-PATH}/public/index.html" atomically:NO)
          ;; chief redirect
          ((&a href:(+ "http://chief." root-domain) "OK, Continue")
           writeToFile:"#{AGENTBOX-PATH}/public/chief.html" atomically:NO))
