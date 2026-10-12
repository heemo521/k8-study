# Port of Kube story guide

Every note section in the study app opens with a short "Port story" callout that explains the section's idea through one consistent analogy world: a shipping port called the **Port of Kube**. The technical notes that follow stay unchanged. The story must make the notes easier to understand, never contradict them, and never add a technical fact that is not already in that section.

## Format rules
- One story per section, 40 to 80 words, plain friendly prose, second person welcome ("you").
- Markup: only `inline code` and **bold**. Never single *asterisks* (italics are not supported). No em-dashes. No emoji.
- Tie the analogy to the real term in parentheses at least once, e.g. "the load planner (`kube-scheduler`)".
- Use only facts already present in that section's blocks. If an analogy would mislead, say briefly where it stops ("Unlike a real ship, ...").
- Don't repeat the section heading; set the scene, then make the point.
- Gender-neutral characters; avoid names unless helpful.

## Canonical cast (use these mappings, consistently)
| Kubernetes | Port of Kube |
|---|---|
| Cluster | the whole port: harbor office plus its fleet |
| Control plane | the harbor office |
| kube-apiserver | the front desk: every order and report goes through it |
| etcd | the master ledger of what should exist |
| kube-scheduler | the load planner who picks a ship with room |
| kube-controller-manager / controllers | supervisors who compare the ledger with the docks and fix gaps |
| cloud-controller-manager | the liaison to the city (cloud provider) |
| Worker node | a cargo ship |
| kubelet | the ship's cargo officer |
| container runtime | the ship's crane |
| kube-proxy | the ship's switchboard operator |
| Pod | a bay on a ship (own phone number = Pod IP, shared power line = network, shared locker = volumes, bay intercom = localhost) |
| Container | a shipping container |
| Image | a sealed packing template that stamps out identical containers |
| Registry | the container depot / catalog where templates are stored |
| kubectl | your radio to the front desk |
| Namespace | a separate company yard inside the port, with its own signs |
| Labels / selectors | coloured tags on bays / "every bay tagged blue" |
| Deployment | a standing shipping contract ("keep 3 bays of X; upgrade them a few at a time") |
| ReplicaSet | the dispatcher who counts bays to match the contract |
| StatefulSet | numbered reserved berths, each with its own named locker |
| DaemonSet | one item on every ship (like a lifeboat) |
| Job / CronJob | a one-off delivery run / a scheduled delivery run |
| Service | a fixed port phone number that forwards to whichever bays currently do the job |
| ClusterIP / NodePort / LoadBalancer | internal extension / a numbered gate on every ship / a public entrance the city builds |
| EndpointSlices | the switchboard's current list of bays behind a number |
| CoreDNS / cluster DNS | the port phone directory |
| Ingress | the main port gate where a receptionist routes visitors by name and path |
| Gateway API | the newer gate system: the port authority owns the gate, tenants own their routes |
| NetworkPolicy | fences and gate passes between bays |
| CNI plugin | the contractor who builds the port's roads and radio network |
| ConfigMap / Secret | an instruction sheet posted in the bay / a sealed envelope with keys and passwords |
| Volume | a locker attached to the bay |
| PersistentVolume / PVC | a warehouse unit / a rental request for one |
| StorageClass | the warehouse rental catalog that builds units on demand |
| Resource requests / limits | the cargo weight a bay declares / the most it may load |
| Taints / tolerations | "hazmat only" signs on a ship / a hazmat permit |
| Node affinity / nodeSelector | preferring or requiring certain ships |
| Cordon / drain | flag a ship "no new cargo" / move its bays off before maintenance |
| metrics-server | gauges on each ship reporting to the office |
| HPA / VPA / cluster autoscaler | add more bays when queues grow / give bays bigger slots / charter more ships |
| RBAC: Role / ClusterRole / RoleBinding | what a staff badge allows in one yard / port-wide / issuing that badge to someone |
| ServiceAccount | a badge for a robot crew member |
| CRD / Operator | a new kind of form added to the ledger / a specialist supervisor who handles that form |
| Helm / Kustomize | a pre-packed shipping kit with fill-in forms / stickers layered over a base form |
| kubeadm | the construction crew that builds a new port |
| etcd backup / restore | photocopying the ledger into a safe / rebuilding from that copy |
| HA control plane | several harbor offices sharing one ledger |
| CRI / CNI / CSI | the standard crane socket / road-network standard / warehouse plug standard |
| Managed Kubernetes | the city runs the harbor office for you |
| minikube | a one-ship training harbor on your desk |
| Troubleshooting | the port investigator following clues |
| Docker engine | the crane and its operator on your own dock |
| Dockerfile / layers | step-by-step packing instructions / stacked packing layers, reused when unchanged |
| Docker volume / bind mount | an external locker the port manages / a hose from your own garage into the container |

Concepts not in the table: invent a fitting port element in the same spirit and keep it consistent within the topic.

## Examples (already shipped)
- Pods / "What a Pod is": "On a cargo ship, containers aren't loaded one by one. They go into a **bay**: a reserved slot with its own phone number (the Pod IP), a shared power line, and a shared locker (volumes). Containers in the same bay talk over the bay intercom (`localhost`). The port tracks bays, not loose containers, and a bay always sits on one ship (node)."
- Pods / "Init containers": "Before any cargo goes into a bay, a **prep crew** goes in first: one worker sweeps, the next checks the power, the next confirms the customer has paid. They go one at a time, in order, and each must finish before the next starts. Only then is the real cargo loaded. If the bay has to be set up again, the whole prep crew repeats its checklist."
- Pods / "Probes": "Inspectors walk the deck with three questions. **Startup**: \"Has this slow unit finished warming up?\" (the other inspectors wait until it has). **Liveness**: \"Is it still working?\" If not, it is restarted. **Readiness**: \"Can it take deliveries right now?\" If not, it is taken off the delivery list for a while, but left alone."
