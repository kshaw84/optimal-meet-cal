/**
 * React 19 Compatibility Utilities
 *
 * This file provides utilities to handle React 19 deprecation warnings
 * and compatibility issues with third-party libraries.
 */
import React from "react";

// Suppress React 19 element.ref deprecation warnings
export const suppressReact19RefWarnings = () => {
  const originalConsoleError = console.error;
  console.error = (...args) => {
    // Check for React 19 element.ref deprecation warnings
    const message = args[0]?.toString() || "";
    if (
      message.includes("Accessing element.ref was removed in React 19") ||
      message.includes("element.ref") ||
      message.includes("ref is now a regular prop") ||
      message.includes("elementRefGetterWithDeprecationWarning")
    ) {
      return;
    }
    originalConsoleError.apply(console, args);
  };

  return () => {
    console.error = originalConsoleError;
  };
};

// React 19 compatible Slot wrapper
export const React19CompatibleSlot = ({ children, ...props }: any) => {
  const restoreConsole = suppressReact19RefWarnings();

  try {
    // If children is a function, call it with the props
    if (typeof children === "function") {
      return children(props);
    }

    // If children is a React element, clone it with the props
    if (children && typeof children === "object" && children.props) {
      return React.cloneElement(children, props);
    }

    return children;
  } finally {
    restoreConsole();
  }
};

// Global React 19 compatibility patch
export const patchReact19Compatibility = () => {
  if (typeof window === "undefined") return;

  // Override console.error globally
  const originalConsoleError = console.error;
  console.error = (...args) => {
    const message = args[0]?.toString() || "";
    if (
      message.includes("Accessing element.ref was removed in React 19") ||
      message.includes("element.ref") ||
      message.includes("ref is now a regular prop") ||
      message.includes("elementRefGetterWithDeprecationWarning") ||
      message.includes("legacyBehavior")
    ) {
      return;
    }
    originalConsoleError.apply(console, args);
  };

  // Override console.warn globally
  const originalConsoleWarn = console.warn;
  console.warn = (...args) => {
    const message = args[0]?.toString() || "";
    if (
      message.includes("Accessing element.ref was removed in React 19") ||
      message.includes("element.ref") ||
      message.includes("ref is now a regular prop") ||
      message.includes("elementRefGetterWithDeprecationWarning") ||
      message.includes("legacyBehavior")
    ) {
      return;
    }
    originalConsoleWarn.apply(console, args);
  };
};

// Initialize the patch immediately
patchReact19Compatibility();
