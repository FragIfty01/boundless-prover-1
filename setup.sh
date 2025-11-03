#!/bin/bash

SILENT_MODE=false
SKIP_CLI_TOOLS=false
while getopts "sc" opt; do
    case $opt in
        s)
            SILENT_MODE=true
            echo "Running in silent mode with default values..."
            ;;
        c)
            SKIP_CLI_TOOLS=true
            echo "Skipping CLI tools installation..."
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            echo "Usage: $0 [-s] [-c]"
            echo "  -s: Silent mode (use default values without prompts)"
            echo "  -c: Skip CLI tools installation"
            exit 1
            ;;
    esac
done

apt update
apt install -y curl nvtop git supervisor build-essential pkg-config libssl-dev python3-dev
echo

echo "-----Installing rust-----"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env
echo

echo "-----Installing rzup and RISC Zero toolchain-----"
curl -L https://risczero.com/install | bash
source $HOME/.bashrc
/root/.risc0/bin/rzup install
/root/.risc0/bin/rzup install risc0-groth16
echo

echo "-----Installing bento components-----"
apt install -y redis postgresql-16 adduser libfontconfig1 musl

wget https://dl.min.io/server/minio/release/linux-amd64/archive/minio_20250613113347.0.0_amd64.deb -O minio.deb
dpkg -i minio.deb

curl -L "https://cancanneed.de/boundless/grafana-enterprise_11.0.0_amd64.deb" -o grafana-enterprise_11.0.0_amd64.deb
dpkg -i grafana-enterprise_11.0.0_amd64.deb
echo

echo "-----Downloading prover binaries-----"
mkdir /app

curl -L "https://cancanneed.de/boundless/v1.0.0/broker" -o /app/broker
curl -L "https://cancanneed.de/boundless/v1.0.0/broker-stress" -o /app/broker-stress
curl -L "https://cancanneed.de/boundless/v1.0.0/bento-agent-v1_0_1-cuda12_8" -o /app/agent
curl -L "https://cancanneed.de/boundless/v1.0.0/bento-rest-api" -o /app/rest_api
curl -L "https://cancanneed.de/boundless/v1.0.0/bento-cli" -o /root/.cargo/bin/bento_cli

chmod +x /app/agent
chmod +x /app/broker
chmod +x /app/broker-stress
chmod +x /app/rest_api
chmod +x /root/.cargo/bin/bento_cli

echo "-----Verifying /app files sha256sum-----"
declare -A FILES_SHA256
FILES_SHA256["/app/broker"]="216a792c4bb1444a0ce7a447ea2cad0b24e660601baa49057f77b37ac9f4ad74"
FILES_SHA256["/app/broker-stress"]="024d916463d8f24fb9d12857b6f1dbdc016f972e8d8b82434804e077e0fe6231"
FILES_SHA256["/app/agent"]="3be0a008af2ae2a9d5cfacbfbb3f75d4a4fd70b82152ae3e832b500ad468f5a0"
FILES_SHA256["/app/rest_api"]="02a0c87b3bfc1fd738d6714ee24fb32fbcb7887bfe46321c3eed2061c581a87a"
FILES_SHA256["/root/.cargo/bin/bento_cli"]="7af2fe49f75acf95e06476e55e6a91343c238b0cf5696d1cae80be54fcc17b45"

INTEGRITY_PASS=true

for file in "${!FILES_SHA256[@]}"; do
    if [ ! -f "$file" ]; then
        echo "File missing: $file"
        INTEGRITY_PASS=false
        continue
    fi
    actual_sum=$(sha256sum "$file" | awk '{print $1}')
    expected_sum="${FILES_SHA256[$file]}"
    if [ "$actual_sum" != "$expected_sum" ]; then
        echo "File integrity check failed: $file"
        echo "  Expected: $expected_sum"
        echo "  Actual:   $actual_sum"
        INTEGRITY_PASS=false
    else
        echo "File integrity check passed: $file"
    fi
done

if [ "$INTEGRITY_PASS" = false ]; then
    echo "Some files failed the sha256sum check. Please verify file integrity and try again."
    exit 1
else
    echo "All files passed sha256sum integrity check."
fi
echo

echo "-----Copying config files-----"
git clone https://github.com/boundless-xyz/boundless.git
cd boundless
git checkout v1.0.0
if [ "$SKIP_CLI_TOOLS" = false ]; then
    git submodule update --init --recursive
    cargo install --path crates/boundless-cli --locked boundless-cli
fi
cp -rf dockerfiles/grafana/* /etc/grafana/provisioning/
echo

# (rest of the script remains unchanged)
