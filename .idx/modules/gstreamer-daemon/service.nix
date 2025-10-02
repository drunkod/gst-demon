{ pkgs, gstd }:

let
  # Wrapper script to start gstd like in the Docker container
  gstdWrapper = pkgs.writeShellScriptBin "gstd-start" ''
    #!/usr/bin/env bash

    # Create directories
    mkdir -p /tmp/gstd/logs
    mkdir -p $PWD/recording

    # Check if already running
    if pgrep -x "gstd" > /dev/null; then
      echo "GStreamer Daemon is already running"
      exit 1
    fi

    echo "Starting GStreamer Daemon..."
    echo "HTTP interface will be available at http://localhost:8080"

    # Start gstd with the same options as the Docker container
    ${pkgs.dumb-init}/bin/dumb-init -- \
      ${gstd}/bin/gstd \
      --enable-http-protocol \
      --http-address=0.0.0.0 \
      --http-port=8080 \
      "$@" &

    # Save PID
    echo $! > /tmp/gstd/gstd.pid

    echo "GStreamer Daemon started with PID $(cat /tmp/gstd/gstd.pid)"
    echo "Use 'gstd-stop' to stop the daemon"
    echo "Use 'gst-client' to interact with the daemon"
  '';

  # Stop script
  gstdStop = pkgs.writeShellScriptBin "gstd-stop" ''
    #!/usr/bin/env bash

    if [ -f /tmp/gstd/gstd.pid ]; then
      PID=$(cat /tmp/gstd/gstd.pid)
      if kill -0 $PID 2>/dev/null; then
        echo "Stopping GStreamer Daemon (PID: $PID)..."
        ${gstd}/bin/gstd -k || kill $PID
        rm -f /tmp/gstd/gstd.pid
        echo "GStreamer Daemon stopped"
      else
        echo "GStreamer Daemon is not running"
        rm -f /tmp/gstd/gstd.pid
      fi
    else
      # Try to kill by name
      ${gstd}/bin/gstd -k 2>/dev/null || true
      echo "GStreamer Daemon stopped (if it was running)"
    fi
  '';

  # Status script
  gstdStatus = pkgs.writeShellScriptBin "gstd-status" ''
    #!/usr/bin/env bash

    if pgrep -x "gstd" > /dev/null; then
      echo "✅ GStreamer Daemon is running"
      if [ -f /tmp/gstd/gstd.pid ]; then
        echo "   PID: $(cat /tmp/gstd/gstd.pid)"
      fi
      echo "   HTTP interface: http://localhost:8080"

      # Test HTTP interface
      if ${pkgs.curl}/bin/curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/pipelines 2>/dev/null | grep -q "200"; then
        echo "   HTTP interface: ✅ responding"
      else
        echo "   HTTP interface: ⚠️  not responding"
      fi
    else
      echo "❌ GStreamer Daemon is not running"
      echo "   Run 'gstd-start' to start it"
    fi
  '';

  # Client wrapper with examples
  gstClientWrapper = pkgs.writeShellScriptBin "gst-client" ''
    #!/usr/bin/env bash

    # Check if gstd is running
    if ! pgrep -x "gstd" > /dev/null; then
      echo "Warning: GStreamer Daemon is not running. Start it with 'gstd-start'"
      exit 1
    fi

    # If no arguments, show help
    if [ $# -eq 0 ]; then
      echo "GStreamer Daemon Client"
      echo ""
      echo "Usage: gst-client <command> [arguments]"
      echo ""
      echo "Examples:"
      echo "  # Create a test pipeline"
      echo "  gst-client pipeline_create testpipe videotestsrc ! autovideosink"
      echo ""
      echo "  # Play the pipeline"
      echo "  gst-client pipeline_play testpipe"
      echo ""
      echo "  # Stop the pipeline"
      echo "  gst-client pipeline_stop testpipe"
      echo ""
      echo "  # Delete the pipeline"
      echo "  gst-client pipeline_delete testpipe"
      echo ""
      echo "  # List all pipelines"
      echo "  gst-client list_pipelines"
      echo ""
      exit 0
    fi

    # Forward to actual gst-client
    exec ${gstd}/bin/gst-client "$@"
  '';

in
{
  wrapper = pkgs.symlinkJoin {
    name = "gstd-services";
    paths = [ gstdWrapper gstdStop gstdStatus ];
  };

  client = gstClientWrapper;
}