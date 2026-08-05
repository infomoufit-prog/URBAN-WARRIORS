#!/usr/bin/env python3
"""Generate the installation QR used by the public download screen."""
from pathlib import Path
import argparse
import qrcode

parser = argparse.ArgumentParser()
parser.add_argument('url', nargs='?', default='https://example.com/urban-warriors/#/download')
args = parser.parse_args()
out = Path(__file__).resolve().parents[1] / 'web' / 'assets' / 'install-qr.png'
qr = qrcode.QRCode(version=None, error_correction=qrcode.constants.ERROR_CORRECT_H, box_size=12, border=3)
qr.add_data(args.url)
qr.make(fit=True)
img = qr.make_image(fill_color='black', back_color='white')
img.save(out)
print(f'QR generado: {out} -> {args.url}')
