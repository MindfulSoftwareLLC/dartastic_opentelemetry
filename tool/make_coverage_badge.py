#!/usr/bin/env python3
"""Generate a shields-style coverage badge SVG from an lcov tracefile.

Usage: make_coverage_badge.py <lcov.info> <out.svg>

Self-hosted replacement for the codecov badge: CI runs this against
coverage/lcov.info and publishes the SVG to the `badges` branch, which
the README references via raw.githubusercontent.com.
"""

import sys


def line_rate(lcov_path):
    total = hit = 0
    with open(lcov_path) as f:
        for line in f:
            if line.startswith('DA:'):
                total += 1
                if int(line.strip().split(',')[1]) > 0:
                    hit += 1
    if total == 0:
        raise SystemExit(f'no DA records found in {lcov_path}')
    return 100.0 * hit / total


def color_for(pct):
    if pct >= 96:
        return '#4c1'  # brightgreen
    if pct >= 90:
        return '#97ca00'  # green
    if pct >= 75:
        return '#dfb317'  # yellow
    return '#e05d44'  # red


def badge(label, value, color):
    # Shields "flat" look: 6.5px per character plus 10px padding per side.
    lw = round(len(label) * 6.5) + 20
    vw = round(len(value) * 6.5) + 20
    w = lw + vw
    lx = lw * 5  # text coordinates are in 10x scale units
    vx = lw * 10 + vw * 5
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="20" role="img" aria-label="{label}: {value}">
  <title>{label}: {value}</title>
  <linearGradient id="s" x2="0" y2="100%">
    <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1" stop-opacity=".1"/>
  </linearGradient>
  <clipPath id="r"><rect width="{w}" height="20" rx="3" fill="#fff"/></clipPath>
  <g clip-path="url(#r)">
    <rect width="{lw}" height="20" fill="#555"/>
    <rect x="{lw}" width="{vw}" height="20" fill="{color}"/>
    <rect width="{w}" height="20" fill="url(#s)"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" font-size="110" text-rendering="geometricPrecision">
    <text x="{lx}" y="150" transform="scale(.1)" fill="#010101" fill-opacity=".3">{label}</text>
    <text x="{lx}" y="140" transform="scale(.1)">{label}</text>
    <text x="{vx}" y="150" transform="scale(.1)" fill="#010101" fill-opacity=".3">{value}</text>
    <text x="{vx}" y="140" transform="scale(.1)">{value}</text>
  </g>
</svg>
'''


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    pct = line_rate(sys.argv[1])
    value = f'{pct:.1f}%'.replace('.0%', '%')
    with open(sys.argv[2], 'w') as f:
        f.write(badge('coverage', value, color_for(pct)))
    print(f'coverage {value} -> {sys.argv[2]}')


if __name__ == '__main__':
    main()
