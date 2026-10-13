import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ConnectivityManager } from "./connectivity";

let navigatorOnline = true;
let backendUp = true;
let probes = 0;
let probeLatency = 0;

const make = () =>
  new ConnectivityManager({
    probe: async () => {
      probes += 1;
      if (probeLatency) await new Promise((r) => setTimeout(r, probeLatency));
      return backendUp;
    },
    isNavigatorOnline: () => navigatorOnline,
    offlineDebounceMs: 60,
    confirmDelayMs: 20,
    minRecoveryDelayMs: 40,
    maxRecoveryDelayMs: 120,
    random: () => 0.5,
  });

const wait = (ms: number) => new Promise((r) => setTimeout(r, ms));
const goOffline = () => {
  navigatorOnline = false;
  window.dispatchEvent(new Event("offline"));
};
const goOnline = () => {
  navigatorOnline = true;
  window.dispatchEvent(new Event("online"));
};

let manager: ConnectivityManager;
let reconnects = 0;

beforeEach(() => {
  navigatorOnline = true;
  backendUp = true;
  probes = 0;
  probeLatency = 0;
  reconnects = 0;
  manager = make();
  manager.onReconnected(() => {
    reconnects += 1;
  });
});

afterEach(() => manager.stop());

describe("ConnectivityManager", () => {
  it("opening without internet -> offline, no probe against a dead radio", async () => {
    navigatorOnline = false;
    backendUp = false;
    manager.start();
    await wait(150);
    expect(manager.getSnapshot().status).toBe("offline");
    expect(probes).toBe(0);
  });

  it("connected to Wi-Fi without real internet -> unreachable, not online", async () => {
    backendUp = false;
    manager.start();
    manager.reportFailure();
    await wait(150);
    expect(manager.getSnapshot().status).toBe("unreachable");
  });

  it("restoring internet after a long outage -> online and reconnect fires exactly once", async () => {
    manager.start();
    goOffline();
    await wait(150);
    expect(manager.getSnapshot().status).toBe("offline");
    await wait(300); // long outage, recovery checks keep it offline
    expect(manager.getSnapshot().status).toBe("offline");
    expect(reconnects).toBe(0);
    goOnline();
    await wait(150);
    expect(manager.getSnapshot().status).toBe("online");
    expect(reconnects).toBe(1);
  });

  it("recovers by itself from backend downtime using backoff probes", async () => {
    backendUp = false;
    manager.start();
    manager.reportFailure();
    await wait(150);
    expect(manager.getSnapshot().status).toBe("unreachable");
    backendUp = true;
    await wait(500);
    expect(manager.getSnapshot().status).toBe("online");
    expect(reconnects).toBe(1);
  });

  it("Wi-Fi -> mobile hand-over never flashes offline", async () => {
    manager.start();
    const seen: string[] = [];
    manager.subscribe(() => seen.push(manager.getSnapshot().status));
    goOffline();
    await wait(20);
    goOnline();
    await wait(250);
    expect(seen).toEqual([]);
    expect(manager.getSnapshot().status).toBe("online");
  });

  it("a single failed probe is not an outage", async () => {
    let calls = 0;
    const flaky = new ConnectivityManager({
      probe: async () => ++calls > 1,
      confirmDelayMs: 10,
      isNavigatorOnline: () => true,
    });
    flaky.start();
    flaky.reportFailure();
    await wait(100);
    expect(flaky.getSnapshot().status).toBe("online");
    flaky.stop();
  });

  it("rapid disconnect/reconnect storm: bounded probes, ends consistent", async () => {
    probeLatency = 30;
    manager.start();
    const before = probes;
    for (let i = 0; i < 20; i += 1) {
      goOffline();
      await wait(5);
      goOnline();
      await wait(5);
    }
    await wait(400);
    expect(manager.getSnapshot().status).toBe("online");
    expect(probes - before).toBeLessThan(20); // 20 flaps must not cost 20 probes
  });

  it("slow connection: concurrent checks share one probe", async () => {
    probeLatency = 120;
    manager.start();
    await wait(300);
    const before = probes;
    const [a, b] = await Promise.all([manager.checkNow(), manager.checkNow()]);
    expect(a && b).toBe(true);
    expect(probes - before).toBeLessThanOrEqual(1);
  });

  it("a successful real API call immediately clears unreachable", async () => {
    backendUp = false;
    manager.start();
    manager.reportFailure();
    await wait(150);
    expect(manager.getSnapshot().status).toBe("unreachable");
    manager.reportSuccess();
    expect(manager.getSnapshot().status).toBe("online");
    expect(reconnects).toBe(1);
  });

  it("Try Again reports the truth while offline", async () => {
    navigatorOnline = false;
    manager.start();
    expect(await manager.checkNow()).toBe(false);
    navigatorOnline = true;
    expect(await manager.checkNow()).toBe(true);
  });

  it("flapping is flagged as unstable", async () => {
    manager.start();
    for (let i = 0; i < 3; i += 1) {
      backendUp = false;
      await manager.checkNow();
      backendUp = true;
      await manager.checkNow();
    }
    expect(manager.getSnapshot().unstable).toBe(true);
  });

  it("stop() removes listeners and timers", async () => {
    backendUp = false;
    manager.start();
    manager.reportFailure();
    await wait(100);
    manager.stop();
    const at = probes;
    await wait(300);
    expect(probes).toBe(at);
  });
});

describe("timers", () => {
  it("uses fake timers without leaking (sanity)", () => {
    vi.useFakeTimers();
    vi.useRealTimers();
    expect(true).toBe(true);
  });
});
