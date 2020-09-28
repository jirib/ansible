# PHP

Configures PHP and PHP-FPM for websites

## Role Variables

* *php_package* - []
* *php_fpm_sites_conf_dir* - path to hold individual PHP-FPM
  configuration for websites Generator intermediate
* *php_fpm_user* - *nginx*, the owner of php-fpm pool process
* *php_fpm_group* - *nginx*, the group of php-fpm pool process
* *php_fpm_pm* - *dynamic*, process manager type
* *php_websites* - [] of dicts

## Individual PHP website variables

* *name* - name of PHP website, also for filename of PHP-FPM config

## Example playbook to configure PHP

Including an example of how to use your role (for instance, with
variables passed in as parameters) is always nice for users too:

    - hosts: "{{ target | default('role_webserver') }}"
	  tasks:
	    - import_role:
		    name: php
