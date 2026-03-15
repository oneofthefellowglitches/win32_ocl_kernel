#define FIXED_ONE (1<<16)
#define FIXED_LN2 45426
#define BAILOUT_FP (4<<16)

typedef unsigned int uint;
typedef int fixed;

static inline fixed fixed_mul(fixed a, fixed b) { long t = (long)a * (long)b; return (fixed)(t >> 16); }
static inline fixed fixed_add(fixed a, fixed b) { return (fixed)(a + b); }
static inline fixed fixed_sub(fixed a, fixed b) { return (fixed)(a - b); }
static inline fixed fixed_div(fixed a, fixed b) { long t = ((long)a << 16); return (fixed)(t / (long)b); }

static fixed fixed_ln_inline(fixed x) {
  if (x <= 0) return (fixed)(-30 * 65536);
  int shift = 0;
  while (x < FIXED_ONE && shift > -20) { x <<= 1; --shift; }
  while (x >= (FIXED_ONE<<1) && shift < 20) { x >>= 1; ++shift; }
  fixed y = x - FIXED_ONE;
  fixed y2 = fixed_mul(y,y);
  fixed y3 = fixed_mul(y2,y);
  fixed y4 = fixed_mul(y3,y);
  const fixed c2 = 32768;
  const fixed c3 = 21845;
  const fixed c4 = 16384;
  fixed ln_mant = fixed_sub(fixed_add(fixed_sub(y, fixed_mul(c2, y2)), fixed_mul(c3, y3)), fixed_mul(c4, y4));
  fixed shift_ln2 = fixed_mul((fixed)(shift << 16), FIXED_LN2);
  return fixed_add(ln_mant, shift_ln2);
}

typedef struct { uchar r,g,b,a; } color24;

__kernel void julia_fixed(__global uint* out, int width, int height, int cx_fp, int cy_fp, 
                          int x_min_fp, int x_max_fp, int y_min_fp, int y_max_fp, 
                          int max_iter, int ln_ln_bailout_fp, __constant color24* pal) {
  size_t gid = get_global_id(0);
  if (gid >= (size_t)width * (size_t)height) return;

  int px = (int)(gid % (size_t)width);
  int py = (int)(gid / (size_t)width);

  fixed dx = fixed_div((fixed)(x_max_fp - x_min_fp), (fixed)((width > 1 ? width - 1 : 1) << 16));
  fixed dy = fixed_div((fixed)(y_max_fp - y_min_fp), (fixed)((height > 1 ? height - 1 : 1) << 16));

  fixed zx = (fixed)x_min_fp + fixed_mul((fixed)(px<<16), dx);
  fixed zy = (fixed)y_min_fp + fixed_mul((fixed)(py<<16), dy);

  fixed zx2 = fixed_mul(zx,zx); fixed zy2 = fixed_mul(zy,zy);
  int iter = 0;
  while (iter < max_iter && (fixed_add(zx2, zy2) <= BAILOUT_FP)) {
    fixed tmp_re = fixed_add(fixed_sub(zx2, zy2), (fixed)cx_fp);
    fixed tmp_im = fixed_add(fixed_mul(fixed_mul(zx, zy), (fixed)(2<<16)), (fixed)cy_fp);
    zx = tmp_re; zy = tmp_im;
    zx2 = fixed_mul(zx,zx); zy2 = fixed_mul(zy,zy);
    ++iter;
  }

  fixed smooth_fp;
  if (iter >= max_iter) smooth_fp = (fixed)(iter<<16);
  else {
    fixed mag2 = fixed_add(zx2, zy2);
    if (mag2 <= 0) smooth_fp = (fixed)(iter<<16);
    else {
      fixed ln_mag2 = fixed_ln_inline(mag2);
      fixed ln_abs = fixed_div(ln_mag2, (fixed)(2<<16)); 
      if (ln_abs <= 0) ln_abs = 65; 
      fixed ln_ln_abs = fixed_ln_inline(ln_abs);
      fixed numer = fixed_sub(ln_ln_abs, (fixed)ln_ln_bailout_fp);
      if (numer <= 0) smooth_fp = (fixed)((iter+1)<<16);
      else {
        fixed nu = fixed_div(numer, FIXED_LN2);
        smooth_fp = fixed_sub((fixed)((iter+1)<<16), nu);
      }
    }
  }

  fixed norm = fixed_div(smooth_fp, (fixed)(max_iter<<16));
  norm = clamp(norm, 0, FIXED_ONE);
  fixed pos_fp = fixed_mul(norm, (fixed)(8<<16));
  int idx = (int)(pos_fp >> 16); 
  fixed frac = (fixed)(pos_fp & 0xFFFF);
  if (idx < 0) { idx = 0; frac = 0; } if (idx >= 8) { idx = 7; frac = 0xFFFF; }

  color24 color_a = pal[idx];
  color24 color_b = pal[idx+1];
  int rr = (int)color_a.r + (((int)(color_b.r - color_a.r) * (int)frac) >> 16);
  int gg = (int)color_a.g + (((int)(color_b.g - color_a.g) * (int)frac) >> 16);
  int bb = (int)color_a.b + (((int)(color_b.b - color_a.b) * (int)frac) >> 16);

  out[gid] = (0xFFu<<24) | ((uint)(rr&255)<<16) | ((uint)(gg&255)<<8) | (uint)(bb&255);
}
