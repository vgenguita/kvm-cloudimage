#!/usr/bin/env bash
helm repo add jenkins https://charts.jenkins.io
helm repo update
kubectl create namespace jenkins
helm install testjenkins jenkins/jenkins --namespace jenkins
