# TASKS

- [x] The app should be reachable only via HTTPS and/or automatic redirect to HTTPS.
- [x] The app should route through nginx and/or uWSGI (or node, if preferred).
- [x] The app should be running as a non-privileged user.
- [x] App/docker container should be automatically restarted if crashes or is killed.
- [x] App's logs should be captured to /var/log/app.log 
- [x] Timezone should be in UTC 

## BUILD APP

I took flask framework and put everything in Docker container. I used github action for automate build process and push the image to target registry: `nikitinay/helloworld`

<details><summary>The app is running under nginx user via supervisor and logs captured to `/var/log/app.log`</summary>
<p>

```
/app # ps axf
PID   USER     TIME  COMMAND
    1 root      0:00 {supervisord} /usr/bin/python3 /usr/bin/supervisord
    9 root      0:00 nginx: master process /usr/sbin/nginx
   10 nginx     0:00 /usr/sbin/uwsgi --ini /etc/uwsgi/uwsgi.ini
   11 nginx     0:00 nginx: worker process
   13 nginx     0:00 /usr/sbin/uwsgi --ini /etc/uwsgi/uwsgi.ini
   14 nginx     0:00 /usr/sbin/uwsgi --ini /etc/uwsgi/uwsgi.ini
   21 root      0:00 sh
   27 root      0:00 ps axf

/app # tail -f /var/log/app.log
mapped 1239640 bytes (1210 KB) for 16 cores
*** Operational MODE: preforking ***
WSGI app 0 (mountpoint='') ready in 1 seconds on interpreter 0x5572906530c0 pid: 11 (default app)
*** uWSGI is running in multiple interpreter mode ***
spawned uWSGI master process (pid: 11)
spawned uWSGI worker 1 (pid: 14, cores: 1)
spawned uWSGI worker 2 (pid: 15, cores: 1)
running "unix_signal:15 gracefully_kill_them_all" (master-start)...
[pid: 15|app: 0|req: 1/1] 172.17.0.1 () {48 vars in 831 bytes} [Sat Feb 27 18:28:25 2021] GET / => generated 13 bytes in 2 msecs (HTTP/1.1 200) 2 headers in 79 bytes (1 switches on core 0)
[pid: 15|app: 0|req: 2/2] 172.17.0.1 () {46 vars in 758 bytes} [Sat Feb 27 18:28:25 2021] GET /favicon.ico => generated 232 bytes in 1 msecs (HTTP/1.1 404) 2 headers in 87 bytes (1 switches on core
 0)
[pid: 15|app: 0|req: 3/3] 172.17.0.1 () {50 vars in 862 bytes} [Sat Feb 27 18:28:37 2021] GET / => generated 13 bytes in 0 msecs (HTTP/1.1 200) 2 headers in 79 bytes (1 switches on core 0)
[pid: 15|app: 0|req: 4/4] 172.17.0.1 () {50 vars in 862 bytes} [Sat Feb 27 18:28:37 2021] GET / => generated 13 bytes in 1 msecs (HTTP/1.1 200) 2 headers in 79 bytes (2 switches on core 0)
```

</p>
</details>

## AWS EKS CLUSTER PROVISIONING

I used simple `module` For EKS cluster provisioning. Specification of the cluster located in `./terraform/variables.tf`

## DEPLOY IMAGE TO THE CLUSTER

I decided to separate cluster provisioining and application deployment. I described deployment in yaml files in `k8sdeploy` folder. Also the task required https, so I generated self signed cert.

Before run specify AWS credentials

```
export aws_access_key_id=XXXXXXXXXXXXXXXXXXXX 
export aws_secret_access_key=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

Required utilities: 

```
curl jq kubectl terraform openssl aws-iam-authenticator
```

For deploy everything you need to run `./deploy.sh`

## CHECK
```
$ k get svc -n ingress-nginx
NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP                                                                     PORT(S)                      AGE
ingress-nginx-controller             LoadBalancer   172.20.211.110   a14594a7395fc4b82837dc1a44e6df22-a468a56e15eb794e.elb.eu-west-2.amazonaws.com   80:30891/TCP,443:30947/TCP   20m
ingress-nginx-controller-admission   ClusterIP      172.20.162.116    <none>                                                                         443/TCP                      20m

$ curl -H "Host: helloworld.net" -k https://a14594a7395fc4b82837dc1a44e6df22-a468a56e15eb794e.elb.eu-west-2.amazonaws.com
Hello, World!

$
```

<details><summary>Sometime AWS ensuring Load Balancer more then 1 minute and the process can fail with the error.</summary>
<p>

```
Error from server (InternalError): error when creating "k8sdeploy/ingress-helloworld.yml": Internal error occurred: failed calling webhook "validate.nginx.ingress.kubernetes.io": Post https://ingre
ss-nginx-controller-admission.ingress-nginx.svc:443/networking/v1beta1/ingresses?timeout=10s: no endpoints available for service "ingress-nginx-controller-admission"
```

For fix the issue just wait when LoadBalancer will be ready and apply ingress rule one more time.

```
$ k get svc -n ingress-nginx -w
NAMESPACE       NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx   ingress-nginx-controller             LoadBalancer   172.20.211.110   <pending>     80:32238/TCP,443:31197/TCP   2m55s
ingress-nginx   ingress-nginx-controller-admission   ClusterIP      172.20.162.116   <none>        443/TCP                      2m55s
ingress-nginx   ingress-nginx-controller             LoadBalancer   172.20.211.110   a14594a7395fc4b82837dc1a44e6df22-a468a56e15eb794e.elb.eu-west-2.amazonaws.com  80:32238/TCP,443:31197/TCP   5m1
9s

$ k apply -f k8sdeploy/ingress-helloworld.yml
ingress.extensions/helloworld-net created
```

</p>
</details>

## DESTROY RESOURCES

```
kubectl delete -f k8sdeploy/
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.44.0/deploy/static/provider/aws/deploy.yaml

cd terraform
terraform destroy -auto-approve
```
