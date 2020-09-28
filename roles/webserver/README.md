# webserver

Configures webserver and could define managed websites.

## Role Variables


* *webserver_daemon* - defaults to 'nginx'
* *webserver_ssl_protocols* - based on mozilla SSL Configuration
  Generator intermediate
* *webserver_ssl_ciphers* - based on mozilla SSL Configuration
  Generator intermediate
* *webserver_www_dir* - a helper directory which has symlinks to real
  website content location
* *webserver_www_users_dir* - directory holding directories based on
  websites owner, ie. if owner is 'foobar' and first domain is
  'foobar.example.com', then there will be
  `foobar/foobar.example.com/html` inside this directory
* *webserver_nginx_conf_site_dir* - directory where websites
  configuration is placed
* *webserver_websites* - list of websites
* *webserver_websites_postremove_cleanup* - if to remove website
  content after the website got unlinked from webserver configuration,
  ie. it was removed from ansible variables

### Individual website variables

* *urls* - list of website domains, first one is used to create
  directories and filenames either holding website content or
  definition
* *tls* - map
* *tls.certificate* - path to TLS certificate
* *tls.key* - path to TLS key
* *tls.trusted_certificate* - path to trusted CA certificates for OCSP
  or client certificate verification
* *nginx_extra_paramenters* - literal block of nginx parameters to be
  placed in website nginx configuration


## Example playbook to configure webserver

Including an example of how to use your role (for instance, with
variables passed in as parameters) is always nice for users too:

    - hosts: "{{ target | default('role_webserver') }}"
	  tasks:
	    - import_role:
		    name: webserver

## An example PHP website

Let's assume PHP-FPM is already configured correctly. All is needed is
to inform webserver how to talk to PHP-FPM website unix socket,
seepath defined below.  This is done via `nginx_extra_parameters`
variable.

```
webserver_websites:
  - name: www.example.com
    urls:
      - www.example.com
    tls:
      certificate: /etc/pki/tls/certs/www.example.com.crt
      key: /etc/pki/tls/private/www.example.com.key
      trusted_certificate: /etc/ipa/ca.crt
    nginx_extra_parameters: |
      index index.php;
      location / {
        try_files $uri $uri/ /index.php?$args;
       }
       location ~ \.php$ {
         include /etc/nginx/fastcgi.conf;
         fastcgi_intercept_errors on;
         fastcgi_pass unix:/run/php-fpm/www.example.com.sock;
       }
```

Practical test:

```
# cat > /var/www/sites/www.example.com/html/index.php <<EOF
> <?php echo "Hello world!\n"; ?>
> EOF

# curl -k -H 'Host: www.example.com' https://127.0.0.1:443
Hello world!
```

## An example website behind a proxy

If using *nginx* and the webserver is behind a proxy (eg. AWS ALB)
then one has to change `log_format` and switch *remote_addr* because
the webserver would see as source IP the IP of the proxy (although the
proxy sends real client IP as HTTP header).

The trick is to use [`set_real_ip_from`,
`real_ip_header`](http://nginx.org/en/docs/http/ngx_http_realip_module.html#real_ip_header)
and change `log_format` to start with `$realip_remote_addr` instead of
`$remote_addr` which would be appended to the end of the log format
where people usually put `$http_x_forwarded_for`. That makes the whole
trick! Be aware that `log_format` can be defined only globally,
ie. for `http` section in nginx configuration.

```
# if behind a proxy one has to modify log_format
webserver_ nginx_log_format: |
  '$realip_remote_addr - $remote_user [$time_local] "$request" '
  '$status $body_bytes_sent "$http_referer" '
  '"$http_user_agent" "$remote_addr"';

webserver_websites:
  - name: www.example.com
    urls:
      - www.example.com
      - example.com
    # set_real_ip_from point to AWS ALB subnet cidrs
    nginx_extra_parameters: |
      set_real_ip_from 10.0.0.0/8;
      real_ip_header X-Forwarded-For;
...
```

If the proxy is AWS Application ELB one has to keep in mind that ELB
sends healthcheck with IP address of target instance in host
header. Thus it could not match defined virtual hosts names.

As, in case of nginx, there are two default servers (HTTP, HTTPS),
which return '444' status code if request header does not have set
correct Host value (ie. matching server_name value), this would make
AWS Application ELB healthcheck fail, thus one needs to change default
server blocks not to return '444'.

Example:

```
webserver_nginx_default_server_extra_parameters: |-
  return 403;
```

This simple trick makes ELB healthcheck working, but do not forget to
change healthcheck settings!
