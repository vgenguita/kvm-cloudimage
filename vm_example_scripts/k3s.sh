#!/usr/bin/env bash
virsh net-define k8s-internal.xml
virsh net-start k8s-internal
virsh net-autostart k8s-internal
