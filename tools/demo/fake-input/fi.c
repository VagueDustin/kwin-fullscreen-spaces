// Minimal org_kde_kwin_fake_input client for scripted demo recordings.
// Reads commands from stdin: "abs X Y", "move X1 Y1 X2 Y2 MS", "btn CODE 0|1", "key CODE 0|1", "sleep MS"
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <stdlib.h>
#include <wayland-client.h>
#include "fake-input.h"

static struct org_kde_kwin_fake_input *fi;
static FILE *trace; // FI_TRACE=file: logs "epoch x y" for every pointer position (to draw the cursor later)
static void at(double x, double y) {
    org_kde_kwin_fake_input_pointer_motion_absolute(fi, wl_fixed_from_double(x), wl_fixed_from_double(y));
    if (trace) { struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts); fprintf(trace, "%.4f %.1f %.1f\n", ts.tv_sec + ts.tv_nsec / 1e9, x, y); fflush(trace); }
}
static void reg(void *d, struct wl_registry *r, uint32_t name, const char *iface, uint32_t v) {
    if (!strcmp(iface, org_kde_kwin_fake_input_interface.name))
        fi = wl_registry_bind(r, name, &org_kde_kwin_fake_input_interface, v < 4 ? v : 4);
}
static void rem(void *d, struct wl_registry *r, uint32_t n) {}
static const struct wl_registry_listener rl = { reg, rem };

int main(void) {
    struct wl_display *dpy = wl_display_connect(NULL);
    if (!dpy) { fprintf(stderr, "no display\n"); return 1; }
    wl_registry_add_listener(wl_display_get_registry(dpy), &rl, NULL);
    wl_display_roundtrip(dpy);
    if (!fi) { fprintf(stderr, "no fake input\n"); return 1; }
    org_kde_kwin_fake_input_authenticate(fi, "demo", "recording");
    if (getenv("FI_TRACE")) trace = fopen(getenv("FI_TRACE"), "a");
    char line[256];
    while (fgets(line, sizeof line, stdin)) {
        double x, y, x2, y2; unsigned a, b; int ms;
        if (sscanf(line, "abs %lf %lf", &x, &y) == 2) {
            at(x, y);
        } else if (sscanf(line, "move %lf %lf %lf %lf %d", &x, &y, &x2, &y2, &ms) == 5) {
            int steps = ms / 16 > 0 ? ms / 16 : 1;
            for (int i = 1; i <= steps; i++) {
                double t = (double)i / steps; t = t * t * (3 - 2 * t); // smoothstep
                at(x + (x2 - x) * t, y + (y2 - y) * t);
                wl_display_flush(dpy); usleep(16000);
            }
        } else if (sscanf(line, "btn %u %u", &a, &b) == 2) {
            org_kde_kwin_fake_input_button(fi, a, b);
        } else if (sscanf(line, "key %u %u", &a, &b) == 2) {
            org_kde_kwin_fake_input_keyboard_key(fi, a, b);
        } else if (sscanf(line, "sleep %d", &ms) == 1) {
            wl_display_roundtrip(dpy); usleep(ms * 1000);
        }
        wl_display_roundtrip(dpy);
    }
    wl_display_roundtrip(dpy);
    return 0;
}
