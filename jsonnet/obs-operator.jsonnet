local cr = import 'generic-operator/config';
local thanos = (import 'stolo-configuration/components/thanos.libsonnet');
local loki = (import 'github.com/observatorium/observatorium/configuration/components/loki.libsonnet');
local api = (import 'lib/observatorium-api.libsonnet');
local obs = (import 'stolo-configuration/components/observatorium.libsonnet');

local override_containers(org_containers, custom_containers) =
[
  if (c.name == custom_container.name) then c {
    args: custom_container.args
  } else c
  for custom_container in custom_containers
  for c in org_containers
];

local operatorObs = obs {

  config+:: {
    name: cr.metadata.name,
    namespace: cr.metadata.namespace,
  },

  thanos+:: thanos({
    name: cr.metadata.name,
    namespace: cr.metadata.namespace,
    commonLabels+:: {
      'app.kubernetes.io/part-of': 'observatorium',
    },
    image: if std.objectHas(cr.spec.thanos, 'image') then cr.spec.thanos.image else obs.thanos.config.image,
    imagePullPolicy: if std.objectHas(cr.spec.thanos, 'imagePullPolicy') then cr.spec.thanos.imagePullPolicy else obs.thanos.config.imagePullPolicy,
    version: if std.objectHas(cr.spec.thanos, 'version') then cr.spec.thanos.version else obs.thanos.config.version,
    objectStorageConfig: cr.spec.objectStorageConfig.thanos,
    hashrings: cr.spec.hashrings,
    compact+:: {
      logLevel: 'info',
      disableDownsampling: if std.objectHas(cr.spec.thanos, 'compact') && std.objectHas(cr.spec.thanos.compact, 'enableDownsampling') then !cr.spec.thanos.compact.enableDownsampling else obs.thanos.compact.config.disableDownsampling,
      securityContext: if std.objectHas(cr.spec, 'securityContext') then cr.spec.securityContext else obs.thanos.compact.config.securityContext,
    } + if std.objectHas(cr.spec.thanos, 'compact') then cr.spec.thanos.compact else {},

    receiveController+:: {
      hashrings: cr.spec.hashrings,
      securityContext: if std.objectHas(cr.spec, 'securityContext') then cr.spec.securityContext else obs.thanos.receiveController.config.securityContext,
    } + if std.objectHas(cr.spec.thanos, 'receiveController') then cr.spec.thanos.receiveController else {},

    receivers+:: {
      securityContext: if std.objectHas(cr.spec, 'securityContext') then cr.spec.securityContext else obs.thanos.receivers.config.securityContext,
    } + if std.objectHas(cr.spec.thanos, 'receivers') then cr.spec.thanos.receivers else {},

    rule+:: {
      securityContext: if std.objectHas(cr.spec, 'securityContext') then cr.spec.securityContext else obs.thanos.rule.config.securityContext,
      alertmanagersURLs: if std.objectHas(cr.spec.thanos, 'rule') && std.objectHas(cr.spec.thanos.rule, 'alertmanagerURLs') then cr.spec.thanos.rule.alertmanagerURLs else obs.thanos.rule.config.alertmanagersURLs,
    } + if std.objectHas(cr.spec.thanos, 'rule') then cr.spec.thanos.rule else {},

    stores+:: {
      local deleteDelay = if std.objectHas(cr.spec.thanos, 'compact') && std.objectHas(cr.spec.thanos.compact, 'deleteDelay') then cr.spec.thanos.compact.deleteDelay else obs.thanos.compact.config.deleteDelay,
      securityContext: if std.objectHas(cr.spec, 'securityContext') then cr.spec.securityContext else obs.thanos.stores.config.securityContext,
      ignoreDeletionMarksDelay: std.ceil(std.parseInt(std.substr(deleteDelay, 0, std.length(deleteDelay) - 1)) / 2) + std.substr(deleteDelay, std.length(deleteDelay) - 1, std.length(deleteDelay)),
      local maxItemSize = if std.objectHas(cr.spec.thanos, 'store') && std.objectHas(cr.spec.thanos.store, 'cache') && std.objectHas(cr.spec.thanos.store.cache, 'maxItemSize') then cr.spec.thanos.store.cache.maxItemSize else obs.thanos.stores.config.maxItemSize,
      maxItemSize: std.strReplace(std.strReplace(maxItemSize, "m", "MiB"), "g", "GiB"),
    } + if std.objectHas(cr.spec.thanos, 'store') then cr.spec.thanos.store else {},

    storeCache+:: (if std.objectHas(cr.spec.thanos, 'store') && std.objectHas(cr.spec.thanos.store, 'cache') then cr.spec.thanos.store.cache else {}) + {
      memoryLimitMb: if std.objectHas(cr.spec.thanos.store, 'cache') && std.objectHas(cr.spec.thanos.store.cache, 'memoryLimitMb') then cr.spec.thanos.store.cache.memoryLimitMb else obs.thanos.storeCache.config.memoryLimitMb,
      resources+: (
        if std.objectHas(cr.spec.thanos.store.cache, 'resources') then {
          memcached: cr.spec.thanos.store.cache.resources,
        } else {}
      ) + (
        if std.objectHas(cr.spec.thanos.store.cache, 'exporterResources') then {
          exporter: cr.spec.thanos.store.cache.exporterResources,
        } else {}
      ),
      securityContext: if std.objectHas(cr.spec, 'securityContext') then cr.spec.securityContext else obs.thanos.storeCache.config.securityContext,
    },

    query+:: {
      securityContext: if std.objectHas(cr.spec, 'securityContext') then cr.spec.securityContext else obs.thanos.query.config.securityContext,
    } + if std.objectHas(cr.spec.thanos, 'query') then cr.spec.thanos.query else {},

    queryFrontend+:: {
      securityContext: if std.objectHas(cr.spec, 'securityContext') then cr.spec.securityContext else obs.thanos.queryFrontend.config.securityContext,
      local maxItemSize = if std.objectHas(cr.spec.thanos, 'queryFrontend') && std.objectHas(cr.spec.thanos.queryFrontend, 'cache') && std.objectHas(cr.spec.thanos.queryFrontend.cache, 'maxItemSize') then cr.spec.thanos.queryFrontend.cache.maxItemSize else obs.thanos.queryFrontend.config.maxItemSize,
      maxItemSize: std.strReplace(std.strReplace(maxItemSize, "m", "MiB"), "g", "GiB"),
    } + if std.objectHas(cr.spec.thanos, 'queryFrontend') then cr.spec.thanos.queryFrontend else {},

    queryFrontendCache+:: (if std.objectHas(cr.spec.thanos, 'queryFrontend') && std.objectHas(cr.spec.thanos.queryFrontend, 'cache') then cr.spec.thanos.queryFrontend.cache else {}) + {
      memoryLimitMb: if std.objectHas(cr.spec.thanos.queryFrontend, 'cache') && std.objectHas(cr.spec.thanos.queryFrontend.cache, 'memoryLimitMb') then cr.spec.thanos.queryFrontend.cache.memoryLimitMb else obs.thanos.queryFrontendCache.config.memoryLimitMb,
      resources+: (
        if std.objectHas(cr.spec.thanos.queryFrontend.cache, 'resources') then {
          memcached: cr.spec.thanos.queryFrontend.cache.resources,
        } else {}
      ) + (
        if std.objectHas(cr.spec.thanos.queryFrontend.cache, 'exporterResources') then {
          exporter: cr.spec.thanos.queryFrontend.cache.exporterResources,
        } else {}
      ),
      securityContext: if std.objectHas(cr.spec, 'securityContext') then cr.spec.securityContext else obs.thanos.queryFrontendCache.config.securityContext,
    },
  }),

  loki:: if std.objectHas(cr.spec, 'loki') then loki(obs.loki.config {
    local cfg = self,
    name: cr.metadata.name + '-' + cfg.commonLabels['app.kubernetes.io/name'],
    namespace: cr.metadata.namespace,
    image: if std.objectHas(cr.spec.loki, 'image') then cr.spec.loki.image else obs.loki.config.image,
    replicas: if std.objectHas(cr.spec.loki, 'replicas') then cr.spec.loki.replicas else obs.loki.config.replicas,
    version: if std.objectHas(cr.spec.loki, 'version') then cr.spec.loki.version else obs.loki.config.version,
    objectStorageConfig: if cr.spec.objectStorageConfig.loki != null then cr.spec.objectStorageConfig.loki else obs.loki.config.objectStorageConfig,
  }) else {},

  gubernator:: {},

  api:: api(obs.api.config + (
    if std.objectHas(cr.spec, 'api') then cr.spec.api else {}
  ) + {
    local cfg = self,
    name: cr.metadata.name + '-' + cfg.commonLabels['app.kubernetes.io/name'],
    namespace: cr.metadata.namespace,
    commonLabels+:: {
      'app.kubernetes.io/instance': cr.metadata.name,
      'app.kubernetes.io/version': if std.objectHas(cr.spec, 'api') && std.objectHas(cr.spec.api, 'version') then cr.spec.api.version else obs.api.config.version,
    },
    tenants: if std.objectHas(cr.spec, 'api') && std.objectHas(cr.spec.api, 'tenants') then { tenants: cr.spec.api.tenants } else obs.api.config.tenants,
    rateLimiter: {},
    metrics: {
      readEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
        operatorObs.thanos.queryFrontend.service.metadata.name,
        operatorObs.thanos.queryFrontend.service.metadata.namespace,
        operatorObs.thanos.queryFrontend.service.spec.ports[0].port,
      ],
      writeEndpoint: if std.objectHas(cr.spec.api, 'writeEndpoint') then cr.spec.api.writeEndpoint
      else 'http://%s.%s.svc.cluster.local:%d' % [
        operatorObs.thanos.receiversService.metadata.name,
        operatorObs.thanos.receiversService.metadata.namespace,
        operatorObs.thanos.receiversService.spec.ports[2].port,
      ],
    },
    logs: if std.objectHas(cr.spec, 'loki') then {
      readEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
        operatorObs.loki.manifests['query-frontend-http-service'].metadata.name,
        operatorObs.loki.manifests['query-frontend-http-service'].metadata.namespace,
        operatorObs.loki.manifests['query-frontend-http-service'].spec.ports[0].port,
      ],
      tailEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
        operatorObs.loki.manifests['querier-http-service'].metadata.name,
        operatorObs.loki.manifests['querier-http-service'].metadata.namespace,
        operatorObs.loki.manifests['querier-http-service'].spec.ports[0].port,
      ],
      writeEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
        operatorObs.loki.manifests['distributor-http-service'].metadata.name,
        operatorObs.loki.manifests['distributor-http-service'].metadata.namespace,
        operatorObs.loki.manifests['distributor-http-service'].spec.ports[0].port,
      ],
    } else {},
  }),
};

{
  manifests: std.mapWithKey(function(k, v) v {
    metadata+: {
      ownerReferences: [{
        apiVersion: cr.apiVersion,
        kind: cr.kind,
        name: cr.metadata.name,
        uid: cr.metadata.uid,
        blockOwnerdeletion: true,
        controller: true,
      }],
    } + (
      if (v.kind == 'StatefulSet' && std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-store-shard')) then {
        local labels = v.metadata.labels,
        labels: {
          [labelName]: labels[labelName]
          for labelName in std.objectFields(labels)
          if !std.setMember(labelName, ['store.thanos.io/shard'])
        } + {
          'store.observatorium.io/shard':labels['store.thanos.io/shard'],
        }
      } else {}
    ) + (
      if (v.kind == 'StatefulSet' && std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-query-frontend-memcached')) then {
        name: 'observability-thanos-query-frontend-memcached',
      } else {}
    ) + (
      if (std.objectHas(cr.spec.thanos.compact, 'serviceAccountAnnotations') && v.kind == 'ServiceAccount' && std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-compact')) then {
        annotations+: cr.spec.thanos.compact.serviceAccountAnnotations,
      } else {}
    ) + (
      if (std.objectHas(cr.spec.thanos.query, 'serviceAccountAnnotations') && v.kind == 'ServiceAccount' && std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-query')) then {
        annotations+: cr.spec.thanos.query.serviceAccountAnnotations,
      } else {}
    ) + (
      if (std.objectHas(cr.spec.thanos.store, 'serviceAccountAnnotations') && v.kind == 'ServiceAccount' && std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-store-shard')) then {
        annotations+: cr.spec.thanos.store.serviceAccountAnnotations,
      } else {}
    ) + (
      if (std.objectHas(cr.spec.thanos.receivers, 'serviceAccountAnnotations') && v.kind == 'ServiceAccount' && std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-receive')) then {
        annotations+: cr.spec.thanos.store.serviceAccountAnnotations,
      } else {}
    ) + (
      if (std.objectHas(cr.spec.thanos.rule, 'serviceAccountAnnotations') && v.kind == 'ServiceAccount' && std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-rule')) then {
        annotations+: cr.spec.thanos.store.serviceAccountAnnotations,
      } else {}
    ),
    spec+: (
      if (std.objectHas(cr.spec, 'nodeSelector') && (v.kind == 'StatefulSet' || v.kind == 'Deployment')) then {
        template+: {
          spec+: {
            nodeSelector: cr.spec.nodeSelector,
          },
        },
      } else {}
    ) + (
      if (v.kind == 'StatefulSet' || v.kind == 'Deployment') then {
        template+: {
          spec+: {
            affinity: {
              podAntiAffinity: {
                preferredDuringSchedulingIgnoredDuringExecution: [
                  {
                    podAffinityTerm: {
                      labelSelector: {
                        matchExpressions: [
                          {
                            key: 'app.kubernetes.io/name',
                            operator: 'In',
                            values: [
                              v.metadata.labels['app.kubernetes.io/name'],
                            ],
                          },
                          {
                            key: 'app.kubernetes.io/instance',
                            operator: 'In',
                            values: [
                              v.metadata.labels['app.kubernetes.io/instance'],
                            ],
                          },
                        ],
                      },
                      topologyKey: 'kubernetes.io/hostname',
                    },
                    weight: 30,
                  },
                  {
                    podAffinityTerm: {
                      labelSelector: {
                        matchExpressions: [
                          {
                            key: 'app.kubernetes.io/name',
                            operator: 'In',
                            values: [
                              v.metadata.labels['app.kubernetes.io/name'],
                            ],
                          },
                          {
                            key: 'app.kubernetes.io/instance',
                            operator: 'In',
                            values: [
                              v.metadata.labels['app.kubernetes.io/instance'],
                            ],
                          },
                        ],
                      },
                      topologyKey: 'topology.kubernetes.io/zone',
                    },
                    weight: 70,
                  },
                ],
              },
            },
          },
        },
      } else {}
    ) + (
      if (v.kind == 'Service' && std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-store-shard')) then {
        local selector = v.spec.selector,
        selector: {
            [labelName]: selector[labelName]
            for labelName in std.objectFields(selector)
            if !std.setMember(labelName, ['store.thanos.io/shard'])
          } + {
            'store.observatorium.io/shard': selector['store.thanos.io/shard'],
        },
      } else {}
    ) + (
      if (v.kind == 'StatefulSet' && std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-store-shard')) then {
        local matchLabels = v.spec.selector.matchLabels,
        local labels = v.spec.template.metadata.labels,
        selector+: {
          matchLabels: {
            [labelName]: matchLabels[labelName]
            for labelName in std.objectFields(matchLabels)
            if !std.setMember(labelName, ['store.thanos.io/shard'])
          } + {
            'store.observatorium.io/shard': matchLabels['store.thanos.io/shard'],
          },
        },
        template+: {
          metadata+: {
            labels: {
              [labelName]: labels[labelName]
              for labelName in std.objectFields(labels)
              if !std.setMember(labelName, ['store.thanos.io/shard'])
            } + {
              'store.observatorium.io/shard': labels['store.thanos.io/shard'],
            },
          },
        },
        volumeClaimTemplates: [
          vct {
            metadata+:{
              labels: {
                [labelName]: matchLabels[labelName]
                for labelName in std.objectFields(matchLabels)
                if !std.setMember(labelName, ['store.thanos.io/shard'])
              } + {
                'store.observatorium.io/shard': matchLabels['store.thanos.io/shard'],
              },
            }
          }
          for vct in v.spec.volumeClaimTemplates
        ]
      } else {}
    ) + (
      if (std.objectHas(cr.spec, 'envVars') && (v.kind == 'StatefulSet' && (
        std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-compact') || 
        std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-receive') || 
        std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-rule') || 
        std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-store-shard')))) then {
        template+: {
          spec+: {
            containers: [
              if std.startsWith(c.name, 'thanos-') then c {
                env+:
                  [
                    { name: envName, value: cr.spec.envVars[envName] }
                    for envName in std.objectFields(cr.spec.envVars)
                  ]
              } else c
              for c in super.containers
            ],
          },
        },
      } else {}
    ) + (
      if (std.objectHas(cr.spec, 'affinity') && (v.kind == 'StatefulSet' || v.kind == 'Deployment')) then {
        template+: {
          spec+: {
            affinity+: cr.spec.affinity,
          },
        },
      } else {}
    ) + (
      if (std.objectHas(cr.spec, 'tolerations') && (v.kind == 'StatefulSet' || v.kind == 'Deployment')) then {
        template+: {
          spec+: {
            tolerations: cr.spec.tolerations,
          },
        },
      } else {}
    ) + (
      if (std.objectHas(cr.spec.thanos.rule, 'reloaderResources') && (v.kind == 'StatefulSet') && v.metadata.name == cr.metadata.name + '-thanos-rule') then {
        template+: {
          spec+: {
            containers: [
              if c.name == 'configmap-reloader' then c {
                resources: cr.spec.thanos.rule.reloaderResources,
              } else c
              for c in super.containers
            ],
          },
        },
      } else {}
    ) + (
      if (std.objectHas(cr.spec, 'pullSecret') && (v.kind == 'StatefulSet' || v.kind == 'Deployment')) then {
        template+: {
          spec+:{
            imagePullSecrets: [
              {
                name: cr.spec.pullSecret,
              },
            ],
          },
        },
      } else {}
    ) + (
      if (std.objectHas(cr.spec.objectStorageConfig.thanos, 'serviceAccountProjection') && 
        cr.spec.objectStorageConfig.thanos.serviceAccountProjection == true) && 
        (v.kind == 'StatefulSet' && (
        std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-compact') || 
        std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-receive') || 
        std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-rule') || 
        std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-store-shard'))) then {
        template+: {
          spec+: {
            containers: [
              if std.startsWith(c.name, 'thanos-') then c {
                volumeMounts+:
                  [
                    {
                      name: 'bound-sa-token',
                      mountPath: '/var/run/secrets/openshift/serviceaccount',
                      readOnly: true,
                    }
                  ]
              } else c
              for c in super.containers
            ],
            volumes+: [
              {
                name: 'bound-sa-token',
                projected: {
                  sources: [
                    {
                      serviceAccountToken: {
                        path: 'token',
                        audience: 'openshift',
                      },
                    },
                  ],
                },
              },
            ],
          },
        },
      } else {}
    ) + (
      if (v.kind == 'StatefulSet' &&
        std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-receive') &&
        std.objectHas(cr.spec.thanos.receivers, 'containers')) then {
        template+: {
          spec+: {
            containers: override_containers(super.containers, cr.spec.thanos.receivers.containers)
          },
        },
      } else {}
    ) + (
      if (v.kind == 'StatefulSet' &&
        std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-store-shard') &&
        std.objectHas(cr.spec.thanos.store, 'containers')) then {
        template+: {
          spec+: {
            containers: override_containers(super.containers, cr.spec.thanos.store.containers)
          },
        },
      } else {}
    ) + (
      if (v.kind == 'StatefulSet' &&
        std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-store-memcached') &&
        std.objectHas(cr.spec.thanos.store.cache, 'containers')) then {
        template+: {
          spec+: {
            containers: override_containers(super.containers, cr.spec.thanos.store.containers)
          },
        },
      } else {}
    ) + (
      // Will this also apply to QFE??
      if (v.kind == 'Deployment' &&
        std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-query') &&
        std.objectHas(cr.spec.thanos.query, 'containers')) then {
        template+: {
          spec+: {
            containers: override_containers(super.containers, cr.spec.thanos.query.containers)
          },
        },
      } else {}
    ) + (
      if (v.kind == 'Deployment' &&
        std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-query-frontend') &&
        std.objectHas(cr.spec.thanos.queryFrontend, 'containers')) then {
        template+: {
          spec+: {
            containers: override_containers(super.containers, cr.spec.thanos.queryFrontend.containers)
          },
        },
      } else {}
    ) + (
      if (v.kind == 'StatefulSet' &&
        std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-rule') &&
        std.objectHas(cr.spec.thanos.rule, 'containers')) then {
        template+: {
          spec+: {
            containers: override_containers(super.containers, cr.spec.thanos.rule.containers)
          },
        },
      } else {}
    ) + (
      if (v.kind == 'StatefulSet' &&
        std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-compact') &&
        std.objectHas(cr.spec.thanos.compact, 'containers')) then {
        template+: {
          spec+: {
            containers: override_containers(super.containers, cr.spec.thanos.compact.containers)
          },
        },
      } else {}
    ),
  }, operatorObs.manifests),
}
