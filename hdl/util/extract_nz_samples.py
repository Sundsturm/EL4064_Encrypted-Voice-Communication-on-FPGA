"""
extract_nz_samples.py

Extracts a window of non-zero samples from audio_test.txt starting at the
first non-zero line, then writes NUM_SAMPLES lines to audio_test_nz.txt.

Usage:
    python extract_nz_samples.py [--input PATH] [--output PATH] [--count N] [--even]

Options:
    --input   Path to source hex file  (default: ../audio_test.txt)
    --output  Path to output hex file  (default: ../audio_test_nz.txt)
    --count   Number of samples to extract (default: 400)
    --even    Force count to be even (required for interleaved L/R pairs)
"""

import argparse
import pathlib

def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    base = pathlib.Path(__file__).parent.parent
    parser.add_argument("--input",  default=str(base / "audio_test.txt"))
    parser.add_argument("--output", default=str(base / "audio_test_nz.txt"))
    parser.add_argument("--count",  type=int, default=400)
    parser.add_argument("--even",   action="store_true", default=True)
    args = parser.parse_args()

    count = args.count
    if args.even and count % 2 != 0:
        count += 1
        print(f"[info] count rounded up to {count} to keep L/R pairs aligned.")

    samples = []
    found_nz = False
    skipped  = 0

    with open(args.input, "r") as f:
        for lineno, line in enumerate(f, start=1):
            line = line.strip()
            if not line or line.startswith("//"):
                continue
            value = int(line, 16)
            if not found_nz:
                if value != 0:
                    found_nz = True
                    # Step back to an even boundary so L[0] is a Left sample.
                    # If we are in the middle of a pair (odd index), go back one.
                    # We track raw (non-comment) line index for parity.
                    skipped = lineno - 1
                    if skipped % 2 != 0:
                        # Back up one sample so we start on a Left channel boundary
                        samples = [0x0000]  # prepend one padding zero
                    samples.append(value)
                    print(f"[info] First non-zero value at line {lineno}: 0x{value:04X}")
            else:
                samples.append(value)

            if len(samples) >= count:
                break

    if not found_nz:
        print("[warn] No non-zero values found in the input file. Output will be all zeros.")

    # Pad with zeros if file ended before count was reached
    while len(samples) < count:
        samples.append(0x0000)

    samples = samples[:count]

    with open(args.output, "w") as f:
        for s in samples:
            f.write(f"{s:04X}\n")

    print(f"[info] Wrote {len(samples)} samples to {args.output}")
    print(f"[info] Update MEM_DEPTH in tb_audio_bypass.v to {len(samples)} and")
    print(f'[info] change $readmemh("audio_test.txt", ...) to $readmemh("audio_test_nz.txt", ...)')

if __name__ == "__main__":
    main()
