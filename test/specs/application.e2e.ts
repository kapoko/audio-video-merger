import { browser, expect } from "@wdio/globals";

describe("Electron", () => {
  it("should have correct application title", async () => {
    expect(await browser.getTitle()).toEqual("Audio Video Merger");
  });
});
