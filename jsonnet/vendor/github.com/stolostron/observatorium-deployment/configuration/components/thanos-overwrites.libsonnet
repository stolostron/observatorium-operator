{
  local thanos = self,
  receivers+:: {
    hashrings:
      std.mapWithKey(function(hashring, obj) obj {  // loops over each [hashring]:obj
        statefulSet+: {
          spec+: {
            template+: {
              spec+: {
                containers: [
                  if c.name == 'thanos-receive' then c {
                    args+: [
                      '--tsdb.too-far-in-future.time-window=5m',
                    ],
                  }
                  else c
                  for c in super.containers
                ],
              },
            },
          },
        },
      }, super.hashrings),
  },
  compact+:: {
    statefulSet+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-compact' then c {
                args+: [
                  '--downsample.concurrency=4',
                  '--compact.concurrency=4',
                  '--debug.max-compaction-level=3',
                ],
              }
              else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },
  query+:: {
    deployment+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              if c.name == 'thanos-query' then c {
                args+: [
                  '--query.promql-engine=thanos',
                ],
              }
              else c
              for c in super.containers
            ],
          },
        },
      },
    },
  },
}
