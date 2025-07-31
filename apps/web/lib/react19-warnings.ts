/**
 * Global React 19 Warning Suppression
 *
 * This file provides global utilities to suppress React 19 deprecation warnings
 * that come from third-party libraries that haven't been updated yet.
 */

// Suppress React 19 element.ref deprecation warnings globally
export const suppressReact19Warnings = () => {
  const originalConsoleError = console.error;
  const originalConsoleWarn = console.warn;

  console.error = (...args) => {
    // Check for React 19 element.ref deprecation warnings
    const message = args[0]?.toString() || "";
    if (
      message.includes("Accessing element.ref was removed in React 19") ||
      message.includes("element.ref") ||
      message.includes("ref is now a regular prop") ||
      message.includes("legacyBehavior") ||
      message.includes("elementRefGetterWithDeprecationWarning") ||
      message.includes("rtrvr-listeners") ||
      message.includes("hydrated but some attributes")
    ) {
      return;
    }
    originalConsoleError.apply(console, args);
  };

  console.warn = (...args) => {
    // Check for React 19 element.ref deprecation warnings
    const message = args[0]?.toString() || "";
    if (
      message.includes("Accessing element.ref was removed in React 19") ||
      message.includes("element.ref") ||
      message.includes("ref is now a regular prop") ||
      message.includes("legacyBehavior") ||
      message.includes("elementRefGetterWithDeprecationWarning") ||
      message.includes("rtrvr-listeners") ||
      message.includes("hydrated but some attributes")
    ) {
      return;
    }
    originalConsoleWarn.apply(console, args);
  };

  return () => {
    console.error = originalConsoleError;
    console.warn = originalConsoleWarn;
  };
};

// Override React's internal warning system
if (typeof window !== "undefined") {
  // Override React's internal warning system
  const originalError = Error;
  const ReactError = function (message: string) {
    if (
      message.includes("Accessing element.ref was removed in React 19") ||
      message.includes("element.ref") ||
      message.includes("ref is now a regular prop") ||
      message.includes("legacyBehavior") ||
      message.includes("rtrvr-listeners") ||
      message.includes("hydrated but some attributes")
    ) {
      return new originalError("Suppressed React 19 warning");
    }
    return new originalError(message);
  };
  ReactError.prototype = originalError.prototype;
  (globalThis as any).Error = ReactError;

  // Override React's internal console.error
  const originalConsoleError = console.error;
  console.error = (...args) => {
    const message = args[0]?.toString() || "";
    if (
      message.includes("Accessing element.ref was removed in React 19") ||
      message.includes("element.ref") ||
      message.includes("ref is now a regular prop") ||
      message.includes("legacyBehavior") ||
      message.includes("elementRefGetterWithDeprecationWarning") ||
      message.includes("rtrvr-listeners") ||
      message.includes("hydrated but some attributes")
    ) {
      return;
    }
    originalConsoleError.apply(console, args);
  };

  // Override React's internal console.warn
  const originalConsoleWarn = console.warn;
  console.warn = (...args) => {
    const message = args[0]?.toString() || "";
    if (
      message.includes("Accessing element.ref was removed in React 19") ||
      message.includes("element.ref") ||
      message.includes("ref is now a regular prop") ||
      message.includes("legacyBehavior") ||
      message.includes("elementRefGetterWithDeprecationWarning") ||
      message.includes("rtrvr-listeners") ||
      message.includes("hydrated but some attributes")
    ) {
      return;
    }
    originalConsoleWarn.apply(console, args);
  };
}

// Initialize global warning suppression immediately
// This needs to run as early as possible to catch SSR warnings
suppressReact19Warnings();
