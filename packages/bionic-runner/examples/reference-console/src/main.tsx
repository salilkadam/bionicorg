import * as React from "react";
import { createRoot } from "react-dom/client";

import { RunnerConsoleApp } from "@bionicai/bionic-runner/react";
import "@bionicai/bionic-runner/styles.css";

const root = document.getElementById("root");
if (root === null) throw new Error("Reference console root is missing.");
createRoot(root).render(<React.StrictMode><RunnerConsoleApp /></React.StrictMode>);
