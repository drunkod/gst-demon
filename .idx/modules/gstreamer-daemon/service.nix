{ pkgs, gstd, interpipe }:  # ✅ Accept interpipe parameter

let
  # Wrapper script to start gstd
  gstdWrapper = pkgs.writeShellScriptBin "gstd-start" ''
    #!/usr/bin/env bash
    set -euo pipefail

    GSTD_STATE_DIR="/tmp/gstd"
    GSTD_LOG_DIR="$GSTD_STATE_DIR/logs"
    GSTD_PID_FILE="$GSTD_STATE_DIR/gstd.pid"
    RECORDING_DIR="$PWD/recording"

    # Create directories
    mkdir -p "$GSTD_LOG_DIR" || {
      echo "ERROR: Failed to create log directory: $GSTD_LOG_DIR"
      exit 1
    }
    
    mkdir -p "$RECORDING_DIR" || {
      echo "ERROR: Failed to create recording directory: $RECORDING_DIR"
      exit 1
    }

    # Check if already running
    if pgrep -x "gstd" > /dev/null; then
      echo "⚠️  GStreamer Daemon is already running"
      if [ -f "$GSTD_PID_FILE" ]; then
        echo "   PID: $(cat "$GSTD_PID_FILE")"
      fi
      exit 1
    fi

    # Build GStreamer plugin path
    GST_PLUGINS=""
    GST_PLUGINS="$GST_PLUGINS:${interpipe}/lib/gstreamer-1.0"
    GST_PLUGINS="$GST_PLUGINS:${pkgs.gst_all_1.gstreamer.out}/lib/gstreamer-1.0"
    GST_PLUGINS="$GST_PLUGINS:${pkgs.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0"
    GST_PLUGINS="$GST_PLUGINS:${pkgs.gst_all_1.gst-plugins-good}/lib/gstreamer-1.0"
    GST_PLUGINS="$GST_PLUGINS:${pkgs.gst_all_1.gst-plugins-bad}/lib/gstreamer-1.0"
    GST_PLUGINS="$GST_PLUGINS:${pkgs.gst_all_1.gst-plugins-ugly}/lib/gstreamer-1.0"
    GST_PLUGINS="$GST_PLUGINS:${pkgs.gst_all_1.gst-libav}/lib/gstreamer-1.0"
    GST_PLUGINS="$GST_PLUGINS:${pkgs.gst_all_1.gst-vaapi}/lib/gstreamer-1.0"
    
    # Remove leading colon
    GST_PLUGINS="''${GST_PLUGINS#:}"

    echo "🚀 Starting GStreamer Daemon..."
    echo "   State dir: $GSTD_STATE_DIR"
    echo "   Log dir: $GSTD_LOG_DIR"
    echo "   Recording dir: $RECORDING_DIR"
    echo ""
    echo "Interfaces:"
    echo "   • TCP:  127.0.0.1:5000 (for gst-client)"
    echo "   • HTTP: http://0.0.0.0:8080 (for REST API)"
    echo ""

    # Start gstd with environment variables for plugin discovery
    GST_PLUGIN_SYSTEM_PATH_1_0="$GST_PLUGINS" \
    GST_PLUGIN_PATH_1_0="$GST_PLUGINS" \
    GST_PLUGIN_PATH="$GST_PLUGINS" \
    ${pkgs.dumb-init}/bin/dumb-init -- \
      ${gstd}/bin/gstd \
      --enable-http-protocol \
      --http-address=0.0.0.0 \
      --http-port=8080 \
      --enable-tcp-protocol \
      --tcp-address=127.0.0.1 \
      --tcp-base-port=5000 \
      "$@" &

    DAEMON_PID=$!
    echo "$DAEMON_PID" > "$GSTD_PID_FILE"

    # Wait and verify startup
    echo -n "Waiting for daemon to start..."
    sleep 2
    
    if ! kill -0 "$DAEMON_PID" 2>/dev/null; then
      echo " ❌ FAILED"
      echo ""
      echo "ERROR: GStreamer Daemon failed to start"
      echo "Check logs in: $GSTD_LOG_DIR"
      rm -f "$GSTD_PID_FILE"
      exit 1
    fi
    
    echo " ✅ OK"
    echo ""
    echo "✅ GStreamer Daemon started successfully"
    echo "   PID: $DAEMON_PID"
    echo ""
    echo "Plugin path includes:"
    echo "   • interpipe     ✅"
    echo "   • core elements ✅ (fakesink, identity, etc.)"
    echo "   • base plugins  ✅ (videotestsrc, etc.)"
    echo "   • good plugins  ✅"
    echo "   • bad plugins   ✅"
    echo "   • ugly plugins  ✅"
    echo "   • libav         ✅"
    echo ""
    echo "Usage Examples:"
    echo ""
    echo "  # Simple test (should work!):"
    echo "  gst-client pipeline_create test \"videotestsrc num-buffers=100 ! fakesink\""
    echo "  gst-client pipeline_play test"
    echo ""
    echo "  # Interpipe example:"
    echo "  gst-client pipeline_create sink \"videotestsrc ! interpipesink name=mysink\""
    echo "  gst-client pipeline_create src \"interpipesrc listen-to=mysink ! fakesink\""
    echo "  gst-client pipeline_play sink"
    echo "  gst-client pipeline_play src"
    echo ""
    echo "Management:"
    echo "  • gstd-status - Check status"
    echo "  • gstd-stop   - Stop daemon"
  '';

  # Stop script
  gstdStop = pkgs.writeShellScriptBin "gstd-stop" ''
    #!/usr/bin/env bash
    set -euo pipefail

    GSTD_PID_FILE="/tmp/gstd/gstd.pid"

    echo "🛑 Stopping GStreamer Daemon..."

    if [ -f "$GSTD_PID_FILE" ]; then
      PID=$(cat "$GSTD_PID_FILE")
      
      if kill -0 "$PID" 2>/dev/null; then
        echo "   Found daemon with PID: $PID"
        
        echo -n "   Attempting graceful shutdown..."
        if ${gstd}/bin/gstd -k 2>/dev/null; then
          echo " ✅ OK"
        else
          echo " ⚠️  gstd -k failed, sending SIGTERM"
          kill "$PID" 2>/dev/null || true
        fi
        
        WAIT_COUNT=0
        while kill -0 "$PID" 2>/dev/null && [ $WAIT_COUNT -lt 10 ]; do
          sleep 0.5
          WAIT_COUNT=$((WAIT_COUNT + 1))
        done
        
        if kill -0 "$PID" 2>/dev/null; then
          echo "   ⚠️  Process still running, sending SIGKILL"
          kill -9 "$PID" 2>/dev/null || true
          sleep 0.5
        fi
        
        rm -f "$GSTD_PID_FILE"
        echo "✅ GStreamer Daemon stopped"
      else
        echo "   Process $PID is not running (stale PID file)"
        rm -f "$GSTD_PID_FILE"
      fi
    else
      echo "   No PID file found, trying to kill by name..."
      
      if pgrep -x "gstd" > /dev/null; then
        ${gstd}/bin/gstd -k 2>/dev/null || {
          pkill -TERM "gstd" 2>/dev/null || true
          sleep 1
          pkill -KILL "gstd" 2>/dev/null || true
        }
        echo "✅ GStreamer Daemon stopped"
      else
        echo "ℹ️  GStreamer Daemon is not running"
      fi
    fi
  '';

  # Enhanced status script
  gstdStatus = pkgs.writeShellScriptBin "gstd-status" ''
    #!/usr/bin/env bash
    set -euo pipefail

    GSTD_PID_FILE="/tmp/gstd/gstd.pid"
    HTTP_ENDPOINT="http://localhost:8080/pipelines"

    echo "🔍 GStreamer Daemon Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if pgrep -x "gstd" > /dev/null; then
      echo "Process:         ✅ Running"
      
      if [ -f "$GSTD_PID_FILE" ]; then
        PID=$(cat "$GSTD_PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
          echo "PID:             $PID"
        else
          echo "PID:             ⚠️  Stale PID file ($PID not running)"
        fi
      else
        ACTUAL_PID=$(pgrep -x "gstd")
        echo "PID:             $ACTUAL_PID (no PID file)"
      fi
      
      echo ""
      echo "Interfaces:"
      
      # Check TCP port
      echo -n "  TCP (5000):    "
      if command -v nc >/dev/null 2>&1; then
        if nc -z 127.0.0.1 5000 2>/dev/null; then
          echo "✅ Listening (for gst-client)"
        else
          echo "❌ Not listening"
        fi
      else
        if ${pkgs.curl}/bin/curl -s --connect-timeout 1 telnet://127.0.0.1:5000 >/dev/null 2>&1; then
          echo "✅ Listening (for gst-client)"
        else
          echo "⚠️  Status unknown (nc not available)"
        fi
      fi
      
      # Check HTTP
      echo -n "  HTTP (8080):   "
      HTTP_CODE=$(${pkgs.curl}/bin/curl -s -o /dev/null -w "%{http_code}" "$HTTP_ENDPOINT" 2>/dev/null || echo "000")
      
      if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ Responding (HTTP $HTTP_CODE)"
        echo "                 http://localhost:8080"
      elif [ "$HTTP_CODE" = "000" ]; then
        echo "❌ Not responding"
      else
        echo "⚠️  HTTP $HTTP_CODE"
      fi
      
      if [ -f "$GSTD_PID_FILE" ] && kill -0 "$(cat "$GSTD_PID_FILE")" 2>/dev/null; then
        PID=$(cat "$GSTD_PID_FILE")
        if [ -f "/proc/$PID/stat" ]; then
          UPTIME=$(ps -p "$PID" -o etime= 2>/dev/null | xargs || echo "unknown")
          echo ""
          echo "Uptime:          $UPTIME"
        fi
      fi
      
      echo ""
      echo "Directories:"
      echo "  State:         /tmp/gstd"
      echo "  Logs:          /tmp/gstd/logs"
      echo "  Recording:     $PWD/recording"
      
    else
      echo "Process:         ❌ Not running"
      echo ""
      echo "Start the daemon with: gstd-start"
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  '';

  # Enhanced client wrapper
  gstClientWrapper = pkgs.writeShellScriptBin "gst-client" ''
    #!/usr/bin/env bash
    set -euo pipefail

    if ! pgrep -x "gstd" > /dev/null; then
      echo "❌ Error: GStreamer Daemon is not running"
      echo ""
      echo "Start it with: gstd-start"
      exit 1
    fi

    if [ $# -eq 0 ]; then
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "🎬 GStreamer Daemon Client"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
      echo "Usage: gst-client <command> [arguments]"
      echo ""
      echo "Pipeline Management (TCP Protocol - Port 5000):"
      echo "  gst-client pipeline_create <name> <description>"
      echo "  gst-client pipeline_play <name>"
      echo "  gst-client pipeline_pause <name>"
      echo "  gst-client pipeline_stop <name>"
      echo "  gst-client pipeline_delete <name>"
      echo "  gst-client list_pipelines"
      echo ""
      echo "Examples (gst-client via TCP):"
      echo "  # Simple test pipeline"
      echo "  gst-client pipeline_create test \"videotestsrc num-buffers=100 ! fakesink\""
      echo "  gst-client pipeline_play test"
      echo "  gst-client pipeline_stop test"
      echo "  gst-client pipeline_delete test"
      echo ""
      echo "  # Interpipe example"
      echo "  gst-client pipeline_create sink \"videotestsrc ! interpipesink name=mysink\""
      echo "  gst-client pipeline_create src \"interpipesrc listen-to=mysink ! fakesink\""
      echo "  gst-client pipeline_play sink"
      echo "  gst-client pipeline_play src"
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "HTTP API Examples (Port 8080):"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
      echo "# Create pipeline"
      echo "curl -X POST 'http://localhost:8080/pipelines?name=test&description=videotestsrc%20num-buffers=100%20!%20fakesink'"
      echo ""
      echo "# Play pipeline"
      echo "curl -X PUT 'http://localhost:8080/pipelines/test/state?name=playing'"
      echo ""
      echo "# List pipelines"
      echo "curl 'http://localhost:8080/pipelines'"
      echo ""
      echo "# Delete pipeline"
      echo "curl -X DELETE 'http://localhost:8080/pipelines?name=test'"
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
      echo "Documentation:"
      echo "  https://developer.ridgerun.com/wiki/index.php/GStreamer_Daemon"
      echo ""
      exit 0
    fi

    if [ -x "${gstd}/bin/gst-client" ]; then
      exec "${gstd}/bin/gst-client" "$@"
    else
      echo "❌ Error: gst-client binary not found"
      echo ""
      echo "Expected location: ${gstd}/bin/gst-client"
      exit 1
    fi
  '';

in
{
  wrapper = pkgs.symlinkJoin {
    name = "gstd-services";
    paths = [ gstdWrapper gstdStop gstdStatus ];
  };

  client = gstClientWrapper;
}