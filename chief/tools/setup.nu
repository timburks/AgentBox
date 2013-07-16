(load "components/config")
(load "components/database")
(load "components/nginx")

(set-property "root-domain" "86.agent.io")
(set-property "deus-domain" "deus.86.agent.io")

(set-username-password "admin" "password123")

(prime-nginx)
;(restart-nginx)
