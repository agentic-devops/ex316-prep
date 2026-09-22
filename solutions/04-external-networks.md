# Solution: Objective 4 (matches questions/04-external-networks.md)

## Task 1-2: NNCP bridge and verification
```bash
oc get nns <a-worker> -o jsonpath='{.status.currentState.interfaces[*].name}{"\n"}'
# find the spare NIC name, then:
cat <<EOF2 | oc apply -f -
apiVersion: nmstate.io/v1
kind: NodeNetworkConfigurationPolicy
metadata:
  name: q4-br-policy
spec:
  nodeSelector:
    node-role.kubernetes.io/worker: ""
  desiredState:
    interfaces:
      - name: q4-br
        type: linux-bridge
        state: up
        ipv4: {enabled: false}
        bridge:
          options: {stp: {enabled: false}}
          port:
            - name: ens224     # replace with the real NIC
EOF2

oc get nncp q4-br-policy
oc get nnce | grep q4-br-policy
oc describe nnce <node>.q4-br-policy   # if a node failed
```

## Task 3: namespace and NAD
```bash
oc create namespace q4-ext
cat <<EOF2 | oc apply -f -
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: q4-net
  namespace: q4-ext
  annotations:
    k8s.v1.cni.cncf.io/resourceName: bridge.network.kubevirt.io/q4-br
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "name": "q4-net",
      "type": "cnv-bridge",
      "bridge": "q4-br",
      "ipam": {}
    }
EOF2
```

## Task 4-5: two VMs with static IPs, then ping
Give each VM a second `bridge: {}` interface on network `q4-net` with a
distinct MAC, and a matching `networkData` (netplan) block setting the
static address — see `labs/04-external-networks/04-vm-multihomed.yaml` for
the exact pattern (MAC-matched `ethernets` entries). Use
`192.168.150.11/24` and `192.168.150.12/24`.

```bash
virtctl ssh cloud-user@vmi/q4-vm1 -n q4-ext -c 'ip -br a'
virtctl ssh cloud-user@vmi/q4-vm1 -n q4-ext -c 'ping -c3 192.168.150.12'
```
