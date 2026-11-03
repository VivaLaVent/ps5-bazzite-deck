# Needs the linux-ps5 RPM in kernel/ (see README)

ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite-deck
ARG BASE_TAG=stable

FROM scratch AS ctx
COPY build_files/ /build_files/
COPY kernel/ /kernel/
COPY ps5/ /ps5/
COPY system_files/ /system_files/

FROM ${BASE_IMAGE}:${BASE_TAG}
ARG BASE_IMAGE
ARG BASE_TAG
ARG IMAGE_VERSION=dev

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    BASE_IMAGE="${BASE_IMAGE}:${BASE_TAG}" IMAGE_VERSION="${IMAGE_VERSION}" \
    /ctx/build_files/build.sh

RUN --mount=type=tmpfs,target=/run --network=none \
    bootc container lint
