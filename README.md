# kairOS
A Linux distribution for the agentic era.

## License

The source code, build configuration, build recipes, scripts, patches,
and other original files in this repository are licensed under the
Apache License, Version 2.0.

See [LICENSE](LICENSE).

Software included or referenced by the build system is subject to its
respective upstream copyright and license terms.

## Run

Build the image:

```bash
docker build -t kairos .
```

Run:

```bash
docker run --rm -it \
  -p 6080:6080 \
  -p 18789:18789 \
  -v kairos-workspaces:/home/kair/workspaces \
  -v kairos-openclaw:/home/kair/.openclaw \
  kairos
```

Open:

```bash
http://localhost:6080/vnc.html
```

This launches the Fedora desktop with Element and OpenClaw preinstalled.