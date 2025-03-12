#!/bin/bash
# CockroachNET: Distributed System Network Testing Tool
# Tests network connectivity between distributed system nodes
# and reports on packet loss, latency, throughput, and other metrics.

# Default configuration values
DEFAULT_NODES=()
DEFAULT_PORTS=("8080")
DEFAULT_TEST_DURATION=3600
DEFAULT_LOG_DIR="/var/log/CockroachNET-tests"
DEFAULT_INTERVAL=60
DEFAULT_PING_INTERVAL=5
DEFAULT_ALERT_THRESHOLD_LATENCY_MS=100
DEFAULT_ALERT_THRESHOLD_PACKET_LOSS=1
DEFAULT_THROUGHPUT_TEST_SIZE="10M"

# Parse command line arguments
parse_arguments() {
  # Display help information
  if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 [options]"
    echo 
    echo "Options:"
    echo "  -n, --nodes IP1,IP2,...    Comma-separated list of node IPs to test"
    echo "  -p, --ports PORT1,PORT2... Comma-separated list of ports to test"
    echo "  -d, --duration SECONDS     Test duration in seconds (default: 3600)"
    echo "  -l, --log-dir DIRECTORY    Directory to store logs (default: /var/log/CockroachNET-tests)"
    echo "  -i, --interval SECONDS     Interval between test runs (default: 60)"
    echo "  --ping-interval SECONDS    Interval between ping tests (default: 5)"
    echo "  --latency-threshold MS     Alert threshold for latency in ms (default: 100)"
    echo "  --loss-threshold PERCENT   Alert threshold for packet loss in % (default: 1)"
    echo "  -h, --help                 Display this help message"
    echo
    echo "Example:"
    echo "  $0 --nodes 10.0.0.1,10.0.0.2 --ports 8080,9090 --duration 7200"
    exit 0
  fi

  # Set default values
  NODES=("${DEFAULT_NODES[@]}")
  PORTS=("${DEFAULT_PORTS[@]}")
  TEST_DURATION=$DEFAULT_TEST_DURATION
  LOG_DIR=$DEFAULT_LOG_DIR
  INTERVAL=$DEFAULT_INTERVAL
  PING_INTERVAL=$DEFAULT_PING_INTERVAL
  ALERT_THRESHOLD_LATENCY_MS=$DEFAULT_ALERT_THRESHOLD_LATENCY_MS
  ALERT_THRESHOLD_PACKET_LOSS=$DEFAULT_ALERT_THRESHOLD_PACKET_LOSS
  THROUGHPUT_TEST_SIZE=$DEFAULT_THROUGHPUT_TEST_SIZE

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--nodes)
        IFS=',' read -ra NODES <<< "$2"
        shift 2
        ;;
      -p|--ports)
        IFS=',' read -ra PORTS <<< "$2"
        shift 2
        ;;
      -d|--duration)
        TEST_DURATION=$2
        shift 2
        ;;
      -l|--log-dir)
        LOG_DIR=$2
        shift 2
        ;;
      -i|--interval)
        INTERVAL=$2
        shift 2
        ;;
      --ping-interval)
        PING_INTERVAL=$2
        shift 2
        ;;
      --latency-threshold)
        ALERT_THRESHOLD_LATENCY_MS=$2
        shift 2
        ;;
      --loss-threshold)
        ALERT_THRESHOLD_PACKET_LOSS=$2
        shift 2
        ;;
      *)
        echo "Unknown option: $1"
        echo "Use --help for usage information."
        exit 1
        ;;
    esac
  done

  # Check if required parameters are provided
  if [ ${#NODES[@]} -eq 0 ]; then
    echo "Error: No target nodes specified. Use --nodes option."
    echo "Use --help for usage information."
    exit 1
  fi

  # Create output file path
  OUTPUT_FILE="$LOG_DIR/network_test_$(date +%Y%m%d_%H%M%S).log"
}

# Ensure needed tools are installed
check_requirements() {
  echo "Checking for required tools..."
  local required_tools=("ping" "nc" "iperf3" "tcpdump" "ss" "traceroute" "nmap" "bc")
  local missing_tools=()
  
  for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      missing_tools+=("$tool")
    fi
  done
  
  if [ ${#missing_tools[@]} -ne 0 ]; then
    echo "Missing required tools: ${missing_tools[*]}"
    echo "Please install them using: yum install -y iputils nc iperf3 tcpdump iproute nmap-ncat traceroute nmap bc"
    exit 1
  fi
  
  echo "All required tools are installed."
}

# Create log directory if it doesn't exist
setup() {
  mkdir -p "$LOG_DIR"
  echo "Network connectivity test started at $(date)" | tee -a "$OUTPUT_FILE"
  echo "Testing connectivity between nodes: ${NODES[*]}" | tee -a "$OUTPUT_FILE"
  echo "Testing ports: ${PORTS[*]}" | tee -a "$OUTPUT_FILE"
  echo "Test will run for $TEST_DURATION seconds" | tee -a "$OUTPUT_FILE"
  echo "---------------------------------------------" | tee -a "$OUTPUT_FILE"
}

# Basic connectivity test using ping
test_basic_connectivity() {
  local source_node=$1
  local target_node=$2
  
  echo "Testing basic connectivity from $source_node to $target_node..." | tee -a "$OUTPUT_FILE"
  
  # Run ping with 10 packets, 1 second interval
  ping_result=$(ping -c 10 -i 1 "$target_node" 2>&1)
  ping_status=$?
  
  echo "$ping_result" >> "$OUTPUT_FILE"
  
  # Extract packet loss percentage and round-trip times
  packet_loss=$(echo "$ping_result" | grep -oP '\d+(?=% packet loss)')
  avg_rtt=$(echo "$ping_result" | grep -oP 'rtt min/avg/max/mdev = [^/]+/\K[^/]+')
  
  if [ "$ping_status" -ne 0 ]; then
    echo "ALERT: Cannot ping $target_node from $source_node" | tee -a "$OUTPUT_FILE"
    return 1
  elif [ -n "$packet_loss" ] && [ "$packet_loss" -gt "$ALERT_THRESHOLD_PACKET_LOSS" ]; then
    echo "ALERT: High packet loss ($packet_loss%) to $target_node from $source_node" | tee -a "$OUTPUT_FILE"
    return 2
  elif [ -n "$avg_rtt" ] && (echo "$avg_rtt > $ALERT_THRESHOLD_LATENCY_MS" | bc -l | grep -q 1); then
    echo "ALERT: High latency ($avg_rtt ms) to $target_node from $source_node" | tee -a "$OUTPUT_FILE"
    return 3
  fi
  
  echo "Basic connectivity test passed for $target_node" | tee -a "$OUTPUT_FILE"
  return 0
}

# Port connectivity test for specified ports
test_port_connectivity() {
  local source_node=$1
  local target_node=$2
  
  echo "Testing port connectivity from $source_node to $target_node..." | tee -a "$OUTPUT_FILE"
  
  for port in "${PORTS[@]}"; do
    nc_result=$(nc -zv -w 5 "$target_node" "$port" 2>&1)
    nc_status=$?
    
    echo "$nc_result" >> "$OUTPUT_FILE"
    
    if [ "$nc_status" -ne 0 ]; then
      echo "ALERT: Cannot connect to $target_node:$port from $source_node" | tee -a "$OUTPUT_FILE"
      return 1
    fi
    
    echo "Port $port connectivity test passed for $target_node" | tee -a "$OUTPUT_FILE"
  done
  
  return 0
}

# Throughput test using iperf3
test_throughput() {
  local source_node=$1
  local target_node=$2
  
  echo "Testing network throughput from $source_node to $target_node..." | tee -a "$OUTPUT_FILE"
  
  # Assuming iperf3 server is running on target_node
  # You may need to start iperf3 in server mode on all nodes: iperf3 -s
  iperf_result=$(iperf3 -c "$target_node" -t 10 -J 2>&1)
  iperf_status=$?
  
  echo "$iperf_result" >> "$OUTPUT_FILE"
  
  if [ "$iperf_status" -ne 0 ]; then
    echo "ALERT: Throughput test failed from $source_node to $target_node" | tee -a "$OUTPUT_FILE"
    echo "Make sure iperf3 server is running on target node (iperf3 -s)" | tee -a "$OUTPUT_FILE"
    return 1
  fi
  
  # Extract throughput if in JSON format - handle both regular and scientific notation
  throughput=$(echo "$iperf_result" | grep -oP '"bits_per_second":\s*\K[0-9.]+e?[-+]?[0-9]*' | tail -1)
  
  # Handle scientific notation if present
  if [[ $throughput == *e* ]]; then
    throughput=$(echo "$throughput" | awk '{printf "%f", $1}')
  fi
  
  throughput_mbps=$(echo "$throughput/1000000" | bc -l)
  
  throughput_mbps=$(printf "%.2f" "$throughput_mbps")
  echo "Throughput: ${throughput_mbps} Mbps from $source_node to $target_node" | tee -a "$OUTPUT_FILE"
  return 0
}

# Test packet capture to examine traffic on specified ports
capture_traffic() {
  local node=$1
  local duration=30 # Capture for 30 seconds
  
  echo "Capturing traffic on $node for $duration seconds..." | tee -a "$OUTPUT_FILE"
  
  local capture_file="$LOG_DIR/traffic_$(date +%Y%m%d_%H%M%S).pcap"
  
  # Simplest approach - for a small number of ports
  if [ ${#PORTS[@]} -eq 1 ]; then
    # If only one port, use simple syntax
    tcpdump_cmd="tcpdump -i any tcp port ${PORTS[0]} -w $capture_file -c 1000"
  else
    # For multiple ports, create an expression with parentheses
    local port_expr="tcp port ${PORTS[0]}"
    for ((i=1; i<${#PORTS[@]}; i++)); do
      port_expr="$port_expr or tcp port ${PORTS[$i]}"
    done
    tcpdump_cmd="tcpdump -i any '($port_expr)' -w $capture_file -c 1000"
  fi
  
  # Run tcpdump on the node
  if [ "$node" == "$(hostname -I | awk '{print $1}')" ]; then
    eval $tcpdump_cmd &
    tcpdump_pid=$!
    sleep $duration
    kill $tcpdump_pid 2>/dev/null
  fi
  
  echo "Traffic capture completed and saved to $capture_file" | tee -a "$OUTPUT_FILE"
  echo "Analyze this file with: tcpdump -r $capture_file -A" | tee -a "$OUTPUT_FILE"
}

# Socket statistics for specified ports
check_socket_stats() {
  local node=$1
  
  echo "Checking socket statistics on $node..." | tee -a "$OUTPUT_FILE"
  
  # Construct the port filter for ss with proper word boundaries
  local port_filter=""
  for port in "${PORTS[@]}"; do
    if [ -z "$port_filter" ]; then
      port_filter=":$port\\b"
    else
      port_filter="$port_filter|:$port\\b"
    fi
  done
  
  # Run ss command to show socket statistics
  ss_result=$(ss -tunap | grep -E "$port_filter")
  
  echo "$ss_result" >> "$OUTPUT_FILE"
  
  # Count established connections
  established_count=$(echo "$ss_result" | grep 'ESTAB' | wc -l)
  
  echo "Established connections on monitored ports: $established_count" | tee -a "$OUTPUT_FILE"
}

# Check for packet retransmissions and other TCP issues
check_tcp_metrics() {
  local node=$1
  
  echo "Checking TCP metrics on $node..." | tee -a "$OUTPUT_FILE"
  
  # Get netstat statistics
  netstat_result=$(netstat -s | grep -E 'retransmit|drop|timeout|failed')
  
  echo "$netstat_result" >> "$OUTPUT_FILE"
  
  # Check for concerning patterns with more robust extraction
  retrans_count=$(echo "$netstat_result" | grep -oP '([0-9]+) segments retransmitted' | awk '{print $1}')
  
  if [ -n "$retrans_count" ] && [ "$retrans_count" -gt 100 ]; then
    echo "ALERT: High TCP retransmission count ($retrans_count) on $node" | tee -a "$OUTPUT_FILE"
  fi
}

# Run traceroute to check network path
check_network_path() {
  local source_node=$1
  local target_node=$2
  
  echo "Checking network path from $source_node to $target_node..." | tee -a "$OUTPUT_FILE"
  
  traceroute_result=$(traceroute -n "$target_node" 2>&1)
  
  echo "$traceroute_result" >> "$OUTPUT_FILE"
  
  # Check if traceroute was successful before counting hops
  if [ -n "$traceroute_result" ]; then
    # Count hops
    hop_count=$(echo "$traceroute_result" | grep -c "^ [0-9]")
    
    echo "Path to $target_node has $hop_count hops" | tee -a "$OUTPUT_FILE"
    
    # Check for timeouts in the path
    timeout_count=$(echo "$traceroute_result" | grep -c '\* \* \*')
    
    if [ "$timeout_count" -gt 0 ]; then
      echo "ALERT: Path to $target_node has $timeout_count hops with timeouts" | tee -a "$OUTPUT_FILE"
    fi
  else
    echo "Error: Could not run traceroute to $target_node" | tee -a "$OUTPUT_FILE"
  fi
}

# Main test function to run all tests between nodes
run_comprehensive_tests() {
  echo "Starting comprehensive network tests at $(date)" | tee -a "$OUTPUT_FILE"
  
  # Get local IP
  local_ip=$(hostname -I | awk '{print $1}')
  
  for target_node in "${NODES[@]}"; do
    # Skip testing against self
    if [ "$target_node" == "$local_ip" ]; then
      continue
    fi
    
    echo "==== Testing connectivity to $target_node ====" | tee -a "$OUTPUT_FILE"
    
    # Run all tests
    test_basic_connectivity "$local_ip" "$target_node"
    test_port_connectivity "$local_ip" "$target_node"
    test_throughput "$local_ip" "$target_node"
    check_network_path "$local_ip" "$target_node"
  done
  
  # Local node tests
  check_socket_stats "$local_ip"
  check_tcp_metrics "$local_ip"
  capture_traffic "$local_ip"
  
  echo "Comprehensive tests completed at $(date)" | tee -a "$OUTPUT_FILE"
  echo "---------------------------------------------" | tee -a "$OUTPUT_FILE"
}

# Continuous ping test to detect intermittent issues
run_continuous_ping() {
  echo "Starting continuous ping monitoring..." | tee -a "$OUTPUT_FILE"
  
  # Get local IP
  local_ip=$(hostname -I | awk '{print $1}')
  
  local ping_log="$LOG_DIR/ping_monitoring_$(date +%Y%m%d_%H%M%S).log"
  
  echo "Continuous ping results will be logged to $ping_log" | tee -a "$OUTPUT_FILE"
  
  local end_time=$(($(date +%s) + TEST_DURATION))
  
  while [ $(date +%s) -lt $end_time ]; do
    for target_node in "${NODES[@]}"; do
      # Skip pinging self
      if [ "$target_node" == "$local_ip" ]; then
        continue
      fi
      
      # Single ping with timeout
      ping_result=$(ping -c 1 -W 2 "$target_node" 2>&1)
      ping_status=$?
      
      timestamp=$(date +"%Y-%m-%d %H:%M:%S")
      
      if [ "$ping_status" -ne 0 ]; then
        echo "[$timestamp] ALERT: Failed to ping $target_node" | tee -a "$ping_log" "$OUTPUT_FILE"
      else
        # Extract ping time
        ping_time=$(echo "$ping_result" | grep -oP 'time=\K[0-9.]+')
        echo "[$timestamp] Ping to $target_node: ${ping_time}ms" >> "$ping_log"
        
        # Alert on high latency with proper comparison
        if [ -n "$ping_time" ] && (echo "$ping_time > $ALERT_THRESHOLD_LATENCY_MS" | bc -l | grep -q 1); then
          echo "[$timestamp] ALERT: High latency (${ping_time}ms) to $target_node" | tee -a "$ping_log" "$OUTPUT_FILE"
        fi
      fi
    done
    
    sleep $PING_INTERVAL
  done
}

# Generate a summary report
generate_summary() {
  echo "Generating summary report..." | tee -a "$OUTPUT_FILE"
  
  local summary_file="$LOG_DIR/network_test_summary_$(date +%Y%m%d_%H%M%S).txt"
  
  {
    echo "===== Network Connectivity Test Summary ====="
    echo "Test period: $(date -d @$start_time) to $(date)"
    echo "Total test duration: $TEST_DURATION seconds"
    echo "Tested nodes: ${NODES[*]}"
    echo "Tested ports: ${PORTS[*]}"
    echo ""
    echo "--- ALERTS ---"
    grep "ALERT:" "$OUTPUT_FILE" | sort | uniq -c
    echo ""
    echo "--- CONNECTIVITY STATISTICS ---"
    echo "Ping failures: $(grep -c "Cannot ping" "$OUTPUT_FILE")"
    echo "Port connectivity failures: $(grep -c "Cannot connect to" "$OUTPUT_FILE")"
    echo "Throughput tests run: $(grep -c "Testing network throughput" "$OUTPUT_FILE")"
    echo "Throughput tests failed: $(grep -c "Throughput test failed" "$OUTPUT_FILE")"
    echo ""
    echo "--- AVERAGE METRICS ---"
    echo "Average latency (msec): $(grep -oP 'Ping to [^:]+: \K[0-9.]+' "$LOG_DIR"/ping_monitoring_*.log 2>/dev/null | awk '{ sum += $1; n++ } END { if (n > 0) print sum / n; else print "N/A" }')"
    echo ""
    echo "For detailed results, please check $OUTPUT_FILE"
  } > "$summary_file"
  
  echo "Summary report generated at $summary_file" | tee -a "$OUTPUT_FILE"
  cat "$summary_file" | tee -a "$OUTPUT_FILE"
}

# Main function
main() {
  # Parse command line arguments
  parse_arguments "$@"
  
  check_requirements
  setup
  
  # Record start time
  start_time=$(date +%s)
  
  # Start continuous ping in the background
  run_continuous_ping &
  continuous_ping_pid=$!
  
  # Run comprehensive tests at regular intervals
  local end_time=$((start_time + TEST_DURATION))
  
  while [ $(date +%s) -lt $end_time ]; do
    # Run one cycle of comprehensive tests
    run_comprehensive_tests
    
    # Sleep until next test cycle
    sleep $INTERVAL
  done
  
  # Stop background processes
  kill $continuous_ping_pid 2>/dev/null
  
  # Generate summary report
  generate_summary
  
  echo "Network connectivity testing completed at $(date)" | tee -a "$OUTPUT_FILE"
}

# Run the script
main "$@"