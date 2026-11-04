#!/usr/bin/env python3
"""Membuat konstanta teredam (XOR + base64) untuk lib/main.dart.

Pemakaian:
    python3 tool/generate_secret.py https://contoh.my.id/cbtadmin contoh.my.id

Salin keluaran _k, _eUrl, dan _eHost ke lib/main.dart.
"""
import base64
import secrets
import sys

if len(sys.argv) != 3:
    sys.exit("Pemakaian: generate_secret.py <url-lengkap> <host>")

url, host = sys.argv[1].encode(), sys.argv[2].encode()
key = secrets.token_bytes(24)


def enc(b: bytes) -> str:
    return base64.b64encode(bytes(c ^ key[i % len(key)] for i, c in enumerate(b))).decode()


print("const List<int> _k = [")
print("  " + ", ".join(str(x) for x in key) + ",")
print("];")
print(f"const String _eUrl = '{enc(url)}';")
print(f"const String _eHost = '{enc(host)}';")
