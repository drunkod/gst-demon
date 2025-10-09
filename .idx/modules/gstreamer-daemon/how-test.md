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