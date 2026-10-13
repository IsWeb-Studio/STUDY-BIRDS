import { useSyncExternalStore } from "react";
import { connectivity } from "../lib/connectivity";

export const useConnectivity = () => useSyncExternalStore(connectivity.subscribe, connectivity.getSnapshot, connectivity.getSnapshot);
