# COCKROACHNET

## Distributed System Network Testing Framework

COCKROACHNET is a comprehensive network diagnostics tool designed to monitor, test, and troubleshoot connectivity issues in distributed systems running on Linux-based environments.

## Overview

NetProbe provides continuous monitoring and testing of network connectivity between nodes in any distributed system, helping identify intermittent issues that can affect system stability and performance. The tool measures key metrics including latency, packet loss, throughput, and TCP connection quality over extended periods.

## Features

- **Basic connectivity testing** with ping, port checks, and traceroute
- **Throughput measurement** between nodes using iperf3
- **Continuous monitoring** to catch intermittent issues
- **Packet capture** for detailed traffic analysis
- **Socket statistics** collection
- **TCP metrics** including retransmission monitoring
- **Detailed reporting** with alerts and summary statistics

## Installation

1. Clone this repository or download the script:
   ```
   git clone https://github.com/GetObok/netprobe.git
   ```

2. Make the script executable:
   ```
   chmod +x cockroachnet.sh
   ```

3. Install dependencies (must have root privileges):
   ```
   # On Fedora/Red Hat-based systems
   dnf install -y ping nc iperf3 tcpdump ss traceroute nmap bc
   
   # On CentOS 7/RHEL 7
   yum install -y iputils nc iperf3 tcpdump iproute nmap-ncat traceroute nmap bc
   
   # On Debian/Ubuntu-based systems
   apt install -y iputils-ping netcat iperf3 tcpdump iproute2 traceroute nmap bc
   ```

## Usage

NetProbe accepts command-line arguments to customize its behavior:

```
./cockroachnet.sh [options]

Options:
  -n, --nodes IP1,IP2,...    Comma-separated list of node IPs to test
  -p, --ports PORT1,PORT2... Comma-separated list of ports to test
  -d, --duration SECONDS     Test duration in seconds (default: 3600)
  -l, --log-dir DIRECTORY    Directory to store logs (default: /var/log/netprobe-tests)
  -i, --interval SECONDS     Interval between test runs (default: 60)
  --ping-interval SECONDS    Interval between ping tests (default: 5)
  --latency-threshold MS     Alert threshold for latency in ms (default: 100)
  --loss-threshold PERCENT   Alert threshold for packet loss in % (default: 1)
  -h, --help                 Display this help message
```

### Examples

Test connectivity to multiple nodes with specific ports:
```
./cockroachnet.sh --nodes 10.0.0.1,10.0.0.2,10.0.0.3 --ports 8080,9090,26257
```

Run an extended test with custom thresholds:
```
./cockroachnet.sh --nodes 192.168.1.100 --ports 27017,27018 --duration 86400 --latency-threshold 50 --loss-threshold 0.5
```

Quick test for 1 minute:
```
./cockroachnet.sh --nodes 192.168.0.84 --ports 2342 --duration 60
```

For long-term monitoring, set up a scheduled job using cron:
```
# Run network testing daily at 2 AM
0 2 * * * /path/to/cockroachnet.sh --nodes 10.0.0.1,10.0.0.2 --ports 8080,9090
```

## Output

The script generates detailed logs including:
- Full test results and metrics
- Alerts for connectivity issues
- Summarized reports
- Packet captures (PCAP files)

All results are stored in `/var/log/netprobe-tests/` by default.

## Troubleshooting

If you encounter high TCP retransmission counts:

1. Check if it's a historical counter by running:
   ```
   netstat -s | grep -i retrans
   ```
   
2. Look for specific issues using:
   - MTU mismatches: `ip link show | grep mtu`
   - TCP offloading: `ethtool -k <interface>`
   - Duplex/speed mismatches: `ethtool <interface>`

3. For cross-platform issues between Windows and Linux:
   - Consider disabling TCP offloading features
   - Test with different MTU settings
   - Check cable quality and switch port errors

## License

MIT License

## Contributing

Contributions welcome! Please feel free to submit a Pull Request.