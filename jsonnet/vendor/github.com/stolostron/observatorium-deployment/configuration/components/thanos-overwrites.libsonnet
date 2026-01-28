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
                  '--block-discovery-strategy=recursive',
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
  stores+:: {
    shards:
      std.mapWithKey(function(shard, obj) obj {  // loops over each [shard-n]:obj
        statefulSet+: {
          spec+: {
            template+: {
              spec+: {
                containers: [
                  if c.name == 'thanos-store' then c {
                    args+: [
                      '--block-discovery-strategy=recursive',
                    ],
                  } else c
                  for c in super.containers
                ],
              },
            },
          },
        },
      }, super.shards),
  },
}
