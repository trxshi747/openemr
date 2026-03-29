# Résultats — Kubernetes + Auto-scaling + Rolling Update

## Configuration
- Environnement : Minikube local
- RAM Minikube : 6GB
- CPUs : 2
- Image : openemr/openemr:7.0.4
- minReplicas : 1
- maxReplicas : 10
- CPU seuil : 60%
- RAM seuil : 70%

## Smoke Test (5 VUs, 1 minute)
| Métrique | Valeur |
|---|---|
| Avg response time | 54.46ms |
| Max response time | 488.81ms |
| Throughput (req/s) | 16.27 |
| Error rate | 0% |
| Pods max | 1 |

## Load Test (100 VUs, 9 minutes)
| Métrique | Valeur |
|---|---|
| Avg response time | 564ms |
| Max response time | 24.71s |
| Throughput (req/s) | 88 |
| Error rate | 91.29% |
| Pods max | 10 |
| CPU max | 460% |

## Stress Test (500 VUs, 8 minutes)
| Métrique | Valeur |
|---|---|
| Avg response time | 4.52s |
| Max response time | 60s |
| Throughput (req/s) | 42.23 |
| Error rate | 90.10% |
| Pods max | 8+ |

## Comportement HPA observé
### Load Test
- Début : 1 pod, CPU 15%
- Montée : CPU > 60% → scale up
- Peak : 10 pods, CPU 460%
- Fin : scale down progressif vers 2 pods

### Stress Test  
- Début : 1 pod
- Montée rapide : 8+ pods créés automatiquement
- Limite atteinte : pods OOMKilled sous 500 VUs

## Observations
- OpenEMR non conçu pour scaling horizontal natif
- Chaque nouveau pod tente une réinstallation complète
- En production réelle, image stateless nécessaire
- Auto-scaling fonctionne correctement côté Kubernetes
