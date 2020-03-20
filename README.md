# KT Connect RBAC

------

This project aims to create a restricted `Role` binding to user `kt-connect` for [KT Connect](https://github.com/alibaba/kt-connect) to use. This restricted `Role` will only have full access to the specified `Namespace` which defaults to `default`



## Features

- Auto create a self-certificated user `kt-connect` 
- Auto generate `kubeconfig` file with restricted privileges for `KT Connect` and `kubectl` to use



## Quick Start

Make sure you clone this repo to your Linux server, not your local machine and follow the instructions below:

```shell
$ cd kt-connect-rbac
$ ./apply-rbac.sh kt-connect -n default
[INFO] Applying RBAC for user 'kt-connect' at namespace 'default' ...
role.rbac.authorization.k8s.io/kt-connect created
rolebinding.rbac.authorization.k8s.io/kt-connect created
clusterrole.rbac.authorization.k8s.io/kt-connect-cluster created
clusterrolebinding.rbac.authorization.k8s.io/kt-connect-cluster created
$ ./gen-kubeconfig.sh
[INFO] Generate certificate for user kt-connect ...
[INFO] Generate kubeconfig for user kt-connect to access namespace default ...
[INFO] kubeconfig file has been saved at 'certs/default/kt-connect.kubeconfig'
$ ls -l certs/default/
total 24
-rw-r--r-- 1 root root  997 Mar 20 14:34 kt-connect.crt
-rw-r--r-- 1 root root  911 Mar 20 14:34 kt-connect.csr
-rw-r--r-- 1 root root 1675 Mar 20 14:34 kt-connect.key
-rw------- 1 root root 5348 Mar 20 14:34 kt-connect.kubeconfig
-rw-r--r-- 1 root root  413 Mar 20 14:34 kt-connect.log
```

Copy `kt-connect.kubeconfig` to some location on your local machine or just overwrite `$HOME/.kube/config` with the new one. Then use `kubectl` and `ktctl` to test the connectivity:

```shell
$ kubectl --kubeconfig /path/to/kt-connect.kubeconfig get pods -n default
NAME                      READY   STATUS    RESTARTS   AGE
busybox                   1/1     Running   0          17h
tomcat-5ff469b85d-kd5c6   1/1     Running   0          3h8m

$ sudo ktctl --kubeconfig /path/to/kt-connect.kubeconfig connect --method=vpn
2:46PM INF Connect Start At 25383
2:46PM INF Client address 192.168.3.163
2:46PM INF deploy shadow deployment kt-connect-daemon-cqnji in namespace default

2:46PM INF pod label: kt=kt-connect-daemon-cqnji
2:46PM INF pod: kt-connect-daemon-cqnji-744c5b94f9-c7w4d is running,but not ready
2:46PM INF pod: kt-connect-daemon-cqnji-744c5b94f9-c7w4d is running,but not ready
2:46PM INF pod: kt-connect-daemon-cqnji-744c5b94f9-c7w4d is running,but not ready
2:46PM INF Shadow pod: kt-connect-daemon-cqnji-744c5b94f9-c7w4d is ready.
Forwarding from 127.0.0.1:2222 -> 22
Forwarding from [::1]:2222 -> 22
2:46PM INF port-forward start at pid: 25384
Handling connection for 2222
Warning: Permanently added '[127.0.0.1]:2222' (ECDSA) to the list of known hosts.
bash: warning: setlocale: LC_ALL: cannot change locale (en_US.UTF-8)
client: Connected.
2:46PM INF vpn(sshuttle) start at pid: 25385
2:46PM INF KT proxy start successful

$ curl http://tomcat.default.svc.cluster.local:8080
kt-connect demo from tomcat9
```

> **Tips:**  The example above assumes that you have already deployed a tomcat service under namespace 'default' in your cluster. You can follow the official guide of KT Connect to do this:
>
> https://github.com/alibaba/kt-connect/blob/master/README.md#deploy-a-service-in-kubernetes



## Reference Links

- https://github.com/alibaba/kt-connect/
- https://alibaba.github.io/kt-connect/#/
- https://blog.csdn.net/weixin_34409741/article/details/86279147
- https://docs.bitnami.com/kubernetes/how-to/configure-rbac-in-your-kubernetes-cluster/



## License

[Apache 2.0](http://www.apache.org/licenses/)

