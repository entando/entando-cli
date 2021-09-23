#!/bin/sh
REG="registry.hub.docker.com"
CMD="k3s ctr image pull"
command -v sudo && CMD="sudo $CMD"

$CMD $REG/centos/mysql-80-centos7:latest
$CMD $REG/centos/postgresql-12-centos7:latest
$CMD $REG/entando/busybox:latest

$CMD $REG/entando/entando-k8s-controller-coordinator:6.3.9
$CMD $REG/entando/app-builder:6.3.93
$CMD $REG/entando/entando-avatar-plugin:6.0.5
$CMD $REG/entando/entando-component-manager:6.3.26
$CMD $REG/entando/entando-de-app-eap:6.3.68
$CMD $REG/entando/entando-de-app-wildfly:6.3.68
$CMD $REG/entando/entando-k8s-app-controller:6.3.12
$CMD $REG/entando/entando-k8s-app-plugin-link-controller:6.3.5
$CMD $REG/entando/entando-k8s-cluster-infrastructure-controller:6.3.7
$CMD $REG/entando/entando-k8s-composite-app-controller:6.3.11
$CMD $REG/entando/entando-k8s-database-service-controller:6.3.11
$CMD $REG/entando/entando-k8s-dbjob:6.3.8
$CMD $REG/entando/entando-k8s-keycloak-controller:6.3.8
$CMD $REG/entando/entando-k8s-plugin-controller:6.3.7
$CMD $REG/entando/entando-k8s-service:6.3.4
$CMD $REG/entando/entando-keycloak:6.3.9
$CMD $REG/entando/entando-plugin-sidecar:6.0.2
$CMD $REG/entando/entando-process-driven-plugin:6.0.50
$CMD $REG/entando/entando-redhat-sso:6.3.9
