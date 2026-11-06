"""Reject simulator, non-arm64, non-dylib and non-system dependencies."""
import json
import pathlib
import struct
import sys

p = pathlib.Path(sys.argv[1])
data = p.read_bytes()
magic, cpu, subtype, kind, ncmd, size, flags, reserved = struct.unpack_from('<8I', data)
assert magic == 0xFEEDFACF, 'Expected thin Mach-O 64-bit'
assert cpu == 0x0100000C and subtype & 0xFFFFFF == 0, 'Expected arm64, not arm64e'
assert kind == 6, 'Expected MH_DYLIB'
position = 32
platform = None
signature = False
deps = []
install_id = None
for _ in range(ncmd):
    command, length = struct.unpack_from('<II', data, position)
    assert length >= 8 and position + length <= 32 + size
    if command == 0x32:
        platform = struct.unpack_from('<I', data, position + 8)[0]
    if command == 0x1D:
        offset, count = struct.unpack_from('<II', data, position + 8)
        signature = count > 0 and offset + count <= len(data)
    if command in (0xC, 0xD, 0x80000018, 0x8000001F, 0x80000023):
        offset = struct.unpack_from('<I', data, position + 8)[0]
        name = data[position + offset:position + length].split(b'\0')[0].decode()
        if command == 0xD:
            install_id = name
        else:
            deps.append(name)
    position += length
assert platform == 2, f'Expected iOS device platform 2, got {platform}'
assert signature, 'Embedded signature missing'
assert install_id == f'@rpath/{p.stem}.dylib', install_id
assert deps and all(d.startswith(('/usr/lib/', '/System/Library/Frameworks/')) for d in deps), deps
assert all('LCFloatingMenu' not in d and 'CydiaSubstrate' not in d for d in deps)
print(json.dumps({'status': 'PASS', 'architecture': 'arm64', 'platform': 'iOS device',
                  'type': 'MH_DYLIB', 'install_name': install_id, 'dependencies': deps}, indent=2))
