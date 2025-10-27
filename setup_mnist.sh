#!/usr/bin/env bash
# Download and prepare MNIST dataset for Neural8086
# "Teaching ancient machines to recognize human handwriting (Yawn)"

# Neural Splines, LLC 2025 Patent Pending by Robert Sitton (SN)

set -euo pipefail

echo "╔═══════════════════════════════════════════════════════╗"
echo "║  MNIST Dataset Downloader for Neural8086              ║"
echo "║  'Come with me if you want your data'    T8086        ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo

# Mirror URLs for MNIST (multiple sources for redundancy)
MIRRORS=(
    "https://ossci-datasets.s3.amazonaws.com/mnist"
    "http://yann.lecun.com/exdb/mnist"
    "https://raw.githubusercontent.com/fgnt/mnist/master"
)

FILES=(
    "train-images-idx3-ubyte.gz:TRAIN.IDX"
    "train-labels-idx1-ubyte.gz:TRAINL.IDX"
    "t10k-images-idx3-ubyte.gz:TEST.IDX"
    "t10k-labels-idx1-ubyte.gz:TESTL.IDX"
)

# Function to download with fallback mirrors
download_file() {
    local filename="$1"
    local output="$2"
    
    for mirror in "${MIRRORS[@]}"; do
        echo "  Trying: $mirror/$filename"
        if curl -fsSL "$mirror/$filename" -o "$filename.tmp" 2>/dev/null || \
           wget -q "$mirror/$filename" -O "$filename.tmp" 2>/dev/null; then
            
            # Check if file is gzipped
            if file "$filename.tmp" | grep -q gzip; then
                echo "    Decompressing..."
                gunzip -c "$filename.tmp" > "$output"
                rm "$filename.tmp"
            else
                # Some mirrors serve uncompressed
                mv "$filename.tmp" "$output"
            fi
            
            echo "  ✓ Downloaded $output ($(wc -c < "$output") bytes)"
            return 0
        fi
    done
    
    echo "  ✗ Failed to download $filename"
    return 1
}

# Main download loop
echo "Downloading MNIST dataset..."
echo

success=true
for pair in "${FILES[@]}"; do
    IFS=':' read -r source target <<< "$pair"
    
    if [[ -f "$target" ]]; then
        echo "✓ $target already exists ($(wc -c < "$target") bytes)"
    else
        echo "Fetching $target..."
        if ! download_file "$source" "$target"; then
            success=false
        fi
    fi
done

echo

if [ "$success" = true ]; then
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║  ✓ MNIST dataset ready!                               ║"
    echo "║  60,000 training samples + 10,000 test samples        ║"
    echo "║  'The machines are ready to learn'                    ║"
    echo "╚═══════════════════════════════════════════════════════╝"
else
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║  ✗ Some files failed to download                      ║"
    echo "║  Check your internet connection and try again         ║"
    echo "║  'No fate but what we make'                           ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    exit 1
fi
