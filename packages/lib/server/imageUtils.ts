// Maximum allowed size for SVG data (5MB)
const MAX_SVG_SIZE = 5 * 1024 * 1024;

/**
 * Converts an SVG image to PNG format (simplified version without Sharp)
 * @param data Base64 encoded image data
 * @returns Base64 encoded PNG data or original data if not SVG
 */
export const convertSvgToPng = async (data: string) => {
  if (data.startsWith("data:image/svg+xml;base64,")) {
    try {
      const base64Data = data.replace(/^data:image\/svg\+xml;base64,/, "");
      const buffer = Buffer.from(base64Data, "base64");

      // Check if the SVG data exceeds the size limit
      if (buffer.length > MAX_SVG_SIZE) {
        throw new Error("SVG data exceeds maximum allowed size");
      }

      // For now, return the original SVG data since we can't convert without Sharp
      // In a production environment, you might want to use a different image processing library
      console.warn("SVG to PNG conversion disabled - returning original SVG data");
      return data;
    } catch (error) {
      console.error("Error processing SVG data", error);
      // Return a 1x1 transparent PNG as placeholder
      return "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=";
    }
  }
  return data;
};
