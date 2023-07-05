# Build the manager binary
FROM registry.ci.openshift.org/stolostron/builder:go1.18-linux AS builder

WORKDIR /workspace
# Copy the jsonnet source
COPY . operator/
COPY ./jsonnet/vendor/stolo-configuration/components/ components/

# Build
WORKDIR /workspace/operator
RUN GO111MODULE="on" CGO_ENABLED=1 go build github.com/brancz/locutus

FROM registry.access.redhat.com/ubi8/ubi-minimal:latest

WORKDIR /
COPY --from=builder /workspace/operator/locutus /
COPY --from=builder /workspace/operator/jsonnet /
COPY --from=builder /workspace/components/ /components/
COPY --from=builder /workspace/operator/jsonnet/vendor/ /vendor/

RUN chgrp -R 0 /vendor && chmod -R g=u /vendor
RUN chgrp -R 0 /components && chmod -R g=u /components

ARG BUILD_DATE
ARG VERSION
ARG VCS_REF
ARG DOCKERFILE_PATH
ARG VCS_BRANCH

LABEL vendor="Observatorium" \
    name="observatorium/operator" \
    description="Observatorium Operator" \
    io.k8s.display-name="observatorium/operator" \
    io.k8s.description="Observatorium Operator" \
    maintainer="Observatorium <team-monitoring@redhat.com>" \
    version="$VERSION" \
    org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.description="Observatorium Operator" \
    org.label-schema.docker.cmd="docker run --rm observatorium/operator" \
    org.label-schema.docker.dockerfile=$DOCKERFILE_PATH \
    org.label-schema.name="observatorium/operator" \
    org.label-schema.schema-version="1.0" \
    org.label-schema.vcs-branch=$VCS_BRANCH \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-url="https://github.com/observatorium/operator" \
    org.label-schema.vendor="observatorium/operator" \
    org.label-schema.version=$VERSION

ENTRYPOINT ["/locutus", "--renderer=jsonnet", "--renderer.jsonnet.entrypoint=main.jsonnet", "--trigger=resource", "--trigger.resource.config=config.yaml"]
