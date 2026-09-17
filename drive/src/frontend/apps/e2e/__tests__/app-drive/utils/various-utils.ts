import { BrowserContext } from "@playwright/test";

export const grantClipboardPermissions = async (
  browserName: string,
  context: BrowserContext,
) => {
  if (browserName === "chromium" || browserName === "webkit") {
    await context.grantPermissions(["clipboard-read"]);
  }
};
