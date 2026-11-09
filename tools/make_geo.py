#!/usr/bin/env python3
"""Build coastline data for Silent Bearing 2 from Natural Earth (public domain).

Usage: python3 -I tools/make_geo.py <ne_50m_land.geojson> <ne_10m_land.geojson> <out_dir>

Writes:
  world.json       campaign-map land polygons as [lon, lat] (North Atlantic and Arctic)
  <mission>.json   local land polygons in km [east, north] around a mission origin
"""
import json, math, sys
sys.setrecursionlimit(20000)

MAP_BOX = (-84.0, 22.0, 64.0, 83.0)  # lon0, lat0, lon1, lat1
# Missions with land nearby: id, lat, lon (origin), half-size of the box in km.
MISSIONS = [
    ("us1", 36.95, -75.6, 70), ("us2", 32.0, -64.75, 60), ("us5", 63.70, -22.60, 60),
    ("us6", 68.2, 12.0, 70), ("us7", 71.6, 26.0, 70), ("su1", 69.40, 33.75, 50),
    ("su3", 70.05, 30.6, 60), ("su4", 69.80, 30.2, 50), ("su6", 63.70, -22.60, 60),
]
R = 6371.0


def rings(path):
    g = json.load(open(path))
    for f in g["features"]:
        geom = f["geometry"]
        polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
        for poly in polys:
            yield poly[0]


def clip(ring, box):
    x0, y0, x1, y1 = box
    def cut(pts, inside, inter):
        out = []
        for i in range(len(pts)):
            a, b = pts[i - 1], pts[i]
            ia, ib = inside(a), inside(b)
            if ib:
                if not ia:
                    out.append(inter(a, b))
                out.append(b)
            elif ia:
                out.append(inter(a, b))
        return out
    def ix(a, b, x):
        t = (x - a[0]) / (b[0] - a[0])
        return (x, a[1] + t * (b[1] - a[1]))
    def iy(a, b, y):
        t = (y - a[1]) / (b[1] - a[1])
        return (a[0] + t * (b[0] - a[0]), y)
    p = [tuple(q) for q in ring]
    for inside, inter in [(lambda q: q[0] >= x0, lambda a, b: ix(a, b, x0)), (lambda q: q[0] <= x1, lambda a, b: ix(a, b, x1)),
                          (lambda q: q[1] >= y0, lambda a, b: iy(a, b, y0)), (lambda q: q[1] <= y1, lambda a, b: iy(a, b, y1))]:
        if not p:
            break
        p = cut(p, inside, inter)
    return p


def simplify(pts, tol):
    if len(pts) < 4:
        return pts
    def rdp(a, b):
        ax, ay = pts[a]; bx, by = pts[b]
        dx, dy = bx - ax, by - ay
        L = math.hypot(dx, dy) or 1e-12
        best, idx = 0.0, -1
        for i in range(a + 1, b):
            px, py = pts[i]
            d = abs(dy * px - dx * py + bx * ay - by * ax) / L
            if d > best:
                best, idx = d, i
        if best > tol and idx > 0:
            return rdp(a, idx)[:-1] + rdp(idx, b)
        return [pts[a], pts[b]]
    # Closed rings: split at the point farthest from the start so neither half is degenerate.
    x0, y0 = pts[0]
    k = max(range(len(pts)), key=lambda i: (pts[i][0] - x0) ** 2 + (pts[i][1] - y0) ** 2)
    if k == 0 or k == len(pts) - 1:
        return rdp(0, len(pts) - 1)
    out = rdp(0, k)[:-1] + rdp(k, len(pts) - 1)
    if len(out) > 1 and out[0] == out[-1]:
        out = out[:-1]
    return out


def area(p):
    return abs(sum(p[i - 1][0] * p[i][1] - p[i][0] * p[i - 1][1] for i in range(len(p)))) * 0.5


def main():
    ne50, ne10, out = sys.argv[1], sys.argv[2], sys.argv[3]
    world = []
    for r in rings(ne50):
        c = clip(r, MAP_BOX)
        if len(c) < 3:
            continue
        s = simplify(c, 0.06)
        if len(s) >= 3 and area(s) > 0.02:
            world.append([[round(x, 2), round(y, 2)] for x, y in s])
    json.dump(world, open(f"{out}/world.json", "w"), separators=(",", ":"))
    print("world:", len(world), "polygons", sum(len(p) for p in world), "points")
    ten = list(rings(ne10))
    for mid, lat, lon, half in MISSIONS:
        dlat = half / 111.2
        dlon = half / (111.2 * math.cos(math.radians(lat)))
        box = (lon - dlon, lat - dlat, lon + dlon, lat + dlat)
        polys = []
        for r in ten:
            xs = [q[0] for q in r]; ys = [q[1] for q in r]
            if max(xs) < box[0] or min(xs) > box[2] or max(ys) < box[1] or min(ys) > box[3]:
                continue
            c = clip(r, box)
            if len(c) < 3:
                continue
            km = [((x - lon) * math.radians(1) * R * math.cos(math.radians(lat)), (y - lat) * math.radians(1) * R) for x, y in c]
            s = simplify(km, 0.25)
            if len(s) >= 3 and area(s) > 0.05:
                polys.append([[round(x, 2), round(y, 2)] for x, y in s])
        json.dump(polys, open(f"{out}/{mid}.json", "w"), separators=(",", ":"))
        print(mid, len(polys), "polygons", sum(len(p) for p in polys), "points")


if __name__ == "__main__":
    main()
