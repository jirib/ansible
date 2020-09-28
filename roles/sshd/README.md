# Role Name

This role configures sshd daemon.

The main purpose of this role is to have ability to define and
override sshd configuration via a template file.

The main interest is `sshd_extra_parameters` which is a variable of a
literal block.

## Role Variables

See `defaults/main.yml`

## Example Playbook

You should know where roles directory is, you can use
`ANSIBLE_ROLES_PATH` if needed.

    - hosts: all
      become: true

      tasks:
        - import_role:
            name: sshd

Example run:

```
ansible -i env/prod/ playbooks/sshd.yml
```

## Customization

### IPA post-enroll

Main point and use case is changing of sshd configuration after a
machine is enrolled to IPA.

```
sshd_gssapiauthentication: 'yes'
sshd_passwordauthentication: 'yes'
sshd_extra_parameters: |-
  Match user *,!ec2-user
    AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
    AuthorizedKeysCommandUser nobody
  Match user ec2-user
    AuthorizedKeysCommand /opt/aws/bin/eic_run_authorized_keys %u %f
    AuthorizedKeysCommandUser ec2-instance-connect
  AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
  AuthorizedKeysCommandUser nobody
```
### SFTP only access

Or defining only SFTP access for particular users/group while keeping
IPA related configuration.

```
sshd_extra_parameters: |-
  Match user *,!ec2-user
    AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
    AuthorizedKeysCommandUser nobody
  Match user ec2-user
    AuthorizedKeysCommand /opt/aws/bin/eic_run_authorized_keys %u %f
    AuthorizedKeysCommandUser ec2-instance-connect
  Match Group sftponly
    ChrootDirectory /var/www/users/%u
    ForceCommand internal-sftp -l INFO # logging data transfer
    AllowTcpForwarding no
    X11Forwarding no
    PasswordAuthentication no
  AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
  AuthorizedKeysCommandUser nobody
```

### TCP port forwarding

Or allowing only to use the server running sshd as jumpbox (TCP port
forwarding) only.

```
sshd_extra_parameters: |-
  Match user *,!ec2-user
    AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
    AuthorizedKeysCommandUser nobody
  Match user ec2-user
    AuthorizedKeysCommand /opt/aws/bin/eic_run_authorized_keys %u %f
    AuthorizedKeysCommandUser ec2-instance-connect
  Match Group sshtcpfwdonly
    ForceCommand echo 'This account can only be used for SSH TCP port forwarding to specific destinations!'
    PasswordAuthentication no
  AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
  AuthorizedKeysCommandUser nobody
```

## Tips

### Default OpenSSH server config

```
# rpm2cpio openssh-server-7.4p1-21.amzn2.0.1.x86_64.rpm | \
  cpio --to-stdout -i ./etc/ssh/sshd_config 2>/dev/null | \
  egrep -v '^(#| *$)'
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
SyslogFacility AUTHPRIV
AuthorizedKeysFile      .ssh/authorized_keys
PasswordAuthentication yes
ChallengeResponseAuthentication no
GSSAPIAuthentication yes
GSSAPICleanupCredentials no
UsePAM yes
X11Forwarding yes
AcceptEnv LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES
AcceptEnv LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT
AcceptEnv LC_IDENTIFICATION LC_ALL LANGUAGE
AcceptEnv XMODIFIERS
Subsystem       sftp    /usr/libexec/openssh/sftp-server
```

### Testing sshd configuration

:exclamation: If a keyword appears in multiple Match blocks that are
satisfied, only the first instance of the keyword is applied.

Let's suppose we have *foo* user which is in *sftponly* group
which should be forced to use SFTP only. We have following
configuration:

```
sshd_extra_parameters: |-
  Match user *,!ec2-user
    AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
    AuthorizedKeysCommandUser nobody
  Match user ec2-user
    AuthorizedKeysCommand /opt/aws/bin/eic_run_authorized_keys %u %f
    AuthorizedKeysCommandUser ec2-instance-connect
  Match Group sftponly
    ChrootDirectory /var/www/users/%u
    ForceCommand internal-sftp -l INFO # logging data transfer
    AllowTcpForwarding no
    X11Forwarding no
    PasswordAuthentication no
  AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
  AuthorizedKeysCommandUser nobody
```

To test this configuration before changing main
`/etc/ssh/sshd_config`, one could execute `sshd -T` and defined
connection specification with `-C user,host,addr` where each
specification is keyword=value pairs.

Following example dumps what sshd configuration would be applied to a
specific user, `foo`, connecting from `1.1.1.1` address.

```
# sshd -f /tmp/sshd_config -T -C user=foo,host=\*,addr=1.1.1.1 | \
  egrep -i "^(authorized|permit|allow|chroot|forcecommand|password)" | sort
allowagentforwarding yes
allowstreamlocalforwarding yes
allowtcpforwarding no
authorizedkeyscommanduser nobody
authorizedkeyscommand /usr/bin/sss_ssh_authorizedkeys
authorizedkeysfile .ssh/authorized_keys
authorizedprincipalscommand none
authorizedprincipalscommanduser none
authorizedprincipalsfile none
chrootdirectory /var/www/users/%u
forcecommand internal-sftp -l INFO 
passwordauthentication no
permitemptypasswords no
permitopen any
permitrootlogin yes
permittty yes
permittunnel no
permituserenvironment no
permituserrc yes
```

And let's suppose we also have `sshtcpfwdonly` group where `bar`
belongs, this use should not get chrooted and not get login shell but
only be able to do TCP port forwarding.

```
# sshd -f /tmp/sshd_config -T -C user=bar,host=\*,addr=1.1.1.1 | \
  egrep -i "^(authorized|permit|allow|chroot|forcecommand|password|x11forwarding)" | \
  sort
allowagentforwarding yes
allowstreamlocalforwarding yes
allowtcpforwarding yes
authorizedkeyscommanduser nobody
authorizedkeyscommand /usr/bin/sss_ssh_authorizedkeys
authorizedkeysfile .ssh/authorized_keys
authorizedprincipalscommand none
authorizedprincipalscommanduser none
authorizedprincipalsfile none
chrootdirectory none
forcecommand echo 'This account can only be used for SSH TCP port forwarding to specific destinations!'
passwordauthentication no
permitemptypasswords no
permitopen any
permitrootlogin yes
permittty yes
permittunnel no
permituserenvironment no
permituserrc yes
x11forwarding no
```
