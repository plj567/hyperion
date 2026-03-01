#!/bin/bash
#
# Build Hercules SDL Hyperion on macOS (Apple Silicon / aarch64)
# 
# This script downloads and installs all required dependencies, then builds
# Hercules from source with native aarch64 support.
#
# Prerequisites: macOS with Xcode command line tools installed
# Usage: ./build-hercules-macos-aarch64.sh
#

set -e

#==============================================================================
# Configuration - Edit these if needed
#==============================================================================
HYPERION_DIR="${HOME}/hercules"          # Where to clone/store Hercules
EXTPKGS_DIR="${HYPERION_DIR}/extpkgs-aarch64"
LIBTOOL_INSTALL="/tmp/libtool-install"
CMAKE_VERSION="3.28.3"
LIBTOOL_VERSION="2.4.7"

#==============================================================================
# Prerequisites Check
#==============================================================================
echo "=============================================="
echo "Hercules SDL Build Script for macOS aarch64"
echo "=============================================="
echo ""

# Check for Xcode command line tools
if ! xcode-select -p > /dev/null 2>&1; then
    echo "ERROR: Xcode command line tools not found."
    echo "Please install them with: xcode-select --install"
    exit 1
fi

echo "Prerequisites check passed."

#==============================================================================
# Step 1: Download and Install CMake
#==============================================================================
echo ""
echo "=============================================="
echo "Step 1: Downloading CMake ${CMAKE_VERSION}"
echo "=============================================="

cd /tmp

# Download CMake if not already present
if [ ! -f "cmake-${CMAKE_VERSION}-macos-universal.tar.gz" ]; then
    echo "Downloading CMake..."
    curl -L -o "cmake-${CMAKE_VERSION}-macos-universal.tar.gz" \
        "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-macos-universal.tar.gz"
fi

# Extract CMake
if [ ! -d "cmake-${CMAKE_VERSION}-macos-universal" ]; then
    echo "Extracting CMake..."
    tar -xzf "cmake-${CMAKE_VERSION}-macos-universal.tar.gz"
fi

# Add CMake to PATH
export PATH="/tmp/cmake-${CMAKE_VERSION}-macos-universal/CMake.app/Contents/bin:$PATH"
echo "CMake version: $(cmake --version)"

#==============================================================================
# Step 2: Clone External Packages
#==============================================================================
echo ""
echo "=============================================="
echo "Step 2: Cloning External Packages"
echo "=============================================="

# Create hyperion directory if it doesn't exist
mkdir -p "${HYPERION_DIR}"
cd "${HYPERION_DIR}"

# Clone Hercules main repository
if [ ! -d "hercules" ]; then
    echo "Cloning Hercules SDL Hyperion..."
    git clone https://github.com/SDL-Hercules-390/hyperion.git hercules
fi

cd hercules

# Create extpkgs directory
mkdir -p extpkgs
cd extpkgs

# Clone all four required external packages
echo "Cloning crypto..."
if [ ! -d "crypto" ]; then
    git clone https://github.com/sdl-hercules-390/crypto.git
fi

echo "Cloning decNumber..."
if [ ! -d "decNumber" ]; then
    git clone https://github.com/sdl-hercules-390/decNumber.git
fi

echo "Cloning SoftFloat..."
if [ ! -d "SoftFloat" ]; then
    git clone https://github.com/sdl-hercules-390/SoftFloat.git
fi

echo "Cloning telnet..."
if [ ! -d "telnet" ]; then
    git clone https://github.com/sdl-hercules-390/telnet.git
fi

#==============================================================================
# Step 3: Build External Packages for aarch64
#==============================================================================
echo ""
echo "=============================================="
echo "Step 3: Building External Packages for aarch64"
echo "=============================================="

cd "${HYPERION_DIR}/hercules/extpkgs"

# Create central install directory
mkdir -p "${EXTPKGS_DIR}/lib"
mkdir -p "${EXTPKGS_DIR}/include"

# Function to build a package
build_package() {
    local pkg="$1"
    echo "  Building ${pkg}..."
    
    # Create install directory for this package
    local pkg_install="./${pkg}.install"
    mkdir -p "${pkg_install}"
    
    # Run the package's build script
    case "$pkg" in
        crypto)
            /Users/peterljungberg/hyperion/hercules/extpkgs/crypto/build \
                -n crypto -m aarch64 -a 64 -c Release -i "${pkg_install}"
            ;;
        decNumber)
            /Users/peterljungberg/hercules/extpkgs/decNumber/build \
                -n decNumber -m aarch64 -a 64 -c Release -i "${pkg_install}"
            ;;
        SoftFloat)
            /Users/peterljungberg/hercules/extpkgs/SoftFloat/build \
                -n SoftFloat -m aarch64 -a 64 -c Release -i "${pkg_install}"
            ;;
        telnet)
            /Users/peterljungberg/hercules/extpkgs/telnet/build \
                -n telnet -m aarch64 -a 64 -c Release -i "${pkg_install}"
            ;;
    esac
    
    # Copy libraries to central location (in lib/aarch64 subdirectory)
    local bld_dir="${pkg}64.Release"
    if [ -d "${bld_dir}/install/lib/aarch64" ]; then
        cp "${bld_dir}/install/lib/aarch64/"*.a "${EXTPKGS_DIR}/lib/"
    fi
    
    # Copy headers
    if [ -d "${bld_dir}/install/include" ]; then
        cp "${bld_dir}/install/include/"*.h "${EXTPKGS_DIR}/include/"
    fi
}

# Build each package
for pkg in crypto decNumber SoftFloat telnet; do
    build_package "${pkg}"
done

# Create lib/aarch64 subdirectory structure expected by Hercules
mkdir -p "${EXTPKGS_DIR}/lib/aarch64"
if [ -d "${EXTPKGS_DIR}/lib" ]; then
    mv "${EXTPKGS_DIR}/lib"/*.a "${EXTPKGS_DIR}/lib/aarch64/" 2>/dev/null || true
fi

echo "  External packages built successfully!"

#==============================================================================
# Step 4: Download and Build GNU libtool (with libltdl)
#==============================================================================
echo ""
echo "=============================================="
echo "Step 4: Downloading GNU libtool ${LIBTOOL_VERSION}"
echo "=============================================="

cd /tmp

# Download libtool if not already present
if [ ! -f "libtool-${LIBTOOL_VERSION}.tar.gz" ]; then
    echo "Downloading GNU libtool..."
    curl -L -o "libtool-${LIBTOOL_VERSION}.tar.gz" \
        "https://ftp.gnu.org/gnu/libtool/libtool-${LIBTOOL_VERSION}.tar.gz"
fi

# Extract libtool
if [ ! -d "libtool-${LIBTOOL_VERSION}" ]; then
    echo "Extracting libtool..."
    tar -xzf "libtool-${LIBTOOL_VERSION}.tar.gz"
fi

# Build libtool
cd "libtool-${LIBTOOL_VERSION}"
if [ ! -d "build" ]; then
    mkdir build
fi
cd build

echo "Configuring libtool..."
../configure --prefix="${LIBTOOL_INSTALL}" --enable-ltdl-install

echo "Building libtool..."
make -j$(sysctl -n hw.ncpu)

echo "Installing libtool..."
make install

echo "  GNU libtool installed successfully!"

#==============================================================================
# Step 5: Configure Hercules
#==============================================================================
echo ""
echo "=============================================="
echo "Step 5: Configuring Hercules"
echo "=============================================="

cd "${HYPERION_DIR}/hercules"

# Clean previous builds (if any)
rm -rf autom4te.cache Makefile config.status config.log

# Set environment variables
export LIBRARY_PATH="${EXTPKGS_DIR}/lib/aarch64:${LIBTOOL_INSTALL}/lib:$LIBRARY_PATH"
export CPATH="${EXTPKGS_DIR}/include:${LIBTOOL_INSTALL}/include:$CPATH"

# Configure Hercules with external packages
echo "Running configure..."
./configure \
    --enable-extpkgs="${EXTPKGS_DIR}" \
    --with-ltdl-include="${LIBTOOL_INSTALL}/include" \
    --with-ltdl-lib="${LIBTOOL_INSTALL}/lib"

#==============================================================================
# Step 6: Build Hercules
#==============================================================================
echo ""
echo "=============================================="
echo "Step 6: Building Hercules"
echo "=============================================="

cd "${HYPERION_DIR}/hercules"
make -j$(sysctl -n hw.ncpu)

#==============================================================================
# Step 7: Verify the Build
#==============================================================================
echo ""
echo "=============================================="
echo "Step 7: Verifying Build"
echo "=============================================="

cd "${HYPERION_DIR}/hercules"
./hercules --version

#==============================================================================
# Summary
#==============================================================================
echo ""
echo "=============================================="
echo "✅ BUILD COMPLETED SUCCESSFULLY!"
echo "=============================================="
echo ""
echo "Executable location: ${HYPERION_DIR}/hercules"
echo "Actual binary: ${HYPERION_DIR}/hercules/.libs/hercules"
echo ""
echo "Architecture: $(file .libs/hercules | cut -d: -f2)"
echo ""
echo "To run Hercules:"
echo "  cd ${HYPERION_DIR}/hercules"
echo "  ./hercules"
echo ""
