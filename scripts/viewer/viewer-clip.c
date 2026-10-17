// viewer-clip MIME=FILE [MIME=FILE ...]
// Puts several formats of one thing on the Wayland clipboard at once (wl-copy can offer only one), over
// ext-data-control-v1, and serves them from the files until something else is copied. Backgrounds itself.
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <wayland-client.h>
#include "ext-data-control-v1-client-protocol.h"

static struct { const char *mime, *path; } item[8];
static int n, done;
static struct ext_data_control_manager_v1 *mgr;
static struct wl_seat *seat;

static void global(void *d, struct wl_registry *r, uint32_t name, const char *iface, uint32_t ver) {
    if (!strcmp(iface, ext_data_control_manager_v1_interface.name))
        mgr = wl_registry_bind(r, name, &ext_data_control_manager_v1_interface, 1);
    else if (!strcmp(iface, "wl_seat") && !seat)
        seat = wl_registry_bind(r, name, &wl_seat_interface, 1);
}
static void gone(void *d, struct wl_registry *r, uint32_t name) {}
static const struct wl_registry_listener reg = { global, gone };

static void send(void *d, struct ext_data_control_source_v1 *s, const char *mime, int fd) {
    for (int i = 0; i < n; i++) {
        if (strcmp(item[i].mime, mime)) continue;
        int in = open(item[i].path, O_RDONLY);
        char buf[65536];
        ssize_t k;
        while (in >= 0 && (k = read(in, buf, sizeof buf)) > 0)
            for (ssize_t off = 0; off < k;) { ssize_t w = write(fd, buf + off, k - off); if (w <= 0) goto out; off += w; }
    out:
        if (in >= 0) close(in);
        break;
    }
    close(fd);
}
static void cancelled(void *d, struct ext_data_control_source_v1 *s) { done = 1; }
static const struct ext_data_control_source_v1_listener src = { send, cancelled };

static void offer(void *d, struct ext_data_control_device_v1 *dev, struct ext_data_control_offer_v1 *o) { ext_data_control_offer_v1_destroy(o); }
static void sel(void *d, struct ext_data_control_device_v1 *dev, struct ext_data_control_offer_v1 *o) {}
static void fin(void *d, struct ext_data_control_device_v1 *dev) { done = 1; }
static const struct ext_data_control_device_v1_listener dl = { offer, sel, fin, sel };

int main(int argc, char **argv) {
    for (int i = 1; i < argc && n < 8; i++) {
        char *eq = strchr(argv[i], '=');
        if (!eq) continue;
        *eq = 0;
        item[n].mime = argv[i];
        item[n++].path = eq + 1;
    }
    if (!n) return 2;
    signal(SIGPIPE, SIG_IGN);
    struct wl_display *dpy = wl_display_connect(NULL);
    if (!dpy) { fprintf(stderr, "viewer-clip: no Wayland display\n"); return 1; }
    struct wl_registry *r = wl_display_get_registry(dpy);
    wl_registry_add_listener(r, &reg, NULL);
    wl_display_roundtrip(dpy);
    if (!mgr || !seat) { fprintf(stderr, "viewer-clip: no ext-data-control here\n"); return 1; }
    struct ext_data_control_source_v1 *s = ext_data_control_manager_v1_create_data_source(mgr);
    ext_data_control_source_v1_add_listener(s, &src, NULL);
    for (int i = 0; i < n; i++) ext_data_control_source_v1_offer(s, item[i].mime);
    struct ext_data_control_device_v1 *dev = ext_data_control_manager_v1_get_data_device(mgr, seat);
    ext_data_control_device_v1_add_listener(dev, &dl, NULL);
    ext_data_control_device_v1_set_selection(dev, s);
    wl_display_roundtrip(dpy);
    if (fork() > 0) _exit(0);
    setsid();
    int nul = open("/dev/null", O_RDWR);
    dup2(nul, 0); dup2(nul, 1); dup2(nul, 2);
    while (!done && wl_display_dispatch(dpy) != -1) {}
    return 0;
}
