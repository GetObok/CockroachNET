# CockroachNET

## CockroachDB Network Connectivity Testing Framework

CockroachNET is a comprehensive network diagnostics tool designed to monitor, test, and troubleshoot connectivity issues in clusters running on Linux based systems, specifically designed to test highly distributed systems.

## Overview

CockroachNET provides continuous monitoring and testing of network connectivity between nodes, helping identify intermittent issues that can affect cluster stability and performance. The tool measures key metrics including latency, packet loss, throughput, and TCP connection quality.

## Features

- **Basic connectivity testing** with ping, port checks, and traceroute
- **Throughput measurement** between nodes using iperf3
- **Continuous monitoring** to catch intermittent issues
- **Packet capture** for detailed analysis of CockroachDB traffic
- **Socket statistics** collection
- **TCP metrics** including retransmission monitoring
- **CockroachDB log monitoring** for network-related errors
- **Detailed reporting** with alerts and summary statistics

## Installation

1. Clone this repository or download the script:
   ```
   git clone https://github.com/GetObok/cockroachnet.git
   ```

2. Make the script executable:
   ```
   chmod +x cockroachnet.sh
   ```

3. Install dependencies (must have root privileges):
   ```
   dnf install -y ping nc iperf3 tcpdump ss traceroute nmap
   ```

## Configuration

Edit the configuration section at the top of the script to:
- Specify your CockroachDB node IP addresses
- Set test duration and intervals
- Configure alert thresholds for latency and packet loss
- Set log directory and other parameters

## Usage

Run the script on each node in your CockroachDB cluster:

```
./cockroachnet.sh
```

For long-term monitoring, set up a scheduled job using cron:

```
# Run network testing daily at 2 AM
0 2 * * * /path/to/cockroachnet.sh
```

## Output

The script generates detailed logs in `/var/log/cockroach-network-tests/` including:
- Full test results and metrics
- Alerts for connectivity issues
- Summarized reports
- Packet captures (PCAP files)

## License

MIT License

## Contributing

Contributions welcome! Please feel free to submit a Pull Request.