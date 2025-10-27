#!/usr/bin/env python3

# Neural Splines, LLC 2025 Patent Pending by Robert Sitton (SN)

"""
═══════════════════════════════════════════════════════════════════════════
◈ gen_test_data.py — Synthetic MNIST-Like Test Data Generator
═══════════════════════════════════════════════════════════════════════════

Generates simple synthetic digit images for testing when real MNIST is not
available. Creates simple geometric patterns that vaguely resemble digits.

Output: TEST.IDX (MNIST-compatible format)
"""

import struct
import sys
import random


def create_digit_0():
    """Create a synthetic '0' (circle/oval)"""
    img = [[0] * 28 for _ in range(28)]
    
    # Draw oval
    for row in range(6, 22):
        for col in range(8, 20):
            dist_from_center = ((row - 14) / 6) ** 2 + ((col - 14) / 4) ** 2
            if 0.7 < dist_from_center < 1.2:
                img[row][col] = 255
    
    return img


def create_digit_1():
    """Create a synthetic '1' (vertical line)"""
    img = [[0] * 28 for _ in range(28)]
    
    # Draw vertical line
    for row in range(4, 24):
        img[row][13] = 255
        img[row][14] = 255
    
    # Small top serif
    for col in range(11, 13):
        img[5][col] = 255
        img[6][col] = 255
    
    return img


def create_digit_7():
    """Create a synthetic '7' (horizontal + diagonal)"""
    img = [[0] * 28 for _ in range(28)]
    
    # Horizontal line at top
    for col in range(6, 22):
        img[4][col] = 255
        img[5][col] = 255
        img[6][col] = 255
    
    # Diagonal line going down-left
    for i in range(18):
        row = 7 + i
        col = 20 - i
        if 0 <= row < 28 and 0 <= col < 28:
            img[row][col] = 255
            if col + 1 < 28:
                img[row][col + 1] = 255
    
    return img


def create_digit_2():
    """Create a synthetic '2' (curves + horizontal)"""
    img = [[0] * 28 for _ in range(28)]
    
    # Top curve
    for col in range(8, 20):
        row = 6 + int(((col - 14) ** 2) / 10)
        if 0 <= row < 28:
            img[row][col] = 255
    
    # Diagonal
    for i in range(10):
        row = 12 + i
        col = 18 - i
        if 0 <= row < 28 and 0 <= col < 28:
            img[row][col] = 255
    
    # Bottom horizontal
    for col in range(8, 20):
        img[22][col] = 255
        img[23][col] = 255
    
    return img


def create_digit_3():
    """Create a synthetic '3' (two bumps on right)"""
    img = [[0] * 28 for _ in range(28)]
    
    # Top horizontal
    for col in range(8, 18):
        img[5][col] = 255
        img[6][col] = 255
    
    # Middle horizontal
    for col in range(10, 18):
        img[13][col] = 255
        img[14][col] = 255
    
    # Bottom horizontal
    for col in range(8, 18):
        img[21][col] = 255
        img[22][col] = 255
    
    # Right vertical sections
    for row in range(7, 13):
        img[row][17] = 255
    for row in range(15, 21):
        img[row][17] = 255
    
    return img


def create_digit_4():
    """Create a synthetic '4' (vertical + horizontal + diagonal)"""
    img = [[0] * 28 for _ in range(28)]
    
    # Left diagonal
    for i in range(12):
        row = 6 + i
        col = 6 + i // 2
        if 0 <= row < 28 and 0 <= col < 28:
            img[row][col] = 255
    
    # Horizontal bar
    for col in range(6, 20):
        img[16][col] = 255
        img[17][col] = 255
    
    # Right vertical
    for row in range(4, 24):
        img[row][16] = 255
        img[row][17] = 255
    
    return img


def create_digit_5():
    """Create a synthetic '5'"""
    img = [[0] * 28 for _ in range(28)]
    
    # Top horizontal
    for col in range(8, 20):
        img[5][col] = 255
        img[6][col] = 255
    
    # Left vertical (top half)
    for row in range(7, 14):
        img[row][8] = 255
        img[row][9] = 255
    
    # Middle horizontal
    for col in range(8, 18):
        img[13][col] = 255
        img[14][col] = 255
    
    # Right curve (bottom)
    for row in range(15, 22):
        img[row][17] = 255
    
    # Bottom horizontal
    for col in range(9, 17):
        img[22][col] = 255
        img[23][col] = 255
    
    return img


def create_digit_6():
    """Create a synthetic '6' (loop at bottom)"""
    img = [[0] * 28 for _ in range(28)]
    
    # Left vertical
    for row in range(6, 23):
        img[row][8] = 255
        img[row][9] = 255
    
    # Top curve
    for col in range(10, 16):
        img[6][col] = 255
        img[7][col] = 255
    
    # Bottom loop
    for col in range(10, 18):
        img[21][col] = 255
        img[22][col] = 255
    for row in range(15, 22):
        img[row][17] = 255
    for col in range(10, 18):
        img[15][col] = 255
    
    return img


def create_digit_8():
    """Create a synthetic '8' (two loops)"""
    img = [[0] * 28 for _ in range(28)]
    
    # Top loop
    for col in range(10, 18):
        img[6][col] = 255
        img[13][col] = 255
    for row in range(7, 13):
        img[row][10] = 255
        img[row][17] = 255
    
    # Bottom loop
    for col in range(10, 18):
        img[22][col] = 255
    for row in range(14, 22):
        img[row][10] = 255
        img[row][17] = 255
    
    return img


def create_digit_9():
    """Create a synthetic '9' (loop at top + tail)"""
    img = [[0] * 28 for _ in range(28)]
    
    # Top loop
    for col in range(10, 18):
        img[6][col] = 255
        img[13][col] = 255
    for row in range(7, 13):
        img[row][10] = 255
        img[row][17] = 255
    
    # Right vertical (tail)
    for row in range(14, 23):
        img[row][17] = 255
        img[row][18] = 255
    
    return img


def flatten_image(img):
    """Flatten 2D image to 1D array"""
    return [pixel for row in img for pixel in row]


def write_idx_file(images, labels, image_file, label_file):
    """Write images and labels in MNIST IDX format"""
    num_images = len(images)
    
    # Write image file
    with open(image_file, 'wb') as f:
        # Magic number for images: 2051
        f.write(struct.pack('>I', 2051))
        # Number of images
        f.write(struct.pack('>I', num_images))
        # Rows
        f.write(struct.pack('>I', 28))
        # Columns
        f.write(struct.pack('>I', 28))
        
        # Write pixel data
        for img in images:
            flat = flatten_image(img)
            f.write(bytes(flat))
    
    # Write label file
    with open(label_file, 'wb') as f:
        # Magic number for labels: 2049
        f.write(struct.pack('>I', 2049))
        # Number of labels
        f.write(struct.pack('>I', num_images))
        
        # Write labels
        f.write(bytes(labels))


def main():
    print("═" * 70)
    print("◈ Synthetic MNIST-Like Test Data Generator")
    print("═" * 70)
    print()
    
    # Digit generators
    generators = [
        create_digit_0,
        create_digit_1,
        create_digit_2,
        create_digit_3,
        create_digit_4,
        create_digit_5,
        create_digit_6,
        create_digit_7,
        create_digit_8,
        create_digit_9
    ]
    
    # Generate multiple examples of each digit
    num_per_digit = 10
    images = []
    labels = []
    
    print(f"Generating {num_per_digit} examples of each digit...")
    
    for digit in range(10):
        print(f"  Creating digit {digit}...")
        for _ in range(num_per_digit):
            img = generators[digit]()
            
            # Add random noise (slight variations)
            for row in range(28):
                for col in range(28):
                    if random.random() < 0.02:  # 2% noise
                        img[row][col] = random.randint(0, 100)
            
            images.append(img)
            labels.append(digit)
    
    # Shuffle
    combined = list(zip(images, labels))
    random.shuffle(combined)
    images, labels = zip(*combined)
    
    # Write files
    print("\nWriting TEST.IDX...")
    write_idx_file(images, labels, "TEST.IDX", "TESTL.IDX")
    
    print(f"✓ Generated {len(images)} test images")
    print()
    print("Output files:")
    print("  TEST.IDX  — Image data (MNIST format)")
    print("  TESTL.IDX — Label data (MNIST format)")
    print()
    print("═" * 70)
    print("✓ Test data generation complete!")
    print("═" * 70)
    print()
    print("🍪 Cookie Monster say: Synthetic cookies still delicious!")


if __name__ == "__main__":
    main()
