NGINX_SITES_AVAILABLE='/usr/local/etc/nginx/sites-available'
NGINX_SITES_ENABLED='/usr/local/etc/nginx/sites-enabled'

if [ -z $1 ]; then
	echo "No domain name given"
	exit 1
fi

DOMAIN=$1
 
# check the domain is roughly valid!
PATTERN="^([[:alnum:]]([[:alnum:]\-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,6}$"
if [[ "$DOMAIN" =~ $PATTERN ]]; then
	DOMAIN=`echo $DOMAIN | tr '[A-Z]' '[a-z]'`
	echo "Creating hosting for:" $DOMAIN
else
	echo "invalid domain name"
	exit 1
fi

VHOST_CONF_NAME="${NGINX_SITES_AVAILABLE}/${DOMAIN}.conf"


echo "Creating new vhost file in: ${VHOST_CONF_NAME}"

touch "${VHOST_CONF_NAME}"

cat <<EOF >> $VHOST_CONF_NAME
server {
	listen 80;

	server_name $DOMAIN www.$DOMAIN;

	root ~/Sites/$DOMAIN;
	index index.php index.html;

    if (\$request_uri ~* "^(.*/)index\.php\$") {
        return 301 \$1;
    }

    error_log  /usr/local/var/log/nginx/$DOMAIN.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
        expires 30d;
    }

    #rewrite ^/index.php/(.*) /\$1  permanent;

    location /app/                       { deny all; }
    location /includes/                  { deny all; }
    location /lib/                       { deny all; }
    location /media/downloadable/        { deny all; }
    location /pkginfo/                   { deny all; }
    location /report/config.xml          { deny all; }
    location ^~ /var/ { return 403; }
    location ^~ /dev/ { return 403; }
    location ~ /\.(git|svn) {     return 404; }

    location /var/export/ {
        auth_basic              "Restricted";
        auth_basic_user_file    htpasswd;
        autoindex               on;
    }

    location ~ /ga.js {
        proxy_pass https://www.google-analytics.com;
        expires 7d;
        proxy_set_header Pragma "public";
        proxy_set_header Cache-Control "max-age=604800, public";
    }

    location ~* \.(eot|ttf|woff|woff2|json|css|js)\$ {
        add_header Access-Control-Allow-Origin "*";
        add_header Access-Control-Allow-Methods "POST, GET, OPTIONS, DELETE, PUT";
        add_header Access-Control-Allow-Headers "Content-Type, Accept";
        gzip_static on;
        expires 30d;
        add_header Cache-Control public;
    }

    location @handler {
        rewrite / /index.php;
    }

    location ~* \.(jp?eg|png|gif|ico|svg)\$ {
       gzip_static on;
       expires 30d;
       add_header Cache-Control public;
    }

    location ~ .php/ {
        rewrite ^(.*.php)/ \$1 last;
    }

    location ~ \.php\$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass 127.0.0.1:9001;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

}
EOF

ln -s $VHOST_CONF_NAME $NGINX_SITES_ENABLED/$DOMAIN.conf

echo "Site Created for $DOMAIN"

echo "Restarting nginx..."

sudo brew services restart nginx

echo "Nginx restarted."