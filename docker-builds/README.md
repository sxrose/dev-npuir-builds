## Quick start

First you will need Docker image for builder. Image with tag:`ascend-builder` will be created.

```bash
$ ./build-image.sh
```

### Building triton-ascend wheel

To build `triton-ascend` wheel run:

```
$ ./build-triton-wheel.sh
```

Wheel package will await you in `./triton-ascend/dist`
