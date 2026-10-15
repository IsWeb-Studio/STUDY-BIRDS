import { useCallback, useEffect, useRef, useState } from "react";
import type { SupportTicketItem } from "../types";
import { getErrorMessage } from "../utils/errors";

export function useSupportFeed(loader: () => Promise<SupportTicketItem[]>, failureMessage: string) {
  const [items, setItems] = useState<SupportTicketItem[]>([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const sequence = useRef(0);
  const inFlight = useRef(false);
  const openedHash = useRef("");
  const refresh = useCallback(async () => {
    const request = ++sequence.current;
    inFlight.current = true;
    try {
      const data = await loader();
      if (request === sequence.current) { setItems(data); setError(""); }
    } catch (issue) {
      if (request === sequence.current) setError(getErrorMessage(issue, failureMessage));
    } finally {
      if (request === sequence.current) { setLoading(false); inFlight.current = false; }
    }
  }, [loader, failureMessage]);
  useEffect(() => {
    void refresh();
    const update = () => { if (!document.hidden && !inFlight.current) void refresh(); };
    const interval = window.setInterval(update, 15000);
    window.addEventListener("focus", update);
    document.addEventListener("visibilitychange", update);
    return () => { sequence.current++; inFlight.current = false; window.clearInterval(interval); window.removeEventListener("focus", update); document.removeEventListener("visibilitychange", update); };
  }, [refresh]);
  useEffect(() => {
    const hash = window.location.hash;
    if (hash.startsWith("#ticket-") && openedHash.current !== hash) {
      const element = document.getElementById(hash.slice(1));
      if (element) { element.scrollIntoView({ block: "center" }); openedHash.current = hash; }
    }
  }, [items]);
  return { items, setItems, error, setError, loading, refresh };
}
