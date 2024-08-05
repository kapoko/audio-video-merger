import type { ConfigEnv, UserConfig } from "vite";
import { viteStaticCopy } from "vite-plugin-static-copy"
import { defineConfig, mergeConfig } from "vite";
import {
    getBuildConfig,
    getBuildDefine,
    external,
    pluginHotRestart,
} from "./vite.base.config";

// https://vitejs.dev/config
export default defineConfig((env) => {
    const forgeEnv = env as ConfigEnv<"build">;
    const { forgeConfigSelf } = forgeEnv;
    const define = getBuildDefine(forgeEnv);
    const config: UserConfig = {
        build: {
            lib: {
                entry: forgeConfigSelf.entry!,
                fileName: () => "[name].js",
                formats: ["cjs"],
            },
            rollupOptions: {
                external,
            },
        },
        plugins: [
            pluginHotRestart("restart"),
            viteStaticCopy({
              targets: [
                {
                  src: "node_modules/ffmpeg-static/ffmpeg",
                  dest: "static",
                },
                {
                  src: `node_modules/ffprobe-static/bin/darwin/${process.arch}/ffprobe`,
                  dest: "static",
                },
              ],
            }),
        ],
        define,
        resolve: {
            // Load the Node.js entry.
            mainFields: ["module", "jsnext:main", "jsnext"],
        },
    };

    return mergeConfig(getBuildConfig(forgeEnv), config);
});
