# **Введение**

В данном домашнем задании нам необходимо получить практический начальный опыт работы с PAM - Pluggable Authentication Modules.

---

# **Запретить всем пользователям, кроме группы admin логин в выходные (суббота и воскресенье), без учета праздников**

1. Для выполнения этого ДЗ будет использоваться VM с CentOS Linux 7 (Core).
2. На стендовой виртуальной машине создадим 2х пользователей - `test1` и `test2`
```
[dima@Test-Pr-Centos7-1 ~]$ sudo useradd test1 && sudo useradd test2.
```
3. Назначим им пароли.
```
[dima@Test-Pr-Centos7-1 ~]$ echo "otus-test1"|sudo passwd --stdin test1 && echo "otus-test2" | sudo passwd --stdin test2
Changing password for user test1.
passwd: all authentication tokens updated successfully.
Changing password for user test2.
passwd: all authentication tokens updated successfully.
```
4. Проверим подключение по ssh.
```
[dima@Test-Pr-Centos7-1 ~]$ ssh test1@127.0.0.1
test1@127.0.0.1's password:
Last login: Wed May  4 19:45:13 2022 from localhost
[test1@Test-Pr-Centos7-1 ~]$ exit
logout
Connection to 127.0.0.1 closed.

[dima@Test-Pr-Centos7-1 ~]$ ssh test2@127.0.0.1
test2@127.0.0.1's password:
Last login: Wed May  4 19:45:47 2022 from localhost
```
5. Создадим группу admin и добавим туда пользователя `dima`.
```
[dima@Test-Pr-Centos7-1 ~]$ sudo groupadd admin && sudo usermod -aG admin dima

[dima@Test-Pr-Centos7-1 ~]$ cat /etc/group
...
test1:x:1002:
test2:x:1003:
admin:x:1004:dima
```
6. Дальше делаем маленький скрипт, в котором проверяем входит ли авторизуемый пользователь в группу admin, и если входит - то возвращаем 0 (значит вход будет разрешён), если не входит проверяем - какой сегодня день. Если Суббота или Воскресенье - то возвращаем 1 (значит вход не будет разрешён), иначе (если другой день недели) - вернём 0 (значит вход будет разрешён). Собственно таким образом мы решаем наше условие задачи - вход всем только Пн-Пт, группе admin - всегда.
Единственное - в скрипте добавлен текущий день(четверг), чтобы сработала блокировка.
```
[dima@Test-Pr-Centos7-1 ~]$ cat /usr/local/bin/login_test.sh 
#!/bin/bash

grp_mem=$(id "$PAM_USER" | grep admin)

if [ -n "$grp_mem" ]; then
    exit 0
elif [ $(date +%a) = "Sat" ] || [ $(date +%a) = "Sun"  ] || [ $(date +%a) = "Thu"  ]; then
    exit 1
else
    exit 0
fi
```
7. Далее нам необходимо подключить данный модуль. Так как нам надо запретить логин - то я добавлю данный скрипт в два файла: 
/etc/pam.d/sshd - чтобы запретить вход по ssh.
/etc/pam.d/system-auth - чтобы запретить возможность локально аутентифицироваться (например зайти под пользователем из группы admin и выполнить `su test1 или test2`).
```
sudo nano /etc/pam.d/system-auth
[dima@Test-Pr-Centos7-1 ~]$ sudo nano /etc/pam.d/system-auth
#%PAM-1.0
# This file is auto-generated.
# User changes will be destroyed the next time authconfig is run.
auth        required      pam_env.so
auth        required      pam_faildelay.so delay=2000000
auth        sufficient    pam_unix.so nullok try_first_pass
auth        requisite     pam_succeed_if.so uid >= 1000 quiet_success
auth        required      pam_deny.so

account     required      pam_exec.so    /usr/local/bin/login_test.sh
account     required      pam_unix.so
...

[dima@Test-Pr-Centos7-1 ~]$ sudo nano /etc/pam.d/sshd 
#%PAM-1.0
auth       required     pam_sepermit.so
auth       substack     password-auth
auth       include      postlogin
# Used with polkit to reauthorize users in remote sessions
-auth      optional     pam_reauthorize.so prepare
account    required     pam_nologin.so
account    requisite    pam_exec.so    /usr/local/bin/login_test.sh
account    include      password-auth
password   include      password-auth
...
```
8. Теперь проверяем, как у нас отрабатывает наш скрипт - коннектимся по `ssh` или пробуем сменить пользователя через `su`.
```
[dima@Test-Pr-Centos7-1 ~]$ su test1
Password:
/usr/local/bin/login_test.sh failed: exit code 1
su: System error

[dima@Test-Pr-Centos7-1 ~]$ su test2
Password:
/usr/local/bin/login_test.sh failed: exit code 1
su: System error

[dima@Test-Pr-Centos7-1 ~]$ su dima
Password:
[dima@Test-Pr-Centos7-1 ~]$ exit
exit

[dima@Test-Pr-Centos7-1 ~]$ ssh test1@127.0.0.1
test1@127.0.0.1's password:
/usr/local/bin/login_test.sh failed: exit code 1
Authentication failed.

[dima@Test-Pr-Centos7-1 ~]$ ssh test2@127.0.0.1
test2@127.0.0.1's password:
/usr/local/bin/login_test.sh failed: exit code 1
Authentication failed.

[dima@Test-Pr-Centos7-1 ~]$ ssh dima@127.0.0.1
dima@127.0.0.1's password:
Last login: Thu May  5 22:50:38 2022
``` 

---

# **Дать конкретному пользователю права работать с докером и возможность рестартить докер сервис**

1. Устанавливаем docker по мануалу с офф.сайта - `https://docs.docker.com/engine/install/centos/`
2. Проверяем под root, что сервис запущен и делаем ему автозапуск
``` 
[root@Test-Pr-Centos7-1 ~]# systemctl status docker
● docker.service - Docker Application Container Engine
   Loaded: loaded (/usr/lib/systemd/system/docker.service; disabled; vendor preset: disabled)
   Active: active (running) since Sun 2022-05-08 21:22:03 MSK; 2 days ago
     Docs: https://docs.docker.com
 Main PID: 1070 (dockerd)
    Tasks: 8
   Memory: 35.5M
   CGroup: /system.slice/docker.service
           └─1070 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
[root@Test-Pr-Centos7-1 ~]# systemctl enable docker
Created symlink from /etc/systemd/system/multi-user.target.wants/docker.service to /usr/lib/systemd/system/docker.service.           
```
3. Чтобы разрешить например пользователю `test1` работать с docker, его необходимо добавить в группу. Проверяем может ли он работать с docker по умолчанию, затем добавляем его в группу и снова проверяем.
```
[test1@Test-Pr-Centos7-1 dima]$ docker run hello-world
docker: Got permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock: Post "http://%2Fvar%2Frun%2Fdocker.sock/v1.24/containers/create": dial unix /var/run/docker.sock: connect: permission denied.
See 'docker run --help'.

[root@Test-Pr-Centos7-1 dima]# usermod -aG docker test1

[test1@Test-Pr-Centos7-1 dima]$ docker run hello-world

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (amd64)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/
```
4. Итак, права на работу с docker у юзер `test1` есть. Теперь необходимо дать права на рестарт сервиса. Для этого необходимо использовать Polkit. Для начала включим логирование - создадим правило (скрипт из теоритеческой части).
```
[root@Test-Pr-Centos7-1 dima]# cat <<EOF > /etc/polkit-1/rules.d/00-access.rules
> polkit.addRule(function(action, subject) {
> polkit.log("action=" + action);
> polkit.log("subject=" + subject);
> });
> EOF
```
5. Далее пробуем рестартануть сервис под `test1` пользователем и смотрим, что у нас в /var/log/secure.
```
[test1@Test-Pr-Centos7-1 dima]$ systemctl restart docker
==== AUTHENTICATING FOR org.freedesktop.systemd1.manage-units ===
Authentication is required to manage system services or units.
Authenticating as: dima
Password:

[root@Test-Pr-Centos7-1 dima]# tail /var/log/secure
May 12 23:00:00 Test-Pr-Centos7-1 polkitd[668]: Reloading rules
May 12 23:00:00 Test-Pr-Centos7-1 polkitd[668]: Collecting garbage unconditionally...
May 12 23:00:00 Test-Pr-Centos7-1 polkitd[668]: Loading rules from directory /etc/polkit-1/rules.d
May 12 23:00:00 Test-Pr-Centos7-1 polkitd[668]: Loading rules from directory /usr/share/polkit-1/rules.d
May 12 23:00:00 Test-Pr-Centos7-1 polkitd[668]: Finished loading, compiling and executing 3 rules
May 12 23:04:25 Test-Pr-Centos7-1 polkitd[668]: Registered Authentication Agent for unix-process:12953:77494124 (system bus name :1.2595 [/usr/bin/pkttyagent --notify-fd 5 --fallback], object path /org/freedesktop/PolicyKit1/AuthenticationAgent, locale en_US.UTF-8)
May 12 23:04:25 Test-Pr-Centos7-1 polkitd[668]: /etc/polkit-1/rules.d/00-access.rules:2: action=[Action id='org.freedesktop.systemd1.manage-units']
May 12 23:04:25 Test-Pr-Centos7-1 polkitd[668]: /etc/polkit-1/rules.d/00-access.rules:3: subject=[Subject pid=12953 user='test1' groups=test1,docker seat='' session='531' local=false active=true]
May 12 23:04:32 Test-Pr-Centos7-1 polkitd[668]: Unregistered Authentication Agent for unix-process:12953:77494124 (system bus name :1.2595, object path /org/freedesktop/PolicyKit1/AuthenticationAgent, locale en_US.UTF-8) (disconnected from bus)
May 12 23:04:32 Test-Pr-Centos7-1 polkitd[668]: Operator of unix-process:12953:77494124 FAILED to authenticate to gain authorization for action org.freedesktop.systemd1.manage-units for system-bus-name::1.2596 [<unknown>] (owned by unix-user:test1)
```
6. Мы видим, что "Operator of unix-process:12953:77494124 FAILED to authenticate to gain authorization for action org.freedesktop.systemd1.manage-units for system-bus-name::1.2596 [<unknown>] (owned by unix-user:test1)", тоже самое и при рестарте "==== AUTHENTICATING FOR org.freedesktop.systemd1.manage-units ===".  То есть нам необходимо дать права нашему пользователю `test1` работать с действием Polkit- `action org.freedesktop.systemd1.manage-units`. Для этого создаём ещё одно правило.
```
cat <<EOF > /etc/polkit-1/rules.d/01-access-docker-restart.rules
polkit.addRule(function(action, subject) {
	if (action.id.match("org.freedesktop.systemd1.manage-units") &&
		action.lookup("unit") == "docker.service" &&
		action.lookup("verb") == "restart"
		subject.user === "test1") {
		return polkit.Result.YES;
	}
});
EOF
```
7. Проверяем, однако правило не сработало. Проблема в версии systemd в Centos7, необходимо обновить - [ссылка на инструкцию](https://copr.fedorainfracloud.org/coprs/jsynacek/systemd-backports-for-centos-7/?ref=https://githubhelp.com).
```
[test1@Test-Pr-Centos7-1 dima]$ systemctl restart docker
==== AUTHENTICATING FOR org.freedesktop.systemd1.manage-units ===
Authentication is required to manage system services or units.
Authenticating as: dima
Password:

[root@Test-Pr-Centos7-1 dima]# setenforce 0
[root@Test-Pr-Centos7-1 dima]# wget https://copr.fedorainfracloud.org/coprs/jsynacek/systemd-backports-for-centos-7/repo/epel-7/jsynacek-systemd-backports-for-centos-7-epel-7.repo -O /etc/yum.repos.d/jsynacek-systemd-centos-7.repo
[root@Test-Pr-Centos7-1 dima]# yum update systemd -y
[root@Test-Pr-Centos7-1 dima]# systemctl --version
systemd 234
+PAM +AUDIT +SELINUX +IMA -APPARMOR +SMACK +SYSVINIT +UTMP +LIBCRYPTSETUP +GCRYPT +GNUTLS +ACL +XZ +LZ4 +SECCOMP +BLKID +ELFUTILS +KMOD -IDN2 +IDN default-hierarchy=hybrid
[root@Test-Pr-Centos7-1 dima]# setenforce 1
```
8. Проверяем ещё раз и убеждаемся, что работает именно restart.
```
[test1@Test-Pr-Centos7-1 dima]$ systemctl start docker
==== AUTHENTICATING FOR org.freedesktop.systemd1.manage-units ===
Authentication is required to start 'docker.service'.
Authenticating as: dima
Password:

[test1@Test-Pr-Centos7-1 dima]$ systemctl restart docker
```