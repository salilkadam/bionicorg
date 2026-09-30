import { createRoot, type Root } from "react-dom/client";

export interface PaperclipReactRootHost {
  __bionicReactRoot?: Root;
}

type CreateRoot = (container: Parameters<typeof createRoot>[0]) => Root;

/**
 * Keep one React root per browser window even if Vite evaluates the entry
 * module more than once during a development reload.
 */
export function getOrCreatePaperclipReactRoot(
  host: object,
  container: Parameters<typeof createRoot>[0],
  create: CreateRoot = createRoot,
): Root {
  const rootHost = host as PaperclipReactRootHost;
  if (rootHost.__bionicReactRoot) return rootHost.__bionicReactRoot;

  const root = create(container);
  rootHost.__bionicReactRoot = root;
  return root;
}
