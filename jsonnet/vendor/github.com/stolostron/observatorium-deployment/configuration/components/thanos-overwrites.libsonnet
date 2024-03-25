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
}
