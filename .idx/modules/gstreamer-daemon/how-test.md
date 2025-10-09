curl -X POST -G http://localhost:8080/pipelines \
--data-urlencode "name=mjpeg" \
--data-urlencode "description=videotestsrc is-live=true ! videoconvert ! jpegenc ! multipartmux ! tcpserversink host=0.0.0.0 port=8081"

gst-client pipeline_create mjpeg2 "videotestsrc pattern=ball is-live=true ! \
  video/x-raw,width=640,height=480,framerate=15/1 ! \
  videoconvert ! \
  jpegenc quality=85 ! \
  multipartmux boundary=--videoboundary ! \
  queue ! \
  tcpserversink host=0.0.0.0 port=8082"


  ### 3. **Test the setup**

```bash
# Test overlay loading
nix-instantiate --eval --strict .idx/dev.nix -A packages

# Build for ARM64
nix-build .idx/dev.nix -A packages.androidLibs-aarch64 -o result-arm64

# Enter development shell
nix-shell .idx/dev.nix -A shell
```

### 4. **Deploy to Android project**

```bash
# After successful build
cp -rL result-arm64/lib/*.so agdk-eframe/app/src/main/jniLibs/arm64-v8a/
cp -rL result-arm64/lib/gstreamer-1.0/*.so agdk-eframe/app/src/main/jniLibs/arm64-v8a/
```
