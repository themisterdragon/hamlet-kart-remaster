// Turns the cast's sculpted models (the N64 edition's tools/characters.py)
// into triangle meshes for the remaster: samples the signed distance field
// on a grid, extracts the surface with surface nets, snaps each vertex onto
// the true surface, and gives it the sculpt's normal and colour. Colours
// that differ get a crisp, smoothed border (triangles are cut along it);
// near-alike colours stay softly blended. Pieces sculpted apart meet with
// a fillet about a cell wide so joins don't zigzag. SDFMESH_JOIN=0 gives
// hard joins; SDFMESH_CHECK=1 prints how well the mesh fits.
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

// the whole model: distance, and (if col) the blended colour and material,
// and the primitive whose colour wins there (the crisp colour, see main)
// pieces sculpted apart (head, body, ruff) meet with a fillet about a grid
// cell wide, so the mesh can follow the join instead of zigzagging along a
// sharp inside corner (0: hard joins, as the N64 sprites had)
static float KG;

static float scene(v3 p, float *col, float *shine, float *emit, int *win, float cutoff) {
    float best = 1e9f, joined = 1e9f;
    for (int g = 0; g < ng; g++) {
        v3 c = V(G[g].c[0], G[g].c[1], G[g].c[2]);
        float bound = len(sub(p, c)) - G[g].r;
        if (bound > best + KG || bound > cutoff) {
            if (bound < best) best = bound;
            if (bound < joined) joined = bound;
            continue;
        }
        float d = 1e9f, cc[3] = {0, 0, 0}, sh = 0, em = 0; int w = -1;
        for (int i = G[g].first; i < G[g].first + G[g].count; i++) {
            const Prim *q = &P[i];
            float e = sd_prim(q, p), k = fmaxf(q->k, 1e-4f);
            if (q->sub) {  // smooth subtraction: the cut takes the carving shape's colour
                float h = clampf(0.5f - 0.5f * (d + e) / k, 0, 1);
                float nd = mixf(d, -e, h) + k * h * (1 - h);
                if (col && h > 0.5f) { memcpy(cc, q->col, sizeof cc); sh = q->shine; em = q->emit; w = i; }
                d = nd;
            } else if (d >= 1e8f) {
                d = e; if (col) { memcpy(cc, q->col, sizeof cc); sh = q->shine; em = q->emit; w = i; }
            } else {  // smooth union, colours blended across the seam
                float h = clampf(0.5f + 0.5f * (e - d) / k, 0, 1);
                d = mixf(e, d, h) - k * h * (1 - h);
                if (col) {
                    float t = 1 - h;  // weight of the new shape
                    for (int j = 0; j < 3; j++) cc[j] = mixf(cc[j], q->col[j], t);
                    sh = mixf(sh, q->shine, t); em = mixf(em, q->emit, t);
                    if (t > 0.5f) w = i;
                }
            }
        }
        if (d < best) {
            best = d;
            if (col) { memcpy(col, cc, sizeof cc); *shine = sh; *emit = em; *win = w; }
        }
        if (KG > 0 && joined < 1e8f) {
            float hh = clampf(0.5f + 0.5f * (d - joined) / KG, 0, 1);
            joined = mixf(d, joined, hh) - KG * hh * (1 - hh);
        } else if (d < joined) joined = d;
    }
    return KG > 0 ? fminf(joined, best) : best;
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

// --- crisp colours: every point of the surface takes the colour of the one
// primitive that wins there, and triangles are cut where that changes, so
// a ruff, a beard or a pair of spectacles has a clean edge instead of a
// colour smeared across the triangles between (and no flicker where two
// shapes nearly touch)

// each colour is the set of primitives that look alike (colour, shine, glow);
// a point of the surface belongs to the colour whose own shapes it lies
// closest to, so a border runs where two colours' distances are equal: a
// smooth line, even along a crease, found by interpolating that difference
static int *CLS; static int ncls;

// near enough that a soft blend between them looks right (two blues of
// the Ghost, skin and a blush): these share a colour and stay blended
static int alike(const Prim *a, const Prim *b) {
    float d = 0;
    for (int j = 0; j < 3; j++) d += (a->col[j] + a->emit - b->col[j] - b->emit) * (a->col[j] + a->emit - b->col[j] - b->emit);
    return d < 0.14f * 0.14f && fabsf(a->shine - b->shine) < 0.2f;
}

static void classes(void) {
    CLS = malloc(sizeof(int) * np);
    for (int i = 0; i < np; i++) {
        CLS[i] = -1;
        for (int j = 0; j < i && CLS[i] < 0; j++)
            if (alike(&P[i], &P[j])) CLS[i] = CLS[j];
        if (CLS[i] < 0) CLS[i] = ncls++;
    }
}

static int first_of(int c) { for (int i = 0; i < np; i++) if (CLS[i] == c) return i; return 0; }

// how near p lies to colour c's own shapes
static float score(v3 p, int c) {
    float b = 1e9f;
    for (int i = 0; i < np; i++)
        if (CLS[i] == c) b = fminf(b, fabsf(sd_prim(&P[i], p)));
    return b;
}

// the colour that shows at p: the sculpt's own blend decides (a shape
// hidden under another never shows through)
static int label(v3 p) {
    float col[3], sh, em; int w = -1;
    scene(p, col, &sh, &em, &w, 1e9f);
    return w < 0 ? 0 : CLS[w];
}

static int same(int a, int b) { return a == b; }

static v3 onto(v3 p, float h) {
    for (int it = 0; it < 4; it++) {
        float dd = dist(p);
        if (fabsf(dd) > h) break;
        p = sub(p, mul(grad(p), dd));
    }
    return p;
}

// where colour la gives way to lb between a and b, on the surface: where
// the two colours' distances cross, if they do; else halving the edge
static v3 crossing(v3 a, int la, v3 b, int lb, float h) {
    float ga = score(a, la) - score(a, lb), gb = score(b, la) - score(b, lb);
    if (ga < 0 && gb > 0) {
        v3 p = onto(add(a, mul(sub(b, a), clampf(ga / (ga - gb), 0.02f, 0.98f))), h);
        if (label(p) == la || label(p) == lb) return p;
    }
    float lo = 0, hi = 1;
    for (int it = 0; it < 9; it++) {
        float t = 0.5f * (lo + hi);
        if (label(onto(add(a, mul(sub(b, a), t)), h)) == la) lo = t; else hi = t;
    }
    return onto(add(a, mul(sub(b, a), 0.5f * (lo + hi))), h);
}

static float *VX; static int NV, CAPV;
static int *TR; static int NT, CAPT;

// a new vertex at p, coloured like vertex `like` (a corner on its side)
static int vert(v3 p, v3 n, int like) {
    if (NV == CAPV) { CAPV = CAPV * 2 + 1024; VX = realloc(VX, sizeof(float) * 10 * CAPV); }
    float *v = VX + 10 * NV;
    v[0] = p.x; v[1] = p.y; v[2] = p.z; v[3] = n.x; v[4] = n.y; v[5] = n.z;
    for (int j = 6; j < 10; j++) v[j] = VX[10 * like + j];
    return NV++;
}

static void tri3(int a, int b, int c) {
    if (NT == CAPT) { CAPT = CAPT * 2 + 1024; TR = realloc(TR, sizeof(int) * 3 * CAPT); }
    TR[3 * NT] = a; TR[3 * NT + 1] = b; TR[3 * NT + 2] = c; NT++;
}

// a fan over a convex polygon, keeping the triangle's winding
static void fan(const int *ring, int n) {
    for (int i = 1; i + 1 < n; i++) tri3(ring[0], ring[i], ring[i + 1]);
}

typedef struct { int a, b; v3 p, n; int va, vb; int nb[4], nn; float t; } Cross;  // va: the copy coloured like a, vb like b
static Cross *CX; static int NCX;
static int *HS; static long HCAP;

static long hkey(int a, int b) { unsigned long k = (unsigned long)a * 2654435761u ^ (unsigned long)b * 40503u; return (long)(k % HCAP); }

static int find_cross(int a, int b) {  // a < b
    for (long s = hkey(a, b);; s = (s + 1) % HCAP) {
        int c = HS[s];
        if (c < 0) return -(int)s - 1;
        if (CX[c].a == a && CX[c].b == b) return c;
    }
}

int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "usage: sdfmesh scene.txt out.bin CELL\n"); return 1; }
    load(argv[1]);
    classes();
    float h = atof(argv[3]);
    KG = getenv("SDFMESH_JOIN") ? atof(getenv("SDFMESH_JOIN")) * h : 1.2f * h;
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
    int *lab = malloc(sizeof(int) * (nv + 1));
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
        lab[q] = label(p);
        gid = first_of(lab[q]);
        v[0] = p.x; v[1] = p.y; v[2] = p.z;
        v[3] = nn.x; v[4] = nn.y; v[5] = nn.z;
        {  // a blend of unlike colours gives way to the winner's own (the cuts below make the edge)
            const Prim *w = &P[gid];
            float dd = 0;
            for (int j = 0; j < 3; j++) dd += (col[j] + em - w->col[j] - w->emit) * (col[j] + em - w->col[j] - w->emit);
            if (dd > 0.14f * 0.14f) {
                for (int j = 0; j < 3; j++) col[j] = w->col[j];
                sh = w->shine; em = w->emit;
            }
        }
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
    // cut the triangles where the colour changes: first find every edge
    // whose ends differ, and where along it the colour flips
    VX = vx; NV = nv; CAPV = (int)(total / 8 + 1024);
    HCAP = 4L * nt + 1024; HS = malloc(sizeof(int) * HCAP);
    for (long s2 = 0; s2 < HCAP; s2++) HS[s2] = -1;
    CX = malloc(sizeof(Cross) * (3L * nt + 16));
    for (int t = 0; t < nt; t++)
        for (int e = 0; e < 3; e++) {
            int a = tri[3 * t + e], b = tri[3 * t + (e + 1) % 3];
            if (same(lab[a], lab[b])) continue;
            if (a > b) { int x = a; a = b; b = x; }
            int c = find_cross(a, b);
            if (c >= 0) continue;
            HS[-c - 1] = NCX;
            CX[NCX].a = a; CX[NCX].b = b; NCX++;
        }
    #pragma omp parallel for schedule(dynamic, 64)
    for (int c = 0; c < NCX; c++) {
        float *A = vx + 10 * CX[c].a, *B = vx + 10 * CX[c].b;
        CX[c].p = crossing(V(A[0], A[1], A[2]), lab[CX[c].a], V(B[0], B[1], B[2]), lab[CX[c].b], h);
        CX[c].n = grad(CX[c].p);
    }
    // smooth each border: a cut point slides along its edge toward the middle
    // of its two neighbours on the border, so one vertex of the other colour
    // makes no tooth and a border at a join doesn't zigzag
    for (int c = 0; c < NCX; c++) CX[c].nn = 0;
    for (int t = 0; t < nt; t++) {
        int v[3] = {tri[3 * t], tri[3 * t + 1], tri[3 * t + 2]}, x[3], k = 0;
        int l0 = lab[v[0]], l1 = lab[v[1]], l2 = lab[v[2]];
        if ((l0 == l1) + (l1 == l2) + (l2 == l0) != 1) continue;  // one colour, or three
        for (int e = 0; e < 3; e++) {
            int a = v[e], b = v[(e + 1) % 3];
            if (lab[a] != lab[b]) x[k++] = find_cross(a < b ? a : b, a < b ? b : a);
        }
        for (int i = 0; i < 2; i++) {
            Cross *c = &CX[x[i]];
            if (c->nn < 4) c->nb[c->nn++] = x[1 - i];
        }
    }
    for (int c = 0; c < NCX; c++) {
        float *A = vx + 10 * CX[c].a, *B = vx + 10 * CX[c].b;
        v3 a = V(A[0], A[1], A[2]), ab = sub(V(B[0], B[1], B[2]), a);
        CX[c].t = clampf(dot(sub(CX[c].p, a), ab) / dot(ab, ab), 0.02f, 0.98f);
    }
    float *nt_ = malloc(sizeof(float) * (NCX + 1));
    for (int it = 0; it < 6; it++) {
        #pragma omp parallel for schedule(static)
        for (int c = 0; c < NCX; c++) {
            Cross *x = &CX[c];
            nt_[c] = x->t;
            if (x->nn != 2) continue;  // a border's end, or a tangle: stays put
            float *A = vx + 10 * x->a, *B = vx + 10 * x->b;
            v3 a = V(A[0], A[1], A[2]), ab = sub(V(B[0], B[1], B[2]), a);
            v3 m = V(0, 0, 0);
            for (int j = 0; j < 2; j++) {
                Cross *y = &CX[x->nb[j]];
                float *YA = vx + 10 * y->a, *YB = vx + 10 * y->b;
                v3 ya = V(YA[0], YA[1], YA[2]);
                m = add(m, mul(add(ya, mul(sub(V(YB[0], YB[1], YB[2]), ya), y->t)), 0.5f));
            }
            float want = clampf(dot(sub(m, a), ab) / dot(ab, ab), 0.02f, 0.98f);
            nt_[c] = x->t + 0.6f * (want - x->t);
        }
        for (int c = 0; c < NCX; c++) CX[c].t = nt_[c];
    }
    free(nt_);
    #pragma omp parallel for schedule(dynamic, 64)
    for (int c = 0; c < NCX; c++) {
        float *A = vx + 10 * CX[c].a, *B = vx + 10 * CX[c].b;
        v3 a = V(A[0], A[1], A[2]);
        CX[c].p = onto(add(a, mul(sub(V(B[0], B[1], B[2]), a), CX[c].t)), h);
        CX[c].n = grad(CX[c].p);
    }
    for (int c = 0; c < NCX; c++) {  // a copy in each colour
        CX[c].va = vert(CX[c].p, CX[c].n, CX[c].a);
        CX[c].vb = vert(CX[c].p, CX[c].n, CX[c].b);
    }
    int split = 0;
    for (int t = 0; t < nt; t++) {
        int v[3] = {tri[3 * t], tri[3 * t + 1], tri[3 * t + 2]};
        int l[3] = {lab[v[0]], lab[v[1]], lab[v[2]]};
        int s01 = same(l[0], l[1]), s12 = same(l[1], l[2]), s20 = same(l[2], l[0]);
        if (s01 && s12) { tri3(v[0], v[1], v[2]); continue; }
        split++;
        // the crossing on edge i (from corner i to i+1): its copy for colour of corner `side`
        #define XV(i, side) ({ int _a = v[i], _b = v[((i) + 1) % 3]; int _lo = _a < _b ? _a : _b, _hi = _a < _b ? _b : _a; \
            Cross *_x = &CX[find_cross(_lo, _hi)]; same(lab[_x->a], l[side]) ? _x->va : _x->vb; })
        if (!s01 && !s12 && !s20) {  // three colours: each corner takes a quarter round the middle
            v3 m = V(0, 0, 0);
            for (int i = 0; i < 3; i++) {
                int a = v[i], b = v[(i + 1) % 3];
                Cross *x = &CX[find_cross(a < b ? a : b, a < b ? b : a)];
                m = add(m, mul(x->p, 1.0f / 3));
            }
            m = onto(m, h);
            v3 mn = grad(m);
            for (int i = 0; i < 3; i++) {
                int ring[4] = {v[i], XV(i, i), vert(m, mn, v[i]), XV((i + 2) % 3, i)};
                fan(ring, 4);
            }
            continue;
        }
        // two colours: walk round the triangle, each colour takes its own
        // corners and the crossings on its sides (a triangle and a quad)
        int other = s01 ? 2 : 1;  // a corner of the second colour
        for (int pass = 0; pass < 2; pass++) {
            int want = pass ? other : 0;
            int ring[5], n = 0;
            for (int i = 0; i < 3; i++) {
                int j = (i + 1) % 3;
                if (same(l[i], l[want])) ring[n++] = v[i];
                if (!same(l[i], l[j])) ring[n++] = XV(i, want);
            }
            fan(ring, n);
        }
        #undef XV
    }
    if (getenv("SDFMESH_CHECK")) {  // (test) how far vertices sit off the surface
        int bad = 0; float worst = 0;
        for (int q = 0; q < NV; q++) {
            float e = fabsf(dist(V(VX[10 * q], VX[10 * q + 1], VX[10 * q + 2])));
            if (e > 0.1f * h) bad++;
            if (e > worst) worst = e;
        }
        int far = 0; float fw = 0;
        for (int c = 0; c < NCX; c++) {
            float *A = VX + 10 * CX[c].a, *B = VX + 10 * CX[c].b;
            v3 a = V(A[0], A[1], A[2]), b = V(B[0], B[1], B[2]);
            float e = fminf(len(sub(CX[c].p, a)), len(sub(CX[c].p, b))) / len(sub(b, a));
            float l = len(sub(CX[c].p, a)) + len(sub(CX[c].p, b)) - len(sub(b, a));
            if (l > 0.5f * h) far++;
            if (l > fw) fw = l;
            (void)e;
        }
        fprintf(stderr, "crossings off their edge: %d of %d (worst detour %.2f)\n", far, NCX, fw);
        int lng = 0;
        for (int t = 0; t < NT; t++)
            for (int e = 0; e < 3; e++) {
                float *A = VX + 10 * TR[3 * t + e], *B = VX + 10 * TR[3 * t + (e + 1) % 3];
                if (len(V(A[0] - B[0], A[1] - B[1], A[2] - B[2])) > 2.5f * h) { lng++; break; }
            }
        fprintf(stderr, "long triangles: %d of %d\n", lng, NT);
        fprintf(stderr, "off the surface: %d of %d (worst %.3f, %d made at cuts)\n", bad, NV, worst, NV - nv);
    }
    FILE *f = fopen(argv[2], "wb");
    fwrite(&NV, 4, 1, f); fwrite(&NT, 4, 1, f);
    fwrite(VX, sizeof(float), 10L * NV, f);
    fwrite(TR, sizeof(int), 3L * NT, f);
    fclose(f);
    fprintf(stderr, "grid %dx%dx%d, %d vertices, %d triangles (%d cut by colour)\n", n[0], n[1], n[2], NV, NT, split);
    return 0;
}
