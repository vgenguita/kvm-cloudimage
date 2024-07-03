#!/bin/bash
NODENAME=$(hostname -s)
kubectl label node ${NODENAME} node-role.kubernetes.io/worker=worker --overwrite