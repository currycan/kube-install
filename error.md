# 安装问题

## 1.18.20 安装报错，docker 版本 18.09

```log
Error response from daemon: OCI runtime create failed: systemd cgroup flag passed, but systemd support for managing cgroups is not available: unknown"
```

查阅报错信息，解决方案是删除 `"exec-opts": ["native.cgroupdriver=systemd"]` ，重启docker。
显然，是要保证 kubelet 和 docker 的 cgroup 一致为 systemd，故此方法不可取，尝试升级 docker (20.10)解决。
