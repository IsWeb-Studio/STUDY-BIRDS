/**
 * Single source of truth for "can the app really reach the backend?".
 *
 * - `navigator.onLine` only says a network interface exists. Going back to
 *   "online" therefore requires a successful probe of the API origin (or a
 *   real API call succeeding).
 * - "offline" is debounced and a failed probe must repeat before we report
 *   "unreachable", so brief fluctuations (Wi-Fi <-> mobile hand-over) never
 *   flash a banner.
 * - While online nothing is polled. Probes run on browser online/offline
 *   events, when the tab becomes visible after a while, and after a real
 *   request failed. While not online, recovery probes use exponential backoff
 *   with jitter and pause while the tab is hidden.
 * - The status never blocks requests; it only drives the UI and refreshes.
 */

export type NetworkStatus = "online" | "offline" | "unreachable";

export interface ConnectivitySnapshot {
  status: NetworkStatus;
  /** True when the link flapped several times in a short window. */
  unstable: boolean;
}

export interface ConnectivityOptions {
  probe: () => Promise<boolean>;
  isNavigatorOnline?: () => boolean;
  offlineDebounceMs?: number;
  confirmDelayMs?: number;
  minRecoveryDelayMs?: number;
  maxRecoveryDelayMs?: number;
  resumeProbeAfterMs?: number;
  random?: () => number;
}

type Listener = () => void;

export class ConnectivityManager {
  private status: NetworkStatus = "online";
  private snapshot: ConnectivitySnapshot = { status: "online", unstable: false };
  private listeners = new Set<Listener>();
  private reconnectListeners = new Set<() => void>();
  private transitions: number[] = [];
  private started = false;
  private hasInterface = true;
  private verifying: Promise<void> | null = null;
  private lastVerifyAt = 0;
  private recoveryAttempt = 0;
  private offlineTimer: ReturnType<typeof setTimeout> | undefined;
  private recoveryTimer: ReturnType<typeof setTimeout> | undefined;
  private hiddenAt: number | null = null;
  private teardown: Array<() => void> = [];

  private readonly probe: () => Promise<boolean>;
  private readonly isNavigatorOnline: () => boolean;
  private readonly offlineDebounceMs: number;
  private readonly confirmDelayMs: number;
  private readonly minRecoveryDelayMs: number;
  private readonly maxRecoveryDelayMs: number;
  private readonly resumeProbeAfterMs: number;
  private readonly random: () => number;

  constructor(options: ConnectivityOptions) {
    this.probe = options.probe;
    this.isNavigatorOnline = options.isNavigatorOnline ?? (() => (typeof navigator === "undefined" ? true : navigator.onLine !== false));
    this.offlineDebounceMs = options.offlineDebounceMs ?? 2000;
    this.confirmDelayMs = options.confirmDelayMs ?? 1500;
    this.minRecoveryDelayMs = options.minRecoveryDelayMs ?? 3000;
    this.maxRecoveryDelayMs = options.maxRecoveryDelayMs ?? 30000;
    this.resumeProbeAfterMs = options.resumeProbeAfterMs ?? 30000;
    this.random = options.random ?? Math.random;
  }

  // --- Public API ---------------------------------------------------------

  getSnapshot = (): ConnectivitySnapshot => this.snapshot;

  subscribe = (listener: Listener) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };

  /** Fires once each time the app goes from not-online to verified online. */
  onReconnected(listener: () => void) {
    this.reconnectListeners.add(listener);
    return () => {
      this.reconnectListeners.delete(listener);
    };
  }

  start() {
    if (this.started) return;
    this.started = true;
    if (typeof window !== "undefined") {
      const onOnline = () => this.handleInterface();
      const onOffline = () => this.handleInterface();
      const onVisibility = () => this.handleVisibility();
      window.addEventListener("online", onOnline);
      window.addEventListener("offline", onOffline);
      document.addEventListener("visibilitychange", onVisibility);
      this.teardown.push(
        () => window.removeEventListener("online", onOnline),
        () => window.removeEventListener("offline", onOffline),
        () => document.removeEventListener("visibilitychange", onVisibility)
      );
    }
    this.handleInterface(true);
  }

  stop() {
    this.started = false;
    this.teardown.forEach((fn) => fn());
    this.teardown = [];
    clearTimeout(this.offlineTimer);
    clearTimeout(this.recoveryTimer);
  }

  /** A real API call succeeded: strongest evidence of being online. */
  reportSuccess() {
    if (!this.started || this.status === "online") return;
    this.hasInterface = true;
    clearTimeout(this.offlineTimer);
    this.setStatus("online");
  }

  /** A real API call failed at the transport level: verify, do not assume. */
  reportFailure() {
    if (!this.started || this.status !== "online") return;
    if (Date.now() - this.lastVerifyAt < this.confirmDelayMs) return;
    void this.verify();
  }

  /** "Try again": verify now and return the truth. */
  async checkNow(): Promise<boolean> {
    this.hasInterface = this.isNavigatorOnline();
    if (!this.hasInterface) {
      this.setStatus("offline");
      return false;
    }
    await this.verify(true);
    return this.status === "online";
  }

  // --- Internals ----------------------------------------------------------

  private handleInterface(initial = false) {
    this.hasInterface = this.isNavigatorOnline();
    if (!this.hasInterface) {
      // Debounce: hand-overs briefly report offline.
      clearTimeout(this.offlineTimer);
      this.offlineTimer = setTimeout(() => {
        this.hasInterface = this.isNavigatorOnline();
        if (this.hasInterface) {
          void this.verify(true);
          return;
        }
        this.setStatus("offline");
        this.scheduleRecovery();
      }, this.offlineDebounceMs);
      return;
    }
    clearTimeout(this.offlineTimer);
    // At startup assume healthy; only verify if we are not already online.
    if (initial && this.status === "online") return;
    void this.verify(true);
  }

  private handleVisibility() {
    if (typeof document === "undefined") return;
    if (document.visibilityState === "hidden") {
      this.hiddenAt = Date.now();
      clearTimeout(this.recoveryTimer); // no background polling
      return;
    }
    const away = this.hiddenAt ? Date.now() - this.hiddenAt : 0;
    this.hiddenAt = null;
    if (this.status !== "online") {
      this.recoveryAttempt = 0;
      void this.checkNow();
    } else if (away >= this.resumeProbeAfterMs) {
      void this.verify(true);
    }
  }

  private verify(force = false): Promise<void> {
    if (this.verifying) return this.verifying; // single-flight
    if (!force && Date.now() - this.lastVerifyAt < this.confirmDelayMs) return Promise.resolve();
    this.verifying = this.doVerify().finally(() => {
      this.verifying = null;
    });
    return this.verifying;
  }

  private async doVerify() {
    let ok = await this.safeProbe();
    if (!ok) {
      // One failed probe is not an outage.
      await new Promise((resolve) => setTimeout(resolve, this.confirmDelayMs));
      ok = await this.safeProbe();
    }
    this.lastVerifyAt = Date.now();
    if (ok) {
      this.recoveryAttempt = 0;
      clearTimeout(this.recoveryTimer);
      this.setStatus("online");
    } else {
      this.setStatus(this.hasInterface ? "unreachable" : "offline");
      this.scheduleRecovery();
    }
  }

  private async safeProbe() {
    try {
      return await this.probe();
    } catch {
      return false;
    }
  }

  private scheduleRecovery() {
    clearTimeout(this.recoveryTimer);
    if (!this.started || this.status === "online") return;
    if (typeof document !== "undefined" && document.visibilityState === "hidden") return;
    const base = Math.min(this.minRecoveryDelayMs * 2 ** this.recoveryAttempt, this.maxRecoveryDelayMs);
    // Jitter 50-100% so many clients do not retry in lock-step.
    const delay = Math.round(base * (0.5 + this.random() / 2));
    if (this.recoveryAttempt < 10) this.recoveryAttempt += 1;
    this.recoveryTimer = setTimeout(() => {
      if (!this.started || this.status === "online") return;
      this.hasInterface = this.isNavigatorOnline();
      if (!this.hasInterface) {
        this.setStatus("offline");
        this.scheduleRecovery();
        return;
      }
      void this.verify(true);
    }, delay);
  }

  private setStatus(next: NetworkStatus) {
    if (next === this.status) return;
    const previous = this.status;
    this.status = next;
    const now = Date.now();
    this.transitions = [...this.transitions, now].slice(-8);
    const unstable = this.transitions.filter((t) => now - t < 30000).length >= 4;
    this.snapshot = { status: next, unstable };
    this.listeners.forEach((l) => l());
    if (previous !== "online" && next === "online") this.reconnectListeners.forEach((l) => l());
  }
}

let probeUrl = "";

/** Called once by the API layer so this module has no import cycle with it. */
export const configureConnectivity = (url: string) => {
  probeUrl = url;
};

const defaultProbe = async () => {
  if (!probeUrl) return true;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 6000);
  try {
    // no-cors: an opaque response still proves DNS + TLS + server are reachable.
    await fetch(probeUrl, { method: "HEAD", mode: "no-cors", cache: "no-store", signal: controller.signal });
    return true;
  } catch {
    return false;
  } finally {
    clearTimeout(timer);
  }
};

export const connectivity = new ConnectivityManager({ probe: defaultProbe });
