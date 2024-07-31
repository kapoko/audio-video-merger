import { browser } from "@wdio/globals";
import { getSeconds, baseName } from "../../src/lib/helpers";

describe("Helpers", () => {
    it("getSeconds() should return false on invalid durationStrings", () => {
        expect(getSeconds("notADurationString")).toBe(false);
        expect(getSeconds("01:01:11")).toBe(false);
        expect(getSeconds("01:01:11.0")).toBe(false);
    });

    it("getSeconds() should return correct number of seconds", () => {
        expect(getSeconds("00:01:33.99")).toEqual(93);
        expect(getSeconds("01:02:34.01")).toEqual(3754);
        expect(getSeconds("11:13:56.49")).toEqual(40436);
    });

    it("baseName() should return filename with extension from path", () => {
        expect(baseName("/path/to/file.js")).toEqual("file.js");
    });
});
