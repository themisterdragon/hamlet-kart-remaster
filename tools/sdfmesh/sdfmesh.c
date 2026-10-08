// Turns the cast's sculpted models (the N64 edition's tools/characters.py)
// into triangle meshes for the remaster: samples the signed distance field
// on a grid, extracts the surface with surface nets, snaps each vertex onto
// the true surface, and gives it the sculpt's normal and blended colour.
// The distance code (Prim, sd_prim, scene, load) is the N64 edition's
// tools/sdfrender, unchanged, so the models match the sprites exactly.
//
// usage: sdfmesh scene.txt out.bin CELL
//   CELL  grid spacing in model units (smaller = finer, more triangles)
// out.bin: int nv, int ntri, then nv records of 10 floats
//   (x y z  nx ny nz  r g b  shine), then ntri*3 ints.
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { float x, y, z; } v3;
static v3 V(float x, float y, float z) { return (v3){x, y, z}; }
static v3 add(v3 a, v3 b) { return V(a.x + b.x, a.y + b.y, a.z + b.z); }
static v3 sub(v3 a, v3 b) { return V(a.x - b.x, a.y - b.y, a.z - b.z); }
static v3 mul(v3 a, float s) { return V(a.x * s, a.y * s, a.z * s); }
static float dot(v3 a, v3 b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
static float len(v3 a) { return sqrtf(dot(a, a)); }
static v3 norm(v3 a) { float l = len(a); return l > 0 ? mul(a, 1 / l) : a; }
static float clampf(float v, float a, float b) { return v < a ? a : v > b ? b : v; }
static float mixf(float a, float b, float t) { return a + (b - a) * t; }

typedef struct {
    int type, group, sub;
    float k, col[3], shine, emit;
    float m[9], t[3], p[8];
} Prim;
typedef struct { float c[3], r; int first, count; } Group;

static Prim *P; static int np;
static Group G[256]; static int ng;

static float sd_prim(const Prim *q, v3 w) {
    v3 d = V(w.x - q->t[0], w.y - q->t[1], w.z - q->t[2]);
    const float *m = q->m;
    v3 p = V(m[0] * d.x + m[3] * d.y + m[6] * d.z, m[1] * d.x + m[4] * d.y + m[7] * d.z, m[2] * d.x + m[5] * d.y + m[8] * d.z);
    const float *a = q->p;
    switch (q->type) {
    case 0: return len(p) - a[0];
    case 1: {  // ellipsoid (iq's bound)
        v3 r = V(a[0], a[1], a[2]);
        float k0 = len(V(p.x / r.x, p.y / r.y, p.z / r.z));
        float k1 = len(V(p.x / (r.x * r.x), p.y / (r.y * r.y), p.z / (r.z * r.z)));
        return k1 > 0 ? k0 * (k0 - 1) / k1 : -fminf(r.x, fminf(r.y, r.z));
    }
    case 2: {  // round cone between two points
        v3 A = V(a[0], a[1], a[2]), B = V(a[3], a[4], a[5]);
        float r1 = a[6], r2 = a[7];
        v3 ba = sub(B, A); float l2 = dot(ba, ba), rr = r1 - r2, a2 = l2 - rr * rr, il2 = 1 / l2;
        v3 pa = sub(p, A); float y = dot(pa, ba), z = y - l2;
        v3 xv = sub(mul(pa, l2), mul(ba, y)); float x2 = dot(xv, xv), y2 = y * y * l2, z2 = z * z * l2;
        float kk = copysignf(rr, rr) * rr * x2;
        if (copysignf(1, z) * a2 * z2 > kk) return sqrtf(x2 + z2) * il2 - r2;
        if (copysignf(1, y) * a2 * y2 < kk) return sqrtf(x2 + y2) * il2 - r1;
        return (sqrtf(x2 * a2 * il2) + y * rr) * il2 - r1;
    }
    case 3: {  // round box
        v3 q2 = V(fabsf(p.x) - a[0] + a[3], fabsf(p.y) - a[1] + a[3], fabsf(p.z) - a[2] + a[3]);
        v3 mx = V(fmaxf(q2.x, 0), fmaxf(q2.y, 0), fmaxf(q2.z, 0));
        return len(mx) + fminf(fmaxf(q2.x, fmaxf(q2.y, q2.z)), 0) - a[3];
    }
    case 4: {  // torus in the xz plane
        float qx = sqrtf(p.x * p.x + p.z * p.z) - a[0];
        return sqrtf(qx * qx + p.y * p.y) - a[1];
    }
    case 5: {  // rounded cylinder along y, centred
        float r = a[0], h = a[1] / 2, rd = a[2];
        float dx = sqrtf(p.x * p.x + p.z * p.z) - r + rd, dy = fabsf(p.y) - h + rd;
        return fminf(fmaxf(dx, dy), 0) + sqrtf(fmaxf(dx, 0) * fmaxf(dx, 0) + fmaxf(dy, 0) * fmaxf(dy, 0)) - rd;
    }
    }
    return 1e9f;
}

// the whole model: distance, and (if col) the blended colour and material
static float scene(v3 p, float *col, float *shine, float *emit, int *gid, float cutoff) {
    float best = 1e9f;
    for (int g = 0; g < ng; g++) {
        v3 c = V(G[g].c[0], G[g].c[1], G[g].c[2]);
        float bound = len(sub(p, c)) - G[g].r;
        if (bound > best || bound > cutoff) { if (bound < best) best = bound; continue; }
        float d = 1e9f, cc[3] = {0, 0, 0}, sh = 0, em = 0;
        for (int i = G[g].first; i < G[g].first + G[g].count; i++) {
            const Prim *q = &P[i];
            float e = sd_prim(q, p), k = fmaxf(q->k, 1e-4f);
            if (q->sub) {  // smooth subtraction: the cut takes the carving shape's colour
                float h = clampf(0.5f - 0.5f * (d + e) / k, 0, 1);
                float nd = mixf(d, -e, h) + k * h * (1 - h);
                if (col && h > 0.5f) { memcpy(cc, q->col, sizeof cc); sh = q->shine; em = q->emit; }
                d = nd;
            } else if (d >= 1e8f) {
                d = e; if (col) { memcpy(cc, q->col, sizeof cc); sh = q->shine; em = q->emit; }
            } else {  // smooth union, colours blended across the seam
                float h = clampf(0.5f + 0.5f * (e - d) / k, 0, 1);
                d = mixf(e, d, h) - k * h * (1 - h);
                if (col) {
                    float t = 1 - h;  // weight of the new shape
                    for (int j = 0; j < 3; j++) cc[j] = mixf(cc[j], q->col[j], t);
                    sh = mixf(sh, q->shine, t); em = mixf(em, q->emit, t);
                }
            }
        }
        if (d < best) {
            best = d;
            if (col) { memcpy(col, cc, sizeof cc); *shine = sh; *emit = em; *gid = g; }
        }
    }
    return best;
}

static float dist(v3 p) { return scene(p, NULL, NULL, NULL, NULL, 1e9f); }
static void load(const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) { perror(path); exit(1); }
    P = calloc(8192, sizeof(Prim));
    char line[1024];
    while (fgets(line, sizeof line, f)) {
        if (line[0] == 'G') {
            Group *g = &G[ng++];
            int id;
            sscanf(line + 1, "%d %f %f %f %f", &id, &g->c[0], &g->c[1], &g->c[2], &g->r);
            g->first = -1;
            continue;
        }
        float v[29]; int n = 0; char *c = line, *e;
        while (n < 29) { v[n] = strtof(c, &e); if (e == c) break; n++; c = e; }
        if (n < 29) continue;  // every line carries all 29 numbers
        Prim *q = &P[np];
        q->type = (int)v[0]; q->group = (int)v[1]; q->sub = (int)v[2]; q->k = v[3];
        memcpy(q->col, v + 4, 3 * sizeof(float)); q->shine = v[7]; q->emit = v[8];
        memcpy(q->m, v + 9, 9 * sizeof(float)); memcpy(q->t, v + 18, 3 * sizeof(float)); memcpy(q->p, v + 21, 8 * sizeof(float));
        np++;
    }
    fclose(f);
    // primitives come grouped in order
    for (int i = 0; i < np; i++) {
        Group *g = &G[P[i].group];
        if (g->first < 0) g->first = i;
        g->count++;
    }
}

static v3 grad(v3 p) {
    const float e = 0.02f;
    return norm(V(dist(add(p, V(e, 0, 0))) - dist(sub(p, V(e, 0, 0))),
                  dist(add(p, V(0, e, 0))) - dist(sub(p, V(0, e, 0))),
                  dist(add(p, V(0, 0, e))) - dist(sub(p, V(0, 0, e)))));
}

int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "usage: sdfmesh scene.txt out.bin CELL\n"); return 1; }
    load(argv[1]);
    float h = atof(argv[3]);
    // the bounding box of every group, with a cell of margin
    float lo[3] = {1e9f, 1e9f, 1e9f}, hi[3] = {-1e9f, -1e9f, -1e9f};
    for (int g = 0; g < ng; g++)
        for (int a = 0; a < 3; a++) {
            lo[a] = fminf(lo[a], G[g].c[a] - G[g].r);
            hi[a] = fmaxf(hi[a], G[g].c[a] + G[g].r);
        }
    int n[3];
    for (int a = 0; a < 3; a++) { lo[a] -= 2 * h; n[a] = (int)((hi[a] + 2 * h - lo[a]) / h) + 1; }
    long total = (long)n[0] * n[1] * n[2];
    float *d = malloc(sizeof(float) * total);
#define IDX(i, j, k) (((long)(k) * n[1] + (j)) * n[0] + (i))
    #pragma omp parallel for schedule(dynamic)
    for (int k = 0; k < n[2]; k++)
        for (int j = 0; j < n[1]; j++)
            for (int i = 0; i < n[0]; i++)
                d[IDX(i, j, k)] = scene(V(lo[0] + i * h, lo[1] + j * h, lo[2] + k * h), NULL, NULL, NULL, NULL, 2 * h);
    // one vertex per cell the surface passes through
    int *vid = malloc(sizeof(int) * total);
    float *vx = malloc(sizeof(float) * 10 * (total / 8 + 1024));
    int nv = 0;
    for (long c = 0; c < total; c++) vid[c] = -1;
    for (int k = 0; k < n[2] - 1; k++)
        for (int j = 0; j < n[1] - 1; j++)
            for (int i = 0; i < n[0] - 1; i++) {
                float cd[8]; int in = 0;
                for (int c = 0; c < 8; c++) {
                    cd[c] = d[IDX(i + (c & 1), j + ((c >> 1) & 1), k + ((c >> 2) & 1))];
                    in += cd[c] < 0;
                }
                if (in == 0 || in == 8) continue;
                // average of the crossings on the cell's 12 edges
                v3 s = V(0, 0, 0); int m = 0;
                for (int c = 0; c < 8; c++)
                    for (int b = 0; b < 3; b++) {
                        int o = c | (1 << b);
                        if (o == c) continue;
                        if ((cd[c] < 0) == (cd[o] < 0)) continue;
                        float t = cd[c] / (cd[c] - cd[o]);
                        v3 pc = V(c & 1, (c >> 1) & 1, (c >> 2) & 1), po = V(o & 1, (o >> 1) & 1, (o >> 2) & 1);
                        s = add(s, add(pc, mul(sub(po, pc), t)));
                        m++;
                    }
                s = mul(s, 1.0f / m);
                vid[IDX(i, j, k)] = nv;
                float *v = vx + 10 * nv++;
                v[0] = lo[0] + (i + s.x) * h; v[1] = lo[1] + (j + s.y) * h; v[2] = lo[2] + (k + s.z) * h;
            }
    // snap onto the true surface; normal and colour from the sculpt
    #pragma omp parallel for schedule(dynamic, 256)
    for (int q = 0; q < nv; q++) {
        float *v = vx + 10 * q;
        v3 p = V(v[0], v[1], v[2]);
        for (int it = 0; it < 3; it++) {
            float dd = dist(p);
            if (fabsf(dd) > h) break;
            p = sub(p, mul(grad(p), dd));
        }
        v3 nn = grad(p);
        float col[3], sh, em; int gid;
        scene(p, col, &sh, &em, &gid, 1e9f);
        v[0] = p.x; v[1] = p.y; v[2] = p.z;
        v[3] = nn.x; v[4] = nn.y; v[5] = nn.z;
        v[6] = fminf(col[0] + em, 1); v[7] = fminf(col[1] + em, 1); v[8] = fminf(col[2] + em, 1); v[9] = sh;
    }
    // a quad around every grid edge the surface crosses, wound outward
    int *tri = malloc(sizeof(int) * 6 * (long)nv * 3 + 64);
    int nt = 0;
    for (int k = 1; k < n[2] - 1; k++)
        for (int j = 1; j < n[1] - 1; j++)
            for (int i = 1; i < n[0] - 1; i++) {
                float d0 = d[IDX(i, j, k)];
                for (int a = 0; a < 3; a++) {
                    int di = a == 0, dj = a == 1, dk = a == 2;  // the edge's far end
                    float d1 = d[IDX(i + di, j + dj, k + dk)];
                    if ((d0 < 0) == (d1 < 0)) continue;
                    // the four cells sharing this edge: step back along the
                    // other two axes (u, w), in right-handed order with a
                    static const int U[3][3] = {{0, 1, 0}, {0, 0, 1}, {1, 0, 0}};
                    static const int W[3][3] = {{0, 0, 1}, {1, 0, 0}, {0, 1, 0}};
                    int c[4];
                    int ui = U[a][0], uj = U[a][1], uk = U[a][2], wi = W[a][0], wj = W[a][1], wk = W[a][2];
                    c[0] = vid[IDX(i, j, k)];
                    c[1] = vid[IDX(i - ui, j - uj, k - uk)];
                    c[2] = vid[IDX(i - ui - wi, j - uj - wj, k - uk - wk)];
                    c[3] = vid[IDX(i - wi, j - wj, k - wk)];
                    if (c[0] < 0 || c[1] < 0 || c[2] < 0 || c[3] < 0) continue;
                    if (d0 < 0) { int t = c[1]; c[1] = c[3]; c[3] = t; }
                    tri[3 * nt] = c[0]; tri[3 * nt + 1] = c[1]; tri[3 * nt + 2] = c[2]; nt++;
                    tri[3 * nt] = c[0]; tri[3 * nt + 1] = c[2]; tri[3 * nt + 2] = c[3]; nt++;
                }
            }
    FILE *f = fopen(argv[2], "wb");
    fwrite(&nv, 4, 1, f); fwrite(&nt, 4, 1, f);
    fwrite(vx, sizeof(float), 10L * nv, f);
    fwrite(tri, sizeof(int), 3L * nt, f);
    fclose(f);
    fprintf(stderr, "grid %dx%dx%d, %d vertices, %d triangles\n", n[0], n[1], n[2], nv, nt);
    return 0;
}
