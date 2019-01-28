# helm-release-tool
helm-release-tool 是一个K8S的 helm chart 自动化生成工具。

通过Kubernetes API, 获取K8S一个Namespace的各微服务的 `image版本, image 环境变量配置, container port`等信息
从一个 generic helm chart, 派生出各个微服务的helm chart 。生成一个包含多个微服务的helm chart，用于快速重建一个项目

helm-release-tool 有以下特点:
* 支持外部中间件
* 支持服务覆盖原有的entrypoint
* 支持服务具备默认的环境变量
* 支持服务环境变量覆盖与新增加
* 所有微服务的部署配置放在统一的单个valuesfile `values-release-apps.yaml`
* 每个服务的镜像环境变量拆分两部分, 可配置的`values-release-apps.yaml`与固定的`charts/{XXX}/files/env.txt`
# 目录结构
```
.
├── helm-maker             K8S一个NameSpace的helm 生成工具目录
│   ├── generic            微服务的基础generic helm chart
│   ├── infra-middleware   中间件的helm
│   └── script             工具脚本, script/mk-release.sh <NS>
├── rc-icev3                  项目ice v3的helm 发布仓库
│   ├── charts                项目ice v3的各个微服务chart
│   ├── Chart.yaml            
│   ├── requirements.yaml     项目ice v3的依赖的各微服务
│   ├── values-middleware-all-in-one.yaml 各服务的helm values
│   └── values-release-apps.yaml
├── README.md
└── release-icev3-release-20190128-09.43.59 script/mk-release.sh <NS> 导出的helm
    ├── charts
    ├── Chart.yaml
    ├── requirements.yaml
    ├── values-middleware-all-in-one.yaml
    └── values-release-apps.yaml
```

#工具用法
```
$ ./helm-maker/script/mk-release.sh <K8S-NS>
```

# generic chart, 派生helm chart 文件说明
以下是
```aidl
.
└── my-nginx
    ├── Chart.yaml
    ├── files
    │   ├── env.txt 该文件提供my-nginx的Docker image的环境变量配置
    │   ├── override-entrypoint.sh <可选> 该文件存在会变成deployment的command 覆盖默认ENTRYPOINT
    │   └── initdata/ 该目录下存在的文件都将以volume挂入容器/cfg/initdata 
    ├── OWNERS
    ├── templates 来源于generic/xxx-generic-chart/templates的generic templates
    │   ├── configmap.yaml
    │   ├── deployment.yaml
    │   ├── _helpers.tpl
    │   ├── ingress-kong-internal.yaml
    │   ├── ingress-kong-public.yaml
    │   ├── initialization-configmap.yaml
    │   ├── NOTES.txt
    │   └── service.yaml
    └── values-single.yaml 本服务单独部署的valuesfile
```
#  配置注入的ENTRYPOINT要求
每个镜像的Dockerfile里指定的entrypoint需要包含以下脚本，支持环境变量注入
```aidl
K8S_NS_FILE="/var/run/secrets/kubernetes.io/serviceaccount/namespace"
if [ -f ${K8S_NS_FILE} ];then
K8S_NS=`head -n 1 ${K8S_NS_FILE}`
else
K8S_NS="cant-get-ns"
fi
SVC_NAME=`echo ${K8S_NS}.${HOSTNAME} | rev | cut -d'-'  -f 3- | rev`

mkdir -p /cfg/
if [ -f /cfg/env.txt ]; then
    echo "###/cfg/env.txt mounted"
    set -a # automatically export all variables
    . /cfg/env.txt
    set +a
    echo "###import  $(wc -l /cfg/env.txt) env vars from /cfg/env.txt done"
else
    echo "###/cfg/env.txt not found!"
fi
```
