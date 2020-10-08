#!/bin/bash -e

podman run -i --rm quay.io/coreos/fcct:release --pretty --strict < example.fcc > example.ign