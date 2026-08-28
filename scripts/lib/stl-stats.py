#!/usr/bin/env python3
"""Report triangle count and connected-component count for a binary STL.

Component count is the interesting number: a decorative feature unioned onto a
perforated panel is only actually attached if the result stays a single body. STL
carries no topology, so components are recovered by welding coincident vertices.

Usage: stl-stats.py <file.stl>   ->   "<triangles> <components>"
"""

import struct
import sys

# Vertex coordinates are rounded before welding: OpenSCAD emits float32, so two
# triangles meeting at one corner can disagree in the last bit.
PRECISION = 4


def read_triangles(path):
    with open(path, "rb") as handle:
        handle.read(80)
        (count,) = struct.unpack("<I", handle.read(4))
        triangles = []
        for _ in range(count):
            record = handle.read(50)
            if len(record) < 50:
                raise ValueError(f"{path}: truncated at triangle {len(triangles)}")
            values = struct.unpack("<12f", record[:48])
            triangles.append(
                tuple(
                    tuple(round(values[i + k], PRECISION) for k in range(3))
                    for i in (3, 6, 9)
                )
            )
    return triangles


def count_components(triangles):
    parent = {}

    def find(vertex):
        while parent[vertex] != vertex:
            parent[vertex] = parent[parent[vertex]]
            vertex = parent[vertex]
        return vertex

    def union(a, b):
        root_a, root_b = find(a), find(b)
        if root_a != root_b:
            parent[root_a] = root_b

    for triangle in triangles:
        for vertex in triangle:
            parent.setdefault(vertex, vertex)
    for triangle in triangles:
        union(triangle[0], triangle[1])
        union(triangle[1], triangle[2])

    return len({find(vertex) for vertex in parent})


def main():
    if len(sys.argv) != 2:
        print("usage: stl-stats.py <file.stl>", file=sys.stderr)
        return 2
    triangles = read_triangles(sys.argv[1])
    if not triangles:
        print("0 0")
        return 0
    print(f"{len(triangles)} {count_components(triangles)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
