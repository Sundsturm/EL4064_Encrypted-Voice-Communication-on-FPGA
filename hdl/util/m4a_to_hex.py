import struct
import subprocess

# Decode M4A to raw signed 16-bit little-endian PCM using ffmpeg.
ffmpeg_cmd = [
    "ffmpeg",
    "-v",
    "error",
    "-i",
    "input.m4a",
    "-f",
    "s16le",
    "-acodec",
    "pcm_s16le",
    "-ac",
    "1",
    "-ar",
    "48000",
    "-",
]

pcm = subprocess.run(ffmpeg_cmd, check=True, stdout=subprocess.PIPE).stdout
samples = struct.unpack("<{}h".format(len(pcm) // 2), pcm)

with open("output.txt", "w") as f:
    for s in samples:
        f.write(f"{s & 0xFFFF:04X}\n")
