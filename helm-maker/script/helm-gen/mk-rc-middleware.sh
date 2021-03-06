#!/bin/bash
#author huangjimin
#jimin.huang@nx-engine.com
# generate helm template for middleware
echo " usage: $0  [NEWNAME] [POST2REPO]
"

###################################################################
THIS_SCRIPT=$(cd "$(dirname "${BASH_SOURCE:-$0}")"; pwd)/$(basename ${BASH_SOURCE:-$0})
#automatic detection TOPDIR
CUR_DIR=$(dirname $(realpath ${THIS_SCRIPT}))
TRYTOP=$(xdir=${CUR_DIR};cd ${CUR_DIR}; while /usr/bin/test ! -e .TOP ; do \
        xdir=`cd ../;pwd`;                       \
        if [ "$xdir" = "/" ] ; then             \
           echo  1>&2; \
           break;                              \
        fi ;                                    \
        cd $xdir;                               \
        done ;                                  \
        pwd;)

if [[ -z ${TRYTOP} ]];then
TRYTOP=${CUR_DIR}
fi
echo THIS_SCRIPT=$THIS_SCRIPT
echo CUR_DIR=$CUR_DIR
echo TRYTOP=$TRYTOP

if [[ -n ${TEAMCITY_GIT_PATH} ]];then
    echo "Run on Teamcity"
    BUILD_COUNTER="-t${BUILD_NUMBER}"
elif [[ -n ${JENKINS_URL} ]];then
    echo "Run on Jenkins CI"
    BUILD_COUNTER="-j${BUILD_NUMBER}"
else
    echo "personal rc"
    BUILD_COUNTER=""
fi


####################################################################
CURDATE=$(date +%Y%m%d%H%M%S)
CATALOG_NAME="$1"

echo "CHART name set to ${CATALOG_NAME}"

#GET_VERSION=$(echo $1 | tr '[A-Z]' '[a-z]' |tr -csd  "[0-9._][a-z][A-Z]" "")   

if [[ -z ${VERSION} ]];then
    VERSION=${CURDATE}${BUILD_COUNTER}
fi
echo "CHART version set to ${VERSION}" 

RCNAME=${TRYTOP}/../${CATALOG_NAME}-${VERSION}
echo "RC: ${CATALOG_NAME}-${CURDATE}"

mkdir -p ${RCNAME}/charts
cat >> ${RCNAME}/Chart.yaml <<EOF
name: ${CATALOG_NAME}
version: ${VERSION}
appVersion: 0.1
description: |
  middleware all in one, $(perl -ne 'print "$1, " if /\s+image:[ ]+(.+)$/' `du -a ${TRYTOP}/infra-middleware | egrep "yaml$" | awk '{print $2}'`   )
keywords:
- nextengine
- middleware
home: https://www.nx-engine.com/
icon: https://bitnami.com/assets/stacks/postgresql/img/postgresql-stack-110x117.png
uuid: $(uuidgen)
sources:
- https://www.nx-engine.com/
maintainers:
- name: Jimmy Huang
  email: jimagile@gmail.com
engine: gotpl
EOF

echo "##########################gen charts, and depencies"
echo  'dependencies:' > ${RCNAME}/requirements.yaml


echo "##############################################################"
echo "##########################gen middleware charts, and depencies"
MWDIR=${RCNAME}/charts/infra-middleware/charts
MW_VALUEFILE=${RCNAME}/values-middleware-all-in-one.yaml

mkdir -p ${MWDIR}
/bin/cp -rf  ${TRYTOP}/infra-middleware/* ${MWDIR}

cat  >>  ${MW_VALUEFILE} <<EOF
infra-middleware:
EOF
#################merge mw chart into one
echo  'dependencies:' > $(dirname ${MWDIR})/requirements.yaml
for i in `/bin/ls ${MWDIR} `; do 
    name=$i
    echo "auto gen charts for middleware ${name}"
    version=$( cat ${MWDIR}/${name}/Chart.yaml   |egrep "^version" | perl -ne 'print $1 if /^version:[ ]+(.+)/')
    mv ${MWDIR}/${name}/values.yaml ${MWDIR}/${name}/values-single.yaml

echo " let infra-middleware depend ${name}"
cat >> $(dirname ${MWDIR})/requirements.yaml <<EOF
- name: ${name}
  version: ~${version}
  repository: "file://charts/${name}"
  condition: ${name}.enabled
EOF
echo " merge ${name} valuefile"
cat  >>  ${MW_VALUEFILE} <<EOF
  ${name}:
    enabled: false
EOF
perl -ne "chomp(\$_);print ' ' x 4;print \$_;print qq(\n);" ${MWDIR}/${name}/values-single.yaml  >>  ${MW_VALUEFILE}
done 



##################let mw below top chart
echo "name: infra-middleware" > $(dirname ${MWDIR})/Chart.yaml
echo "version: 0.9.1" >> $(dirname ${MWDIR})/Chart.yaml

cat >> ${RCNAME}/requirements.yaml <<EOF
- name: infra-middleware
  version: ~0.9.1
  repository: "file://charts/infra-middleware"
EOF
cat ${MW_VALUEFILE} >> ${RCNAME}/values.yaml

################# post to repo
if [ $# -ge 2 ];then
  echo "post to repo"
  rm -rf ${RCNAME}/../${CATALOG_NAME}
  /bin/cp -rf ${RCNAME} ${RCNAME}/../${CATALOG_NAME}
  cd ${RCNAME}/..
  helm package ${CATALOG_NAME}
  curl --data-binary "@${CATALOG_NAME}-${VERSION}.tgz" http://charts.ops/api/charts
  curl --data-binary "@${CATALOG_NAME}-${VERSION}.tgz" https://helm-charts.nx-engine.com/api/charts
fi
